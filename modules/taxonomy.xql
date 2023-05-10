xquery version "3.1";
(:~
: This module provides the functions related to the taxonomy of the tls
: of the TLS. 
: 2022-11-16
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace tax="http://hxwd.org/taxonomy";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace  cb="http://www.cbeta.org/ns/1.0";

import module namespace tlslib="http://hxwd.org/lib" at "/db/apps/tls-app/modules/tlslib.xql";
import module namespace imp="http://hxwd.org/xml-import" at "/db/apps/tls-app/modules/import.xql"; 
import module namespace xed="http://hxwd.org/xml-edit" at "/db/apps/tls-app/modules/xml-edit.xql"; 
import module namespace tlsapi="http://hxwd.org/tlsapi" at "/db/apps/tls-app/api/tlsapi.xql";
import module namespace config="http://hxwd.org/config" at "/db/apps/tls-app/modules/config.xqm";
import module namespace src="http://hxwd.org/search" at "/db/apps/tls-app/modules/search.xql"; 

declare function tax:extent-map(){
    map:merge(
    for $h in collection($config:tls-texts-root)//tei:TEI//tei:body
    let $md := src:facets-get-metadata($h, "kr-categories")
    , $ex := src:facets-get-metadata($h, "extent")
    , $grp := string-join($md[1])
    group by $grp
    where string-length($grp) > 0
    return
    map:entry($grp, sum(for $m in $ex return xs:int($m)))
    )
};

declare function tax:facets-add-chars($n, $map){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@chars,
    if ($map?($id)) then attribute chars {$map?($id)} else (),
    for $nn in $n/node() return tax:facets-add-chars($nn, $map)}
  case element(*)
   return $n
  default return $n
};

declare function tax:facets-sum-chars($n, $map){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   , $nv := if ($n/@chars) then xs:int($n/@chars) else 0
   , $sum := sum(($nv, for $s in $n//tei:category/@chars return xs:int($s)))
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@char-sum,
    if ($n/tei:category) then if ($sum > $nv) then attribute char-sum {$sum} else () else (),
    for $nn in $n/node() return tax:facets-sum-chars($nn, $map)}
  case element(*)
   return $n
  default return $n
};

declare function tax:update-taxonomy(){
let $g := "kr-categories"
let $tax := doc($config:tls-texts-meta||"/taxonomy.xml")//tei:category[@xml:id=$g]
, $map := tax:extent-map()
, $tree :=  tax:facets-add-chars($tax, $map) => tax:facets-sum-chars($map)  
, $hits := collection($config:tls-texts-root)//tei:TEI//tei:body
, $tmap := src:facets-map($hits, $g)
, $tree2 :=  src:facets-add-n($tree, $tmap) => src:facets-sum-n($tmap)  
return 
  update replace $tax with $tree2
};