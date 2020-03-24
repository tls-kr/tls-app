xquery version "3.1";

(: so this is now the xquery that displays the dialog for 
 - new concept for character:  type=concept
 - new word within concept for character: type=word
 - revision of existing swl:  type=swl
 the available information differs slightly, this will collected into a map and sent over to tlsapi
 
 the name is now slightly misleading, but I'll keep it for now:-)
 
:)

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

let $rpara := map {"uuid" : request:get-parameter("uid", "xx"),
"type" : request:get-parameter("type", "swl"),
"word" : request:get-parameter("word", "xx"),
"wid" : request:get-parameter("wid", "xx"),
"py" : request:get-parameter("py", "xx"),
"line-id" : request:get-parameter("line-id", "xx"),
"line" : request:get-parameter("line", "xx"),
"concept" : request:get-parameter("concept", "xx"),
"concept-id" : request:get-parameter("concept-id", "xx") }

return 

tlsapi:get-swl($rpara)