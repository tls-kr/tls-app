xquery version "3.1";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $slot := request:get-parameter("slot", "slot1")
let $loc := request:get-parameter("location", "xx")
, $trid := request:get-parameter("trid", "xx"),
$prec := request:get-parameter("prec", "15"),
$foll := request:get-parameter("foll", "15")

return

tlsapi:new-translation($slot, $loc, $trid)
