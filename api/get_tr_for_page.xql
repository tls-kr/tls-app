xquery version "3.1";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

import module namespace ltr="http://hxwd.org/lib/translation" at "../modules/lib/translation.xqm";

let $loc := request:get-parameter("location", "xx"),
$prec := request:get-parameter("prec", "15"),
$foll := request:get-parameter("foll", "15"),
$slot := request:get-parameter("slot", "slot1"),
$content-id := request:get-parameter("content-id", "")

return

ltr:get-tr-for-page($loc, xs:int($prec), xs:int($foll), $slot, $content-id)
