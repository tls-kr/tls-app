xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "text";
declare option output:media-type "text/javascript";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $type := request:get-parameter("type", "xx")
,$term := request:get-parameter("term", "xx")

return 

tlsapi:autocomplete($type, $term)

