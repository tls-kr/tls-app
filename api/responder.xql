xquery version "3.1";

(: this will take the name of a tlsapi function at its first parameter 
 and pass the following parameters in a map to that function. 
:)

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: this will need to be set dynamically :)
declare option output:media-type "text/html";

let $func := request:get-parameter("func", "xx")
let $resmap := map:merge(
   for $p in request:get-parameter-names()
   where not ($p = "func")
   return
   map:entry($p, request:get-parameter($p, "xx")))
return 

util:eval("tlsapi:" ||  $func || "($resmap)" )
