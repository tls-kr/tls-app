xquery version "3.1";

(:~
 : Library module for analyzing citations.
 :
 : @author Christian Wittern
 : @date 2024-11-05
 :)

module namespace lct="http://hxwd.org/citations";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace ltx="http://hxwd.org/taxonomy" at "taxonomy.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";
import module namespace ltg="http://hxwd.org/tags" at "tags.xqm";

import module namespace src="http://hxwd.org/search" at "../search.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";


declare variable $lct:perspectives := map{
'chars' : 'Characters',
'concept' : 'Concepts',
'users' : 'Contributors'
,"syn-func": "Syntactical Functions"
,"texts": "Texts"
};

(:, 'date' : 'Creation date' :)


declare variable $lct:grouping := map{
"diachronic" : "Diachronic", 
"by-diachronic" : "Diachronic(tree)", 
"by-char" : "By character", 
"concept" : "By Concept",
"by-concept" : "By Concept(tree)",
"by-text": "By text", 
"syn-func": "By Syntactic Function", 
"by-syn-func": "By Syntactic Function(tree)", 
"by-sem-feat": "By Semantic Feature", 
"by-pos": "By Part Of Speech" 
};
declare variable $lct:use-tax := ("by-concept", "by-diachronic", "by-syn-func");
declare function lct:citations-form($node as node()*, $model as map(*), $item as xs:string?, $perspective as xs:string?){
let $n := if (string-length($model?n)>0) then $model?n else 20
return
(
<div class="row">
 <div class="col-md-1"></div>
 {lrh:form-control-input(
   map{
    'id' : 'input-target'
    , 'col' : 'col-md-2'
    , 'value' : $item
    , 'label' : 'Item:'
    , 'extra-elements' :  <span id="input-id-span" style="display:none;"></span>
    })}
 {lrh:form-control-select(map{
    'id' : 'select-perspective'
    , 'col' : 'col-md-3'
    , 'attributes' : map{'onchange' :'initialize_cit_autocomplete()'}
    , 'option-map' : $lct:perspectives
    , 'selected' : $perspective
    , 'label' : 'Perspectives:'
 })}
 <div class="col-md-3">
  <div class="row">
   <div class="col"><b>Grouping: Key 1</b> </div>
   <div class="col"><b>Key 2</b> </div>
 </div>
 <div class="row">
  {lrh:form-control-select(map{
    'id' : 'select-grouping-1'
    , 'col' : 'col'
    , 'option-map' : $lct:grouping
  })}
  {lrh:form-control-select(map{
    'id' : 'select-grouping-2'
    , 'col' : 'col'
    , 'selected' : 'none'
    , 'option-map' : map:merge(($lct:grouping , map:entry('none', 'None')))
 })}
 </div>
 </div>
 <div class="col-md-2">
 <b>　　</b><br/>
 <button type="button" class="btn btn-primary" onclick="do_citation()">Show</button>
 </div>
</div>,
<hr/>,
if (1 = 1) then <div class="row" id="cit-results"/> else
<div class="row" id="cit-results">
 <div class="col-md-1">x</div>
 <div class="col-md-2"><b>Most frequent concepts</b>
{lct:citations(map{"parameters" : map{"perspective" : "concept", "count" : $n}})}
 </div>
 <div class="col-md-2"><b>Most frequent characters</b>
{lct:citations(map{"parameters" : map{"perspective" : "chars", "count" : $n}})}
 </div>
 {if (1 = 1) then () else 
 <div class="col-md-3"><b>Most prolific contributors</b>
{lct:citations(map{"parameters" : map{"perspective" : "users", "count" : $n}})}
 </div>
 }
 {if (1 = 2) then () else 
 <div class="col-md-2"><b>Most attributed texts</b>
{lct:citations(map{"parameters" : map{"perspective" : "texts", "count" : $n}})}
 </div>
 }
 {if (1 = 1) then () else 
 <div class="col-md-4"><b>Most recent citations</b>
{lct:recent(10)}
 </div>
 }
</div>,
<hr/>
)
};

(: this is called via API to actually execute the requested analysis :)
declare function lct:citations($map as map(*)){
let $perspective := $map?parameters?perspective
, $count := if (string-length($map?parameters?count) > 0) then xs:int($map?parameters?count) else 10 
, $item := $map?parameters?item
, $sort := if (string-length($map?parameters?sort)>0) then $map?parameters?sort else ""
return
if (string-length($item) > 0) then
   let $set :=
     switch ($perspective)
       case "chars" return $config:tls-ann[tei:form/tei:orth[. = $item]]
       case "concept" return $config:tls-ann[@concept = $item]
       case "syn-func" return $config:tls-ann[.//tls:syn-func[. = $item]]
       case "users" return $config:tls-ann[tls:metadata[@resp="#"||$item]]
       case "texts" return $config:tls-ann[.//tls:srcline/@title[. = $item]]
       default return ()
   return 
    let $res := lct:by-item($set, $map)
    let $k := map:keys($res)
    , $total := sum(for $l in $k return map:get($res, $l)[1])
   return 
   (<div class="col-md-1"><h3>Total: {$total}</h3></div>,
     <div class="col-md-10">
        {if ($map?parameters?grouping = $lct:use-tax) then
            <ul>{lct:add-n($res) => ltx:tax-sum-n() => ltx:tax-prune() => lct:format-result-tree()}</ul>
        else lct:format-result-map($res, 1)}
    </div>
    )
else
   lct:by-top($perspective, $count)
};

declare function lct:format-result-tree($node as node()) {
 typeswitch ($node)
 case element(tei:category) return 
   let $s := $node/@sum
   , $cnt := if ($s) then $s else $node/@n
   , $desc := $node/tei:catDesc/text()
   , $uid := util:uuid()
   return
   if ($s = $node/tei:category/@sum) then (<span title="{$desc}">({$desc})→</span>, for $nn in $node/node() return lct:format-result-tree($nn))
   else
    <li><span data-toggle="collapse" data-target="#res-map-{$uid}">{$desc} ({data($cnt)})</span>
    <ul id="res-map-{$uid}" class="collapse container">{for $nn in $node/node() return lct:format-result-tree($nn)}</ul>
    </li>
 case element(tls:ann) return lct:format-citation($node, map{})   
 case element(tei:span) return 
   let $t := $node/text() 
   return
   if ($t = 'none') then () else <span>{lct:format-key($t)}</span>
 case element(tei:debug) return ()
 case element(tei:catDesc) return ()
 case element(tei:div) return  for $nn in $node/node() return lct:format-result-tree($nn)
 case element(*) return local-name($node)
(: for $nn in $node/node() return lct:format-result-tree($nn):)
 default return ()
};

declare function lct:by-item($set, $map){
map:merge(
let $key1 := $map?parameters?grouping
, $key2 := if (string-length($map?parameters?group2) > 0) then $map?parameters?group2 else "none" 
, $sort := $map?parameters?sort
for $a in $set
 let $o := lct:get-grouping-key($a, $key1)
 group by $o
 let $s := lct:get-sort-key($a, $sort)
 order by $s descending
 return 
 map:entry($o, (count($a),
  map:merge(
   for $b in $a
    let $o2 := lct:get-grouping-key($b, $key2[1])
    group by $o2
    let $s2 := lct:get-sort-key($b, $sort[1])
    order by $s2
    return 
 map:entry($o2, (count($b), $b))))
 ))
};

declare function lct:format-result-map($map, $level){
let $k := map:keys($map)
, $total := sum(for $l in $k return map:get($map, $l)[1])
return
<div id="result-map-top-{$level}">
  
  {for $l at $pos in $k
  let $cnt := map:get($map, $l)[1]
  , $pc := format-number(($cnt div $total) * 100, "0.#") 
  , $cd := if ($cnt > 0) then "&#160;(" || $cnt || " / "||$pc||"%)" else "" 
  , $uid := util:uuid()
  , $class := if ($l = 'none') then () else "collapse container"
  , $cc := if (starts-with($l, 'dat')) then $l else $cnt
  order by $cc descending
  return
  <div id="res-map-{$level}-{$pos}">
  {if ($l = 'none') then () else (<h3 data-toggle="collapse" data-target="#res-map-{$uid}">{lct:format-key($l)} {$cd}</h3> )}
  <div id="res-map-{$uid}" class="{$class}">
{for $e at $epos in map:get($map, $l)
 return
  typeswitch($e[1])
   case xs:int return 
    (for $f in $e return lct:format-citation($f[2], map{}) )
   case element(tls:ann) return 
    (for $f in $e return lct:format-citation($f, map{})    )
   case map() return lct:format-result-map($e, $level+1)
   default return ()
}{if ($l = 'none') then () else if (lpm:can-use-linked-items()) then ltg:tag-actions($uid) else ()}
</div>
</div>
}
</div>
};

(:~ 
get the name for the key, not exactly elegant //
:)
declare function lct:format-key($k){
if (starts-with($k, 'dat') ) 
 then ltx:get-catdesc($k, 'tls-dates', 'desc')
else if (starts-with($k, 'uuid')) 
 then ltx:get-catdesc($k, 'tls-concepts-top', 'desc')
else
 $k
};

declare function lct:by-top($perspective, $n){
let $l := subsequence( for $a in $config:tls-ann
        let $o := lct:get-grouping-key($a, $perspective)
        group by $o
        let $cnt := count($a)
        order by $cnt descending
        where $cnt > $n
        return 
        [$cnt, $o[1]], 1, $n)
let $res := <ol >
    {
    for $i at $pos in $l
    return
       if ($perspective = 'users') then
        let $u := substring($i?2, 2)
         return
         <li pos="{$pos}" onclick="cit_set_value('{$perspective}', '{string($i?2)}')">{tu:get-member-name($i?2)} ({$i?1})</li>
       else
        <li pos="{$pos}" onclick="cit_set_value('{$perspective}', '{lct:format-key(string($i?2))}')">{lct:format-key(string($i?2))} ({$i?1})</li>
        }
    </ol>

return $res
};
(: we expect a tls:ann node here :)
declare function lct:get-grouping-key($a, $group){
let $g := if (string-length($group) > 0) then $group else "none"
let $gk :=
switch($g)
case "by-diachronic"
case "diachronic" return lmd:get-metadata($a, "tls-dates")
case "texts"
case "by-text" return $a//tls:srcline/@title
case "syn-func"
case "by-syn-func" return for $s in $a//tls:syn-func/@corresp return substring($s, 2)
case "by-sem-feat" return $a//tls:sem-feat
case "by-pos" return $a//tei:pos
case "chars"
case "by-char" return ($a//tei:form/tei:orth)[1]
case "concept"
case "by-concept" return ($a//@concept-id)[1]
case "users"
case "by-user" return ($a//tls:metadata/@resp)[1]
default return "none"
return
if ($gk) then $gk else "none"
};

declare function lct:get-sort-key($a, $sort){
count($a)
};

declare function lct:group-by-key($set as node()*, $key as xs:string){
for $s in $set 
let $o := lct:get-grouping-key($s, $key)
group by $o
return $s
};

declare function lct:recent($n){
let $ann := $config:tls-ann//tls:ann
, $l := subsequence(
for $a in $ann
 let $o := ($a//tls:metadata/@created)[1]
 order by $o descending
return 
    $o/ancestor::tls:ann, 1, 10)

let $res := 

    for $i at $pos in $l
    where $pos < $n
    return
    lct:format-citation($i, map{})

return $res
};

declare function lct:format-citation($node as node()*, $options as map(*)){
let $creator-id := if ($node/tls:metadata/@resp) then substring($node/tls:metadata/@resp, 2) else ()
, $concept := data($node/@concept)
, $exemplum := if ($node/tls:metadata/@rating) then xs:int($node/tls:metadata/@rating) else 0
, $bg := if ($exemplum > 0) then "protypical-"||$exemplum else "bg-light"
, $marktext := if ($exemplum = 0) then "Mark this attribution as prototypical" else "Currently marked as prototypical "||$exemplum ||". Increase up to 3 then reset."
, $resp := tu:get-member-initials($creator-id)
, $zi := string-join($node/tei:form/tei:orth/text(), "/")
, $creation-date := format-dateTime($node/tls:metadata/@created, "[Y0001]-[M01]-[D01]/[H01]:[m01]:[s01]")
, $src := data($node/tls:text/tls:srcline/@title)
, $line := $node/tls:text/tls:srcline/text()
, $type := $node/ancestor::tei:TEI/@type
, $target := substring(data($node/tls:text/tls:srcline/@target), 2)
, $loc := try {xs:int((tokenize($target, "_")[3] => tokenize("-"))[1])} catch * {0}
, $tr := $node/tls:text/tls:line/text()
, $pr := string-join($node/tei:form/tei:pron, '/')
, $sf := $node//tls:syn-func/text()
, $sm := $node//tls:sem-feat/text()
, $def := $node//tei:def/text()
, $attid := $node/@xml:id/string()
return
<div class="row {$bg}">
<div class="col-sm-1" title="{$creation-date}">{ if (lpm:can-use-linked-items()) then <input class="form-check-input" type="checkbox" name="res-check" value="" id="res-{$attid}"/> else ()}<span class="chn-font">{$zi}</span> ({$pr}){lct:set-value('chars', $zi)}</div>
<div class="col-sm-2"><a href="concept.html?concept={$concept}{$node//tei:sense/@corresp}">{$concept}</a> {lct:set-value('concept', $concept)}</div>
<div class="col-sm-4"><a href="textview.html?location={$target}{if ($type='remote')then '&amp;mode=remote'else()}" class="font-weight-bold">{$src, $loc}</a>&#160;{$line}{if ($tr) then (<br/>, $tr) else ()}</div>
<div class="col-sm-2">{lct:set-value('syn-func', $sf)}<span class="font-weight-bold ml-2">{$sf}</span> {if ($sm) then ("&#160;",<em>{$sm}</em>) else ()}</div>
<div class="col-sm-3">{$def}
  {lrh:swl-buttons(map{'ann': 'swl', 'resp': $resp, 'user' : sm:id()//sm:real/sm:username/text(), 'creator-id': $creator-id, 'node': $node, 'zi': $zi, 'context' : 'cit', 'marktext' : $marktext})}
</div>
</div>
};

declare function lct:set-value($perspective, $item){
<span class="btn badge badge-light" onclick="cit_set_value('{$perspective}', '{$item}')">CIT</span>
};

declare function lct:set-valuex($perspective, $item){
<span class="btn badge badge-light" style="background-color:palegreen" onclick="cit_set_value('{$perspective}', '{$item}')">CIT</span>
};

declare function lct:cit-count($node as node()*, $model as map(*)){
    count($config:tls-ann)
};

declare function local:format-map($m){
    <div xmlns="http://www.tei-c.org/ns/1.0">{
    for $k in map:keys($m)
    return
        <div>
        <span type="group">{$k}</span>
        {map:get($m, $k)[2]}
        </div>
    }</div>    
};


declare function lct:add-n($map as map(*)){
let $key := map:keys($map)
, $tax := ltx:get-taxonomy($key[1])
return
local:cit-add-n($map, $tax)
};

declare function local:cit-add-n($map as map(*), $n){
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
            case map() return local:format-map ($i)
            case element(*) return $i
            case xs:integer return <debug>{$i}</debug>
            case node()+ return ('seq', $pos, $i)
            default return <debug>other</debug>
         ) else () ,
    for $nn in $n/node() return local:cit-add-n($map, $nn)}
  case element(*)
   return $n
  default return $n
};

