xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare option output:method "html5";
declare option output:media-type "text/html";

let $trid := request:get-parameter("trid", "xxxx")
, $tr := request:get-parameter("tr", "xx")
, $lang := request:get-parameter("lang", "en")
(: , $tr-path := request:get-parameter("trpath", "en") :)

return 
tlsapi:save-tr($trid, $tr, $lang)
 