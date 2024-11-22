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
    ,$show := if (string-length($ontshow) > 0) then " show" else "",
    $tr := $c//tei:list[@type="translations"]//tei:item
 

return
map{'user' : $user
   ,'key': $c/@xml:id
   ,'concept' : $c
   ,'name': $c/tei:head/text()
   ,'edit': lpm:can-edit-concept()
   ,'trs' :  $c//tei:list[@type="translations"]//tei:item
   ,'def' : ($c/tei:div[@type="definition"]//tei:p/text())[1]
   ,'divs' : $c//tei:div
   ,'alt' : $c//tei:list[@type="altnames"]/tei:item
   ,'ann' : for $a in collection($config:tls-data-root||"/notes")//tls:ann[@concept-id=$c/@xml:id] return $a
   }
};


declare
    %templates:wrap
function lc:settings($node as node()*, $model as map(*))
{
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


declare function lc:display($node as node(), $map as map(*)){
typeswitch($node) 
case element(tei:div) return ()
case text() return $node
default return $node
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
