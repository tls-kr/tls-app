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

import module namespace src="http://hxwd.org/search" at "../search.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(: We receive the result-set and calculate the count on the nodes 
@hits is the result set
@genre is the desired genre 

in the facet search, this is how I use it
           - create the map
            let $map := src:facets-map($hits, $g)
            , $tax := doc($config:tls-texts-taxonomy)//tei:category[@xml:id=$g]
            - add the hitcount to the map , then sum them up on the different levels, finally remove the categories w/o hit
            , $tree :=  src:facets-add-n($tax, $map) => src:facets-sum-n($map) => src:facets-prune()


:)
(:
declare function ltx:by-item($set, $map){
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
:)


(: turns a flat list to a map :) 

declare function ltx:hits-to-map($hits, $genre){
    map:merge(
    for $h in $hits
    let $md := lmd:get-metadata($h, $genre)
     for $m in $md
     let $grp := $m
    group by $grp
    where string-length($grp) > 0
    return
    map:entry($grp, (count($m), $h))
    )
};

declare function ltx:facets-add-n($n, $map){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@n,
    if ($map?($id)) then attribute n {$map?($id)} else (),
    for $nn in $n/node() return ltx:facets-add-n($nn, $map)}
  case element(*)
   return $n
  default return $n
};

declare function ltx:facets-sum-n($n, $map){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   , $nv := if ($n/@n) then xs:int($n/@n) else 0
   , $sum := sum(($nv, for $s in $n//tei:category/@n return xs:int($s)))
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@sum,
    if ($n/tei:category) then if ($sum > $nv) then attribute sum {$sum} else () else (),
    for $nn in $n/node() return ltx:facets-sum-n($nn, $map)}
  case element(*)
   return $n
  default return $n
};

(: sum of characters on the same level :)
declare function ltx:lev-sum($node){
let $p := $node/parent::tei:category
, $cn := $p/tei:category
, $s := sum(for $t in $cn return 
    if ($t/@sum) then xs:int($t/@sum)
    else if ($t/@n) then xs:int($t/@n) 
    else 0)
   return $s
};

declare function ltx:facets-prune($n){
  typeswitch ($n)
  case element(tei:category) return
   if ($n/@n or xs:int($n/@sum) > 0 ) then 
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* ,
    for $nn in $n/node() return ltx:facets-prune($nn)}
    else ()
  case element(*)
   return $n
  default return $n
};

