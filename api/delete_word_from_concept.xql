xquery version "3.1";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:media-type "text/html";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $wid := request:get-parameter("wid", "xx")
, $type := request:get-parameter("type", "xx")
, $ref := request:get-parameter("ref", "xx")

return

tlsapi:delete-word-from-concept($wid, $type, $ref)
