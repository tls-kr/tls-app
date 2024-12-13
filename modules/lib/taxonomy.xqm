xquery version "3.1";

(:~
 : Library module for processing the taxonomy.
 :
 : @author Christian Wittern
 : @date 2024-11-14
 :)

module namespace ltx="http://hxwd.org/taxonomy";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";

import module namespace src="http://hxwd.org/search" at "../search.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls= "http://hxwd.org/ns/1.0";

(:~
get the clear text name description or definition of the category
@catid is the xml:id of the category to be retrieved
@taxid is the xml:id of the top-level category of the tree to be searched
@type : desc or def
:)
declare function ltx:get-catdesc($catid, $taxid, $type){
let $tax := collection($config:tls-data-root||"/core")//tei:category[@xml:id=$taxid]
, $cat := ($tax//tei:category[@xml:id=$catid])[1]
return
if ($type = 'desc') then
 string-join($cat/tei:catDesc/text())
else
 string-join($cat/tei:def/text())
};

declare function ltx:get-subtree($catid as xs:string, $taxid as xs:string, $count as xs:int){
let $tax := collection($config:tls-data-root||"/core")//tei:category[@xml:id=$taxid]
, $cat := $tax//tei:category[@xml:id=$catid]
, $n := $cat/ancestor::tei:category[position() <= $count]
, $r := reverse (for $id at $pos in $n/@xml:id return $id/string())
return $r
};

(: this will simply call the display as  :)
(:~ display taxonomy as a tree, for inspection and editing :)
declare function ltx:proc-taxonomy($node as node(), $type){
typeswitch($node)
case element(tei:category) return
  let $root := $node/ancestor::tei:taxonomy   (: $node/ancestor::tei:taxonomy :)
  , $cor := $root//tei:category[@corresp="#"||$node/@xml:id]
  , $label := (: if (string-length($node/tei:catDesc/text())=0) then :) $node/tei:catDesc/text() 
(:  else "<no label>":)
  return
  if (starts-with($node/@xml:id, 'new')) then 
   <li>
   <a id="{$node/@xml:id}" href="{$node/@corresp}">{$label}</a>
   {lrh:format-button("move_word('"|| $label || "', '"|| $node/@xml:id ||"', '1', '"||$type||"')", "Attach the concept "|| $label || " to another concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor")}
   {if ($cor) then 
    <ul>{for $l in $cor
      return <li>XR <a href="#{$l/@xml:id}">{$l/tei:catDesc}</a> {$l/tei:def}</li>
    }</ul> else () }
   <ul>{for $n in $node/node() return ltx:proc-taxonomy($n, $type)}</ul>
  </li> 
  else 
   <li>
   {if ($node/@corresp) then 
   <a href="{$node/@corresp}">->{$label}</a>
    else   
   <a id="{$node/@xml:id}" target="other" href="{$type}.html?uuid={$node/@xml:id}">{$label}</a>
   }
   {lrh:format-button("delete_word_from_concept('"|| $node/@xml:id || "', '"||$type||"')", "Delete the concept '"|| $label || "' from the tree, including all attached concepts.", "open-iconic-master/svg/x.svg", "", "", "tls-editor")}   
   {lrh:format-button("move_word('"|| $label || "', '"|| $node/@xml:id ||"', '1', '"||$type||"')", "Attach the concept "|| $label || " to another concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor")}
   {if ($cor) then 
    <ul>{for $l in $cor
      return <li>XR <a href="#{$l/@xml:id}">{$l/tei:catDesc}</a> {$l/tei:def}</li>
    }</ul> else () }
   <ul>{for $n in $node/node() return ltx:proc-taxonomy($n, $type)}</ul>
  </li> 
case element(tei:catDesc) return ()
case element(tei:def) return 
  let $edit := if (lpm:can-edit-concept()) then 'true' else 'false'
  return
   <span id="{$node/parent::tei:category/@xml:id}-tx" class="sf" contenteditable="{$edit}">{$node/text()}</span>
case element(*) return 
 for $n in $node/node() 
 return ltx:proc-taxonomy($n, $type)
case text() return $node
default return $node
};

(:~ 
$map?trg-concept : uuid of the concept we attach to
$map?wid : uuid of the concept being moved. 
:)
declare function ltx:move-category($map as map(*)){
let $src :=  (collection($config:tls-data-root||"/core")//tei:category[@xml:id=$map?wid])[1]
let $trg :=  collection($config:tls-data-root||"/core")//tei:category[@xml:id=$map?trg-concept]
return
if ($src and $trg) then 
  let $copy := ltx:copy-of($src)
  return
  ( update delete $src ,
   update insert $copy into $trg)
else () 
};

declare function ltx:delete-category($id){
let $src :=  (collection($config:tls-data-root||"/core")//tei:category[@xml:id=$id])[1]
return
if ($src) then
 update delete $src
else
 "Category not found."
};

declare function ltx:copy-of($nodes){
for $node in $nodes
return
typeswitch($node)
case element(*) return
  element {QName(namespace-uri($node), local-name($node))} {
  $node/@*
  , ltx:copy-of($node/node())
  }
(: it seems I have to explicitly touch this node, otherwise it will be ignored. :)  
case text() return normalize-space(string-join($node))
default return $node  
};

(:~ from any category element, we look for the top of the tree :)
declare function ltx:get-taxonomy($id as xs:string){
    let $cat := collection($config:tls-data-root||"/core")//tei:category[@xml:id=$id]
    return $cat/ancestor::tei:category[@rend='top']
};


(:~ turns a flat list to a map 
the callback function needs to be able to extract the grouping key from the provided node  
:) 

declare function ltx:hits-to-map($hits as item()*, $genre as xs:string, $get-grouping-key as function(*)){
    map:merge(
    for $h in $hits
    let $md := $get-grouping-key($h, $genre)
     for $m in $md
     let $grp := $m
    group by $grp
    where string-length($grp) > 0
    return
    map:entry($grp, $h)
    )
};

declare function local:format-tax-map($m){
    <div xmlns="http://www.tei-c.org/ns/1.0">{
    for $k in map:keys($m)
    return
        <div>
        <span type="group">{$k}</span>
        {map:get($m, $k)[2]}
        </div>
    }</div>    
};


declare function local:facets-add-n($map as map(*), $n, $options as map(*)){
  typeswitch ($n)
  case element(tei:category) return
   let $id := data($n/@xml:id)
   , $l := count($map?($id))
   , $m := $map?($id)[2]
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@n,
    if ($l > 0) then (attribute n {$l} ,
        for $i at $pos in $map?($id)
        return
        typeswitch($i)
            case map() return local:format-tax-map ($i)
            case element(*) return $i
            case xs:integer return ()
            case node()+ return ('seq', $pos, $i)
            default return <debug>other</debug>
         ) else () ,
    for $nn in $n/node() return local:facets-add-n($map, $nn, $options)}
  case element(*)
   return $n
  default return $n
};


(: pass in the taxonomy, starting with the top tei:category :)
declare function ltx:tax-add-n($map as map(*), $tax as node(), $options as map(*)){
  typeswitch ($tax)
  case element(tei:category) return
   let $id := $tax/@xml:id
   , $l := count($map?($id))
   , $m := for $t in $map?($id) return $t
   return
    element {QName(namespace-uri($tax),local-name($tax))} {
    $tax/@* except $tax/@n,
    if ($l > 0) then (attribute n {$l} ,
(:     if (string-length($options?grouping)>0) then 
     (ltx:hits-to-map($m, $options?genre, $options?ggk) ) else:)
      <res>{$map?($id)}</res> 
    )else (),
    for $nn in $tax/node() return ltx:tax-add-n($map, $nn, $options)}
  case element(*)
   return $tax
  default return $tax
};

declare function ltx:tax-sum-n($n){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   , $nv := if ($n/@n) then xs:int($n/@n) else 0
   , $sum := sum(($nv, for $s in $n//tei:category/@n return xs:int($s)))
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@sum,
    if ($n/tei:category) then if ($sum > $nv) then attribute sum {$sum} else () else (),
    for $nn in $n/node() return ltx:tax-sum-n($nn)}
  case element(*)
   return $n
  default return $n
};

(: remove unused categories :)
declare function ltx:tax-prune($n){
  typeswitch ($n)
  case element(category) return <bla>XX</bla>
  case element(tei:category) return
   if (xs:int($n/@n) > 0 or xs:int($n/@sum) > 0 ) then 
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* ,
    for $nn in $n/node() return ltx:tax-prune($nn)}
    else 
    ()
  case element(*)
   return $n
  default return $n
};

(:~ 
Save an update to the tei:def element.   This is called from save_sf_def on leaving the contenteditable element, and routed here from tlsapi:save-sf-def when $map?type is '-tx'

:)
declare function ltx:save-def($map){
let $cat := collection($config:tls-data-root||"/core")//tei:category[@xml:id=$map?id]
, $def := $cat/tei:def
, $newdef := <def xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($map?def)}</def>
return
if ($def) then 
 update replace $def with $newdef
else if ($cat) then
 update insert $newdef into $cat
else () 
};

(: add the hits to the taxonomy 

dont need this anymore...
:)
declare function ltx:tax-add-hits($n, $set){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@*
    (: at this point, I can further process the reduced set :)
    , <res>{$set[@concept-id=$id]}</res>
    ,for $nn in $n/node() return ltx:tax-add-hits($nn, $set)}
  case element(*)
   return $n
  default return $n
};

