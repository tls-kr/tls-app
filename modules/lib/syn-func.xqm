xquery version "3.1";
(:~
: This module deals with the syntactical functions and semantic features

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace lsf="http://hxwd.org/lib/syn-func";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace lsi="http://hxwd.org/special-interest" at "special-interest.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";
import module namespace ltx="http://hxwd.org/taxonomy" at "taxonomy.xqm";

import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";


import module namespace templates="http://exist-db.org/xquery/templates" ;

import module namespace wd="http://hxwd.org/wikidata" at "../wikidata.xql"; 


declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
(: this displays the syn-func :)
declare 
%templates:wrap 
function lsf:syn-func($node as node()*, $model as map(*), $uuid as xs:string?){
let $sf := doc($config:tls-data-root||"/core/syntactic-functions.xml")//tei:div[@xml:id = $uuid]
, $rel := doc($config:tls-data-root||"/core/syntactic-functions.xml")//tei:ref[@target= "#" || $uuid]
, $lexent := collection($config:tls-data-root||"/concepts")//tls:syn-func[@corresp="#" || $uuid]
, $atts := collection($config:tls-data-root||"/notes")//tls:syn-func[@corresp="#" || $uuid]
return
<div class="row">
<div class="col-md-3"></div>

<div class="card col-md-6" style="max-width: 1000px;">
 <div class="card-header">
  <h4 class="card-title">Syntactic function <span id="{$uuid}" class="font-weight-bold" >{$sf/tei:head/text()}</span></h4>
  <div class="card-body">
  {for $p in $sf/tei:p return <p>{$p/text()}</p>}
  {if ($sf/tei:note) then 
   <p class="text-muted">{$sf/tei:note}</p> else ()
  }
  <hr/>
  <h5>Usage</h5>
  <ul><li>Lexical entries:  <button class="btn badge badge-light ml-2" type="button"  onclick="show_use_of('syn-func', '{$uuid}')" title="Click here to show at most 30 lexical entries">{count($lexent)}</button></li></ul>
  <ul id="{$uuid}-resp"><li>Found {count($atts)} attributions</li></ul>
  <hr/>
  {if ($rel) then (
  <h5>Hypernym</h5>,
  <ul>
  {for $r in $rel
   let $p := $r/ancestor::tei:div[@type='syn-func']
  return
  <li><a href="syn-func.html?uuid={$p/@xml:id}" title="{$p/tei:p[1]}">{$p/tei:head/text()}</a></li>}
  </ul>
  ) else ()}
  {if ($sf/tei:div[@type='pointers']) then 
  (<h5>Hyponym</h5>,
  <ul>
  {for $i in $sf//tei:list[@type="taxonymy"]/tei:item
  
  return 
  <li><a href="syn-func.html?uuid={substring($i/tei:ref/@target,2)}">{$i}</a></li>
  }
   </ul>) else ()
   }
  </div>
 </div>
</div>
</div>   
};

(: dispatcher :)
declare function lsf:get-sw-dispatch($word, $context, $domain, $leftword){
let $pref := lus:get-sf-display-setting()
return 
( if (lpm:show-buddhist-tools($context)) then 
  let $qc := for $c in string-to-codepoints($word) return codepoints-to-string($c)
  return
  <ul>{lrh:maybe-show-items(map{'qc' : $qc})}</ul> else (),
  switch($pref)
case 'by-syn-func' return
 lsf:get-sw-by-syn-func($word, $context, $domain, $leftword)
case 'by-frequency' return
 lsf:get-sw-by-frequency($word, $context, $domain, $leftword)
default return
 lsf:get-sw-by-concept($word, $context, $domain, $leftword)
)
};

(: produce the list and return as array  
required: word, domain, context
:)

declare function lsf:get-sw-list($map as map(*)){
let $w-context := ($map?context = "dic") or contains($map?context, "concept")
let $ws := if ($w-context) then  
      collection($config:tls-data-word-root)//tei:entry[.//tei:orth[contains(. , $map?word)]]/tei:sense
    else 
      collection($config:tls-data-word-root)//tei:entry[.//tei:orth[. = $map?word]]/tei:sense
  for $w in $ws
  let $concept := $w/@tls-concept/string()
      , $concept-id := $w/@tls:concept-id/string()
      , $cdef := ltx:get-catdesc($concept-id, 'tls-concepts-top', 'def')
      , $wid := $w/ancestor::tei:entry/@xml:id
      , $py := $w/ancestor::tei:entry/tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]/text()
      , $zi := $w/ancestor::tei:entry/tei:form/tei:orth/text()
      , $sid := $w/@xml:id
      , $sfs := ($w//tls:syn-func)[1]
      , $sfid := substring(($sfs/@corresp), 2)
      , $atts := xs:int($w/@n)
      , $def := $w//tei:def/text()
      , $sm := $w//tls:sem-feat/text()
      , $smid := substring($sm/@corresp, 2)
return
(:1    2     3     4          5           6     7      8    9      10    11    12    13:)
[$zi, $py, $wid, $concept, $concept-id, $sfs, $sfid, $sm, $smid, $sid, $def, $atts, $w/@resp]
};


(: colors : #FFC647 (goldenrod), 
#5220DD
blue #17224D, #17C6E9
:)

declare function lsf:display-sense($sw as node(), $count as xs:int, $display-word as xs:boolean){
    let $id := if ($sw/@xml:id) then data($sw/@xml:id) else substring($sw/@corresp, 2),
    $sf := ($sw//tls:syn-func/text())[1],
    $sm := $sw//tls:sem-feat/text(),
    $user := sm:id()//sm:real/sm:username/text(),
    $def := $sw//tei:def/text(),
    $char := $sw/preceding-sibling::tei:form[1]/tei:orth/text()
    , $resp := tu:get-member-initials($sw/@resp)
    return
    <li id="{$id}">
    {if ($display-word) then <span class="ml-2">{$char}</span> else ()}
    <span id="sw-{$id}" class="font-weight-bold">{$sf}</span>
    <em class="ml-2">{$sm}</em> 
    <span class="ml-2">{$def}</span>
    {if ($resp[1]) then 
    <small><span class="ml-2 btn badge-secondary" title="{$resp[1]} - {$sw/@tls:created}">{$resp[2]}</span></small> else ()}
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp" onclick="show_att('{$id}')">
          {if ($count > -1) then $count else ()}
          {if ($count = 1) then " Attribution" else  " Attributions" }
      </button>
     {if ($user = "guest") then () else 
      if ($count != -1 and not($display-word)) then
     <button title="Search for this word" class="btn badge btn-outline-success ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp1" onclick="search_and_att('{$id}')">
      <img class="icon-small" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
      </button> else (),
      if ($count = 0) then
      lrh:format-button("delete_word_from_concept('"|| $id || "')", "Delete the syntactic word "|| $sf || ".", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else 
      if ($count > 0) then (
      lrh:format-button("move_word('"|| $char || "', '"|| $id ||"', '"||$count||"')", "Move the SW  '"|| $sf || "' including "|| $count ||"attribution(s) to a different concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor") ,      
      lrh:format-button("merge_word('"|| $sf || "', '"|| $id ||"', '"||$count||"')", "Delete the SW '"|| $sf || "' and merge "|| $count ||"attribution(s) to a different SW.", "open-iconic-master/svg/wrench.svg", "", "", "tls-editor")       
      )
      else ()
      }
      <div id="{$id}-resp" class="collapse container"></div>
      <div id="{$id}-resp1" class="collapse container"></div>
    </li>
 
 };



declare function lsf:format-grouping-item($map){
<span style="{$map?style}"><strong title="{$map?title}"><a href="syn-func.html?uuid={$map?uuid}">{$map?item}</a></strong>
<!--<span class="text-muted" title="there are a total of {sum($w?12)} attribution">{sum($w?12)}</span> -->
<button title="There are a total of {$map?sum} attributions in {$map?count} syntactic words. Click to reveal" class="btn badge badge-light" type="button" 
data-toggle="collapse" data-target="#{$map?uuid}-synfunc">{$map?count}</button></span>
};

(: This displays the list of words by syn-func in the right hand popup pane (floater)  :)
declare function lsf:get-sw-by-syn-func($word as xs:string, $context as xs:string, $domain as xs:string, $leftword as xs:string) as item()* {
let $map := map{'word' : $word, 'domain' : $domain, 'context' : $context}
, $list := lsf:get-sw-list($map)
, $doann := contains($context, 'textview')  (: the page we were called from can annotate :)
, $user := sm:id()//sm:real/sm:username/text()
, $edit := sm:id()//sm:groups/sm:group[. = "tls-editor"] and $doann
, $sum := sum(for $a in $list return $a?12 )
return
(<li><a href="char.html?char={$word}" title="Click here to go to the taxonomy for {$word}"><span id="syn-disp-zi">{$word}</span></a>&#160;Total annotations: <strong>{$sum}</strong> <span class="text-muted">(by syntactic functions)</span></li>,
for $w in $list
  let $sfs := $w?6
  group by $sfs
  let $lsum := sum($w?12)
  , $g:= if ($sum > 0) then lu:get-gradient( (181,60,255),  (0,0,100), $sum, $lsum) else ()
  let $style := try{ if ( ($lsum div $sum) > 0.1) then 
                "background: rgb(" || string-join($g, ',') ||"); color:white;" 
                else 
                ""} catch * {()}
  ,$map := map{'style' : $style, 'title' : lsf:get-sf-def($w[1]?7, 'syn-func'), 'uuid' : $w[1]?7, 'item' : $sfs, 'sum' : sum($w?12), 'count' : count($w)}
  order by $sfs  
return
<li>{lsf:format-grouping-item($map)}
<ul class="collapse" id="{$w[1]?7}-synfunc">
{
for $s at $pos in $w
let $def := $s?11
let $sf := ($s?6)[1],
$sfid := $s?7,
$sm := $s?8,
$smid := $s?9,
$sid := $s?10,
$sresp := tu:get-member-initials($s?13),
$clicksf := if ($edit) then concat("get_sf('" , $sid , "', 'syn-func')") else "",
$clicksm := if ($edit) then concat("get_sf('" , $sid , "', 'sem-feat')") else "",
$atts := $s?12,
$wid := $s?3,
$zi := $s?1,
$py := $s?2,
$concept-id := $s?5,
$cdef := "", 
$concept := $s?4,
$esc := replace($concept[1], "'", "\\'")
order by $atts descending
return
<li  class="mb-3 chn-font">
<span id="{$wid}-{$pos}-py" title="Click here to change pinyin" onclick="assign_guangyun_dialog({{'zi':'{$zi}', 'wid':'{$wid}','py': '{$py}','concept' : '{$esc}', 'concept_id' : '{$concept-id}', 'pos' : '{$pos}'}})">&#160;({string-join($py, "/")})&#160;</span>
{if ($edit) then
(<a href="#" onclick="{$clicksf}" title="{lsf:get-sf-def($sfid, 'syn-func')}">{$sf}&#160;</a>)
else ()
}
{
 if (string-length($sm) > 0) then
 <em title="{lsf:get-sf-def($smid, 'sem-feat')}">{$sm}</em>
 else 
  if ($edit) then
  (: allow for newly defining sem-feat :) 
  <a href="#" onclick="{$clicksm}" title="Click here to add a semantic feature to the SWL">＋</a>
  else ()
}

<span class="swedit" id="def-{$sid}" contenteditable="{if ($edit) then 'true' else 'false'}">{ $def}</span>

<strong><a href="concept.html?uuid={$concept-id}#{$wid}" title="{$cdef}" >{$concept}</a></strong> 
     { if (sm:is-authenticated()) then 
     (
     if ($user != 'test' and $doann) then
     <button class="btn badge badge-primary ml-2" type="button" onclick="save_this_swl('{$sid}')">
           Use
      </button> else ()) else ()}

     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$sid}-resp" onclick="show_att('{$sid}')">
      <span class="ml-2">SWL: {$atts}</span>
      </button> 
      
      <div id="{$sid}-resp" class="collapse container"></div>

</li>
} 
</ul>
</li>
)
};

(: This displays the list of words by frequency in the right hand popup pane (floater)  :)
declare function lsf:get-sw-by-frequency($word as xs:string, $context as xs:string, $domain as xs:string, $leftword as xs:string) as item()* {
let $map := map{'word' : $word, 'domain' : $domain, 'context' : $context}
, $list := lsf:get-sw-list($map)
, $doann := contains($context, 'textview')  (: the page we were called from can annotate :)
, $user := sm:id()//sm:real/sm:username/text()
, $edit := sm:id()//sm:groups/sm:group[. = "tls-editor"] and $doann
, $sum := sum(for $a in $list return $a?12 )
return
(<li><a href="char.html?char={$word}" title="Click here to go to the taxonomy for {$word}"><span id="syn-disp-zi">{$word}</span></a>&#160;Total annotations: <strong>{$sum}</strong>&#160;<span class="text-muted">(frequent use first)</span></li>,
for $w in $list
  order by $w?12 descending  
return
<ul  id="{$w[1]?7}-synfunc">

{
for $s at $pos in $w
let $def := $s?11
let $sf := ($s?6)[1],
$sfid := $s?7,
$sm := $s?8,
$smid := $s?9,
$sid := $s?10,
$sresp := tu:get-member-initials($s?13),
$clicksf := if ($edit) then concat("get_sf('" , $sid , "', 'syn-func')") else "",
$clicksm := if ($edit) then concat("get_sf('" , $sid , "', 'sem-feat')") else "",
$atts := $s?12,
$wid := $s?3,
$zi := $s?1,
$py := $s?2,
$concept-id := $s?5,
$cdef := "", 
$concept := $s?4,
$esc := replace($concept[1], "'", "\\'")
order by $atts descending
return
<li  class="mb-3 chn-font">
<span id="{$wid}-{$pos}-py" title="Click here to change pinyin" onclick="assign_guangyun_dialog({{'zi':'{$zi}', 'wid':'{$wid}','py': '{$py}','concept' : '{$esc}', 'concept_id' : '{$concept-id}', 'pos' : '{$pos}'}})">&#160;({string-join($py, "/")})&#160;</span>
{if ($edit) then
(<a href="#" onclick="{$clicksf}" title="{lsf:get-sf-def($sfid, 'syn-func')}">{$sf}&#160;</a>)
else 
(<span class="font-weight-bold" title="{lsf:get-sf-def($sfid, 'syn-func')}">{$sf}</span>)
}
{
 if (string-length($sm) > 0) then
 <em title="{lsf:get-sf-def($smid, 'sem-feat')}">{$sm}</em>
 else 
  if ($edit) then
  (: allow for newly defining sem-feat :) 
  <a href="#" onclick="{$clicksm}" title="Click here to add a semantic feature to the SWL">＋</a>
  else ()
}

<span class="swedit" id="def-{$sid}" contenteditable="{if ($edit) then 'true' else 'false'}">{ $def}</span>

<strong><a href="concept.html?uuid={$concept-id}#{$wid}" title="{$cdef}" >{$concept}</a></strong> 
     { if (sm:is-authenticated()) then 
     (
     if ($user != 'test' and $doann) then
     <button class="btn badge badge-primary ml-2" type="button" onclick="save_this_swl('{$sid}')">
           Use
      </button> else ()) else ()}

     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$sid}-resp" onclick="show_att('{$sid}')">
      <span class="ml-2">SWL: {$atts}</span>
      </button> 
      
      <div id="{$sid}-resp" class="collapse container"></div>

</li>
} 
</ul>
)
};



declare function lsf:get-sw($word as xs:string, $context as xs:string, $domain as xs:string, $leftword as xs:string) as item()* {
let $map := map{'word' : $word, 'domain' : $domain, 'context' : $context}
, $list := lsf:get-sw-list($map)
, $w-context := ($context = "dic") or contains($context, "concept")
, $doann := contains($context, 'textview')  (: the page we were called from can annotate :)
, $user := sm:id()//sm:real/sm:username/text()
, $edit := sm:id()//sm:groups/sm:group[. = "tls-editor"] and $doann
, $sum := sum(for $a in $list return $a?12 )
return
(<li>Total annotations: <strong>{$sum}</strong></li>,
for $w in $list
  let $concept := $w?4
  group by $concept
  order by $concept
  
return
for $s at $pos in $w
let $def := $s?11
let $sf := ($s?6)[1],
$sfid := $s?7,
$sm := $s?8,
$smid := $s?9,
$sid := $s?10,
$resp := tu:get-member-initials($s?13),
$clicksf := if ($edit) then concat("get_sf('" , $sid , "', 'syn-func')") else "",
$clicksm := if ($edit) then concat("get_sf('" , $sid , "', 'sem-feat')") else "",
$atts := $s?12,
$wid := $s?3,
$zi := $s?1,
$py := $s?2,
$id := $s?5,
$cdef := "", 
$concept := $s?4,
$esc := replace($concept[1], "'", "\\'"),
$scnt := count($w),
$syn := collection($config:tls-data-root)//tei:div[@xml:id = $id]//tei:div[@type="old-chinese-criteria"]//tei:p,
$wx := collection($config:tls-data-root)//tei:entry[@xml:id = $wid]
, $global-def := ""
order by $concept ascending
return
<li class="mb-3 chn-font">
{if ($zi) then
(: todo : check for permissions :)
(<strong>
{ if (not ($w-context)) then <a href="char.html?char={$zi}" title="Click here to go to the taxonomy for {$zi}"><span id="{$wid}-{$pos}-zi">{$zi}</span></a> else <span id="{$wid}-{$pos}-zi">{$zi}</span>}
</strong>,<span id="{$wid}-{$pos}-py" title="Click here to change pinyin" onclick="assign_guangyun_dialog({{'zi':'{$zi}', 'wid':'{$wid}','py': '{$py}','concept' : '{$esc}', 'concept_id' : '{$id}', 'pos' : '{$pos}'}})">&#160;({string-join($py, "/")})&#160;</span>)
else ""}
<strong><a href="concept.html?uuid={$id}#{$wid}" title="{$cdef}">{$concept}</a></strong> 
 {if ($resp[1]) then <button class="ml-2 btn badge badge-light" title="{$resp[1]} - {$wid/ancestor::tei:entry/@tls:created}">{$resp[2]}</button> else ()}

{if ($doann and sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then 
 if ($wid) then     
      if (string-length($leftword) = 0) then
     (<button class="btn badge badge-secondary ml-2" type="button" 
 onclick="show_newsw({{'wid':'{$wid}','py': '{string-join($py, "/")}','concept' : '{$esc}', 'concept_id' : '{$id}'}})">
           New SW
      </button>,
      <button title="Start defining a word relation by setting the left word" class="btn badge badge-secondary ml-2" type="button" onclick="set_leftword({{'wid':'{$wid}', 'concept' : '{$esc}', 'concept_id' : '{$id}'}})">LW</button>)
      else
      <button title="Set the right word of word relation for {$leftword}" class="btn badge badge-primary ml-2" type="button" onclick="set_rightword({{'wid':'{$wid}', 'concept' : '{$esc}', 'concept_id' : '{$id}'}})">RW</button>
else 
<button class="btn badge badge-secondary ml-2" type="button" 
onclick="show_newsw({{'wid':'xx', 'py': '{string-join($py, "/")}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">
           New Word
      </button>
   else ()}

{if ($scnt > 0) then      
<span>      
 {if ($context = 'dic') then wd:display-qitems($wid, $context, $zi) else ()}
{if (count($syn) > 0) then
<button title="Click to view {count($syn)} synonyms" class="btn badge badge-info ml-2" data-toggle="collapse" data-target="#{$wid}-syn">SYN</button> else 
if ($edit) then 
<button title="Click to add synonyms" class="btn" onclick="new_syn_dialog({{'char' : '{$zi}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">＋</button>
else ()
}
<button title="click to reveal {$scnt} syntactic words" class="btn badge badge-light" type="button" data-toggle="collapse" data-target="#{$wid}-concept">{$scnt}</button>
<ul class="list-unstyled collapse" id="{$wid}-syn" style="swl-bullet">{
for $l in $syn
return
<li>{$l}</li>
}
</ul>
<ul class="list-unstyled collapse" id="{$wid}-concept" style="swl-bullet">
{ if ($global-def) then
<li>
{$global-def}
</li>
else ()
}
{for $s in $wx/ancestor::tei:entry/tei:sense
let $sf := ($s//tls:syn-func)[1],
$sfid := substring(($sf/@corresp), 2),
$sm := $s//tls:sem-feat/text(),
$smid := substring($sm/@corresp, 2),
$def := $s//tei:def/text(),
$sid := $s/@xml:id,
$sresp := tu:get-member-initials($s/@resp),
$clicksf := if ($edit) then concat("get_sf('" , $sid , "', 'syn-func')") else "",
$clicksm := if ($edit) then concat("get_sf('" , $sid , "', 'sem-feat')") else "",
$atts := count(collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = "#" || $sid])
order by $sf
(:  :)
return
<li>
<span id="pop-{$s/@xml:id}" class="small btn">●</span>

<a href="#" onclick="{$clicksf}" title="{lsf:get-sf-def($sfid, 'syn-func')}">{$sf/text()}</a>&#160;{
if (string-length($sm) > 0) then
<a href="#" onclick="{$clicksm}" title="{lsf:get-sf-def($smid, 'sem-feat')}">{$sm}</a>
else 
 if ($edit) then
(: allow for newly defining sem-feat :) 
 <a href="#" onclick="{$clicksm}" title="Click here to add a semantic feature to the SWL">＋</a>
 else ()

}: 
<span class="swedit" id="def-{$sid}" contenteditable="{if ($edit) then 'true' else 'false'}">{ $def}</span>
 {if ($sresp) then <button class="ml-2 btn badge badge-light" title="{$sresp[1]} - {$s/ancestor::tei:entry/@tls:created}">{$resp[2]}</button> else ()}

    {if ($edit) then 
     <button class="btn badge badge-warning ml-2" type="button" onclick="save_def('def-{$sid}')">
           Save
     </button>
    else ()}
     { if (sm:is-authenticated()) then 
     (
     if ($user != 'test' and $doann) then
     <button class="btn badge badge-primary ml-2" type="button" onclick="save_this_swl('{$s/@xml:id}')">
           Use
      </button> else ()) else ()}
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$sid}-resp" onclick="show_att('{$sid}')">
      <span class="ml-2">SWL: {$atts}</span>
      </button> 
      
      <div id="{$sid}-resp" class="collapse container"></div>
</li>
}
</ul>
</span> 
else ()
}
</li>

)

(:else 
<li class="list-group-item">No word selected or no existing syntactic word found.</li>
:)

};

(: This displays the list of words by concept in the right hand popup pane (floater)  :)
declare function lsf:get-sw-by-concept($word as xs:string, $context as xs:string, $domain as xs:string, $leftword as xs:string) as item()* {
let $w-context := ($context = "dic") or contains($context, "concept")
, $coll := if ($domain = ("core", "undefined")) then "/concepts/" else "/domain/"||$domain
let $words-tmp := if ($w-context) then 
  collection($config:tls-data-root||$coll)//tei:orth[contains(. , $word)]
  else
  collection($config:tls-data-root||$coll)//tei:entry/tei:form/tei:orth[. = $word]
  (: this is to filter out characters that occur multiple times in a entry definition (usually with different pronounciations, however we actually might want to get rid of them :)
, $words := for $w in $words-tmp
   let $e := $w/ancestor::tei:entry
   group by $e
   return $w[1]
let $user := sm:id()//sm:real/sm:username/text()
, $doann := contains($context, 'textview')  (: the page we were called from can annotate :)
, $edit := sm:id()//sm:groups/sm:group[. = "tls-editor"] and $doann
, $taxdoc := doc($config:tls-data-root ||"/core/taxchar.xml")
(: creating a map as a combination of the concepts in taxchar and the existing concepts :)
, $wm := map:merge((
    for $c in $taxdoc//tei:div[tei:head[. = $word]]//tei:ref
        let $s := $c/ancestor::tei:list/tei:item[@type='pron'][1]/text()
    return
        if (string-length($s) > 0) then (
      let $pys := tokenize(normalize-space($s), '\s+') 
       , $py := if (lu:iskanji($pys[1])) then $pys[2] else $pys[1]
        return map:entry(substring($c/@target, 2), map {"concept": $c/text(), "py" : $py, "zi" : $word})
        ) else ()    
    ,
    for $w in $words
    let $concept := $w/ancestor::tei:div/tei:head/text(),
    $wid := $w/ancestor::tei:entry/@xml:id,
    $concept-id := $w/ancestor::tei:div/@xml:id,
    $py := $w/parent::tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]/text(),
    $zi := $w/parent::tei:form/tei:orth/text(),
    $cwid := concat(data($concept-id), "::", data($wid))
    group by $concept-id
    return map:entry($concept-id, map {"concept": $concept, "py" : $py, "zi" : $zi, "w" : $w})
    ))          
return
if (map:size($wm) > 0) then
for $id in map:keys($wm)
let $concept := map:get($wm($id), "concept"),
(:$w := map:get($wm($id), "w"):)
(:$w := collection(concat($config:tls-data-root, '/concepts/'))//tei:entry[@xml:id = $cid[2]]//tei:orth:)
$w := collection($config:tls-data-root||$coll)//tei:div[@xml:id = $id]//tei:orth[. = $word]
,$cdef := $w/ancestor::tei:div/tei:div[@type="definition"]/tei:p/text(),
$form := $w/parent::tei:form/@corresp,
$z := map:get($wm($id), "zi")
(:$py := for $p in map:get($wm($id), "py")
        return normalize-space($p):)
(:group by $concept:)
order by $concept[1]
return
(: since I used "order by" for populating the map, some values are sequences now, need to disentangle that here  :)
for $zi at $pos in distinct-values($z) 
(: there might be more than one entry that has the char $zi, so $wx is a sequence of one or more
 we need to loop through these entries:)
for $wx at $pw in (collection($config:tls-data-root||$coll)//tei:div[@xml:id = $id]//tei:orth[. = $zi])[1]
(: we take only the first, because for multiple readings of the same char, we have two entries here :)


let $scnt := for $w1 in $wx return
           count($w1/ancestor::tei:entry/tei:sense),
$resp := tu:get-member-initials($wx/ancestor::tei:entry/@resp),
$wid := $wx/ancestor::tei:entry/@xml:id,
$syn := $wx/ancestor::tei:div[@xml:id = $id]//tei:div[@type="old-chinese-criteria"]//tei:p,
$py := for $pp in $wx/ancestor::tei:entry/tei:form[tei:orth[.=$zi]]/tei:pron[@xml:lang="zh-Latn-x-pinyin"] return normalize-space($pp),
$global-def := $wx/ancestor::tei:entry/tei:def,
$esc := replace($concept[1], "'", "\\'")
return
<li class="mb-3 chn-font">
{if ($zi) then
(: todo : check for permissions :)
(<strong>
{ if (not ($w-context)) then <a href="char.html?char={$zi}" title="Click here to go to the taxonomy for {$zi}"><span id="{$wid}-{$pos}-zi">{$zi}</span></a> else <span id="{$wid}-{$pos}-zi">{$zi}</span>}
</strong>,<span id="{$wid}-{$pos}-py" title="Click here to change pinyin" onclick="assign_guangyun_dialog({{'zi':'{$zi}', 'wid':'{$wid}','py': '{$py[$pos]}','concept' : '{$esc}', 'concept_id' : '{$id}', 'pos' : '{$pos}'}})">&#160;({string-join($py, "/")})&#160;</span>)
else ""}
<strong><a href="concept.html?uuid={$id}#{$wid}" title="{$cdef}" class="{if ($scnt[$pw] = 0) then 'text-muted' else ()}">{$concept[1]}</a></strong> 
 {if ($resp[1]) then <button class="ml-2 btn badge badge-light" title="{$resp[1]} - {$wx/ancestor::tei:entry/@tls:created}">{$resp[2]}</button> else ()}

{if ($doann and sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then 
 if ($wid) then     
      if (string-length($leftword) = 0) then
     (<button class="btn badge badge-secondary ml-2" type="button" 
 onclick="show_newsw({{'wid':'{$wid}','py': '{string-join($py, "/")}','concept' : '{$esc}', 'concept_id' : '{$id}'}})">
           New SW
      </button>,
      <button title="Start defining a word relation by setting the left word" class="btn badge badge-secondary ml-2" type="button" onclick="set_leftword({{'wid':'{$wid}', 'concept' : '{$esc}', 'concept_id' : '{$id}'}})">LW</button>)
      else
      <button title="Set the right word of word relation for {$leftword}" class="btn badge badge-primary ml-2" type="button" onclick="set_rightword({{'wid':'{$wid}', 'concept' : '{$esc}', 'concept_id' : '{$id}'}})">RW</button>
else 
<button class="btn badge badge-secondary ml-2" type="button" 
onclick="show_newsw({{'wid':'xx', 'py': '{string-join($py, "/")}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">
           New Word
      </button>
   else ()}

{if ($scnt > 0) then      
<span>      
 {if ($context = 'dic') then wd:display-qitems($wid, $context, $zi) else ()}
{if (count($syn) > 0) then
<button title="Click to view {count($syn)} synonyms" class="btn badge badge-info ml-2" data-toggle="collapse" data-target="#{$wid}-syn">SYN</button> else 
if ($edit) then 
<button title="Click to add synonyms" class="btn" onclick="new_syn_dialog({{'char' : '{$zi}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">＋</button>
else ()
}
<button title="click to reveal {count($wx/ancestor::tei:entry/tei:sense)} syntactic words" class="btn badge badge-light" type="button" data-toggle="collapse" data-target="#{$wid}-concept">{$scnt}</button>
<ul class="list-unstyled collapse" id="{$wid}-syn" style="swl-bullet">{
for $l in $syn
return
<li>{$l}</li>
}
</ul>
<ul class="list-unstyled collapse" id="{$wid}-concept" style="swl-bullet">
{ if ($global-def) then
<li>
{$global-def}
</li>
else ()
}
{for $s in $wx/ancestor::tei:entry/tei:sense
let $sf := ($s//tls:syn-func)[1],
$sfid := substring(($sf/@corresp), 2),
$sm := $s//tls:sem-feat/text(),
$smid := substring($sm/@corresp, 2),
$def := $s//tei:def/text(),
$sid := $s/@xml:id,
$sresp := tu:get-member-initials($s/@resp),
$clicksf := if ($edit) then concat("get_sf('" , $sid , "', 'syn-func')") else "",
$clicksm := if ($edit) then concat("get_sf('" , $sid , "', 'sem-feat')") else "",
$atts := count(collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = "#" || $sid])
order by $sf
(:  :)
return
<li>
<span id="pop-{$s/@xml:id}" class="small btn">●</span>

<a href="#" onclick="{$clicksf}" title="{lsf:get-sf-def($sfid, 'syn-func')}">{$sf/text()}</a>&#160;{
if (string-length($sm) > 0) then
<a href="#" onclick="{$clicksm}" title="{lsf:get-sf-def($smid, 'sem-feat')}">{$sm}</a>
else 
 if ($edit) then
(: allow for newly defining sem-feat :) 
 <a href="#" onclick="{$clicksm}" title="Click here to add a semantic feature to the SWL">＋</a>
 else ()

}: 
<span class="swedit" id="def-{$sid}" contenteditable="{if ($edit) then 'true' else 'false'}">{ $def}</span>
 {if ($sresp) then <button class="ml-2 btn badge badge-light" title="{$sresp[1]} - {$s/ancestor::tei:entry/@tls:created}">{$resp[2]}</button> else ()}

    {if ($edit) then 
     <button class="btn badge badge-warning ml-2" type="button" onclick="save_def('def-{$sid}')">
           Save
     </button>
    else ()}
     { if (sm:is-authenticated()) then 
     (
     if ($user != 'test' and $doann) then
     <button class="btn badge badge-primary ml-2" type="button" onclick="save_this_swl('{$s/@xml:id}')">
           Use
      </button> else ()) else ()}
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$sid}-resp" onclick="show_att('{$sid}')">
      <span class="ml-2">SWL: {$atts}</span>
      </button> 
      
      <div id="{$sid}-resp" class="collapse container"></div>
</li>
}
</ul>
</span> 
else ()
}
</li>
else 
<li class="list-group-item">No word selected or no existing syntactic word found.</li>
};


declare function lsf:get-sf-def($sfid as xs:string, $type as xs:string){
let $sfdef := if ($type= 'syn-func') then 
  doc($config:tls-data-root || "/core/syntactic-functions.xml")//tei:div[@xml:id=$sfid]/tei:p/text()
  else 
  doc($config:tls-data-root || "/core/semantic-features.xml")//tei:div[@xml:id=$sfid]/tei:p/text()
return $sfdef
};


