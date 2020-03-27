xquery version "3.1";

(: this will take the name of a tlsapi function at its first parameter 
 and pass the following parameters in a map to that function. 
:)

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";
import module namespace dialogs="http://hxwd.org/dialogs" at "../modules/dialogs.xql"; 
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: this will need to be set dynamically :)
declare option output:method "html5";
declare option output:media-type "text/html";

let $func := request:get-parameter("func", "xx")
let $resmap := map:merge(
   for $p in request:get-parameter-names()
   where not ($p = "func")
   return
   map:entry($p, request:get-parameter($p, "xx")))
return 
if (starts-with($func, "dialogs")) then
util:eval($func || "($resmap)" )
else
if (starts-with($func, "tlslib")) then
util:eval($func || "($resmap)" )
else

util:eval("tlsapi:" ||  $func || "($resmap)" )
