xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
(:declare option output:method "html5";:)
declare option output:media-type "text/html";

(:import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";:)
import module namespace lsf="http://hxwd.org/lib/syn-func" at "../modules/lib/syn-func.xqm";


let $word := request:get-parameter("word", "xx"),
$context := request:get-parameter("context", "xx")
,$domain := request:get-parameter("domain", "core")
,$leftword := request:get-parameter("leftword", "")
return

lsf:get-sw-dispatch($word, $context, $domain, $leftword)
