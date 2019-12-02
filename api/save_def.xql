xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare option output:method "html5";
declare option output:media-type "text/html";

let $defid := request:get-parameter("defid", "xxxx")
, $def := request:get-parameter("def", "xx")

return 
tlsapi:save-def($defid, $def)
 