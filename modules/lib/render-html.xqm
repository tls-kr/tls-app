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

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function lrh:display-row($map as map(*)){
  <div class="row">
    <div class="col-sm-1">{$map?col1}</div>
    <div class="col-sm-4" title="{$map?col2-tit}"><span class="font-weight-bold float-right">{$map?col2}</span></div>
    <div class="col-sm-7" title="{$map?col3-tit}"><span class="sm">{$map?col3}</span></div>　
  </div>  
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
 let $lem :=  string-join($app/tei:lem//text(), ' ') || $lwit ||"；" 
 , $t := string-join(for $r in $app/tei:rdg
        let $wit := "【" || string-join(for $w in tokenize($r/@wit) return $app/ancestor::tei:TEI//tei:witness[@xml:id=substring($w, 2)]/text() , "，") ||  "】"
        return $r/text() || $wit, "；")
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
