xquery version "3.1";

(:~
 : Library module for rendering html fragments
 :
 : @author Christian Wittern
 : @date 2023-10-24
 :)

module namespace lrh="http://hxwd.org/lib/render-html";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";
import module namespace lsi="http://hxwd.org/special-interest" at "special-interest.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace os="http://a9.com/-/spec/opensearch/1.1/";


(:~  checks which available items should be displayed
:)
declare function lrh:maybe-show-items($map as map(*)){
let $sections := ('external-resources', 'internal-resources')
for $type in $sections
for $id in lsi:resource-list($type)
let $p := lus:get-user-item($id)

return if ($p = '1' ) then lrh:render-extra-item($id, $map?qc) else ()
};


declare function lrh:render-extra-item($id, $qc){
if ($id = map:keys($lsi:label)) then 
 if ($lsi:label?($id)[2] = 'char') then 
   lrh:dic-internal($id, $qc)
 else 
   lrh:dic-internal($id, string-join($qc))
else 
 (: we assume external here :)
   lrh:dic-external($id, $qc)
};

declare function lrh:dic-internal($id, $qc){
for $word in $qc
for $w in doc($config:tls-data-root||"/external/" || $id ||".xml")//entry[./orth[. = $word]]
let $link := $w/href/text()
, $def := $w/def/text()
, $pron := $w/pron[@lang='zh']
return 
if ($link) then
<li title="{$lsi:label($id)[3]}" ><span class="ml-2 badge">{$lsi:label($id)[1]}</span><a target="docs" href="{$link}">{$word}</a><small class="text-muted">{$pron}</small>:<span class="ml-2">{$def}</span></li>
else
<li title="{$lsi:label($id)[3]}" ><span class="ml-2 badge">{$lsi:label($id)[1]}</span>{$word} <small class="text-muted">{$pron}</small>:<span class="ml-2">{$def}</span></li>
};

declare function lrh:dic-external($id, $qc){
for $r in collection($lsi:resources)//os:OpenSearchDescription[@xml:id=$id]
let $url := $r/os:Url/@template
, $tags := tokenize($r/os:Tags)
return
if ('char' = $tags) then 
 for $word in $qc
 let $link := replace($url, '\{searchTerms\}', $word)
 return
 <li title="{$r/os:LongName/text()}" ><span class="ml-2 badge">{$r/os:ShortName/text()}</span><a target="docs" href="{$link}">{$word}</a></li>
 else
 let $link := replace($url, '\{searchTerms\}', string-join($qc))
 return
<li title="{$r/os:LongName/text()}" ><span class="ml-2 badge">{$r/os:ShortName/text()}</span><a target="docs" href="{$link}">{string-join($qc)}</a></li>

};

(:~
: format the duration in a human readable way
: @param  $pt a xs:duration instance
:)
declare function lrh:display-duration($pt as xs:duration) {
let $y := years-from-duration($pt)
,$m := months-from-duration($pt)
,$d := days-from-duration($pt)
,$h := hours-from-duration($pt)
,$mi := minutes-from-duration($pt)
,$s := seconds-from-duration($pt)
return
<span>{(
if ($y > 0) then if ($y > 1) then <span> {$y} years </span> else <span>{$y} year </span> else (),
if ($m > 0) then if ($m > 1) then <span> {$m} months </span> else <span> {$m} month </span> else (),
if ($d > 0) then if ($d > 1) then <span> {$d} days </span> else <span> {$d} day </span> else (),
if ($h > 0) then if ($h > 1) then <span> {$h} hours </span> else <span> {$h} hour </span> else (),
if ($mi > 0) then if ($mi > 1) then <span> {$mi} minutes </span> else <span> {$mi} minute </span> else (),
if ($s > 0) then if ($s > 1) then <span> {$s} seconds </span> else <span> {$s} second </span> else ()
)
}
</span>
};


declare function lrh:display-row($map as map(*)){
  <div class="row">
    <div class="col-sm-1">{$map?col1}</div>
    <div class="col-sm-4" title="{$map?col2-tit}"><span class="font-weight-bold float-right">{$map?col2}</span></div>
    <div class="col-sm-7" title="{$map?col3-tit}"><span class="sm">{$map?col3}</span></div>　
  </div>  
};

declare function lrh:simple-input-row($map as map(*)){
  (<div class="row">
    <div class="col-sm-1">{$map?col1}</div>
    <div class="col-sm-4" title="{$map?col2-tit}"><span class="font-weight-bold float-right">{$map?col2}</span></div>
    <div class="col-sm-5" id="{$map?input-id}-group" >
     <input id="{$map?input-id}" type="{$map?type}" name="{$map?input-id}" class="form-control" value="{$map?input-value}"/>
     </div>
    <div class="col-sm-2">
     <button id="tr-search-button" type="button" class="btn btn-outline-success sm-2" onclick="do_tr_search('{$map?input-id}', '{$map?trid}', '1', '25')">
     <img class="icon" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/></button>
   </div>    
 </div>,
 <div class="row">
  <div class="col-sm-12"  id="tr-search-results"></div>
 </div>
) 
};

declare function lrh:get-content-id($textid as xs:string, $slot as xs:string, $tr as map(*)){
   let $show-transl := lpm:should-show-translation()
   , $slot-no := xs:int(substring-after($slot, 'slot')) - 1
   , $select := for $t in map:keys($tr)
        let $lic := $tr($t)[4]
        where if (lpm:should-show-translation()) then $lic < 5 else $lic < 3
        (: TODO in the future, maybe also consider the language :)
        order by $lic ascending
        return $t
   , $content-id := if (lpm:is-testuser()) then 
          lu:session-att($textid || "-" || $slot, $select[1 + $slot-no]) 
        else
          let $t1 := lus:get-settings()//tls:section[@type='slot-config']/tls:item[@textid=$textid and @slot=$slot]/@content
          return
        if ($t1) then data($t1)
          else if (count($select) > $slot-no) then $select[1 + $slot-no] else "new-content"
  return if (string-length($content-id) > 0) then $content-id else "new-content"
};


(:~
: recurse through the supplied node (a tei:seg) and return only the top level text()
: 2020-02-20: created this element because KR2m0054 has <note> elements in translation. 
: @param $node a tei:seg node, typically
:)
declare function lrh:proc-seg($node as node(), $options as map(*)){
 let $lpb := if ($options?lpb) then $options?lpb else true()
 return
 typeswitch ($node)
 case element(tei:note) return ()
(:     <small>{$node/text()}</small>:)
  case element (tei:l) return ()
  case element (tei:c) return 
  if ($options?punc) then
   if ($node/@type = "shifted") then 
     <span class="swxz">{data($node/@n)}</span>
     else
   if ($node/@type = "swxz-uni") then 
     <span class="swxz-uni">{data($node/@n)}</span>
     else
     data($node/@n)
   else ()
  case element (tei:g) return 
   if ($node/@type = "SWXZ-PUA") then 
     <span class="swxz-pua">{$node/text()}</span>
     else
   if ($node/@type = "shifted") then 
     <span class="swxz">{data($node/@n)}</span>
     else
   if ($node/@type = "swxz-uni") then 
     <span class="swxz-uni">{data($node/@n)}</span>
   else 
     $node/text()
  case element (tei:lb)  return 
   if ($lpb) then    
   <span title="{data($node/@ed)}:{data($node/@n)}" class="lb text-muted ed-{data($node/@ed)}"><img class="icon note-anchor" src="{$config:lb}"/></span> else ()
  case element (tei:pb)  return 
   if ($lpb) then    
  <span title="{data($node/@ed)}:{data($node/@n)}" class="lb text-muted ed-{data($node/@ed)}"><img class="icon note-anchor" src="{$config:lb}"/></span>
   else ()
  (: <span title="Click here to display a facsimile of this page\n{data($node/@ed)}:{data($node/@n)}" class="text-muted"><img class="icon note-anchor" onclick="get_facs_for_page('slot1', '{$node/@facs}')" src="{$config:pb}"/></span> :)
  case element (tei:space)  return "　"
  case element (exist:match) return <mark>{$node/text()}</mark>
  case element (tei:hi) return <span class="{if ($node/@rend = 'red') then 'bcj' else ()}" style="color:{$node/@rend}">{$node/text()}</span>
  case element (tei:anchor) return 
    (: since I need it later, I will get it here, even if it might not get a result :)
    let $app := $node/ancestor::tei:TEI//tei:app[@from="#"||$node/@xml:id]
    let $t := if (starts-with($node/@xml:id, "xxnkr_note_mod")) then lrh:format-note($node/ancestor::tei:TEI//tei:note[@target = "#"|| $node/@xml:id]) else
    if (starts-with($node/@xml:id, 'beg')) then 
     if ($app) then
       lrh:format-app($app) else ()
    else
      ()
    return if ($t) then <span title="{$t}" class="text-muted"><img class="icon note-anchor" onclick="edit_app('{$options?textid}','{data($node/@xml:id)}')" src="{$config:circle}"/></span> else ()
  case element(tei:seg) return (if (string-length($node/@n) > 0) then data($node/@n)||"　" else (), for $n in $node/node() return lrh:proc-seg($n, $options))
  case attribute(*) return () 
 default return $node    
};

declare function lrh:format-note($note){
string-join(
for $node in $note/node()
 return
 typeswitch ($node)
 case text() return $node
 case element(tei:c) return
  data($node/@n) 
 default return $node
 ) => normalize-space()
 };

(: format the app for display in the segment :)
declare function lrh:format-app($app as node()){
 let $lwit := $app/ancestor::tei:TEI//tei:witness[@xml:id=substring($app/tei:lem/@wit, 2)]/text()
 let $lem :=   string-join($app/tei:lem//text(), ' ') || $lwit ||"；" 
 , $t := try{ string-join(for $r in $app/tei:rdg
        let $wit := "【" || string-join(for $w in tokenize($r/@wit) return $app/ancestor::tei:TEI//tei:witness[@xml:id=substring($w, 2)]/text() , "，") ||  "】"
        return $r/text() || $wit, "；")  } catch * {"XX"}
 , $note := if ($app/tei:note) then "&#xA;(Note: " || $app/tei:note/text() || ")&#xA;" || $app/tei:note/tei:bibl else ()
  return $lem || $t || $note
};

declare function lrh:multiple-segs($seg, $n){
    string-join(
    for $s at $p in lu:next-n-segs($seg, $n)
    return
    lrh:proc-seg($s, map{"punc" : true()}) )
};

declare function lrh:multiple-segs-plain($loc as xs:string, $prec as xs:int, $foll as xs:int){
let $dseg := lu:get-targetsegs($loc, $prec, $foll)
return
string-join(
  for $s at $p in $dseg
  return
  normalize-space(string-join( lrh:proc-seg($s, map{"punc" : true(), "lpb" : false()}), ''))
, '\n')
};

(: button, mostly at the right side, in which case class will be "close" :)
declare function lrh:format-button($onclick as xs:string, $title as xs:string, $icon as xs:string, $style as xs:string, $class as xs:string, $groups as xs:string+){
 let $usergroups := sm:id()//sm:group/text()
 return
 if (contains($usergroups, $groups)) then
 if (string-length($style) > 0) then
   <button type="button" class="btn {$class}" onclick="{$onclick}"
   title="{$title}">
    {if (ends-with($icon, ".svg")) then 
    <img class="icon" style="width:12px;height:15px;top:0;align:top" src="resources/icons/{$icon}"/>
    else 
    <small><span class="initialism" >{$icon}</span></small>}
   </button>
 else 
   <button type="button" class="btn {$class}" onclick="{$onclick}"
    title="{$title}">
    {if (ends-with($icon, ".svg")) then 
     <img class="icon"  src="resources/icons/{$icon}"/>
    else 
    <span>{$icon}</span>}
   </button>
 else ()
};

declare function lrh:format-button-common($onclick as xs:string, $title as xs:string, $icon as xs:string){
  lrh:format-button($onclick, $title, $icon, "", "close", "tls-user")
};

declare function lrh:swl-buttons($map as map(*)){
( if (lpm:show-setting-restricted('swl-buttons', '')) then
   if ($map?ann = 'wrl') then () else
   ( <span class="rp-5">
       {lrh:format-button("review_swl_dialog('" || data($map?node/@xml:id) || "')", "Review the SWL for " || $map?zi[1], "octicons/svg/unverified.svg", "small", "close", "tls-editor")}&#160;&#160;</span>,   
    lrh:format-button("save_swl_review('" || data($map?node/@xml:id) || "')", "Approve the SWL for " || $map?zi, "octicons/svg/thumbsup.svg", "small", "close", "tls-editor")
    ) else ()

, if (not(lpm:show-setting-restricted('swl-buttons', ''))) then () else 
   if (not($map?context='review')) then
      if (not($map?user = $map?creator-id)) then
   (  lrh:format-button("null()", "Resp: " || $map?resp[1] , $map?resp[2], "small", "close", "tls-user") 
    ,  if ($map?ann = 'wrl') then () else lrh:format-button("incr_rating('swl', '" || data($map?node/@xml:id) || "')", $map?marktext, "open-iconic-master/svg/star.svg", "small", "close", "tls-editor")  
   )  else () else ()
   (: every user can delete her own swls :)
, if ($map?user = $map?creator-id or lpm:show-setting-restricted('swl-buttons', '')) then
    if ($map?ann = 'wrl') then
      lrh:format-button("delete_word_relation('" || data($map?node/@xml:id) || "')", "Immediately delete this WR", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
    else 
      lrh:format-button("delete_swl('swl', '" || data($map?node/@xml:id) || "')", "Immediately delete this SWL for "||$map?zi[1], "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
    else ()
, switch($map?ann)
   case 'wrl' return ()
   case 'nswl' return()
   default return ()
)
};

(:~
: formats a single syntactic word location for display either in a row (as in the textview, made visible by the blue eye) or as a list item, this is used in the left hand display for the annotations
: @param $node  the tls:ann element to display
: @param $type  type of the display, currently 'row' for selecting the row style, anything else will be list style
: called from api/show_swl_for_line.xql
: 2021-10-15: also display other annotation types (e.g. rhetorical devices etc.)
: 2024-11-06 moved here from tlslib
:)
declare function lrh:format-swl($node as node(), $options as map(*)){
let $user := sm:id()//sm:real/sm:username/text(),
$usergroups := sm:get-user-groups($user),
(: already used swl as a class, so need a different one here; for others we want the type given in the source :)
$anntype := if (local-name($node)='ann') then "nswl" else 
               if (local-name($node)='drug') then "drug" else
               if (local-name($node)='item') then "wrl"
               else data($node/@type),
$type := $options?type,
$context := $options?context
let $concept := data($node/@concept),
$creator-id := if ($node/tls:metadata/@resp) then
 substring($node/tls:metadata/@resp, 2) else 
 substring($node/ancestor::tei:div[@type='word-rel-ref']/@resp, 2)  ,
$zi := string-join($node/tei:form/tei:orth/text(), "/")
(: 2021-03-17 we ignore the pinyin from SWL, retrieve the one from concept below as $cpy :)
(:$py := $node/tei:form[1]/tei:pron[starts-with(@xml:lang, 'zh-Latn')][1]/text(),:)
,$link := substring(tokenize($node/tei:link/@target)[2], 2)
(: 2021-03-17 below we get the data from the CONCEPT entry, rather than the SWL, all we need in the SWL now is the link :)
, $s := collection($config:tls-data-root)//tei:sense[@xml:id=$link]
, $w := $s/ancestor::tei:entry
, $czi := string-join($w/tei:form/tei:orth/text(), " / ")
, $cpy := string-join($w/tei:form/tei:pron[@xml:lang='zh-Latn-x-pinyin']/text(), " / ")
,$cdef := $w/ancestor::tei:div/tei:div[@type="definition"]/tei:p/text()
,$sf := $s//tls:syn-func
,$sm := $s//tls:sem-feat
,$def := lu:get-sense-def($link)
,$rid := $options?line-id || "-" || $node/@xml:id 
, $exemplum := if ($node/tls:metadata/@rating) then xs:int($node/tls:metadata/@rating) else 0
, $bg := if ($exemplum > 0) then "protypical-"||$exemplum else "bg-light"
, $marktext := if ($exemplum = 0) then "Mark this attribution as prototypical" else "Currently marked as prototypical "||$exemplum ||". Increase up to 3 then reset."
, $resp := tu:get-member-initials($creator-id)
, $wr-rel :=  $node/ancestor::tei:div[@type='word-rel-ref']
(:$pos := concat($sf, if ($sm) then (" ", $sm) else "")
:)
return
if ($type = "row") then
if ($anntype = "wrl") then 
<div class="row {$bg} {$anntype}">
<div class="col-sm-1"><span class="{$anntype}-col">●</span></div>
<div class="col-sm-2"><span>{$node/text()}</span></div>
<div class="col-sm-3"><a href="concept.html?concept={$concept}{$node/@corresp}" title="{$cdef}">{$concept}</a></div>
<div class="col-sm-6"><span>WR: {$wr-rel/ancestor::tei:div[@type='word-rel-type']/tei:head/text()} /  {data($node/@p)}</span>
  {lrh:swl-buttons(map{'ann': $anntype, 'resp': $resp, 'user' : $user, 'creator-id': $creator-id , 'context' : $context, 'node': $wr-rel})}
</div>
</div>
else
if ($anntype eq "nswl") then
<div class="row {$bg} {$anntype}">
{if (not($context = 'review')) then 
<div class="col-sm-1"><span class="{$anntype}-col">●</span></div>
else ()}
<div class="col-sm-2"><span class="zh chn-font">{$czi}</span> ({$cpy})
{if  ("tls-admin.x" = sm:get-user-groups($user)) then (data(($node//tls:srcline/@pos)[1]),
 <a href="{
      concat($config:exide-url, "?open=", document-uri(root($node)))}">eXide</a>)
      else ()
  }    
</div>
<div class="col-sm-2"><a href="concept.html?concept={$concept}#{$w/@xml:id}" title="{$cdef}">{$concept}</a></div>
<div class="col-sm-7">
<span><a href="browse.html?type=syn-func&amp;id={data($sf/@corresp)}">{($sf)[1]/text()}</a>&#160;</span>
{if ($sm) then 
<span><a href="browse.html?type=sem-feat&amp;id={$sm/@corresp}">{($sm)[1]/text()}</a>&#160;</span> else ()}
<span class="ml-2">{$def}</span>
  {lrh:swl-buttons(map{'ann': $anntype, 'resp': $resp, 'user' : $user, 'creator-id': $creator-id, 'node': $node, 'zi': $zi, 'context' : $context, 'marktext' : $marktext})}
</div>
</div>
else if ($anntype eq "drug") then
<div class="row bg-light {$anntype}">
 <div class="col-sm-2"><span class="{$anntype}-col">drug</span></div>
 <div class="col-sm-6">{$node/text()}, Q:{data($node/@quantity)}, FL:{data($node/@flavor)}
 {
   if (($user = $creator-id) or lpm:show-setting-restricted('swl-buttons', '')) then 
    lrh:format-button("delete_swl('drug', '" || data($node/@xml:id) || "')", "Immediately delete the observation "||data($node/text()), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()
}
</div>
</div>
else
(: not swl, eg: rhet-dev etc :)
<div class="row bg-light {$anntype}" style="{if ($anntype ne 'nswl') then 'display:None;' else ()}">
{
let $role := if (ends-with(data($node/tls:text[tls:srcline[@target="#"||$options?line-id]]/@role), 'start')) then "(●" else "●)"
return
(
 <div class="col-sm-2"><span class="{$anntype}-col">{$role}</span></div>,
 <div class="col-sm-6">{if ($anntype='rdl') then <a href="rhet-dev.html?uuid={$node/@rhet-dev-id}">{data($node/@rhet-dev)}</a> else
 if ($anntype = 'comment') then
 (<span class="text-muted">{collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@xml:id=$anntype]/tei:head/text() || ":　"}</span>, 
  if ($role eq "(●") then
   (: for the comment, we display the note, not the @name, which does not make sense here.. :)
   <span class="{$anntype}-name" data-uuid="{data($node/@xml:id)}" data-lineid="{$options?line-id}">{data($node/tls:note)}</span>
  else ()
  ) 
 else
 (collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@xml:id=$anntype]/tei:head/text() || "　", 
  if ($role eq "(●") then
   <span class="{$anntype}-name" data-uuid="{data($node/@xml:id)}" data-lineid="{$options?line-id}">{data($node/@name)}</span>
  else ()
 )}
{
   if (($user = $creator-id) or lpm:show-setting-restricted('swl-buttons', '')) then 
    lrh:format-button("delete_swl('rdl', '" || data($node/@xml:id) || "')", "Immediately delete the observation "||data($node/@rhet-dev), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()
}
 </div>
) 
}
</div> 
(: not in the row :)
else 
<li class="list-group-item" id="{$concept}">{$cpy} {$concept} {$sf} {$sm} {
if (string-length($def) > 10) then concat(substring($def, 10), "...") else $def}</li>
};


 (:~
 : called from function tlsapi:show-att($uid as xs:string)
  : 2020-02-26 it seems this belongs to tlsapi
  : 2020-03-13 this is called from app:recent 
  : 2024-11-06 moved here from tlslib
 :)
 
declare function lrh:show-att-display($a as node()){

let $user := sm:id()//sm:real/sm:username/text()
let $src := data($a/tls:text/tls:srcline/@title)
let $line := $a/tls:text/tls:srcline/text()
(: 2024-11-05:  the type is remote for texts not annotated locally :)
, $type := $a/ancestor::tei:TEI/@type
, $tr := $a/tls:text/tls:line
, $target := substring(data($a/tls:text/tls:srcline/@target), 2)
(: TODO find a better way, get juan for CBETA texts :)
, $loc := try {xs:int((tokenize($target, "_")[3] => tokenize("-"))[1])} catch * {0}
, $exemplum := if ($a/tls:metadata/@rating) then xs:int($a/tls:metadata/@rating) else 0
, $bg := if ($exemplum > 0) then "protypical-"||$exemplum else "bg-light"
, $creator-id := substring($a/tls:metadata/@resp, 2)
(:, $resp := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$creator-id]//tei:persName/text():)
, $resp := tu:get-member-initials($creator-id)
return
<div class="row {$bg} table-striped">
<div class="col-sm-2"><a href="textview.html?location={$target}{if ($type='remote')then '&amp;mode=remote'else()}" class="font-weight-bold">{$src, $loc}</a></div>
<div class="col-sm-3"><span data-target="{$target}" data-toggle="popover">{$line}</span></div>
<div class="col-sm-7"><span>{$tr/text()}</span>
{if ((sm:has-access(document-uri(fn:root($a)), "w") and $a/@xml:id) and not(contains(sm:id()//sm:group, 'tls-test'))) then 
(
 if ($resp[1]) then 
   lrh:format-button("null()", "Resp: " || $resp[1] , $resp[2], "small", "close", "tls-user") else (),

(:lrh:format-button("review_swl_dialog('" || data($a/@xml:id) || "')", "Review this attribution", "octicons/svg/unverified.svg", "small", "close", "tls-editor"),:)
lrh:format-button("incr_rating('swl', '" || data($a/@xml:id) || "')", "Mark this attribution as prototypical", "open-iconic-master/svg/star.svg", "small", "close", "tls-editor"),
lrh:format-button("delete_swl('swl', '" || data($a/@xml:id) || "')", "Delete this attribution", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor"),
 if (not ($user = substring($a/tls:metadata/@resp, 2))) then
    lrh:format-button("save_swl_review('" || data($a/@xml:id) || "')", "Approve the SWL", "octicons/svg/thumbsup.svg", "small", "close", "tls-editor") else ()
)
else ()}
</div>
</div>
};


(: some interface elements for general use :)



declare function lrh:card-collapsable($map as map(*)){
    <div class="card">
    <div class="card-header" id="{$map?type}-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#{$map?type}-body" >
         {$map?header}
        </button>
      </h5>
      </div>
     <div id="{$map?type}-body" class="collapse">
     <div class="card card-body">
     {$map?body}
     </div>
     </div>
    </div>
};

declare function lrh:form-input-row($name, $map){
            <div class="form-row">
              {if ($map?required = true()) then
              
                <div id="{$map?input-id}-group" class="{if (string-length($map?col-size)>0) then $map?col-size else "col-md-12"} ">
                    <label for="{$map?input-id}"><strong>{$map?hint}</strong> </label>
                    <input id="{$map?input-id}" type="{$map?type}" required="required"  name="{if (string-length($map?input-name)>0) then $map?input-name else $map?input-id}" class="form-control" value="{$map?input-value}"/>
                </div>
               else
                <div id="{$map?input-id}-group" class="{if (string-length($map?col-size)>0) then $map?col-size else "col-md-12"} ">
                    <label for="{$map?input-id}"><strong>{$map?hint}</strong> </label>
                    <input id="{$map?input-id}" type="{$map?type}" name="{if (string-length($map?input-name)>0) then $map?input-name else $map?input-id}" class="form-control" value="{$map?input-value}"/>
                </div>    
              }  
            </div>
};

declare function lrh:form-control-input($map){
 <div class="{$map?col} form-group ui-widget" id="{$map?id}-group" >
 <b>{$map?label}</b>
 <input id="{$map?id}" class="form-control" value="{$map?value}"/>
 {$map?extra-elements}
 </div>
};

declare function lrh:form-control-select($map){
 <div class="{$map?col} form-group ui-widget" id="{$map?id}-group" >
 <b>{$map?label}</b>
 {element select {
 attribute class {"form-control"}
 , attribute id {$map?id}
 , if ($map?attributes instance of map()) then 
   for $a in map:keys($map?attributes)
    return
    attribute {$a} {$map?attributes?($a)} else () 
,  for $o in map:keys($map?option-map)
(:    order by $map?option-map?($o):)
    return 
    if ($o = $map?selected) then
    <option value="{$o}" selected='selected'>{$map?option-map?($o)}</option>
     else
    <option value="{$o}">{$map?option-map?($o)}</option> 
  }}
 </div>
};

declare function lrh:settings-display($node as node()*, $model as map(*)){
<div>
<p>Here are settings to the place, type and number of items to display:</p>
<ul>
{for $i in doc($config:tls-app-interface||"/settings.xml")//tls:section[@type='display-options']/tls:item
  let $id := 'select-'||$i/@type
  , $currentvalue := lus:get-user-item($i/@type)
  , $displaycontext := if ($currentvalue = ('0', '1')) then () else $currentvalue
  return 
  <div class="row">{
 lrh:form-control-select(map{
    'id' : $id
    , 'col' : 'col-md-8'
    , 'attributes' : map{'onchange' :"us_save_setting('display-options','"||$id||"')"}
    , 'option-map' : $config:lus-values
    , 'selected' : $currentvalue
    , 'label' : ( $i/text() , <a class="ml-2" href="{$config:help-base-url}" title="Open documentation for this item" target="docs" role="button">?</a>)
 })}
 {lrh:form-control-input(
   map{
    'id' : 'input-'||$id
    , 'col' : 'col-md-2'
    , 'value' : $displaycontext
    , 'label' : 'Context:'
    })}
</div>
}
</ul>
</div>
};

(:~ render a help link for the context given as key
:)
declare function lrh:help-link($key as xs:string){
   let $link := $config:help-map?($key)
   return
  <a class="nav-link" href="{$config:help-base-url}{$link}"  target="docs" role="button">Help<img class="icon"  src="resources/icons/help.svg"/></a>
};

declare function lrh:settings-bookmarks($node as node()*, $model as map(*)){
<div>
<p>Currently defined bookmarks.  Click on the <img src="resources/icons/open-iconic-master/svg/x.svg"/> to delete a bookmark.</p>
<ul>
{for $b in doc($config:tls-user-root || $model?user || "/bookmarks.xml")//tei:item
  let $segid := $b/tei:ref/@target,
  $id := $b/@xml:id,
  $date := xs:dateTime($b/@modified)
  order by $date descending

return
<li id="{$id}">{lrh:format-button("delete_bm('"||$id||"')", "Delete this bookmark.", "open-iconic-master/svg/x.svg", "", "", "tls-user")}
<a href="textview.html?location={substring($segid, 2)}">{$b/tei:ref/tei:title/text()}: {$b/tei:seg}</a></li>
}
</ul>
</div>
};
