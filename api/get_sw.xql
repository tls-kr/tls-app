xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace ttm="http://tls.kanripo.org/ns/1.0";
declare namespace t2= "http://tls.kanripo.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(:declare option output:method "html5";
:)
declare option output:media-type "text/html";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

declare variable $word := request:get-parameter("word", "xx");

let $words := collection(concat($config:tls-data-root, '/concepts/'))//tei:orth[. = $word]
return
if (count($words) > 0) then
for $w in $words
let $concept := $w/ancestor::tei:div/tei:head/text(),
$id := $w/ancestor::tei:div/@xml:id,
$py := $w/parent::tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]/text(),
$zi := $w/parent::tei:form/tei:orth/text()

(:group by $concept
order by $concept:)
return
<li>{$zi}&#160;({$py})&#160;{$concept} 
<ul>{for $s in $w/ancestor::tei:entry/tei:sense
let $sf := $s//tls:syn-func/text(),
$sm := $s//tls:sem-feat/text(),
$def := $s//tei:def/text()
return
<li>{$sf}&#160;{$sm}: {$def}
     <button class="btn badge badge-primary" type="button" onclick="save_this_swl('{$s/@xml:id}')">
           Use
      </button>
</li>
}
</ul></li>
else 
<li class="list-group-item">New Word</li>



