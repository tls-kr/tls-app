xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(:declare option output:method "html5";:)

declare option output:media-type "text/html";
import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $uid := request:get-parameter("uid", "xx")
, $type := request:get-parameter("type", "xx")

return 
tlsapi:show-use-of($uid, $type)

