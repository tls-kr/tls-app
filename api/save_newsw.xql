xquery version "3.1";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $rpara := map {"concept-id" : request:get-parameter("concept", "xx"),
 "line-id" : request:get-parameter("line", "xx"),
 "word" : request:get-parameter("word", "xx"),
 "wuid" : request:get-parameter("wid", "xx"),
 "py" : request:get-parameter("py", "xx"),
 "guangyun-id" : request:get-parameter("guangyun", "xx"),
 "concept-val" : request:get-parameter("concept-val", "xx"),
 "synfunc" : request:get-parameter("synfunc", "xx"),
 "synfunc-val" : replace(normalize-space(request:get-parameter("synfunc-val", "xx")), "\$x\$", '+') ,
 "semfeat" : request:get-parameter("semfeat", "xx"),
 "semfeat-val" : replace(normalize-space(request:get-parameter("semfeat-val", "xx")), "\$x\$", '+') ,
 "def" : replace(normalize-space(request:get-parameter("def", "xx")), "\$x\$", '+') 
}
return
tlsapi:save-newsw($rpara)

