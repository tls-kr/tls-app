xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";
import module namespace tu="http://hxwd.org/utils" at "../modules/tlsutils.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(:declare option output:method "html5";:)

declare option output:media-type "text/html";


let $sense-id := request:get-parameter("sense-id", "uuid-20c9da30-27bc-4b0a-ab0a-787663fdf4b2", false())
, $start := request:get-parameter("start", "1", false())
, $count := request:get-parameter("count", "100", false())
, $mode  :=  request:get-parameter("mode", "date", false())
,$sense := collection($config:tls-data-root)//tei:sense[@xml:id = $sense-id]
,$concept-id := $sense/ancestor::tei:entry/@tls:concept-id/string()
,$ann := for $c in collection($config:tls-data-root||"/notes")//tls:ann[@concept-id=$concept-id]
     return $c//tls:srcline/@target
,$label := concat($sense/tei:gramGrp/tls:syn-func, " ", $sense/tei:gramGrp/tls:sem-feat, " ", $sense/tei:def)
,$entry := $sense/ancestor::tei:entry
,$orth := $entry/tei:form/tei:orth
,$user := sm:id()//sm:real/sm:username/text()
,$ratings := doc("/db/users/" || $user || "/ratings.xml")//text
(: not yet using the dates here, this would require refactoring in separate fun, cf app:concept :)
,$dates := if (exists(doc("/db/users/" || $user || "/textdates.xml")//data)) then 
      doc("/db/users/" || $user || "/textdates.xml")//data else 
      doc($config:tls-texts-meta  || "/textdates.xml")//data
,$ret := for $o in $orth/text()
  for $p in  collection($config:tls-texts-root)//tei:p[ngram:contains(., $o)]
    let $src := $p/ancestor::tei:TEI//tei:titleStmt/tei:title/text()
    for $line in util:expand($p)//exist:match/ancestor::tei:seg
    let $target := $line/@xml:id,
    $locs := substring-before(tokenize(substring-before($target, "."), "_")[last()], "-"),
    $textid := tokenize($target, "_")[1],
    $loc := try {if (string-length($locs) > 0) then xs:int($locs) else $locs} catch * {0}, 
    $tr := collection($config:tls-translation-root)//tei:seg[@corresp="#" || $target]
(:    ,$atts := for $a in $ann 
               where $a = "#" || $target
               return $a:)
(:   ,$atts := for $h in collection(concat($config:tls-data-root, '/notes/'))//tls:srcline[@target = "#" || $target]
              let $o1 := $h/ancestor::tls:ann/tei:form[1]/tei:orth[1]/text()
              where ($o1 = $o) 
              return $h:)
    ,$flag := substring($textid, 1, 3)
    (: should I switch this to date sorting as well? :) 
    ,$r :=  if ($mode = "rating") then 
        if ($ratings[@id=$textid]) then xs:int($ratings[@id=$textid]/@rating) else 0
      else
        switch ($flag)
         case "CH1" return 0
         case "CH2" return 300
         case "CH7" return 700
         case "CH8" return -200
         default return
         if (string-length($dates[@corresp="#" || $textid]/@notafter) > 0) then  tu:index-date($dates[@corresp="#" || $textid]) else 0
    
    order by $r descending
    (: I am ignoring all lines that have an attribution to this concept ...  :)
    where $tr and not (contains("#" || $target , $ann))
(:    where $tr:)
return 
<div class="row bg-light table-striped">
<div class="col-sm-2">
 <a href="textview.html?location={$target}" class="font-weight-bold">{$src, $loc}</a>
     { if (sm:is-authenticated()) then 
      let $posx := string-length(substring-before($line, $o)) + 1
      return
     <button title="{$label}" class="btn badge badge-primary ml-2" type="button" onclick="do_save_swl_line('{$sense-id}','{$target}', '{$posx}', '{$line}', '{$src}' )">Use</button>
      else () }</div>
<div class="col-sm-3"><span data-target="{$target}" data-toggle="popover">{
         substring-before($line, $o), 
        <mark>{$o}</mark> 
        ,substring-after($line, $o)}</span></div>
<div class="col-sm-7"><span>{$tr[1]}</span></div>
</div>
, $cnt := count($ret)
return 
if ($cnt > 0) then
<div><p class="ml-2 font-weight-bold">Found {$cnt} matches, returning {min((xs:int($count), $cnt))}.</p>
{
subsequence($ret, $start, $count)
}</div>
else 
<p class="font-weight-bold">No matches found.</p>