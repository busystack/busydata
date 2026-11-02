package io.busystack.busydata;

import io.busystack.busydata.protocol.Engine;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.function.Consumer;
import org.testcontainers.containers.BindMode;
import org.testcontainers.containers.GenericContainer;

/** Keep the disposable database on the same capacity-checked store as its input. */
final class LargeTransferStorage {
    static Consumer<GenericContainer<?>> prepare(Path root, Engine engine) throws IOException {
        String destination = switch (engine) {
            case POSTGRESQL -> "/var/lib/postgresql/data";
            case MYSQL, MARIADB -> "/var/lib/mysql";
            default -> throw new IllegalArgumentException("Unsupported transfer fixture engine");
        };
        Path data = Files.createDirectory(root.resolve("database-data")).toAbsolutePath();
        // Official images support an arbitrary numeric user. Preserve ownership
        // on Unix so normal fixture teardown can delete the complete data tree.
        String owner = Files.getFileStore(data).supportsFileAttributeView("unix")
            ? Files.getAttribute(data, "unix:uid") + ":" + Files.getAttribute(data, "unix:gid")
            : null;
        return container -> {
            container.withFileSystemBind(data.toString(), destination, BindMode.READ_WRITE);
            if (owner != null) {
                container.withCreateContainerCmdModifier(command -> command.withUser(owner));
            }
        };
    }
}
