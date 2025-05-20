xquery version "3.1";

(:~
 : Library module for display of text panel
 :
 : @author Christian Wittern
 : @date 2023-11-30
 :)

module namespace ltp="http://hxwd.org/lib/textpanel";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";

import module namespace krx="http://hxwd.org/krx-utils" at "../krx-utils.xql";
import module namespace wd="http://hxwd.org/wikidata" at "../wikidata.xql"; 

import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace lv="http://hxwd.org/lib/vault" at "vault.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "../db-utility.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";
import module namespace lli="http://hxwd.org/lib/link-items" at "link-items.xqm";
import module namespace ltr="http://hxwd.org/lib/translation" at "translation.xqm";
import module namespace log="http://hxwd.org/log" at "../log.xql";
import module namespace lsd="http://hxwd.org/lib/swl-dialog" at "swl-dialog.xqm";
import module namespace lvs="http://hxwd.org/lib/visits" at "visits.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare variable $ltp:log := $config:tls-log-collection || "/tlslib";
(: for debugging, leave this here ftm  :)
declare variable $ltp:panel-matrix-orig := map{
                 0: ("col-sm-11"),
                 1: ("col-sm-5", "col-sm-6"),
                 2: ("col-sm-3", "col-sm-4", "col-sm-4"),
                 3: ("col-sm-3", "col-sm-3", "col-sm-3", "col-sm-2"),
                 4: ("col-sm-2", "col-sm-3", "col-sm-2", "col-sm-2", "col-sm-2")
};

declare variable $ltp:panel-matrix := map{
                 0: ("col-sm-11"),
                 1: ("col-sm-5", "col-sm-6"),
                 2: ("col-sm-3", "col-sm-4", "col-sm-4"),
                 3: ("col-sm-3", "col-sm-3", "col-sm-3", "col-sm-2"),
                 4: ("col-sm-2", "col-sm-3", "col-sm-2", "col-sm-2", "col-sm-2")
};

declare function ltp:get-text-preview($loc as xs:string, $options as map(*)){

let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id = $loc],
$context := if($options?context) then $options?context else 5,
$format := if($options?format) then $options?format else 'tooltip',
$title := $seg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
$pseg := $seg/preceding::tei:seg[fn:position() < $context],
$fseg := $seg/following::tei:seg[fn:position() < $context],
$dseg := ($pseg, $seg, $fseg),
$textid := tokenize($loc, "_")[1],
$tr := ltr:get-translations($textid),
$slot1 := if ($options?transl-id) then $options?transl-id else lus:get-settings()//tls:section[@type='slot-config']/tls:item[@textid=$textid and @slot='slot1']/@content,
$transl := if ($slot1) then $tr($slot1) else ()
return
if ($format = 'tooltip') then
<div class="popover" role="tooltip">
<div class="arrow"></div>
<h3 class="popover-header">
<a href="textview.html?location={$loc}">{$title}</a></h3>
<div class="popover-body">
    {
for $d in $dseg 
return 
    (: we hardcode the translation slot to 1; need to make sure that 1 always has the one we want :)
    ltp:display-seg($d, map{"transl" : $transl[1], "ann": "false", "loc": $loc})
    }
</div>
</div>
else 
<div class="col">
    {
for $d in $dseg 
return 
    (: we hardcode the translation slot to 1; need to make sure that 1 always has the one we want :)
    ltp:display-seg($d, map{"transl" : $transl[1], "ann": "false", "loc": $loc})
    }
</div>
};


declare function ltp:show-textpanel($seg as node(), $map as map(*)){

};

(: ugly quick fix, copied over from tlslib
TODO : handle properly! :)
declare function ltp:annotation-types($type as xs:string){
  let $map := 
 map{'nswl' : ('Grammar', 'Syntactic Word Location'), 
     'rdl' : ('Rhetoric', 'Rhetoric Device Location'),
     'drug' : ('本草', 'Drug Location')}
 return
 if (count($map($type))> 0) then $map($type) else ( collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@xml:id=$type]/tei:head/text(), '')
};


(:
TODO: move this
      $visit := lvs:record-visit($targetseg),
      {tlslib:textinfo($model?textid)}
:)

declare function ltp:prepare-chunk($chunk as node()*, $map as map(*)){
      let $zh-width := 'col-sm-3'
      , $colums := if (string-length($map?columns)>0) then xs:int($map?columns) else 2 
      , $state := if ($chunk/div/info/@state) then $chunk/div/info/@state else "yellow" 
      , $xpos := data($chunk/div/stats/@xpos)
      , $percent := data($chunk/div/stats/@percent)
      , $pb := $chunk/div/pb 
      , $facs := data($pb/@facs)
      , $fpref :=  data($pb/@fpref)
      , $ed :=  data($pb/@ed)
      , $n := data($pb/@n)
      , $head := $chunk/div/head
      , $dseg := $chunk/div/segments/div
      , $tseg := $dseg[@data-mark]
      , $show-transl := lpm:should-show-translation()
      , $show-variants := xs:boolean(1)
      , $textid := data($chunk/div/info/@textid)
      , $visit := lvs:record-visit-remote(data($tseg/@xml:id), string-join($tseg/text(), ''))
      , $tr := if (lpm:should-show-translation()) then 
         if (string-length($facs) > 0) then map:merge((ltr:get-translations($textid), 
            for $edx in tokenize($chunk/div/pb/@eds)
            return
            map:entry("facs_"||$edx, ("dummy", $edx, data($tseg/@xml:id)) ))) 

         else ltr:get-translations($textid)
         else map{},
      $slot1-id := lrh:get-content-id($textid, 'slot1', $tr),
      $slot2-id := lrh:get-content-id($textid, 'slot2', $tr),
      $atypes := distinct-values(for $s in $dseg/@xml:id
        let $link := "#" || $s
        return
        for $node in (collection($config:tls-data-root|| "/notes")//tls:ann[.//tls:srcline[@target=$link]] | collection($config:tls-data-root|| "/notes")//tls:span[.//tls:srcline[@target=$link]] ) return 
        (: need to special case the legacy type ann=swl :)
        if (local-name($node)='ann') then "nswl" else data($node/@type))
    return
      (
      <div id="chunkrow" class="row">
      <div id="srcref" class="col-sm-12 collapse" data-toggle="collapse">
      {(: textinfo goes here :) ()}
      </div>
      <!-- here is where we select what kind of annotation to display -->
      {if (count($atypes) > 1) then 
      <div id="swlrow" class="col-sm-12 swl collapse" data-toggle="collapse">
       <div class="row">
         <div class="col-sm-2" id="swlrow-1"><span class="font-weight-bold">Select type of annotation:</span></div>
         <div class="col-sm-5" id="swlrow-2">{for $a in $atypes return <button id="{$a}-select" onclick="showhide('{$a}')" title="{ltp:annotation-types($a)[2]}" class="btn btn-primary ml-2" type="button">{ltp:annotation-types($a)[1]}</button>}</div>
      </div>
      </div>
      else ()
      }
      <div id="toprow" class="col-sm-12">
      
      {(:  this is the same structure as the one display-seg will fill it 
      with selection for translation etc, we use this as a header line :)()}
       <div class="row">
        <div class="col .no-gutters"><img class="icon state-{$state}"  src="{$config:circle}"/></div>
        <div class="{$zh-width}" id="toprow-1"><span class="font-weight-bold">{$head}</span><span class="btn badge badge-light">line {$xpos} / {$percent}%</span> 
        {if (string-length($facs) > 0) then 
        let $pg := substring-before(tokenize($facs, '/')[last()], '.')
        return
          <span class="btn badge badge-light ed-{$ed}" title="Click here to display a facsimile of this page &#10; {$pg}" onclick="get_facs_for_page('slot1', '{$fpref}{$facs}', '{$ed}', '{data($tseg/@xml:id)}')" >{$config:wits?($ed)}:{$n}</span>
         else <span title="No facsimile available" class="btn badge badge-light">{$n}</span>
         }
        <!-- zh --></div>
        <!-- 2024-09-06 this is rubbish, this needs also to be moved to textpanel and not hardcode the width -->
        {for $i in (1 to $colums)
        return 
        <div class="col-sm-4" id="top-slot{$i}"><!-- tr -->
        {if ($show-transl) then ltr:render-translation-submenu($textid, "slot"||$i, lrh:get-content-id($textid, 'slot'||$i, $tr) , $tr) else ()}
        </div>
        }
        </div>
      </div>
      <div id="chunkcol-left" class="col-sm-12">
      {ltp:chunkcol-left($dseg, map:put($map, "zh-width", $zh-width), $tr, $slot1-id, $slot2-id, data($tseg/@xml:id), 0)}
      </div>
      <div id="chunkcol-right" class="col-sm-0">
      {lsd:swl-form-dialog('textview', $map)}
    </div>
    </div>,
      <div class="row">
      <div class="col-sm-2">
      {if ($dseg) then  
       <button type="button" class="btn" onclick="page_move('{$chunk/div/nav/@first}')" title="Go to the first page"><span style="color: blue">First</span></button>
       else ()}
       </div>
      <div class="col-sm-2">
      {if (1) then  
       <button type="button" class="btn" onclick="page_move('{$chunk/div/nav/@prev}')" title="Go to the previous page"><span style="color: blue">Previous</span></button>
       else ()}
       </div>
       <div class="col-sm-2">
       {
       if (1) then
       <button id="nextpagebutton" type="button" class="btn" onclick="page_move('{$chunk/div/nav/@next}')" title="Go to the next page"><span style="color: blue">Next</span></button>
       else ()}
       </div> 
       <div class="col-sm-2">
       {
       if (1) then
       <button type="button" class="btn" onclick="page_move('{$chunk/div/nav/@last}')" title="Go to the last page"><span style="color: blue">Last</span></button>
       else ()}
       </div> 
        {if (lpm:show-setting('wd', 'concept')) then wd:quick-search-form('title') else ()}
      </div>
)

};

(: 

      <div class="row">
      <div class="col-sm-2">
      {if ($dseg) then  
       <button type="button" class="btn" onclick="page_move('{tokenize($dseg/@xml:id, "_")[1]}&amp;first=true')" title="Go to the first page"><span style="color: blue">First</span></button>
       else ()}
       </div>
      <div class="col-sm-2">
      {if ($dseg[1]/preceding::tei:seg[1]/@xml:id) then  
       <button type="button" class="btn" onclick="page_move('{$dseg[1]/preceding::tei:seg[1]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=2')" title="Go to the previous page"><span style="color: blue">Previous</span></button>
       else ()}
       </div>
       <div class="col-sm-2">
       {
       if ($dseg[last()]/following::tei:seg[1]/@xml:id) then
       <button id="nextpagebutton" type="button" class="btn" onclick="page_move('{$dseg[last()]/following::tei:seg[1]/@xml:id}&amp;prec=2&amp;foll={$foll+$prec -2}')" title="Go to the next page"><span style="color: blue">Next</span></button>
       else ()}
       </div> 
       <div class="col-sm-2">
       {
       if ($dseg/following::tei:seg[last()]/@xml:id) then
       <button type="button" class="btn" onclick="page_move('{$dseg/following::tei:seg[last()]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=0')" title="Go to the last page"><span style="color: blue">Last</span></button>
       else ()}
       </div> 
        {wd:quick-search-form('title')}
      </div>

:)


declare function ltp:display-seg($seg as node()*, $options as map(*) ) {
 let $log := log:info($ltp:log, "entering display-seg for " || $seg/@xml:id)
 let $user := sm:id()//sm:real/sm:username/text()
 ,$usergroups := sm:get-user-groups($user)
 ,$colums := if (string-length($options?columns)>0) then xs:int($options?columns) else 2 
 ,$segid := data($seg/@xml:id)
 ,$show-transl := not(contains(sm:id()//sm:group/text(), "guest"))
 ,$testuser := lpm:is-testuser() 
 ,$link := concat('#', $segid)
  (: we are displaying in a reduced context, only 2 rows  :)
 ,$ann := lower-case(map:get($options, "ann"))
 ,$loc := map:get($options, "loc")
 ,$locked := $seg/@state = 'locked'
 ,$textid := lmd:get-metadata($seg, "textid")
 ,$mark := if ($seg/@data-mark or $options?loc = $segid) then "mark" else ()
 ,$lang := 'zho'
 ,$alpheios-class := if ($user = 'test2') then 'alpheios-enabled' else ''
 ,$markup-class := "tei-" || local-name($seg/parent::*)
 ,$slot1 := if (lpm:should-show-translation()) then 
     if (map:contains($options, "transl")) then $options?transl
     else map:get($options, $options?slot1)[1] else ()
  ,$slot2 := if ($show-transl and not($ann = 'false')) then map:get($options, $options?slot2)[1] else ()
  (: check if transl + comment are related, if yes than do not manipulate tab-index :)
  (: if tei:TEI, then we have a translation, otherwise a variant :)
  ,$px1 := typeswitch ($slot1) case element(tei:TEI) return  replace(($slot1//tei:seg[@corresp="#"||$segid]/@resp)[1], '#', '') default return () 
  ,$resp1 := if ($px1) then "Resp: "||tu:get-member-name($px1) else ()
  ,$px2 :=  typeswitch ($slot2) case element(tei:TEI) return replace(($slot2//tei:seg[@corresp="#"||$segid]/@resp)[1], '#', '') default return () 
  ,$resp2 :=  if ($px2) then "Resp: "||doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px2]//tei:persName/text() else () 
  ,$editable := if (not($testuser) and not($locked) ) then 'true' else 'false'
  ,$zhclass := 
                $ltp:panel-matrix?($colums)[1] || " zh chn-font " || $alpheios-class || " " || $markup-class     
   let $log := log:info($ltp:log, "starting display-seg for " || $seg/@xml:id)

(:
, "tr" : if (lpm:has-edit-permission($textid)) then try {for $t in ltr:find-translators($textid) return $t/ancestor::tei:TEI } catch * {()} else ()

:)

return
(
<div class="row {$mark}">
{ltp:zero-panel-row(map{"locked" : $locked, "textid" : $textid, "seg" : $seg
}) }
{ if (local-name($seg) = 'div') then
  (: 2024-10-31: most code expects @xml:id, so we have both @id and @xml:id here, but filter out the unwanted latter.   :)
  element {local-name($seg)}
  {$seg/@* except $seg/@xml:id, 
   $seg/node()}
else
<div class="{$zhclass}{if ($seg/@type='comm') then ' tls-comm' else if($locked) then 'locked' else '' }" style="{if ($seg/@type='bcj') then 'color:red' else ()}" lang="{$lang}" id="{$segid}" >{
try {lrh:proc-seg($seg, map{"punc" : true(), "textid" : $textid}) } catch * {$seg/text()}
}
<!-- data-tei="{ util:node-id($seg) }" -->
</div>
}
{
for $i in (1 to $colums)
 let $slot := if (lpm:should-show-translation()) then 
     if (map:contains($options, "transl")) then $options?transl
     else map:get($options, map:get($options, 'slot'||$i))[1] else ()
 , $px := typeswitch ($slot) case element(tei:TEI) return  replace(($slot//tei:seg[@corresp="#"||$segid]/@resp)[1], '#', '') default return "chris"  
 , $resp := if ($px) then "Resp: "||doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px]//tei:persName/text() else $px
  let $log := log:info($ltp:log, "entering left-panel-row for " || $seg/@xml:id)

 return

ltp:right-panel-row($slot, map{"seg" : $seg, "col-class" : $ltp:panel-matrix?($colums)[$i + 1],  "ann" : $ann, "resp": $px||$resp, "ex": "slot"||$i, "tabindex" : $options('pos')+ (500*$i), "editable" : $editable, "user" : $user, "trans-lang" : "en-GB" })

}
</div>,
ltp:swl-rows($seg)
,
if (local-name(($seg/following::tei:*)[1]) = 'figure') then
 let $img := ($seg/following::tei:*)[1]
 let $fig:= "../tls-texts/img/" || $img/tei:graphic/@facs
 , $tit := $img/tei:graphic/@n
 return
<div class="row">
<span title="{$tit}"><img src="{$fig}"/></span>
</div>
else ()
)
};

declare function ltp:swl-rows($seg){
<div class="row swl collapse" data-toggle="collapse">
<div class="col-sm-3">　</div>
<div class="col-sm-7 swlid" id="{$seg/@xml:id}-swl"></div>
<div class="col-sm-2">　</div>
</div>};

(: this code has been moved to XHR, calling api/show_swl_for_line.xql; kept here just in case... :)
declare function ltp:swl-rows-old-code($seg){
<div class="row swl collapse" data-toggle="collapse">
<div class="col-sm-10 swlid" id="{$seg/@xml:id}-swl">
{if (starts-with($ann, "false")) then () else 
for $swl in collection($config:tls-data-root|| "/notes")//tls:srcline[@target=$link]
let $pos := if (string-length($swl/@pos) > 0 and not($swl/@pos = 'undefined')) then xs:int(tokenize($swl/@pos)[1]) else 0
order by $pos
return
if ($swl/ancestor::tls:ann) then ()
(:tlslib:format-swl($swl/ancestor::tls:ann, map{'type' : 'row'}):)
else 
<div class="row bg-light ">
<div class="col-sm-1">Rhet:</div>
<div class="col-sm-4"><a href="rhet-dev.html?uuid={$swl/ancestor::tls:span/@rhet-dev-id}">{data($swl/ancestor::tls:span/@rhet-dev)}</a>
{
let $creator-id := substring($swl/ancestor::tls:span/@resp, 2)
return
   if (($user = $creator-id) or contains($usergroups, "tls-editor" )) then 
    lrh:format-button("delete_swl('rdl', '" || data($swl/ancestor::tls:span/@xml:id) || "')", "Immediately delete the attribution of rhetorical device "||data($swl/ancestor::tls:span/@rhet-dev), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()
}
</div>
</div>
}
</div>
<div class="col-sm-2"></div>
</div>
};
(: TODO: adopt for remote texts! the pb is now already in the html :)
declare function ltp:zero-panel-row($map){
<div class="col .no-gutters">
{ (
if (count($map?tr) > 0) then <span>{count($map?tr//tei:seg[@corresp = "#" || $map?seg/@xml:id])}</span> else (),

if($map?locked and $map?textid and lpm:has-edit-permission($map?textid)) then 
  lrh:format-button("display_punc_dialog('" || data($map?seg/@xml:id) || "')", "Add punctuation to this text segment", "octicons/svg/lock.svg", "", "", ("tls-editor", "tls-punc")) 
else (), 
 if ($map?seg//tei:lb) then 
  let $node := ($map?seg//tei:lb)[1]
  , $n := if (contains($node/@n, "-")) then tokenize($node/@n, '-')[2] else $node/@n
  return
  <span class="badge badge-light text-muted ed-{data($node/@ed)}">{data($n)}</span>
else
if ($map?seg//span[contains(@class, "lb")]) then
  let $n := tokenize($map?seg//span/@title, ':')
  return
  <span class="badge badge-light text-muted ed-{$n[1]}">{$n[2]}</span>
else
if ($map?seg//tei:pb or local-name(($map?seg/preceding-sibling::*)[last()]) = ('lb', 'pb')) then 
 let $node := ($map?seg//tei:pb | ($map?seg/preceding-sibling::tei:pb)[last()])[1]
 , $n := tokenize($node/@n, '-')[2]
 , $fpref :=  $config:ed-img-map?($node/@ed) 
 , $pg := substring-before(tokenize(data($node/@facs), '/')[last()], '.')
 return
 if ($pg) then
<span title="Click here to display a facsimile of this page &#10;{$config:wits?(data($node/@ed))}:{$pg}" onclick="get_facs_for_page('slot1', '{$fpref}{$node/@facs}', '{data($node/@ed)}', '{data($map?seg/@xml:id)}')" class="btn badge badge-light text-muted ed-{data($node/@ed)}">{$n}</span>
else "　" 
else "　"
)
}
</div>
};

declare function ltp:right-panel-row($node, $map){
if ($map?ann = 'false') then () else 
 (: using en-GB for now, need to get that from translation in the future...  :)
<div class="{$map?col-class}" title="{$map?resp}" lang="{$map?trans-lang}" >
  {typeswitch ($node) 
case element(tei:TEI) return (if ($node/@type='notes') then 
      lli:get-linked-items($map?user, $map?seg/@xml:id) else (),
      <div class="tr" tabindex="{$map?tabindex}" id="{$map?seg/@xml:id}-{$map?ex}" contenteditable="{$map?editable}">{$node//tei:seg[@corresp="#"||$map?seg/@xml:id]//text()}</div>  )
default return ()

(:(krx:get-varseg-ed($map?seg/@xml:id, substring-before($node, "::"))):)

}
</div>
};


declare function ltp:chunkcol-left($dseg, $model, $tr, $slot1-id, $slot2-id, $loc, $cnt){
      for $d at $pos in $dseg 
(:      let $log := log:info($ltp:log, "chunkcol-left, $d " || $pos):)
      return ltp:display-seg($d, map:merge(($model, $tr, 
      map{'slot1': $slot1-id, 'slot2': $slot2-id, 
          'loc' : $loc, 
          'zh-width' : 'col-sm-3', 
          'pos' : $pos + $cnt, "ann" : "xfalse.x"})))
};


