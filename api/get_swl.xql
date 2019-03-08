xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";



(: let $title := "Adding concept for" :)

let $uuid := request:get-parameter("uid", "xx")
,$type := request:get-parameter("type", "xx")
,$word := request:get-parameter("word", "xx")
(:let $uuid := "7b5a735a-6d13-4013-9a73-5a6d1310131b":)
,$swl:= collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$uuid]
,$title := "Editing Attribution for"
return
if (not ($swl)) then 
tlsapi:swl-dialog(<empty/>,$type,$title, $word)
else 
tlsapi:swl-dialog($swl,$type,$title, $word)
