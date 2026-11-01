package io.busystack.busydata;

import io.busystack.busydata.metadata.IdentifierRules;
import io.busystack.busydata.protocol.Engine;

/** Explicit synthetic native evidence for pure fixtures. Only ASCII folding is
 * declared here; non-ASCII entries are identity mappings, never an assertion
 * about a real MySQL/MariaDB Unicode implementation. Live oracles acquire their
 * rules from the actual server and must not use this helper. */
public final class NativeCaseFixtures {
    private NativeCaseFixtures(){}
    private static final class Maps {
        static final String LOWER=map(false),UPPER=map(true),DICTIONARY=map(true),FOREIGN=foreign();
        private static String map(boolean upper){
            var chars=new char[65536];
            for(int c=1;c<chars.length;c++)if(c<0xd800||c>0xdfff)chars[c]=(char)c;
            for(char c='A';c<='Z';c++)if(upper)chars[c+32]=c;else chars[c]=(char)(c+32);
            return new String(chars);
        }
        private static String foreign(){var map=new char[256];for(int b=0;b<map.length;b++)map[b]=(char)(b+1);for(char c='a';c<='z';c++)map[c]=(char)(c-32+1);return new String(map);}
    }
    public static IdentifierRules rules(Engine engine,int mode){return rules(engine,mode,"unit-ascii-fixture-v1");}
    public static IdentifierRules rules(Engine engine,int mode,String version){return rules(engine,mode,version,false);}
    public static IdentifierRules rules(Engine engine,int mode,String version,boolean lowerCaseFileSystem){
        if(engine==Engine.POSTGRESQL){if(lowerCaseFileSystem)throw new IllegalArgumentException("PostgreSQL synthetic header has no filesystem case flag");return new IdentifierRules(engine,mode);}
        return IdentifierRules.nativeRules(engine,mode,version,Maps.LOWER,engine==Engine.MYSQL?Maps.LOWER:Maps.UPPER,Maps.DICTIONARY,engine==Engine.MARIADB?Maps.FOREIGN:null,lowerCaseFileSystem);
    }
}
