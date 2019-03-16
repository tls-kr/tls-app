xquery version "3.1";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(:declare option output:method "html5";:)

declare option output:media-type "text/html";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

let $uid := request:get-parameter("uid", "xx")
let $key := "#" || $uid
let $res := for $r in collection($config:tls-data-root)//tls:*[@corresp = $key]
     where exists($r/ancestor::tei:sense)
     return $r

return

if (count($res) > 0) then
for $r in subsequence($res, 1, 10)
  let $sw := $r/ancestor::tei:sense
  return
  tlslib:display_sense($sw)
else 

concat("No usage examples found for key: ", $key)
