package io.busystack.busydata.analysis;

import io.busystack.busydata.protocol.Engine;

/** Native lexical character facts shared by independent execution/editor scanners. */
public final class SqlLexicalCharacters {
    private SqlLexicalCharacters(){}
    public static boolean isSpace(int codePoint){return codePoint==' '||codePoint=='\t'||codePoint=='\n'||codePoint=='\r'||codePoint=='\f'||codePoint==11;}
    public static boolean isDigit(int codePoint){return codePoint>='0'&&codePoint<='9';}
    public static boolean identifierStart(int codePoint,Engine engine){
        boolean ascii=codePoint>='A'&&codePoint<='Z'||codePoint>='a'&&codePoint<='z'||codePoint=='_';
        if(engine==Engine.POSTGRESQL)return ascii||scalar(codePoint)&&codePoint>=128;
        if(engine==Engine.MYSQL||engine==Engine.MARIADB)return ascii||isDigit(codePoint)||codePoint=='$'||codePoint>=128&&codePoint<=65535&&scalar(codePoint);
        throw new IllegalArgumentException("Unsupported lexical dialect");
    }
    public static boolean identifierPart(int codePoint,Engine engine){return identifierStart(codePoint,engine)||isDigit(codePoint)||codePoint=='$';}
    public static boolean dollarTagPart(int codePoint){return codePoint!='$'&&identifierPart(codePoint,Engine.POSTGRESQL);}
    public static boolean mysqlCommentFollower(int codePoint){return codePoint>=0&&codePoint<=32||codePoint==127;}
    private static boolean scalar(int codePoint){return codePoint>=0&&codePoint<=Character.MAX_CODE_POINT&&(codePoint<Character.MIN_SURROGATE||codePoint>Character.MAX_SURROGATE);}
}
