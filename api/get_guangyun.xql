xquery version "3.1";

import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html";
declare option output:media-type "text/html";

declare variable $chars := request:get-parameter("char", "xx");

tlslib:get-guangyun($chars, "", true())
