package io.busystack.busydata.transfers;

import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.Values;
import com.google.gson.JsonPrimitive;
import java.io.*;
import java.sql.*;
import java.util.*;

/** Encodes the current JDBC row directly. No retained result or whole-row copy. */
final class ExportEncoder {
    private final Writer output;private final ToolRequest request;private final Jobs.Job job;
    private final List<Column> columns;private final boolean csv,lines;private final char delimiter;
    ExportEncoder(Writer output,ToolRequest request,Jobs.Job job,List<Column> columns){
        this.output=output;this.request=request;this.job=job;this.columns=columns;
        csv=Set.of("csv","tsv").contains(request.getFormat());lines=request.getFormat().equals("ndjson");
        if(!csv&&!lines&&!request.getFormat().equals("json"))throw new IllegalArgumentException("Choose CSV, TSV, JSON, or NDJSON");
        delimiter=CsvContract.delimiter(request);
        if(!csv&&columns.stream().map(Column::getName).distinct().count()!=columns.size())throw new IllegalArgumentException("JSON object export requires unique result labels; choose CSV or alias duplicate labels");
    }
    void begin()throws Exception{
        if(csv){for(int i=0;i<columns.size();i++){if(i>0)output.write(delimiter);quoted(columns.get(i).getName(),false);}output.write('\n');}
        else if(!lines)output.write("[\n");
    }
    void row(ResultSet rows,long ordinal)throws Exception{
        if(!csv){if(!lines&&ordinal>0)output.write(",\n");output.write('{');}
        for(int i=0;i<columns.size();i++){
            job.checkCancel();if(i>0)output.write(csv?delimiter:',');
            if(!csv){output.write(new JsonPrimitive(columns.get(i).getName()).toString());output.write(':');}
            cell(rows,i+1,columns.get(i));
        }
        output.write(csv?'\n':'}');if(!csv&&lines)output.write('\n');
    }
    void end()throws IOException{if(!csv&&!lines)output.write("\n]\n");}
    private void cell(ResultSet rows,int ordinal,Column column)throws Exception{
        int type=column.getJdbcType();
        if(Set.of(Types.BINARY,Types.VARBINARY,Types.LONGVARBINARY,Types.BLOB).contains(type)){
            try(var input=rows.getBinaryStream(ordinal)){
                if(input==null){nil();return;}output.write('"');byte[] buffer=new byte[8192];int length;long bytes=0;
                while((length=input.read(buffer))!=-1){job.checkCancel();if((bytes+=length)>16L*1024*1024)throw new IOException("Export binary cell exceeds 16MiB; select a bounded projection");output.write(HexFormat.of().formatHex(buffer,0,length));}output.write('"');return;
            }
        }
        if(Set.of(Types.CHAR,Types.VARCHAR,Types.LONGVARCHAR,Types.NCHAR,Types.NVARCHAR,Types.LONGNVARCHAR,Types.CLOB,Types.NCLOB,Types.OTHER).contains(type)){
            try(var input=rows.getCharacterStream(ordinal)){
                if(input==null){nil();return;}
                boolean rawJson=!csv&&Set.of("json","jsonb").contains(column.getTypeName().toLowerCase(Locale.ROOT));
                if(!rawJson)output.write('"');char[] buffer=new char[8192];int length;long characters=0;
                while((length=input.read(buffer))!=-1){job.checkCancel();if((characters+=length)>8L*1024*1024)throw new IOException("Export text cell exceeds 8Mi UTF-16 units; select a bounded projection");for(int i=0;i<length;i++)escape(buffer[i],!csv,rawJson);}
                if(!rawJson)output.write('"');return;
            }
        }
        var value=Values.value(rows,ordinal,column);
        if(value.getTruncated())throw new IllegalArgumentException("Full structured value unavailable; select an explicit textual projection");
        if(value.hasNullValue()){nil();return;}
        if(csv)quoted(Values.text(value),false);else output.write(Transfers.json(value).toString());
    }
    private void nil()throws IOException{output.write(csv?CsvContract.marker(request):"null");}
    private void quoted(String value,boolean json)throws IOException{output.write('"');for(int i=0;i<value.length();i++)escape(value.charAt(i),json,false);output.write('"');}
    private void escape(char character,boolean json,boolean raw)throws IOException{
        if(raw){output.write(character);return;}
        if(!json){if(character=='"')output.write('"');output.write(character);return;}
        switch(character){case '"'->output.write("\\\"");case '\\'->output.write("\\\\");case '\n'->output.write("\\n");case '\r'->output.write("\\r");case '\t'->output.write("\\t");default->{if(character<32)output.write(String.format("\\u%04x",(int)character));else output.write(character);}}
    }
}
