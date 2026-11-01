package io.busystack.busydata;

import io.busystack.busydata.metadata.JdbcMetadataPatterns;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class JdbcMetadataPatternsTest {
    @Test void exactPostgresPatternsEscapeTheEscapeAndEveryWildcard(){assertEquals("part\\_\\%\\\\tail",JdbcMetadataPatterns.exactPattern("part_%\\tail","\\"));assertEquals("a!_b!%c!!d",JdbcMetadataPatterns.exactPattern("a_b%c!d","!"));}
    @Test void anUnavailableEscapeDoesNotBecomeAnUnboundedPattern(){assertThrows(IllegalArgumentException.class,()->JdbcMetadataPatterns.exactPattern("anything",""));assertThrows(IllegalArgumentException.class,()->JdbcMetadataPatterns.exactPattern("anything",null));}
}
