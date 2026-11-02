package io.busystack.busydata;

import static org.junit.jupiter.api.Assertions.*;

import com.github.dockerjava.api.command.CreateContainerCmd;
import io.busystack.busydata.protocol.Engine;
import java.lang.reflect.Proxy;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.utility.DockerImageName;

class LargeTransferStorageTest {
    @TempDir Path root;

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void databaseUsesTheCheckedStoreAndPreservesCleanupOwnership(Engine engine) throws Exception {
        try (var container = new GenericContainer<>(DockerImageName.parse("postgres:17.11"))) {
            LargeTransferStorage.prepare(root, engine).accept(container);
            assertEquals(1, container.getBinds().size());
            var mount = container.getBinds().getFirst();
            Path data = root.resolve("database-data").toAbsolutePath();
            assertEquals(data.toString(), mount.getPath());
            assertEquals(engine == Engine.POSTGRESQL ? "/var/lib/postgresql/data" : "/var/lib/mysql",
                mount.getVolume().getPath());
            assertEquals("rw", mount.getAccessMode().toString());
            assertEquals(Files.getFileStore(root), Files.getFileStore(data));

            var configuredUser = new AtomicReference<String>();
            var command = (CreateContainerCmd) Proxy.newProxyInstance(
                CreateContainerCmd.class.getClassLoader(), new Class<?>[]{CreateContainerCmd.class},
                (proxy, method, arguments) -> {
                    assertEquals("withUser", method.getName());
                    configuredUser.set((String) arguments[0]);
                    return proxy;
                });
            for (var modifier : container.getCreateContainerCmdModifiers()) modifier.modify(command);
            String expected = Files.getFileStore(data).supportsFileAttributeView("unix")
                ? Files.getAttribute(data, "unix:uid") + ":" + Files.getAttribute(data, "unix:gid")
                : null;
            assertEquals(expected, configuredUser.get());
        }
    }

    @Test
    void existingDatabaseDirectoryIsNeverReused() throws Exception {
        Path data = Files.createDirectory(root.resolve("database-data"));
        Path marker = Files.writeString(data.resolve("existing-state"), "preserve");
        assertThrows(FileAlreadyExistsException.class,
            () -> LargeTransferStorage.prepare(root, Engine.MYSQL));
        assertEquals("preserve", Files.readString(marker));
    }

    @Test
    void unsupportedEngineCreatesNoDatabaseDirectory() {
        assertThrows(IllegalArgumentException.class,
            () -> LargeTransferStorage.prepare(root, Engine.ENGINE_UNSPECIFIED));
        assertFalse(Files.exists(root.resolve("database-data")));
    }
}
