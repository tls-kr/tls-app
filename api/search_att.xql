xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(:declare option output:method "html5";:)

declare option output:media-type "text/html";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $sense-id := request:get-parameter("sense-id", "uuid-20c9da30-27bc-4b0a-ab0a-787663fdf4b2", false())
, $start := request:get-parameter("start", "1", false())
, $count := request:get-parameter("count", "30", false())
,$sense := collection($config:tls-data-root)//tei:sense[@xml:id = $sense-id]
,$label := concat($sense/tei:gramGrp/tls:syn-func, " ", $sense/tei:gramGrp/tls:sem-feat, " ", $sense/tei:def)
,$entry := $sense/ancestor::tei:entry
,$orth := $entry/tei:form/tei:orth
,$ret := for $o in $orth/text()
  for $line in  collection($config:tls-texts-root)//tei:seg[ngram:contains(., $o)]
    let $target := $line/@xml:id,
    $locs := substring-before(tokenize(substring-before($target, "."), "_")[last()], "-"),
    $loc := if (string-length($locs) > 0) then xs:int($locs) else $locs, 
    $src := $line/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
    $tr := collection($config:tls-translation-root)//tei:seg[@corresp="#" || $target]
(:    ,$atts := collection(concat($config:tls-data-root, '/notes/'))//tls:srcline/@target = "#" || $target
    where $tr and (count($atts) = 0):)
    where $tr
return 
<div class="row bg-light table-striped">
<div class="col-sm-2">
     { if (sm:is-authenticated()) then 
     <button title="{$label}" class="btn badge badge-primary ml-2" type="button" onclick="save_swl_line('{$sense-id}','{$target}')">Use</button>
      else () }
<a href="textview.html?location={$target}" class="font-weight-bold">{$src, $loc}</a></div>
<div class="col-sm-3"><span data-target="{$target}" data-toggle="popover">{
         substring-before($line, $o), 
        <mark>{$o}</mark> 
        ,substring-after($line, $o)}</span></div>
<div class="col-sm-7"><span>{$tr}</span></div>
</div>

return 
if (count($ret) > 0) then
subsequence($ret, $start, $count)
else 
<p class="font-weight-bold">No matches found.</p>