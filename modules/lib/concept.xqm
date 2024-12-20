xquery version "3.1";

(:~
 : Display the concept.
 :
 : @author Christian Wittern
 : @date 2024-11-05
 :)

module namespace lc="http://hxwd.org/concept";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace ltx="http://hxwd.org/taxonomy" at "taxonomy.xqm";
import module namespace lw="http://hxwd.org/word" at "word.xqm";
import module namespace bib="http://hxwd.org/biblio" at "../biblio.xql";

import module namespace templates="http://exist-db.org/xquery/templates" ;


import module namespace src="http://hxwd.org/search" at "../search.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function lc:concept-top($node as node()*, $model as map(*), $concept as xs:string?, $uuid as xs:string?, $ontshow as xs:string?, $bychar as xs:boolean?)
{
let $user := sm:id()//sm:real/sm:username/text()
, $key := replace($uuid, '^#', '')
, $c :=  if (string-length($key) > 0) then
       (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[ends-with(@xml:id,$key)]    
     else
       (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[tei:head[. = $concept]]
, $show := if (string-length($ontshow) > 0) then " show" else ""
, $tr := $c//tei:list[@type="translations"]//tei:item
, $update := if ($c//tei:entry/@n) then () else for $e in $c//tei:entry return lw:update-word-ann-count($e)   

return
map{'user' : $user
   ,'key': $c/@xml:id
   ,'concept' : $c
   ,'name': $c/tei:head/text()
   ,'edit': lpm:can-edit-concept()
   ,'trs' :  $c//tei:list[@type="translations"]//tei:item
   ,'def' :  lc:display-defintion($c/@xml:id)
   ,'divs' : $c//tei:div
   ,'alt' : $c//tei:list[@type="altnames"]/tei:item
   ,'ann' : sum(for $e in $c//tei:entry return $e/@n)
   }
};


declare %templates:wrap %templates:default("bychar", 0)  function lc:concept($node as node()*, $model as map(*), $concept as xs:string?, $uuid as xs:string?, $ontshow as xs:string?, $bychar as xs:boolean) {
    let $key := replace($uuid, '^#', '')
    let $c :=  if (string-length($key) > 0) then
       (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[ends-with(@xml:id,$key)]    
     else
       (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[tei:head[. = $concept]]
    ,$show := if (string-length($ontshow) > 0) then " show" else ""   

return
( session:create()
, lc:display($c, map{'show' : $show, 'bychar': $bychar})
)
};

declare function lc:name($node as node()*, $model as map(*)){ 
<span id="{$model?key}-la" class="sf" contenteditable="{$model?edit}" >{$model?name}</span>
};

declare %templates:wrap function lc:tr-names($node as node()*, $model as map(*)){
for $t in $model?trs return
<span class="badge badge-light" title="{map:get($config:lmap, $t/@xml:lang)}">{$t/text()}</span> 
};

declare function lc:edit-link($node as node()*, $model as map(*)){
<a target="_blank" class="float-right badge badge-pill badge-light" href="{$config:exide-url || "?open=" || document-uri(root($model?concept))}">Edit concept</a>
};
declare function lc:label-count($node as node()*, $model as map(*)){count($model?alt)};

declare %templates:wrap function lc:definition($node as node()*, $model as map(*)){ $model?def };

declare %templates:wrap function lc:divs($node as node()*, $model as map(*), $type as xs:string?){  

};

declare %templates:wrap function lc:div-heads($node as node()*, $model as map(*), $type as xs:string?){  
switch($type)
 case 'pointers' return <span>{$config:lmap?($type)} of {$model?name}</span>
 default return () 
};


declare %templates:wrap function lc:labels($node as node()*, $model as map(*)){
for $i in $model?alt return
 <span class="badge badge-pill badge-light">{$i}</span>
};


declare function lc:display($nodes as node()*, $map as map(*)){
for $node in $nodes
return
typeswitch($node) 
case element(tei:div) return 
      let $type := $node/@type/string()
      return
       switch($type)
       case "concept" return 
         let $key := $node/@xml:id
         ,$edit := if (lpm:can-edit-concept()) then 'false' else 'false'
         return
         <div class="row" id="concept-id" data-id="{$key}">
         {lc:display-card-body($node, map:merge(
          ($map, 
          map{'key': $key 
          ,'edit': $edit
          })))}
         </div>
       case "definition" return ()
       case "source-references" return lc:display-card(
         map{'type': $type
         ,'size' : " (" || count ($node//tei:bibl) || " items)"
         ,'list' : $node//tei:bibl
         })
       case "notes" return lc:display-card(
         map{'type': $type
         ,'size' : " (" || string-length(string-join($node//text())) || " characters)"
         ,'node' : $node
         })
       case "old-chinese-criteria"  
       case "huang-jingui"
       case "modern-chinese-criteria" return
         (<h5 class="ml-2 mt-2">{map:get($config:lmap, $type)}</h5>
         ,<div lang="en-GB" contenteditable="{$map?edit}" style="white-space: pre-wrap;" class="nedit" id="{$type}_{$map?key}-nt">
         {lc:display($node/node(), $map)}
         </div>)
       case "pointers" return
        (lc:display-card(
         map{'type': $type
         ,'node' : $node
         ,'list' : $node//tei:list
         ,'show' : $map?show
         }) )
       case "words" return 
(:       let $ws := $node//tei:entry:)
       let $ws := lw:get-words-by-concept-id($node/ancestor::tei:div[@type='concept']/@xml:id)
       return
      <div id="word-content" class="card">
       <div class="card-body">
         <h4 class="card-title">Words ({count($ws)} items)</h4>
       <div class="card-text">  
       {for $e in $ws
         let $wc := xs:int($e/@n)
         order by $wc descending  
        return
        lw:display-word($e, map:merge(($map, 
        map{
         'concept' : $e/@tls:concept/string()
         ,'ann' : $wc
        }))) }
       </div></div></div>
       default return ()
case element(tei:head) return () 
case element(tei:list) return 
      let $type := $node/@type/string()
      return
       switch($type)
       case "altnames" return ()
       case "translations" return ()
       default return ()
case element(tei:p) return (lc:display($node/node(), $map))
case element(tei:divx) return ()
case text() return $node
default return $node
};

declare function lc:display-card-body($node, $map){
    <div class="card col-sm-12" style="max-width: 1000px;">
    <div class="card-body">
    <h4 class="card-title">
     <span id="{$map?key}-la" class="sf" contenteditable="{$map?edit}">{$node/tei:head/text()}</span>
      &#160;&#160;
      {lc:display-translations($node)} 
      {if  (lpm:can-edit-concept()) then 
      <a target="_blank" class="float-right badge badge-pill badge-light" href="{
      concat($config:exide-url, "?open=", document-uri(root($node)))}">Edit concept</a>
      else ()}
      </h4>
      <h5 class="card-subtitle" id="concept-def">{lc:display-defintion($map?key)}</h5>
      <div id="concept-content" class="accordion">
       {lc:display-card(
         map{'type': 'altnames',
         'list' : $node//tei:list[@type="altnames"]/tei:item/text(),
         'size' : " (" || count($node//tei:list[@type="altnames"]/tei:item/text()) || ")"
         })}
       {lc:display-card(
       map{'type' : 'citation'
       ,'concept' : $node/tei:head/text()
       ,'size' : " (" || sum( for $e in lw:get-words($node) return $e/@n ) || ")"
       })}
       {lc:display($node/node(), $map)}
      </div>
     </div>
    </div>
};

declare function lc:display-translations($node){
let  $tr := $node//tei:list[@type="translations"]//tei:item
return
for $t in $tr return 
<span class="badge badge-light" title="{map:get($config:lmap, $t/@xml:lang)}">{$t/text()}</span>
};

declare function lc:display-defintion($key){
ltx:get-catdesc($key, 'tls-concepts-top', 'def')
};

declare function lc:display-citation($node, $map){
};

declare function lc:display-card($map){
    <div class="card">
    <div class="card-header" id="{$map?type}-head">
      <h5 class="mb-0">
        {if ($map?type='citation') then 
        <button class="btn" data-toggle="collapse" data-target="#look" >
          <a href="citations.html?perspective=concept&amp;item={$map?concept}" title="This moves to a separate page">Citations</a> <span class="btn badge badge-light">{$map?size}</span>
        </button>
        else
        <button class="btn" data-toggle="collapse" data-target="#{$map?type}" >
          {$config:lmap?($map?type)}  {$map?size}
        </button>}
      </h5>
      </div>
      {if ($map?type='citation') then () else
      <div id="{$map?type}" class="collapse{$map?show}" data-parent="#concept-content">
      {if ($map?type='notes') then lc:display($map?node/node(), map{}) 
      else
      for $i in $map?list
      return
      typeswitch($i)
      case element(tei:bibl) return bib:display-bibl($i)
      case element(tei:list) return lc:display-pointer-list($i)
      default return
      <span class="badge badge-pill badge-light">{$i}</span>
      }</div>
      }
    </div>
};

declare function lc:display-pointer-list($l){
let $tax-type := 'tls-concepts-top'
return
for $p in $l
     (:order by $p/@type:)
     return
     (<h5 class="ml-2">
     {map:get($config:lmap, data($p/@type))}
     </h5>
     (: we assume that clicking here implies an interest in the ontology, so we load in open state:)
     ,<ul>{
     for $r in $p//tei:ref 
     let $lk := replace($r/@target, "#", "")
     , $def := ltx:get-catdesc($lk, $tax-type, 'def')
     return
     (<li>
     <a class="badge badge-light" href="concept.html?uuid={$lk}&amp;ontshow=true">{$r/text()}</a>
     <small class="ml-2" style="display:inline;">{$def}</small> </li>
     ,
     if ($p[@type = "hypernymy"]) then
      <ul>{
      for $x at $pos in ltx:get-subtree($lk, $tax-type, 3)
      let $desc := ltx:get-catdesc($x, $tax-type, 'desc')
      let $dex := ltx:get-catdesc($x, $tax-type, 'def')
      return
       <li class="ml-{$pos + 1}"><span><a  class="badge badge-light" href="concept.html?uuid={$x}&amp;ontshow=true">{$desc}</a>
     <small style="display:inline;">　{$dex}</small></span></li>
     }</ul>
     else if ($p[@type = "taxonymy"]) then
      <ul>{
      for $x in ltx:get-children($lk, $tax-type)
      let $desc := ltx:get-catdesc($x, $tax-type, 'desc')
      let $dex := ltx:get-catdesc($x, $tax-type, 'def')
      return
       <li class="ml-2"><span><a  class="badge badge-light" href="concept.html?uuid={$x}&amp;ontshow=true">{$desc}</a>
     <small style="display:inline;">　{$dex}</small></span></li>
     }</ul>
     else ()
     )
     }</ul>
     )
};

(: also in bib, where it belongs :)
declare function lc:display-bibl($bibl as node()){
<li><span class="font-weight-bold">{$bibl/tei:title/text()}</span>
(<span><a class="badge" href="bibliography.html?uuid={replace($bibl/tei:ref/@target, '#', '')}">{$bibl/tei:ref}</a></span>)
<span>p. {$bibl/tei:biblScope}</span>
{for $p in $bibl/tei:note/tei:p return
<p>{$p/text()}</p>}
</li>
};


declare function lc:alt-stub($node as node()*, $model as map(*)){};
