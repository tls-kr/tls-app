xquery version "3.1";

(:~
 : Library module for various types of data review.
 :
 : @author Christian Wittern
 : @date 2024-11-06
 :)

module namespace lrv="http://hxwd.org/lib/review";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace lv="http://hxwd.org/lib/vault" at "vault.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace lvs="http://hxwd.org/lib/visits" at "visits.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tx="http://exist-db.org/tls";
declare namespace tls="http://hxwd.org/ns/1.0";


declare function lrv:review-special($issue as xs:string){
let $user := "#" || sm:id()//sm:username
, $issues := map{
"missing-pinyin" : "Concepts with missing pinyin reading",
"duplicate" : "Concepts with duplicate word entries",
"no-dates" : "Texts with no dates assigned"
}
return
<div>
<h3>Special pages : {map:get($issues, $issue)}</h3>
 <div class="container">
 <ul>
 {switch ($issue)
 case "missing-pinyin" return lrv:review-missing-pinyin()
 case "duplicate" return lrv:review-duplicate()
 case "no-dates" return lrv:review-no-dates()
 default return 
  for $i in map:keys($issues)
  order by $i
  return
  <li><a href="review.html?type=special&amp;issue={$i}">{map:get($issues, $i)}</a></li>
 }
 </ul>
 </div>
</div> 
};

declare function lrv:review-missing-pinyin(){
  let $missing := for $p in (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:pron[@xml:lang="zh-Latn-x-pinyin" and (string-length(.) = 0)] 
  let $z := $p/ancestor::tei:form/tei:orth/text()
  where string-length($z) > 0
  return $p

  for $p in $missing
  let $w := $p/ancestor::tei:entry
  , $c := $p/ancestor::tei:div[@type="concept"]
  let $z := $p/ancestor::tei:form/tei:orth/text()

  return
  <li>{$z}　<a href="concept.html?uuid={$c/@xml:id}#{$w/@xml:id}">{$c/tei:head/text()}</a></li>
};

declare function lrv:review-duplicate(){
 let $dup := 
  for $c in (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@type="concept"]
    for $e in $c//tei:entry
      let $cx := for $o in $e//tei:orth
        let $x := count($c//tei:entry[.//tei:orth[. = $o]])
        let $w := $o/ancestor::tei:entry/@xml:id
              return ($x, $o, $o/ancestor::tei:entry/@xml:id, $w)
    where $cx[1] > 1
   return 
   <li>{$cx[2]/text()}　<a href="concept.html?uuid={$c/@xml:id}&amp;bychar=1#{$cx[4]}">{$c/tei:head/text()}</a> {$cx[1]}</li>
  return (count($dup), $dup)
};

declare function lrv:review-no-dates(){
let $sc := (collection('/db/apps/tls-data/notes/swl')|collection('/db/apps/tls-data/notes/doc'))
, $tc := (collection('/db/apps/tls-texts/data'))

, $res :=
for $y in distinct-values($sc/tei:TEI/@xml:id)
let $i := tokenize($y, "-")[1]
, $x := $sc//tei:TEI[@xml:id=$y]
, $c := count($x/ancestor-or-self::tei:TEI//tls:ann)
, $t := $tc//tei:TEI[@xml:id=$i]
, $d := $t/tei:teiHeader//tei:catRef[@scheme="#tls-dates"]
order by $c descending
where not($d)
return 
    <li cnt="{$c}" at="{base-uri($t)}" >{$i}: {lmd:get-metadata($t, 'title')} ({$c}); 
    <span class="btn badge badge-light " onclick="show_dialog('text-info', {{'textid': '{$i}'}})" title="Information about this text">
           <img class="icon "  src="resources/icons/octicons/svg/info.svg"/></span></li>
    
    
return <ul>{$res}</ul>
};

declare function lrv:review-gloss(){
let $user := "#" || sm:id()//sm:username
  ,$review-items := for $r in 
     (collection($config:tls-data-root || "/guangyun")//tx:guangyun-entry[tx:gloss[starts-with(., "Added by")]] 
    (: | collection($config:tls-data-root || "/guangyun")//tx:guangyun-entry[string-length(tx:gloss) = 0] :)
     )
     let $g := $r/tx:graphs[1]/tx:standardised-graph[1]/tx:graph[1]
       , $date := xs:dateTime($r/tls:metadata/@created)
     order by $date descending
     return $r
return

<div class="container">
<div>
<h3>New pronounciations without gloss: {count($review-items)} items</h3>
<small class="text-muted">Glosses can be added by clicking on "No gloss"<br/>Current pinyin assignments can be confirmed by clicking the pinyin</small>
{for $r at $pos in $review-items
     let $g := $r/tx:graphs[1]/tx:standardised-graph[1]/tx:graph[1]
     ,$py := $r/tx:pronunciation[1]/tx:mandarin[1]/tx:jin[1]
     ,$un := $r/tls:metadata//tx:name
     ,$created := $r/tls:metadata/@created
return
  <div class="row border-top pt-4" id="{data($r/@xml:id)}">
  <div class="col-sm-2">{$g}</div>
  <div class="col-sm-2"><span title="Click here to confirm the current pinyin assignments" onclick="assign_guangyun_dialog({{'zi':'{$g}', 'wid':'','py': '{$py}', 'type' : 'read-only', 'pos' : '{$pos}'}})">{$py}</span></div>  
  <div class="col-sm-3"><span id="gloss-{$pos}" title="Click here to add/change gloss" onclick="update_gloss_dialog({{'zi':'{$g}', 'py': '{$py}', 'uuid': '{$r/@xml:id}',  'pos' : '{$pos}'}})">No gloss</span></div>
  <div class="col-sm-3" title="{$created}">created by {$un}&#160;</div>
  <div class="col-sm-2">{lrh:format-button("delete_pron('" || data($r/@xml:id) || "')", "Immediately delete pronounciation "||$py||" for "||$g, "open-iconic-master/svg/x.svg", "", "close", "tls-editor")}</div>
  </div>,
()
}
</div>
</div>
};

declare function lrv:review-request(){
let $user := "#" || sm:id()//sm:username
, $text := doc($config:tls-add-titles)//work[@request]
, $recent := doc($config:tls-add-titles)//work[@requested-by]
return

<div class="container">
<div>
<h3>Requested texts: {count($text)} items</h3>
{lrv:review-request-rows($text)}
</div>
<div>
<h3>Recently added texts: {count($recent)} items</h3>
{lrv:review-request-rows($recent)}
</div>

</div>
};

declare function lrv:review-request-rows($res as node()*){
for $w at $pos in $res
      let $kid := data($w/@krid)
      , $req := if ($w/@request) then 
        <span id="{$kid}-req">　Requests: {count(tokenize($w/@request, ','))}</span> else 
        <span id="{$kid}-req">　Requested by: {data($w/@requested-by)}</span>
      , $cb := $w/altid except $w/altid[matches(., "^(ZB|SB|SK)")] 
      , $cbid := if ($cb) then $cb else $kid
      , $date := if ($w/@tls-added) then xs:dateTime($w/@tls-added) else xs:dateTime($w/@request-date)
    order by $date descending
return
  <div class="row border-top pt-4" id="{data($w/@krid)}">
  <div class="col-sm-3"><a href="textview.html?location={$kid}">{$kid}　{$w/title/text()}</a></div>
  <div class="col-sm-3"><span>{$req}</span> {" "||data($w/@tls-added)}</div>  
  {if ($w/@request) then
  <div class="col-sm-3"><span id="gloss-{$pos}" title="Click here to add text" onclick="add_text('{$kid}', '{$cbid=> string-join('$')}')">Add: {$cbid}</span></div>
  else
  <div class="col-sm-3"><span id="gloss-{$pos}" title="Click here to analyze text" onclick="analyze_text('{$kid}')">Analyze this text</span></div>
  }
  <div class="col-sm-3"><a target="eXide" href="{
      concat ($config:exide-url, "?open=", $config:tls-texts-root || "/KR/", substring($kid, 1, 3) || "/" || substring($kid, 1, 4) || "/"  || $kid || ".xml")}"
      >Open in eXide</a></div>
  </div>,
()
  
};

declare function lrv:review-swl(){
let $user := "#" || sm:id()//sm:username
  ,$review-items := for $r in collection($config:tls-data-root || "/notes")//tls:metadata[not(@resp= $user)]
       let $score := if ($r/@score) then data($r/@score) else 0
       , $date := xs:dateTime($r/@created)
       where $score < 1 and $date > xs:dateTime("2019-08-29T19:51:15.425+09:00")
       order by $date descending
       return $r/parent::tls:ann
return
<div>
<h3>Reviews due: {count($review-items)}</h3>
 <div class="container">
 {for $att in subsequence($review-items, 1, 20)
  let  $px := substring($att/tls:metadata/@resp, 2)
  let $un := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px]//tei:persName/text()
  , $created := $att/tls:metadata/@created
  return 
  (
  <div class="row border-top pt-4">
  <div class="col-sm-4"><img class="icon" src="resources/icons/octicons/svg/pencil.svg"/>
By <span class="font-weight-bold">{$un}</span>(@{$px})</div>
  <div class="col-sm-5" title="{$created}">created {lrh:display-duration(current-dateTime()- xs:dateTime($created))} ago</div>
  </div>,
lrh:show-att-display($att),
lrh:format-swl($att, map{"type" : "row", "context" : "review"})
  )
 }
 </div>
 <p>Refresh page to see more items.</p>
</div>
};

