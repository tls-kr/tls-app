xquery version "3.1";
(: probably obsolete 2020-02-26 :)
(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace ttm="http://tls.kanripo.org/ns/1.0";
declare namespace t2= "http://tls.kanripo.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(:declare option output:method "html5";
:)
declare option output:media-type "text/html";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";

declare variable $word := request:get-parameter("word", "xx");

let $m := tlslib:getwords($word, map{})
for $k in map:keys($m)
return 
<option id="{$k}">{map:get($m, $k)}</option>




