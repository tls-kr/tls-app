xquery version "3.1";

(:~
 : Library module for functionality of special interest to some users.
 :
 : @author Christian Wittern
 : @date 2024-11-05
 :)

module namespace lsi="http://hxwd.org/special-interest";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";

declare namespace os="http://a9.com/-/spec/opensearch/1.1/";

declare variable $lsi:resources := $config:tls-data-root||"/external/resources";
declare variable $lsi:internal := $config:tls-data-root||"/external";

declare variable $lsi:general := 
  map{"moedict" : ("MoeDict", "", "https://www.moedict.tw/#{searchTerms}"),
  "concise" : ("《國語辭典簡編本》", "", "https://dict.concised.moe.edu.tw/search.jsp?md=1&amp;word={searchTerms}&amp;size=-1"),
  "gouyu" : ("《重編國語辭典修訂本》", "", "https://dict.revised.moe.edu.tw/search.jsp?md=1&amp;word={searchTerms}&amp;&amp;size=1000&amp;sound=1")
  };
declare variable $lsi:buddhist := 
  map{
  "dbdextern" : ("Digital Dictionary of Buddhism", "Edited by Charles Muller", "http://www.buddhism-dict.net/cgi-bin/search-ddb4.pl?Terms={searchTerms}")
  , "cbc" : ("CBC Attributions", "The Chinese Buddhist Canonical Attributions project by Michael Radich and Jamie Norrish", "https://dazangthings.nz/cbc/text/?q={searchTerms}")
  , "translations" : ("Bibliography of Translations", "Marcus Bingenheimer", "https://mbingenheimer.net/tools/bibls/transbibl.html#{searchTerms}")
  };
  
(:
also add chise ids-find :: need to separate character only and word type SE.

"https://dict.concised.moe.edu.tw/search.jsp?md=1&amp;word=%E5%A4%A2&amp;size=-1"
:)
declare variable $lsi:label := map{
'buddhdic' : ('DDB', "word", "Digital Dictionary of Buddhism", "Edited by Charles Muller")
,'cjkvedic' : ('CJKV', "word", "CJKV Character Dictionary", "Edited by Charles Muller")
,'swjzdic' : ('SWJZ', "char", "說文解字", "TLS Version")
,'sbgydic' : ('GY', 'char', '校正宋本廣韻', "")
};



declare function lsi:ddb-lookup($word, $map){
for $w in collection($config:tls-data-root||"/external")//orth[. = $word]
let $link := $w/parent::entry/href/text()
, $def := $w/parent::entry/def/text()
, $r := substring-before(tokenize(base-uri($d), '/')[last()], '.xml')

return <li><span class="ml-2 badge">{$lsi:label($r)}</span><a target="docs" href="{$link}">{$word}</a>:<span class="ml-2">{$def}</span></li>
};

declare function lsi:parse-opensearch($nodes, $map){
for $node in $nodes
return
typeswitch($node)
case element(os:Url) return ()
case element(os:OpenSearchDescription) return
   for $n in $node/node()
   return lsi:parse-opensearch($n, $map)
default return ()

};


(: body for the dialog, rest is in dialogs :)
declare function lsi:resource-dialog-body($map as map(*)){
let $os := doc($config:tls-app-interface||"/opensearch.xml")/os:OpenSearchDescription
return
<div class="col">
{for $s in $os/os:*
let $n := local-name($s)
return 
  lrh:form-input-row($n, 
  map{"input-id" : 'input-'||$n
     , "input-value" : if ($n = 'Url') then data($s/@template) else $s/text()
     , "hint" : data($s/@hint)
     , "type" : "text"}) 
}
</div>
};

declare function lsi:save-resource($map as map(*)){
let $uuid := "uuid-" || util:uuid()
let $node := <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/" xml:id="{$uuid}">
{for $n in map:keys($map)
(: TODO need to order this properly, according to DTD :)
 return
 if (starts-with($n, 'input-')) then
   let $nname := substring-after($n, 'input-')
   return
   element {$nname} {
   if ($nname = 'Url') then (
     attribute type {'text/html'},
     attribute template {$map?($n)} ) else 
    $map?($n)  
   } else ()
}
</OpenSearchDescription>
return 
  (xmldb:store($lsi:resources, $uuid||".xml", $node), "OK")
};

declare function lsi:resource-list($type){
switch($type)
case "internal-resources" return
  for $d in collection($lsi:internal)//dict
  return substring-before(tokenize(base-uri($d), '/')[last()], '.xml')
case "external-resources" return
  for $r in collection($lsi:resources)//os:OpenSearchDescription
  return $r/@xml:id/string()
case "guguolin" return ()
default return ()
};



declare function lsi:list-resources-form($map as map(*)){
for $id in lsi:resource-list($map?type)
let $label := if($map?type = 'external-resources') then 
               let $r := collection($lsi:resources)//os:OpenSearchDescription[@xml:id = $id] 
               return $r/os:ShortName/text() || " (" || $r/os:Description/text() || ")" else
              $lsi:label?($id)[1] || " (" || $lsi:label?($id)[3] || ")" 
return
<div class="row">
{lrh:form-control-select(map{
    'id' : $id
    , 'col' : 'col-md-8'
    , 'attributes' : map{'onchange' :"us_save_setting('"||$map?type||"', '"||$id||"')"}
    , 'option-map' : $config:lus-values
    , 'selected' : ''
    , 'label' : ( $label  , <a class="ml-2" href="{$config:help-base-url}" title="Open documentation for this item" target="docs" role="button">?</a>)
 })}
 {lrh:form-control-input(
   map{
    'id' : 'input-'||$id
    , 'col' : 'col-md-2'
    , 'value' : ''
    , 'label' : 'Context:'
    })}
 
 </div>

};
