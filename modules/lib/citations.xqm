xquery version "3.1";

(:~
 : Library module for analyzing citations.
 :
 : @author Christian Wittern
 : @date 2023-10-23
 :)

module namespace lct="http://hxwd.org/citations";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare variable $lct:coll := (collection($config:tls-data-root||"/notes/swl")|collection($config:tls-data-root||"/notes/doc"));

declare variable $lct:perspectives := map{
'concepts' : 'Concepts',
'chars' : 'Characters',
'users' : 'Contributors',
'date' : 'Creation date'
};
declare variable $lct:grouping := map{
"diachronic" : "Diachronic", 
"by-text": "By text", 
"by-syn-func": "By Syntactical Function", 
"by-char" : "By character", 
"by-concept" : "By Concept"
};

declare function lct:citations-form($node as node()*, $model as map(*)){
(
<div class="row">
 <div class="col-md-1">x</div>
 <div class="col-md-3">
 <b>Perspectives:</b>
 <select class="form-control" name="select-perspective">
 {for $o in map:keys($lct:perspectives)
 return 
 <option value="{$o}">{$lct:perspectives?($o)}</option>}
 </select>
 </div>
 <div class="col-md-2">
 <b>Item</b>
 <input id="input-target" class="form-control" value=""/>
 </div>
 <div class="col-md-3">
 <b>Grouping:</b>
 <select class="form-control" name="select-perspective">
 {for $o in map:keys($lct:grouping)
 return 
 <option value="{$o}">{$lct:grouping?($o)}</option>}
 </select>
 </div>
</div>,
<hr/>,
<div class="row">
 <div class="col-md-1">x</div>
 <div class="col-md-2"><b>Most frequent concepts</b>
{lct:citations(map{"parameters" : map{"perspective" : "concepts", "count" : 10}})}
 </div>
 <div class="col-md-2"><b>Most frequent characters</b>
{lct:citations(map{"parameters" : map{"perspective" : "chars", "count" : 10}})}
 </div>
 <div class="col-md-2"><b>Most prolific contributors</b>
{lct:citations(map{"parameters" : map{"perspective" : "users", "count" : 10}})}
 </div>
 <div class="col-md-4"><b>Most recent citations</b>
{lct:recent(10)}
 </div>
</div>,
<hr/>
)
};

(: this is called via API to actually execute the requested analysis :)
declare function lct:citations($map as map(*)){
let $perspective := $map?parameters?perspective
, $count := $map?parameters?count
, $item := $map?parameters?item
, $sort := if (string-length($map?parameters?sort)>0) then $map?parameters?sort else ""
, $ann := $lct:coll//tls:ann
return
lct:by($perspective, $count)
};

declare function lct:by($perspective, $n){
let $ann := $lct:coll//tls:ann
, $l := subsequence( for $a in $ann
        let $o :=  switch ($perspective)
        case "concepts" return   ($a//@concept)[1]
        case "users" return ($a//tls:metadata/@resp)[1]
        case "chars" return ($a//tei:form/tei:orth)[1]
        default return ()
        group by $o
        let $cnt := count($a)
        order by $cnt descending
        where $cnt > $n
        return 
        [$cnt, $o[1]], 1, 10)
let $res := <ul >
    {
    for $i at $pos in $l
    where $pos < $n
    return
        <li pos="{$pos}" cnt="{$i?1}">{string($i?2)} ({$i?1})</li>
        }
    </ul>

return $res
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
return
<div class="row {$bg}">
<div class="col-sm-2"><span>{format-dateTime($node/tls:metadata/@created, "[Y0001]-[M01]-[D01]/[H01]:[m01]:[s01]")}</span></div>
<div class="col-sm-2"><span>{$node/text()}</span></div>
<div class="col-sm-3"><a href="concept.html?concept={$concept}{$node/@corresp}">{$concept}</a></div>
</div>
};

declare function lct:cit-count($node as node()*, $model as map(*)){
    count($lct:coll//tls:ann)
};