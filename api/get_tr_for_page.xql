xquery version "3.1";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

import module namespace ltr="http://hxwd.org/lib/translation" at "../modules/lib/translation.xqm";
import module namespace ai="http://hxwd.org/lib/gemini-ai" at "../modules/lib/gemini-ai.xqm";

let $loc := request:get-parameter("location", "xx"),
$prec := request:get-parameter("prec", "15"),
$foll := request:get-parameter("foll", "15"),
$slot := request:get-parameter("slot", "slot1"),
$content-id := request:get-parameter("content-id", "")
, $ai := request:get-parameter("ai", "undefined")
return
if ($ai = 'undefined') then
ltr:get-tr-for-page($loc, xs:int($prec), xs:int($foll), $slot, $content-id)
else 
ai:make-tr-for-page($loc, xs:int($prec), xs:int($foll), $slot, $content-id, $ai)
