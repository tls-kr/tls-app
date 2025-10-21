xquery version "3.1";
(:~
: This module provides functions that calculate and process statistics about the content of tls-data
: they are intended to be called eg. from the scheduler.

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)


import module namespace config="http://hxwd.org/config" at "config.xqm";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace ltr="http://hxwd.org/lib/translation" at "lib/translation.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "lib/utils.xqm";
import module namespace sgn="http://hxwd.org/signup" at "signup.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function local:translations(){
let $trlines := collection($config:tls-translation-root)//tei:seg,
$translations := for $d in collection($config:tls-translation-root)
    let $tlc := count($d//tei:seg),
    $tsrc := substring($d//tei:sourceDesc//tei:bibl/@corresp, 2),
    $title := $d//tei:titleStmt
    group by $tsrc
    let $txtid := data($tsrc[1])
    order by sum($tlc) descending
    return <tr class="table-hr">
    <td>{sum($tlc)}</td>
    <td>{$txtid}</td>
    <td>{lu:get-title($txtid)}</td>
    <td><ul>
    {
    for $t in $d 
    let $lc := count($t//tei:seg)
    order by $lc descending
    return
    <li>
        {if ($lc > 0) then
    <a href="textview.html?location={substring(ltr:get-translation-seg($t//tei:TEI/@xml:id, true())/@corresp, 2)}">{$t//tei:titleStmt/tei:title/text()} // by  {$t//tei:titleStmt/tei:editor/text()} (<span>{$lc}</span> lines)</a>
    else 
    <span>{$t//tei:titleStmt/tei:title/text()} // by  {$t//tei:titleStmt/tei:editor/text()} ({$lc} lines)</span>        
        }
    </li>}</ul></td></tr>
return <table id="stat-translations">
<thead><tr>
<th>Lines</th>
<th>TextID</th>
<th>Text</th>
<th>Translations</th>
</tr></thead>
<tbody>
<tr>
<td>Total: {count($trlines)}</td>
<td>{count($translations)}</td>
<td></td>
<td>{count(collection($config:tls-translation-root))}</td>
</tr>
{$translations}</tbody></table>
};

declare function local:concepts(){
let $c := collection($config:tls-data-root || "/concepts")//tei:div[@type='concept']
,$refs := collection($config:tls-data-root || "/concepts")//tei:ref
return
count($c)
};

declare function local:overview(){
let $c := collection($config:tls-data-root || "/concepts")//tei:div[@type='concept']
,$words := collection($config:tls-data-root || "/words")//tei:entry
,$rd := collection($config:tls-data-root || "/core")//tei:div[@type='rhet-dev']
,$sem := collection($config:tls-data-root || "/core")//tei:div[@type='sem-feat']
,$syn := collection($config:tls-data-root || "/core")//tei:div[@type='syn-func']
,$ann := collection($config:tls-data-root || "/notes")//tls:ann
,$trlines := collection($config:tls-translation-root)//tei:seg
,$translations := for $d in collection($config:tls-translation-root)
    let $tsrc := substring($d//tei:sourceDesc//tei:bibl/@corresp, 2)
    return $tsrc
return
<table id="stat-overview">
<thead><tr>
<th>Feature</th>
<th>Defined</th>
<th>Types</th>
<th>Tokens</th>
</tr></thead>
<tbody>
<tr id="stat-ov-concepts">
<td>Concepts</td>
<td title="Total number of concepts defined">{count($c)}</td>
<td title="Unique number of concepts used in attributions">{count(distinct-values($ann//@concept-id))}</td>
<td title="Total number of concepts used in attributions">{count($ann//@concept-id)}</td>
</tr>
<tr id="stat-ov-words">
<td>Words</td>
<td title="Total number of words defined">{count(distinct-values($ann//tei:sense/@corresp))}</td>
<td title="Number of unique syntactic words used in attributions">{count($words)}</td>
<td title="Total number of syntactic words in attributions">{count($ann//tei:sense/@corresp)}</td>
</tr>
<tr id="stat-ov-syn-func">
<td>Syntactic functions</td>
<td title="Total number of syntactic functions defined">{count($syn)}</td>
<td title="Number of unique syntactic functions used in attributions">{count(distinct-values($ann//tls:syn-func/@corresp))}</td>
<td title="Total number of syntactical functions in attributions">{count($ann//tls:syn-func/@corresp)}</td>
</tr>
<tr id="stat-ov-sem-feat">
<td>Semantic features</td>
<td title="Total number of semantic features defined">{count($sem)}</td>
<td title="Number of unique semantic features used in attributions">{count(distinct-values($ann//tls:sem-feat/@corresp))}</td>
<td title="Total number of semantic features in attributions">{count($ann//tls:sem-feat/@corresp)}</td>
</tr>
<tr>
<td id="stat-ov-rhet-dev">Rhetorical devices</td>
<td title="Total number of rhetorical devices defined">{count($rd)}</td>
<td>{count(for $r in $rd 
  let $l := $r//tei:div[@type='rhet-dev-loc']/tei:p
  where string-length($l) > 0
  return $l)
}</td>
<td title="Not yet available">{sum(for $r in $rd 
  let $l := $r//tei:div[@type='rhet-dev-loc']/tei:p
  return
  if (string-length($l) > 0) then xs:int($l) else ()
  )}</td>
</tr>
{
    <tr id="stat-ov-translations">
    <td><a href="translations.html">Translations</a></td>
    <td title="Total number of translations">{count(collection($config:tls-translation-root))}</td>
    <td title="Number of translated texts">{count(distinct-values($translations))}</td>    
    <td title="Number of translated lines">{count($trlines)}</td>
    </tr>
}
{
    <tr id="stat-ov-texts">
    <td>Texts</td>
    <td title="Total number of texts">{count(collection($config:tls-texts-root)//tei:titleStmt)}</td>
    <td title="Number of text lines">{count(collection($config:tls-texts-root)//tei:seg)}</td>    
    <td title="Number of text characters">{sum(for $s in collection($config:tls-texts-root)//tei:seg
    return (count(string-to-codepoints($s))))
    }</td>
    </tr>
}

</tbody>
</table>
};


declare function local:save-stats(){
let $user := sm:id()//sm:real/sm:username/text()
, $uuid := concat("uuid-", util:uuid())
, $filename := $uuid || ".xml"
,$date := current-dateTime()
,$docpath := $config:tls-data-root || "/statistics/" || $filename
let $doc :=
  if (not (doc-available($docpath))) then
   doc(xmldb:store($config:tls-data-root || "/statistics/", $filename, 
<div type="statistics" modified="{$date}">
{local:overview(),
local:translations()}
</div>   
)) 
 else doc($docpath)
return ()
(:     (sm:chmod(xs:anyURI($docpath), "rw-rw-rw-"),
       sm:chgrp(xs:anyURI($docpath), "tls-user"), 
     sm:chown(xs:anyURI($docpath), "tls")) :)
};

(
local:save-stats(),
sgn:check-approved()
)