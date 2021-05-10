xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare option output:method "html5";
declare option output:media-type "text/html";
(:    url : "api/save_sf.xql?sense-id="+sense_id+"&sf_id="+synfunc_id+
"&sf_val="+synfunc_val+"&def="+def_val,   :)
let $sense-id := request:get-parameter("sense-id", "xxxx")
, $synfunc-id := request:get-parameter("sf_id", "xx")
, $synfunc-val := replace(normalize-space(request:get-parameter("sf_val", "xx")), "\$x\$", '+') 
, $def := replace(normalize-space(request:get-parameter("def", "xx")), "\$x\$", '+')
, $type := request:get-parameter("type", "xx")

return 
tlsapi:save-sf($sense-id, $synfunc-id, $synfunc-val, $def, $type)
 