xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

(:  url : "api/save_to_concept.xql?line="+line_id+
"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"
&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"
&semfeat-val="+semfeat_val+"&guangyun="+guangyun_id+"&def="+def_val,
 :)

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $rpara := map {"concept-id" : request:get-parameter("concept", "xx"),
 "line-id" : request:get-parameter("line", "xx"),
 "word" : request:get-parameter("word", "xx"),
 "wuid" : request:get-parameter("wid", "xx"),
 "guangyun-id" : request:get-parameter("guangyun-id", "xx"),
 "concept-val" : request:get-parameter("concept-val", "xx"),
 "synfunc" : request:get-parameter("synfunc", "xx"),
 "synfunc-val" : request:get-parameter("synfunc-val", "xx"),
 "semfeat" : request:get-parameter("semfeat", "xx"),
 "semfeat-val" : request:get-parameter("semfeat-val", "xx"),
 "def" : request:get-parameter("def", "xx")
}

return
tlsapi:save-to-concept($rpara)