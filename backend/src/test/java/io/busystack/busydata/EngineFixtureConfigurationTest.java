package io.busystack.busydata;

import io.busystack.busydata.protocol.Engine;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.AbstractWaitStrategy;
import org.testcontainers.containers.wait.strategy.HostPortWaitStrategy;
import org.testcontainers.containers.wait.strategy.LogMessageWaitStrategy;
import static org.junit.jupiter.api.Assertions.*;

class EngineFixtureConfigurationTest {
    @TempDir Path root;

    @ParameterizedTest
    @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void selectedReadinessRetainsTheDeclaredStartupBound(Engine engine)throws Exception {
        var configured=new AtomicReference<GenericContainer<?>>();
        var observed=new IllegalStateException("Fixture configuration observed before Docker start");
        var result=assertThrows(IllegalStateException.class,()->new EngineFixture(root,engine.name(),container->{
            configured.set(container);throw observed;
        }));
        assertSame(observed,result);
        var container=configured.get();assertNotNull(container);
        assertEquals(List.of(engine==Engine.POSTGRESQL?5432:3306),container.getExposedPorts());
        // Observe the selected real dependency strategy without starting Docker.
        var getter=GenericContainer.class.getDeclaredMethod("getWaitStrategy");getter.setAccessible(true);
        var strategy=getter.invoke(container);
        if(engine==Engine.POSTGRESQL)assertInstanceOf(LogMessageWaitStrategy.class,strategy);
        else assertInstanceOf(HostPortWaitStrategy.class,strategy);
        var timeout=AbstractWaitStrategy.class.getDeclaredField("startupTimeout");timeout.setAccessible(true);
        assertEquals(Duration.ofMinutes(3),timeout.get(strategy),
            "Selecting engine readiness must retain the fixture's existing three-minute startup bound");
    }
}
