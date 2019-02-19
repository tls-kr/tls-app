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
$title := $seg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
$pseg := $seg/preceding::tei:seg[fn:position() < 5],
$fseg := $seg/following::tei:seg[fn:position() < 5],
$dseg := ($pseg, $seg, $fseg)
return
<div class="popover" role="tooltip">
<div class="arrow"></div>
<h3 class="popover-header">
<a href="textview.html?location={$loc}">{$title}</a></h3>
<div class="popover-body">
    {
for $d in $dseg 
return 
    tlslib:displayseg($d, map{"ann": "false", "log": $loc})
    }
</div>
</div>