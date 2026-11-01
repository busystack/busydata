package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class EditorAssignmentsIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void defaultNullCloneAndRecoveryPreserveIntent(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();String identity=f.engine==Engine.POSTGRESQL?"INTEGER GENERATED ALWAYS AS IDENTITY":"INTEGER AUTO_INCREMENT";
            f.execute(session,"CREATE TABLE assignments (id "+identity+" PRIMARY KEY,n DECIMAL(30,9) DEFAULT 7.125,note VARCHAR(100) DEFAULT 'server',code VARCHAR(40) UNIQUE); INSERT INTO assignments (note,code) VALUES ('original','used')");
            if(f.engine!=Engine.POSTGRESQL)
                f.execute(session,"CREATE TABLE exact_native_numbers(n TINYINT(1),y YEAR,b BIT(1)); INSERT INTO exact_native_numbers VALUES(2,2026,b'1'),(-128,0,b'0')");
            // Finish known DDL setup before capturing this test's source proof.
            // A later harmless SELECT still makes the editable source older
            // than the current execution, without introducing schema publication.
            f.warm(session,"assignments");
            String table=session.adapter.table(session.context.catalog(),f.schema(),"assignments");
            var source=f.results.get(f.execute(session,"SELECT id,n,note,code FROM "+table).info().getResults(0).getResultId());
            if(f.engine!=Engine.POSTGRESQL){
                var exact=f.results.get(f.execute(session,"SELECT n,y,b FROM exact_native_numbers ORDER BY n DESC").info().getResults(0).getResultId());
                assertEquals("2",exact.read(0).getValues(0).getSignedInteger());assertEquals("-128",exact.read(1).getValues(0).getSignedInteger());
                assertEquals("2026",io.busystack.busydata.results.Values.text(exact.read(0).getValues(1)));assertEquals(java.math.BigInteger.ZERO,new java.math.BigInteger(io.busystack.busydata.results.Values.text(exact.read(1).getValues(1))));assertTrue(exact.read(0).getValues(2).getBoolean());
            }
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            var request=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("assignments")
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.defaultValue()).putValues(3,Assignments.nullValue())).build();
            var plan=planner.preview(session,request);assertTrue(plan.getSql(0).contains("DEFAULT"));assertTrue(plan.getChanges(0).getValuesOrThrow("n").hasDefaultValue());
            var draft=planner.captureDraft(session,request,"document");assertTrue(draft.getChanges().getChanges(0).getValuesOrThrow(2).hasDefaultValue());
            EditingIT.apply(planner,f.jobs,session,request);
            var fresh=f.results.get(f.execute(session,"SELECT id,n,note,code FROM "+table).info().getResults(0).getResultId());assertTrue(fresh.read(0).getValues(2).hasNullValue());assertEquals("7.125000000",fresh.read(0).getValues(1).getDecimal());
            var clone=planner.cloneRow(session,CloneRowRequest.newBuilder().setSessionId(session.id).setResultId(fresh.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("assignments").build());
            assertEquals(ChangeKind.INSERT,clone.getKind());assertFalse(clone.containsValues(1));assertFalse(clone.containsValues(4),"A non-NULL nullable UNIQUE assignment must not be duplicated");assertTrue(clone.getValuesOrThrow(3).hasNullValue());
            EditingIT.apply(planner,f.jobs,session,request.toBuilder().setResultId(fresh.id).clearChanges().addChanges(clone).build());
            assertEquals("2",f.results.get(f.execute(session,"SELECT COUNT(*) FROM assignments").info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void typedInputsAreValidatedBeforeReviewAndTimeTransportIsExact(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();
            f.execute(session,"CREATE TABLE typed_editor_values(id INTEGER PRIMARY KEY,small SMALLINT NOT NULL,n DECIMAL(10,3) NOT NULL,at TIME(6),note VARCHAR(40) NOT NULL DEFAULT 'kept'); INSERT INTO typed_editor_values VALUES(1,7,1.125,'12:00:00','kept')");
            new Explorer(f.metadata).refreshFragment(session,session.context.catalog(),f.schema(),"typed_editor_values",ObjectKind.TABLE);
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            String table=session.adapter.table(session.context.catalog(),f.schema(),"typed_editor_values");
            var source=f.results.get(f.execute(session,"SELECT id,small,n,at,note FROM "+table).info().getResults(0).getResultId());
            var request=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("typed_editor_values");
            var overflow=request.clone().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.value(Value.newBuilder().setText("32768").build()))).build();
            assertEquals(EditValues.Code.OUT_OF_RANGE,assertThrows(EditValues.Failure.class,()->planner.preview(session,overflow)).code());
            var malformed=request.clone().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,Assignments.value(Value.newBuilder().setText("private-invalid-decimal").build()))).build();
            var invalid=assertThrows(EditValues.Failure.class,()->planner.preview(session,malformed));assertEquals(EditValues.Code.INVALID_FORMAT,invalid.code());assertFalse(invalid.getMessage().contains("private-invalid-decimal"));
            var rounding=request.clone().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,Assignments.value(Value.newBuilder().setText("1.1234").build()))).build();
            assertEquals(EditValues.Code.LOSS_OF_PRECISION,assertThrows(EditValues.Failure.class,()->planner.preview(session,rounding)).code());
            var nil=request.clone().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(5,Assignments.nullValue())).build();
            assertThrows(IllegalArgumentException.class,()->planner.preview(session,nil));
            var durable=f.results.get(f.execute(session,"SELECT small,n,note FROM typed_editor_values").info().getResults(0).getResultId()).read(0);
            assertEquals("7",durable.getValues(0).getSignedInteger());assertEquals("1.125",durable.getValues(1).getDecimal());assertEquals("kept",durable.getValues(2).getText());
            var values=f.engine==Engine.POSTGRESQL?java.util.List.of("24:00:00","00:00:00.123456"):java.util.List.of("-25:00:00.123456",f.engine==Engine.MARIADB?"838:59:59.999999":"838:59:59");
            for(String literal:values) {
                var current=f.results.get(f.execute(session,"SELECT id,small,n,at,note FROM "+table).info().getResults(0).getResultId());
                var change=request.clone().setResultId(current.id).addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(4,Assignments.value(Value.newBuilder().setText(literal).build()))).build();
                EditingIT.apply(planner,f.jobs,session,change);
                var value=f.results.get(f.execute(session,"SELECT at FROM typed_editor_values").info().getResults(0).getResultId()).read(0).getValues(0);
                assertTrue(value.hasTemporal(),"Native time must retain exact temporal transport");
                assertEquals(0,timeSeconds(literal).compareTo(timeSeconds(value.getTemporal().getIso())),"Native TIME duration/fraction must remain exact");
                if(f.engine!=Engine.POSTGRESQL)try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT at FROM typed_editor_values")){assertTrue(rows.next());assertEquals(rows.getString(1),value.getTemporal().getIso(),"Retained TIME must preserve the native duration representation");}
            }
        }
    }

    private static java.math.BigDecimal timeSeconds(String raw){boolean negative=raw.startsWith("-");var parts=(negative?raw.substring(1):raw).split(":");var total=new java.math.BigDecimal(parts[0]).multiply(java.math.BigDecimal.valueOf(3600)).add(new java.math.BigDecimal(parts[1]).multiply(java.math.BigDecimal.valueOf(60))).add(parts.length==3?new java.math.BigDecimal(parts[2]):java.math.BigDecimal.ZERO);return negative?total.negate():total;}
}
