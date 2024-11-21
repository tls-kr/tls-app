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

(: from any category element, we look for the top of the tree :)
declare function ltx:get-taxonomy($id as xs:string){
    let $cat := collection($config:tls-data-root||"/core")//tei:category[@xml:id=$id]
    return $cat/ancestor::tei:category[@rend='top']
};


(: turns a flat list to a map :)
(: the callback function needs to be able to extract the grouping key from the provided node  :) 

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

