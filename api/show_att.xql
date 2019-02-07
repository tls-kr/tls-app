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

declare variable $uid := request:get-parameter("uid", "xx");
let $key := "#" || $uid
let $atts := collection(concat($config:tls-data-root, '/notes/'))//tls:swl[tei:sense/@corresp = $key]
return
if (count($atts) > 0) then
for $a in $atts
let $src := data($a/tls:text/tls:srcline/@title),
$when := data($a/tls:text/@tls:when)
let $line := $a/tls:text/tls:srcline/text(),
$tr := $a/tls:text/tls:line,
$target := substring(data($a/tls:text/tls:srcline/@target), 2),
$loc := xs:int(substring-before(tokenize(substring-before($target, "."), "_")[last()], "-"))
order by $when descending
return
<div class="row bg-light table-striped">
<div class="col-sm-2"><a href="textview.html?location={$target}" class="font-weight-bold">{$src, $loc}</a></div>
<div class="col-sm-3"><span>{$line}</span></div>
<div class="col-sm-7"><span>{$tr}</span></div>
</div>
else 
<p class="font-weight-bold">No attributions found</p>


