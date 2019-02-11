xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

let $line-id := request:get-parameter("line", "xx"),
 $link := concat('#', $line-id)

for $swl in collection($config:tls-data-root|| "/notes")//tls:srcline[@target=$link]
return
tlslib:format-swl($swl/ancestor::tls:swl, "row")