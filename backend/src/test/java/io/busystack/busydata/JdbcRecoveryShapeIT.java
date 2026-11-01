package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class JdbcRecoveryShapeIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void originalDriverRecoveryShapeSurvivesNativeEnrichmentAndPrivateModeNormalization(String engine)throws Exception {
        var failRestore=new AtomicBoolean();var failedViewClosed=new AtomicBoolean();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
            Connection connection=adapter.connect(request,port);
            return request.getProfile().getReadOnly()?restorationFault(connection,failRestore,failedViewClosed):connection;
        })) {
            var session=f.open();f.execute(session,"SET SESSION sql_mode=''");
            f.execute(session,"CREATE TABLE legacyshape(id INTEGER AUTO_INCREMENT PRIMARY KEY,b TINYINT(1),u BIGINT UNSIGNED,n DECIMAL(20,6),f FLOAT,d DOUBLE,c CHAR(8),v VARCHAR(40) DEFAULT 'text',t TEXT,bin VARBINARY(8),blobv BLOB,da DATE,ti TIME(6),dt DATETIME(6),ts TIMESTAMP(6) NULL DEFAULT NULL,y YEAR,bitv BIT(3),j JSON,e ENUM('a','b'),s SET('a','b'),g INTEGER GENERATED ALWAYS AS (b+1) STORED,optionalv VARCHAR(40) UNIQUE)");
            String original=originalShape(session,"legacyshape");
            var first=NativeStructureReader.inspect(session,session.context.catalog(),f.schema(),"legacyshape");
            assertEquals(original,first.recoverySignature(),"Existing durable drafts must use the original getColumns shape");
            assertEquals("6",first.columns().stream().filter(column->column.getName().equals("ti")).findFirst().orElseThrow().getPropertiesOrThrow("scale"),"Native structural precision remains independent of durable JDBC transport facts");
            f.execute(session,"SET SESSION sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'");String mode=mode(session.connection);
            var second=NativeStructureReader.inspect(session,session.context.catalog(),f.schema(),"legacyshape");
            assertEquals(original,second.recoverySignature());assertEquals(mode,mode(session.connection));
            session.metadata(view->{String before=mode(view.connection);var columns=JdbcMetadataPatterns.columns(view,view.context.catalog(),f.schema(),"legacyshape");assertEquals(22,columns.size());assertEquals(before,mode(view.connection));return null;});
            f.execute(session,"CREATE TABLE `exact_shape_%`(id INTEGER PRIMARY KEY,n TIME(6)); CREATE TABLE `exactXshapeYother`(wrong INTEGER)");
            var exact=JdbcMetadataPatterns.columns(session,session.context.catalog(),f.schema(),"exact_shape_%");assertEquals(List.of("id","n"),exact.stream().map(SchemaObject::getName).toList());assertEquals(mode,mode(session.connection));
            failRestore.set(true);
            assertThrows(SessionRegistry.MetadataFailure.class,()->JdbcMetadataPatterns.columns(session,session.context.catalog(),f.schema(),"legacyshape"));
            assertTrue(failedViewClosed.get(),"A failed private restoration must dispose that connection");assertEquals(mode,mode(session.connection));
            failRestore.set(false);assertEquals(22,JdbcMetadataPatterns.columns(session,session.context.catalog(),f.schema(),"legacyshape").size());
        }
    }
    /** Exact schema-2 algorithm from ChangePlanner, using actual pinned-driver metadata. */
    private static String originalShape(SessionRegistry.Session session,String table)throws SQLException {
        var metadata=session.connection.getMetaData();String catalog=session.context.catalog();
        var types=new TreeMap<String,Integer>();var details=new TreeMap<String,List<String>>();var generated=new TreeSet<String>();var nonNull=new TreeSet<String>();
        try(var rows=metadata.getColumns(catalog,null,table,null)){while(rows.next()){
            if(!table.equals(rows.getString("TABLE_NAME")))continue;String name=rows.getString("COLUMN_NAME");types.put(name,rows.getInt("DATA_TYPE"));var values=new ArrayList<String>();
            for(String field:List.of("TYPE_NAME","COLUMN_SIZE","DECIMAL_DIGITS","NULLABLE","COLUMN_DEF","ORDINAL_POSITION","IS_GENERATEDCOLUMN","IS_AUTOINCREMENT"))values.add(Objects.toString(rows.getString(field),""));
            details.put(name,List.copyOf(values));if(rows.getInt("NULLABLE")==DatabaseMetaData.columnNoNulls)nonNull.add(name);
            if("YES".equals(rows.getString("IS_GENERATEDCOLUMN"))||"YES".equals(rows.getString("IS_AUTOINCREMENT")))generated.add(name);
        }}
        var primary=new TreeSet<String>();try(var rows=metadata.getPrimaryKeys(catalog,null,table)){while(rows.next())primary.add(rows.getString("COLUMN_NAME"));}
        var unique=new TreeMap<String,Set<String>>();var invalid=new HashSet<String>();
        try(var rows=metadata.getIndexInfo(catalog,null,table,true,false)){while(rows.next()){
            if(rows.getShort("TYPE")==DatabaseMetaData.tableIndexStatistic||rows.getBoolean("NON_UNIQUE"))continue;String index=rows.getString("INDEX_NAME"),column=rows.getString("COLUMN_NAME");if(index==null)continue;
            unique.computeIfAbsent(index,ignored->new TreeSet<>());if(column==null||!nonNull.contains(column))invalid.add(index);else unique.get(index).add(column);
            try{if(rows.getString("FILTER_CONDITION")!=null&&!rows.getString("FILTER_CONDITION").isBlank())invalid.add(index);}catch(SQLFeatureNotSupportedException ignored){}
        }}
        return types.toString()+details+generated+primary+unique+invalid;
    }
    private static String mode(Connection connection)throws SQLException {try(var statement=connection.createStatement();var rows=statement.executeQuery("SELECT @@SESSION.sql_mode")){assertTrue(rows.next());return rows.getString(1);}}
    private static Connection restorationFault(Connection actual,AtomicBoolean fail,AtomicBoolean closed) {
        var sets=new AtomicInteger();
        return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class<?>[]{Connection.class},(proxy,method,args)->{
            if(method.getName().equals("close")){if(fail.get())closed.set(true);actual.close();return null;}
            Object value=invoke(actual,method,args);
            if(method.getName().equals("prepareStatement")&&args[0].equals("SET SESSION sql_mode=?")){
                PreparedStatement statement=(PreparedStatement)value;
                return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class<?>[]{PreparedStatement.class},(p,m,a)->{
                    if(m.getName().equals("execute")&&sets.incrementAndGet()==3&&fail.get())throw new SQLException("Synthetic private mode restoration failure","HY000");
                    return invoke(statement,m,a);
                });
            }return value;
        });
    }
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable {try{return method.invoke(target,args);}catch(InvocationTargetException error){throw error.getCause();}}
}
