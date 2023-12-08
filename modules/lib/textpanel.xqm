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

import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace lv="http://hxwd.org/lib/vault" at "vault.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "../db-utility.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";
import module namespace lli="http://hxwd.org/lib/link-items" at "link-items.xqm";
import module namespace ltr="http://hxwd.org/lib/translation" at "translation.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";



declare function ltp:show-textpanel($seg as node(), $map as map(*)){

};

declare function ltp:display-seg($seg as node()*, $options as map(*) ) {
 let $user := sm:id()//sm:real/sm:username/text(),
 $usergroups := sm:get-user-groups($user),
 $show-transl := not(contains(sm:id()//sm:group/text(), "guest")),
 $testuser := contains(sm:id()//sm:group, ('tls-test', 'guest'))
 let $link := concat('#', $seg/@xml:id),
  (: we are displaying in a reduced context, only 2 rows  :)
  $ann := lower-case(map:get($options, "ann")),
  $loc := map:get($options, "loc"),
  $locked := $seg/@state = 'locked',
  $textid := string($seg/ancestor::tei:TEI/@xml:id),
  $mark := if (data($seg/@xml:id) = $loc) then "mark" else ()
  ,$lang := 'zho'
  ,$alpheios-class := if ($user = 'test2') then 'alpheios-enabled' else ''
  ,$markup-class := "tei-" || local-name($seg/parent::*)
  ,$slot1 := if ($show-transl) then 
     if (map:contains($options, "transl")) then $options?transl
     else map:get($options, $options?slot1)[1] else ()
  ,$slot2 := if ($show-transl and not($ann = 'false')) then map:get($options, $options?slot2)[1] else ()
  (: check if transl + comment are related, if yes than do not manipulate tab-index :)
  (: if tei:TEI, then we have a translation, otherwise a variant :)
  , $px1 := typeswitch ($slot1) case element(tei:TEI) return  replace(($slot1//tei:seg[@corresp="#"||$seg/@xml:id]/@resp)[1], '#', '') default return () 
  ,$resp1 := if ($px1) then "Resp: "||tu:get-member-name($px1) else ()
  , $px2 :=  typeswitch ($slot2) case element(tei:TEI) return replace(($slot2//tei:seg[@corresp="#"||$seg/@xml:id]/@resp)[1], '#', '') default return () 
  ,$resp2 :=  if ($px2) then "Resp: "||doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px2]//tei:persName/text() else () 
(: normalize-space(string-join($seg/text(),'')) :)
return
(
<div class="row {$mark}">
<div class="col .no-gutters">
{
if($locked and $textid and lpm:has-edit-permission($textid)) then 
  lrh:format-button("display_punc_dialog('" || data($seg/@xml:id) || "')", "Add punctuation to this text segment", "octicons/svg/lock.svg", "", "", ("tls-editor", "tls-punc")) 
else (), 
 if ($seg//tei:lb) then 
  let $node := ($seg//tei:lb)[1]
  , $n := if (contains($node/@n, "-")) then tokenize($node/@n, '-')[2] else $node/@n
  return
<span class="btn badge badge-light text-muted ed-{data($node/@ed)}">{data($n)}</span>
else
if ($seg//tei:pb or local-name(($seg/preceding-sibling::*)[last()]) = ('lb', 'pb')) then 
 let $node := ($seg//tei:pb | ($seg/preceding-sibling::tei:pb)[last()])[1]
 , $n := tokenize($node/@n, '-')[2]
 , $fpref :=  $config:ed-img-map?($node/@ed) 
 , $pg := substring-before(tokenize(data($node/@facs), '/')[last()], '.')
 return
 if ($pg) then
<span title="Click here to display a facsimile of this page &#10;{$config:wits?(data($node/@ed))}:{$pg}" onclick="get_facs_for_page('slot1', '{$fpref}{$node/@facs}', '{data($node/@ed)}', '{data($seg/@xml:id)}')" class="btn badge badge-light text-muted ed-{data($node/@ed)}">{$n}</span>
else "　" 
else "　"
(: either within or without the segment, for the moment place it within :)
(:, if ($seg/tei:c[@type='shifted']) then <span class="swxz">{data($seg/tei:c[@type='shifted']/@n)}</span> else ():)
}
</div>
<div class="{
if ($seg/@type='comm') then 'tls-comm ' else 
if($locked) then 'locked ' else () }{
if ($ann='false') then 'col-sm-4' else $options?zh-width} zh chn-font {$alpheios-class} {$markup-class}" lang="{$lang}" id="{$seg/@xml:id}" data-tei="{ util:node-id($seg) }">{
lrh:proc-seg($seg, map{"punc" : true(), "textid" : $textid})
}{(:if (exists($seg/tei:anchor/@xml:id)) then <span title="{normalize-space(string-join($seg/ancestor::tei:div//tei:note[tei:ptr/@target='#'||$seg/tei:anchor/@xml:id]/text()))}" >●</span> else ():) ()}</div>　
<div class="col-sm-4 tr" title="{$resp1}" lang="en-GB" tabindex="{$options('pos')+500}" id="{$seg/@xml:id}-tr" contenteditable="{if (not($testuser) and not($locked)) then 'true' else 'false'}">{typeswitch ($slot1) 
case element(tei:TEI) return  $slot1//tei:seg[@corresp="#"||$seg/@xml:id]//text()
default return (krx:get-varseg-ed($seg/@xml:id, substring-before($slot1, "::")))
}</div>
 {if ($ann = 'false') then () else 
 (: using en-GB for now, need to get that from translation in the future...  :)
  <div class="col-sm-4" title="{$resp2}" lang="en-GB" >
  {typeswitch ($slot2) 
case element(tei:TEI) return (if ($slot2/@type='notes') then lli:get-linked-items($user, $seg/@xml:id) else (),<div class="tr" tabindex="{$options('pos')+1000}" id="{$seg/@xml:id}-ex" contenteditable="{if (not($testuser) and not($locked)) then 'true' else 'false'}">{$slot2//tei:seg[@corresp="#"||$seg/@xml:id]//text()}</div>  )
default return

(krx:get-varseg-ed($seg/@xml:id, substring-before($slot2, "::")))

}
  </div>}
</div>,
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
</div>,
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

declare function ltp:chunkcol-left($dseg, $model, $tr, $slot1-id, $slot2-id, $loc, $cnt){
      for $d at $pos in $dseg 
      return ltp:display-seg($d, map:merge(($model, $tr, 
      map{'slot1': $slot1-id, 'slot2': $slot2-id, 
          'loc' : $loc, 
          'zh-width' : 'col-sm-3',
          'pos' : $pos + $cnt, "ann" : "xfalse.x"})))
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
(:$transl := collection("/db/apps/tls-data")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator']:)
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
