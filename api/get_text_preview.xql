xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(:declare option output:method "html5";
:)
declare option output:media-type "text/html";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

(:let $loc := "KR1e0001_tls_001-5a.2",:)
let $loc := request:get-parameter("loc", "xx"),
$seg := collection($config:tls-texts-root)//tei:seg[@xml:id = $loc],

$pseg := subsequence($seg/preceding::tei:seg, 1, 5),
$fseg := subsequence($seg/following::tei:seg, 1, 5),
$dseg := ($pseg, $seg, $fseg)
return
<div>
    {
for $d in $dseg 

return 
    tlslib:displayseg($d, map{"ann": "false", "log": $loc})
    }
</div>