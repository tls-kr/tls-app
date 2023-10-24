xquery version "3.1";

(: this will take the name of a tlsapi function at its first parameter 
 and pass the following parameters in a map to that function. 
:)

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";
import module namespace dialogs="http://hxwd.org/dialogs" at "../modules/dialogs.xql"; 
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace wd="http://hxwd.org/wikidata" at "../modules/wikidata.xql"; 
import module namespace bib="http://hxwd.org/biblio" at "../modules/biblio.xql"; 
import module namespace sgn="http://hxwd.org/signup" at "../modules/signup.xql"; 
import module namespace txc="http://hxwd.org/text-crit" at "../modules/text-crit.xql";

import module namespace ltr="http://hxwd.org/lib/translation" at "../modules/lib/translation.xqm";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
(:import module namespace console="http://exist-db.org/xquery/console";:)

(: this will need to be set dynamically :)
declare option output:method "html5";
declare option output:media-type "text/html";

let $func := request:get-parameter("func", "xx")
, $header := request:get-parameter("header", "xx")
, $content-type := request:get-header("Content-type")
(:, $log := for $h in request:get-header-names()
   return console:log($h, request:get-header($h)):)

let $resmap := map:merge(
   for $p in (request:get-parameter-names(), "body")
   where not ($p = "func")
   return
   if ($p = 'body') then 
   if (contains($content-type, "xml")) then
   map:entry($p, request:get-data()) 
   else 
   map:entry($p, util:base64-decode(request:get-data()))
   else
   map:entry($p, request:get-parameter($p, "xx")))
return 
if (not($header = "xx")) then ( 
<ul>{
for $h in request:get-header-names()
return <li>{$h}:{request:get-header($h)}</li>
}</ul>
)
else
if (matches($func, "^(dialogs|tlslib|wd|bib|sgn|txc|ltr)")) then
 util:eval($func || "($resmap)" )
else
 util:eval("tlsapi:" ||  $func || "($resmap)" )
