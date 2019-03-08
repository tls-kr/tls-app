xquery version "3.1";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html";
declare option output:media-type "text/html";

declare variable $chars := request:get-parameter("char", "xx");

tlsapi:get-guangyun($chars, "")
