xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:media-type "text/html";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

(:let $loc := "KR1e0001_tls_001-5a.2",:)

let $loc := request:get-parameter("loc", "xx")

return tlsapi:get-text-preview($loc)

