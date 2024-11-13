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

import module namespace src="http://hxwd.org/search" at "../search.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare variable $lct:coll := (collection($config:tls-data-root||"/notes/swl")|collection($config:tls-data-root||"/notes/doc"))//tls:ann;

declare variable $lct:perspectives := map{
'chars' : 'Characters',
'concept' : 'Concepts',
'users' : 'Contributors'
,"syn-func": "Syntactical Functions"
,"texts": "Texts"
};

(:, 'date' : 'Creation date' :)


declare variable $lct:grouping := map{
"none" : "None",
"diachronic" : "Diachronic", 
"by-char" : "By character", 
"by-concept" : "By Concept",
"by-text": "By text", 
"by-syn-func": "By Syntactical Function", 
"by-sem-feat": "By Semantical Feature", 
"by-pos": "By Part Of Speech" 
};

declare function lct:citations-form($node as node()*, $model as map(*), $item as xs:string?, $perspective as xs:string?){
let $n := if (string-length($model?n)>0) then $model?n else 20
return
(
<div class="row">
 <div class="col-md-1">x</div>
 <div class="col-md-2 form-group ui-widget" id="input-group" >
 <b>Item</b>
 <input id="input-target" class="form-control" value="{$item}"/>
 <span id="input-id-span" style="display:none;"></span>
 </div>
 <div class="col-md-3">
 <b>Perspectives:</b>
 <select class="form-control" id="select-perspective" onchange="initialize_cit_autocomplete()">
 {for $o in map:keys($lct:perspectives)
 return 
 if ($o = $perspective) then
 <option value="{$o}" selected='true'>{$lct:perspectives?($o)}</option>
 else
 <option value="{$o}">{$lct:perspectives?($o)}</option>
 }
 </select>
 </div>
 <div class="col-md-3">
  <div class="row">
   <div class="col">
     <b>Grouping: Key 1</b> </div>
   <div class="col">
     <b>Key 2</b> </div>
 </div>
 <div class="row">
 <div class="col">
 <select class="form-control" id="select-grouping-1">
 {for $o in map:keys($lct:grouping)
 where not ($o = 'none')
 return 
 <option value="{$o}">{$lct:grouping?($o)}</option>}
 </select>
 </div>
 <div class="col">
 <select class="form-control" id="select-grouping-2">
 {for $o in map:keys($lct:grouping)
 return 
 <option value="{$o}">{$lct:grouping?($o)}</option>}
 </select>
 </div>
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
       case "chars" return $lct:coll[tei:form/tei:orth[. = $item]]
       case "concept" return $lct:coll[@concept = $item]
       case "syn-func" return $lct:coll[.//tls:syn-func[. = $item]]
       case "users" return $lct:coll[tls:metadata[@resp=$item]]
       case "texts" return $lct:coll[.//tls:srcline/@title[. = $item]]
       default return ()
   return (<div class="col-md-1"/>,
     lct:by-item($set, $map) => lct:format-result-map(1) )
else
   lct:by-top($perspective, $count)
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
, $cl := if ($level = 1) then 'col-md-10' else ''
, $total := sum(for $l in $k return map:get($map, $l)[1])
return
<div id="result-map-top-{$level}" class="{$cl}">
  <h3>Total: {$total}</h3>
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
  {if ($l = 'none') then () else <h3 data-toggle="collapse" data-target="#res-map-{$uid}">{lct:format-key($l)} {$cd}</h3>}
  <div id="res-map-{$uid}" class="{$class}">
{for $e at $epos in map:get($map, $l)
 return
  typeswitch($e[1])
   case xs:int return 
    for $f in $e return lct:format-citation($f[2], map{})
    case element(tls:ann) return 
   for $f in $e return lct:format-citation($f, map{})
   case map() return lct:format-result-map($e, $level+1)
   default return ()
}
</div>
</div>
}
</div>
};


declare function lct:format-key($k){
if (starts-with($k, 'dat')) 
 then lmd:cat-title($k)
else
 $k
};

declare function lct:by-top($perspective, $n){
let $l := subsequence( for $a in $lct:coll
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
        <li pos="{$pos}" onclick="cit_set_value('{$perspective}', '{string($i?2)}')">{string($i?2)} ({$i?1})</li>
        }
    </ol>

return $res
};
(: we expect a tls:ann node here :)
declare function lct:get-grouping-key($a, $group){
let $g := if (string-length($group) > 0) then $group else "none"
return
switch($g)
case "diachronic" return lmd:get-metadata($a, "tls-dates")
case "texts"
case "by-text" return $a//tls:srcline/@title
case "syn-func"
case "by-syn-func" return $a//tls:syn-func
case "by-sem-feat" return $a//tls:sem-feat
case "by-pos" return $a//tei:pos
case "chars"
case "by-char" return ($a//tei:form/tei:orth)[1]
case "concept"
case "by-concept" return ($a//@concept)[1]
case "users"
case "by-user" return ($a//tls:metadata/@resp)[1]
default return "none"
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
let $ann := $lct:coll//tls:ann
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
return
<div class="row {$bg}">
<div class="col-sm-1" title="{$creation-date}"><span class="chn-font">{$zi}</span> ({$pr}){lct:set-value('chars', $zi)}</div>
<div class="col-sm-2"><a href="concept.html?concept={$concept}{$node//tei:sense/@corresp}">{$concept}</a> {lct:set-value('concept', $concept)}</div>
<div class="col-sm-4"><a href="textview.html?location={$target}{if ($type='remote')then '&amp;mode=remote'else()}" class="font-weight-bold">{$src, $loc}</a>&#160;{$line}{if ($tr) then (<br/>, $tr) else ()}</div>
<div class="col-sm-2">{lct:set-value('syn-func', $sf)}<span class="font-weight-bold ml-2">{$sf}</span> {if ($sm) then ("&#160;",<em>{$sm}</em>) else ()}</div>
<div class="col-sm-3">{$def}</div>
</div>
};

declare function lct:set-value($perspective, $item){
<span class="btn badge badge-light" onclick="cit_set_value('{$perspective}', '{$item}')">CIT</span>
};

declare function lct:set-valuex($perspective, $item){
<span class="btn badge badge-light" style="background-color:palegreen" onclick="cit_set_value('{$perspective}', '{$item}')">CIT</span>
};

declare function lct:cit-count($node as node()*, $model as map(*)){
    count($lct:coll)
};