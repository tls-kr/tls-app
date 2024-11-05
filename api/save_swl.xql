xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $line-id := request:get-parameter("line-id", "xx")
let $line := request:get-parameter("line", "xx")
let $sense-id := request:get-parameter("sense", "xx")
let $pos := request:get-parameter("pos", "0")
let $tit := request:get-parameter("tit", "xx")

return

tlsapi:save-swl($line-id, $line, $sense-id, $pos, $tit)
