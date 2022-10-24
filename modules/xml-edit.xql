xquery version "3.1";
(:~
: This module provides function for generic changes to xml files in the database
: 2022-10-10
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace xed="http://hxwd.org/xml-edit";

import module namespace config="http://hxwd.org/config" at "config.xqm";

import module namespace krx="http://hxwd.org/krx-utils" at "krx-utils.xql";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tx="http://exist-db.org/tls";

(:~
  Split parent of xml node at the node n
  n will be the first node of the second element, the first element contains all the preceding siblings
  xml:id will be changed
  returns the two split elements
:)

declare function xed:split($n as node()){
let $p := $n/parent::*
, $segs:=$p/node()
, $i := index-of($segs, $n)
, $n1 := element {QName(namespace-uri($p),local-name($p))} {
    $p/@* except $p/@xml:id,
    if ($p/@xml:id) then attribute xml:id {$p/@xml:id || ".1"} else (),
    subsequence($segs, 1, $i)
}
,$n2  := element {QName(namespace-uri($p),local-name($p))} {
    $p/@* except $p/@xml:id,
    if ($p/@xml:id) then attribute xml:id {$p/@xml:id || ".2"} else (),
    subsequence($segs, $i+1)
}
return ($n1, $n2)
};
(: this will have the splitting node as the first of the second sequence :)
declare function xed:split-1($n as node()){
let $p := $n/parent::*
, $segs:=$p/node()
, $i := index-of($segs, $n)
, $n1 := element {QName(namespace-uri($p),local-name($p))} {
    $p/@* except $p/@xml:id,
    if ($p/@xml:id) then attribute xml:id {$p/@xml:id || ".1"} else (),
    subsequence($segs, 1, $i -1)
}
,$n2  := element {QName(namespace-uri($p),local-name($p))} {
    $p/@* except $p/@xml:id,
    if ($p/@xml:id) then attribute xml:id {$p/@xml:id || ".2"} else (),
    subsequence($segs, $i)
}
return ($n1, $n2)
};


(: split in three parts if necessary to have the node $n in a node by itself :)
declare function xed:split3($n as node(), $newname as xs:string){
let $p := $n/parent::*
, $segs:=$p/node()
, $i := index-of($segs, $n)
return
for $pos  in (1, 2, 3)
   let $cs := switch ($pos) 
    case 1 return subsequence($segs, 1, $i - 1)
    case 2 return subsequence($segs, $i, 1)
    case 3 return subsequence($segs, $i+1)
    default return ()
   return
   if (string-length(string-join($cs, '')) > 0) then 
   let $name := if (string-length($newname) > 1 and count($cs) = 1) then $newname else local-name($p) 
   return
   element {QName(namespace-uri($p), $name)} {
    $p/@* except $p/@xml:id,
    if ($p/@xml:id) then attribute xml:id {$p/@xml:id || "." || $pos} else (),
    $cs
   }
   else ()
};


declare function xed:rename($n as node(), $name as xs:string){
element {QName(namespace-uri($n),$name)} {
    $n/@* ,
    $n/node()
}
};

(: this does in fact rename the parent of the seg, if necessary splitting the parent first :)
declare function xed:rename-seg($n as node(), $name as xs:string){
let $p:=$n/parent::*
, $i := index-of($p/tei:seg,$n)
, $sp := xed:split3($n, "")
, $t := if ($i = 1) then  
 element {QName(namespace-uri($n),$name)} {
    $n/@* ,
    $n/node()
}
else ()
return $t
};


(: repeatedly split until the node name is reached :)

declare function xed:split-to($n as node(), $container as node()){
let $p := $n/parent::*
, $s := xed:split($n)
return
if (local-name($p) = $name) then 
    element {QName(namespace-uri($p),local-name($p))} {
    $p/@* except $p/@xml:id,
    if ($p/@xml:id) then attribute xml:id {$p/@xml:id || ".1"} else (),
    $s
}
else 
  (: we take the second one and split again :)
  xed:split-to($s[2], $name)
};

declare function xed:process-p($node as node()){
    typeswitch ($node)
    case element(tei:p) return <tei:p>{for $n in $node/* return xed:process-p($n)}</tei:p>
    case element(tei:note) return <tei:seg>{xed:process-p($node)}</tei:seg>
    case element (tei:lb) return ()
    case element (tei:pb) return ()
    default return $node
   
}; 

(: some seg-types require structural changes in the xml :)

declare function xed:change-seg-type($seg as node(), $type as xs:string){
let $p := $seg/parent::*
, $res :=
switch($type)
 case "root"
 case "comm" 
  return 
    xed:save-nodes($seg, element {QName(namespace-uri($seg), local-name($seg))} {
    $seg/@* except $seg/@type ,
    attribute type {$type},
    $seg/node()})
 case "fw" 
 case "byline"
  return xed:save-nodes($p, xed:split3($seg, $type))
 case "p"
  return xed:save-nodes($p, xed:split-1($seg))
 case "head"
  (: if there are tei:p before the head, we need to split the parent div :)
  return 
   let $preceding-p := count($p/preceding-sibling::tei:p)
   , $res := xed:split3($seg, $type)
   return
   if ($preceding-p > 0) then 
     let $hid := $res[2]/@xml:id
     , $r1 := xed:save-nodes($p, $res)
     , $hd := doc(document-uri(root($seg)))//tei:head[@xml:id=$hid]
     , $hp := $hd/parent::*
     , $sp := xed:split-1($hd)
     return xed:save-nodes($hp, $sp)
   (: I will split the parent div, then replace the second one with my result  :)
   else xed:save-nodes($p, $res)
 case "head+" return $seg
   (: this is not ready 
   return
   let $div := index-of($seg/parent::tei:div, $seg)
   return
   if (index-of($seg/parent::tei:div, $seg) = 1) 
     then () 
     else () :)
  (: split the current tei:p in a tei:div and  :) 
  
 default return $seg
 return
 $res
};

declare function xed:save-nodes($seg as node(), $segs as node()*){
    (if (count($segs) > 1) then
     let $firstseg := $segs[1]/@xml:id
     return (
     update insert subsequence($segs, 2) following $seg
     , update replace $seg with $segs[1]
     )
    else
    update replace $seg with $segs
    , $segs[last()]/@xml:id)
};

(: the following is mainly for dealing with imported texts, maybe move to import module? :) 

declare function xed:line2lb($line as node()){
$line/node()
};

declare function xed:set-state ($node as node(), $state as xs:string){
let $tei := $node/ancestor-or-self::tei:TEI
return 
 if ($tei/@state) then 
    update replace $tei/@state with $state 
 else
    update insert attribute state {$state} into $tei
};

(: remove short notes and replace with () notation :)
(: this exist in import.xql, but needs to be generalized, operate on <note> element :)
declare function xed:process-inline-notes($node as node(), $limit as xs:int ){
()
};


(: replace ideographic space characters with space elements :)
(: TODO probably reimplement as recursion with one save operation will be more efficient :)
declare function xed:space-to-element($node as node()){
let $tei := $node/ancestor-or-self::tei:TEI
let $res := for $s in $tei//tei:text//text()[contains(., "　")]
    let $as := analyze-string($s, "　+")
    , $r := for $n in $as/node()
    return
        if (local-name($n)='match') then 
         element {QName(namespace-uri($s), "space")} { 
         attribute n {$n},
         attribute quantity {string-length($n)}}
        else $n/text()
    return xed:save-nodes($s, $r)
return $res
};

(: the g element needs to be represented with a codepoint from the unicode PUA area.
CBETA texts and krp texts have different ranges of codepoint values
@param: node is any element-node in the document, we will get the tei:TEI element from there 
:)
declare function xed:g-to-unicode($node as node()){
let $tei := $node/ancestor-or-self::tei:TEI
, $is-cbeta := $tei//tei:distributor[contains(., "CBETA")]
, $pua-const:= if ($is-cbeta) then $config:pua-base-cbeta else $config:pua-base-krp
return
 for $g in $tei//tei:text//tei:g
 let $r := xs:int(substring($g/@ref, 4))
 , $t := $g/text()
 , $p := $g/preceding-sibling::text()[1]
 , $f := $g/following-sibling::text()[1]
 , $nc :=  if (string-length($t) > 0) then $t else codepoints-to-string($r+$pua-const)
  (: if g has text content, it is the normalized form of the character, which we will use here :)
 return (if ($p) then update replace $p with $p || $nc else update replace $f with $nc || $f , update delete $g)
};




declare function xed:lb2line($lb as node()){
let $nlb := $lb/following-sibling::tei:lb[1]
, $line := $lb/following-sibling::node() intersect $nlb/preceding-sibling::node()
return  
    element {QName(namespace-uri($lb),"line")} {$lb, $line} 
};

declare function xed:remove-extra-lbs($lbs as node()*){
let $root := root($lbs[1])
let $res :=
  for $lb in $lbs
    let $line := xed:lb2line($lb)
  , $lt := $line//text() => string-join('') => normalize-space() => replace(' ', '')  
  return if ($line/tei:pb and string-length($lt)=0) then (update delete $lb, 1)  else ()
return if (sum($res) > 0) then xed:remove-extra-lbs($root//tei:lb) else 0
};

(: for KR WYG texts, there are some with paragraphs marked with 2 spaces (type B) and others with the original layout (type A). 
We need to distinguish these types :)


declare function xed:stub($map as map(*)){
() 
};
