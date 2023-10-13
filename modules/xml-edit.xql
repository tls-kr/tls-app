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
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "db-utility.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tx="http://exist-db.org/tls";

declare variable $xed:encodingDesc :=       
<encodingDesc xmlns="http://www.tei-c.org/ns/1.0">
       <tagsDecl>
           <namespace name="http://www.tei-c.org/ns/1.0">
                  <tagUsage gi="app">
                      <listWit>
                      </listWit>
                  </tagUsage>
           </namespace>
       </tagsDecl>
       <variantEncoding location="external" method="double-end-point"/>
</encodingDesc>;

declare function xed:normalize-chars($s as xs:string){
fn:translate($s, $config:zvar-in, $config:zvar-out)
};

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
(: call xed:process-inline-notes() before to deal with short notes :)
declare function xed:move-notes-out($node as node(), $id as xs:string){
if ($node/tei:note) then 
let $nodes :=  for $n in $node/node() return if (local-name($n) = 'xx') then () else $n
, $note-i := (0,  for $s in $node/tei:note
     return
     index-of($nodes, $s))
  (: these are the extra text() nodes after the last note :)
, $extra := $nodes[position() = $note-i[last()] + 1 to count($nodes)]
, $extra-len := string-length(string-join($extra))
, $res := (
  for $i at $pos in $note-i 
   let $s1 := $nodes[position () = $i+1 to $note-i[$pos + 1] - 1]
    , $cs1 := xed:cleanstring($s1) => string-length()
   (: $s2 is the note node, which is used to separate the preceding and following text() into separate segs :)
   , $s2 := $nodes[$note-i[$pos + 1]]
   return
    (if ($cs1 > 0) then 
    element {QName(namespace-uri($node), "seg")} {
     $node/@* except ($node/@xml:id , $node/@len, $node/@uuid, $node/@lno, $node/@indent),
     attribute state {"locked"},
     attribute xml:id {$id || "." || $pos * 2 -1},  $s1} else (),
    if ($s2) then 
    element {QName(namespace-uri($node), "seg")} {
     $node/@* except ($node/@xml:id , $node/@type, $node/@len, $node/@uuid, $node/@lno, $node/@indent),
     attribute state {"locked"},
     attribute type {"comm"},
     attribute subtype {"nested"},
     attribute xml:id {$id || "." || $pos * 2 }, 
     if ($cs1 = 0 and $s1 = $node/tei:lb) then $s1 else (),
     for $n in $s2/node() return 
       if (string-length(local-name($n)) > 0) then $n else replace($n, "/", ""), 
     if ($extra-len = 0 and $extra = $node/tei:pb) then $extra else ()} else () 
    ),
    (: this is coming after the loop :)
    if ($extra-len > 0) then  
    element {QName(namespace-uri($node), "seg")} {
     $node/@* except ($node/@xml:id , $node/@len, $node/@uuid, $node/@lno, $node/@indent),
     attribute state {"locked"},
     attribute xml:id {$id || "." || count($note-i) * 2 -1},  $extra} else ()     
    )
return $res
else $node
};

(: remove short notes and replace with () notation :)
declare function xed:process-inline-notes($seg as node(), $limit as xs:int ){
element {QName(namespace-uri($seg), local-name($seg))} {
    $seg/@*  ,
for $n in $seg/node()
 let $c := $n => string-join('') => string-length()
 , $nn := local-name($n)
 return
  if ($c < $limit and $nn = 'note') then 
  (<c n="("/>, $n/text() => string-join('') => normalize-space() => replace(' ', '') => replace('/', ''), <c n=")"/>)
  else $n
}  
};


declare function xed:line2lb($line as node()){
for $n in $line/node()
return
if (local-name($n) = 'xx') then () else $n
};

declare function xed:set-state ($node as node(), $state as xs:string){
let $tei := $node/ancestor-or-self::tei:TEI
return 
 if ($tei/@state) then 
    update replace $tei/@state with $state 
 else
    update insert attribute state {$state} into $tei
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
         element {QName(xs:anyURI("http://www.tei-c.org/ns/1.0"), "space")} { 
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

(: not used?! :)
declare function xed:process-p2line($nodes as node()*){
   for $node in $nodes
   return
    typeswitch ($node)
    case element(tei:p) return element {QName(namespace-uri($node), local-name($node))} 
                 { $node/@* , 
(:                 if ($node/tei:lb) then:)
                 for $l in $node//tei:lb return xed:lb2line($l)
                 (:else $node:)}
    case element(*) return element {QName(namespace-uri($node), local-name($node))} {
                 $node/@* , 
                 xed:process-p2line($node)}    
    default return $node
}; 

declare function xed:line-doc($doc as node()){
let $linedoc := for $p in $doc//tei:p[tei:lb] 
            let $np := element {QName(namespace-uri($p), local-name($p))} {
                 $p/@* , 
                 for $l in $p/tei:lb
                 return xed:lb2line($l)}
             return update replace $p with $np
return ()
};

declare function xed:line-temp-doc($doc as node()){
let $d-uri := tokenize(document-uri(root($doc)), "/")[last()]
, $src-coll := util:collection-name($doc)
, $trg-coll := dbu:ensure-collection("/tmp")
, $rem := try {xmldb:remove($trg-coll, $d-uri) } catch * {()}
, $tmp-uri :=  xmldb:copy-resource($src-coll, $d-uri, $trg-coll, $d-uri)
, $tdoc := doc($tmp-uri)
, $linedoc := for $p in $tdoc//tei:p[tei:lb] 
            let $np := element {QName(namespace-uri($p), local-name($p))} {
                 $p/@* , 
                 for $l in $p/tei:lb
                 return xed:lb2line($l)}
             return update replace $p with $np
return $tmp-uri
};

declare function xed:cleanstring($str as xs:string*){
$str => string-join() => normalize-space() => replace(' ', '')
};

declare function xed:str-len($str as xs:string*){
$str => xed:cleanstring() => string-length()
}; 

declare function xed:lb2line($lb as node()){
let $nlb := $lb/following-sibling::tei:lb[1]
, $lbc := count($lb/preceding::tei:lb) + 1
, $line := $lb/following-sibling::node() intersect $nlb/preceding-sibling::node()
, $sp :=  $lb/following-sibling::tei:space intersect $nlb/preceding-sibling::tei:space
, $indent := if (true()) then data($sp[1]/@quantity) else ()
, $len := $line => xed:str-len() + sum( for $s in $sp return xs:int($s/@quantity)) 
return  
    element {QName(namespace-uri($lb),"line")} {
    if ($indent > 0) then attribute indent {$indent} else (),
    attribute len {$len},
    attribute lno {$lbc}, 
    attribute uuid {util:uuid()},
    (: indexing to the line requires unique string values in the sequence :)
    element {QName(namespace-uri($lb), "xx")} {$lbc},
    $lb, $line} 
};

(: tries to determine heuristically if the line has a special function.  This could be 
  - header of a subsection where we want to split a div in paragraphs
     - begins with three spaces (different from surrounding lines)
     - ends with 序, 跋 or other such indicators
  - fw or byline
  - commentary
  - para-ending-line
:) 
declare function xed:is-special-line($map as map(*)) as xs:string?{
let $h-indent := if ($map?h-indent) then $map?h-indent else 3
return
if ($map?line/@indent = $h-indent or ends-with($map?line, "序") 
      or matches($map?line, "^[\s?\d?]+?提要")
      )
 then "head"
else if (matches($map?line, "^[\s?\d?]+?欽定四庫全書") 
      or matches($map?line, "卷"||$config:kanji-numberlike-tokens||"$")  
      or matches($map?line, "^[\s?\d?]+?"||$map?title)
      ) 
 then "fw"
else if ($map?line/@len > 0 and $map?line/@len < $map?len) 
 then "maybe-end-p" 
else ()
};

(: find the most frequently seen line length :)
declare function xed:common-line-len($div as node()*){
let $ls := for $l in $div//tei:line 
   let $n := xs:int($l/@len)
   group by $g := $n
   order by count($n) descending
   return $g
return $ls[1]
};

(: find the most commonly used edition :)
declare function xed:common-edition($div as node()*){
let $ls := for $l in $div//tei:pb 
   let $ed := data($l/@ed)
   group by $g := $ed
   order by count($ed) descending
   return $g
return $ls[1]
};

(: the first phase of the conversion has put all the content of a juan (file) in a div with one p
here we digest this and create subdivisions etc. where necessary
:)
declare function xed:post-process-div($div as node(), $no as xs:int){
 for $p in $div/tei:p
  let $idprefix := tokenize(($p//tei:pb/@xml:id)[1], '-')[1]
  , $title := $div/ancestor::tei:TEI//tei:titleStmt/tei:title/text() => string-join()
  let $lines := $p/tei:line
  , $ll := xed:common-line-len($div)
  , $maybe-comment := count($p/tei:line[@indent="1"])
  , $all-index :=   
    ((:<r type="head" index="1"/>,:) for $l in $lines
     let $t := xed:is-special-line(map{"line" : $l, "len" : $ll, "title" : $title, "h-indent" : 2})
      where string-length($t) > 0
      return <r type="{$t}" index="{index-of($lines, $l)}" lno="{$l/@lno}">{data($l/@uuid)}</r>
      , <r type="head" index="{count($lines)}">last-head-{count($lines)}</r> )
  , $h-index := filter ($all-index, function ($n) {$n/@type='head'})
  where count($lines) > 0
  return
 if (count($h-index) > 1 
  (: we want to avoid the toc with many header lines :)
  and  (count($h-index) div count($lines) < 0.4)
 ) then 
  for $v at $pos in ($h-index)
   let $type := data($v/@type)
    , $i := xs:int($v/@index)
    , $next-i := xs:int($h-index[$pos + 1]/@index)
   where $pos < count($h-index)
  return
     element {QName(namespace-uri($p),"div")}
     {attribute {"n"} { "d" || $no || $pos}
     , attribute {"type"} {"gen"}
     , attribute {"xml:id"} {$idprefix || "-d" || $pos}
(:     , <o>{(count($h-index) div count($lines))}</o>:)
     , xed:process-fw-lines($lines, $all-index, $h-index, $v)
      , element {QName(namespace-uri($p),"head")} 
         {$lines[$i]}
      , xed:process-maybe-p-lines($lines, $all-index, $h-index, $v)
     }
 else 
  (: if there are no header lines, we output the whole juan in one go :)
  let $pos := 1
  , $v := ()
  , $do-comments := $maybe-comment div count($lines) > 0.5
  return
     element {QName(namespace-uri($p),"div")}
     {attribute {"n"} { "d" || $no || $pos}
     , attribute {"type"} {"orig"}
     , attribute {"xml:id"} {$idprefix || "-d" || $pos}
(:     , <o>{$do-comments, $all-index}</o>:)
     , xed:process-all-lines($lines, $all-index)
     }
  
};

(: this is called for texts that have no header lines.  :)
declare function xed:process-all-lines($lines, $all-index){
let $fw-is := filter ($all-index, function ($n) {$n/@type = "fw"})
for $f at $pos in $fw-is
  let $fi := xs:int($f/@index)
  , $next-fi := if ($fw-is[$pos + 1]) then xs:int($fw-is[$pos + 1]/@index) else count($lines)
  , $start := $fi + 1 
  , $len := $next-fi - $start   
  return (element {QName(namespace-uri($lines[$fi]),"fw")} {$lines[$fi]},
  if ($len > 1) then 
    element {QName(namespace-uri($lines[$fi]), "p")}
    {if ($len = 1) then $lines[$start] else subsequence($lines, $start, $len)}
  else () 
  )
};

(: when processing the head, we look for fw lines of the same div, that need to be inserted before the head:)
declare function xed:process-fw-lines($lines, $all-index, $h-index, $v){
 let $vi := if ($v) then xs:int($v/@index) else 9999 (: maybe I should calculate the first non-fw line here? :)
 let $prev-head-is := for $h in $h-index 
           let $i := xs:int($h/@index)
           order by $i ascending
           where $i < $vi 
           return $h
  , $prev-head-i := if ($prev-head-is) then xs:int(subsequence($prev-head-is, 1, 1)/@index)  else 0
  ,$fw-is := filter ($all-index, function ($n) {$n/@type = "fw" and xs:int($n/@index) >= $prev-head-i and xs:int($n/@index) <= $vi})
    return for $f in $fw-is
       let $fi := xs:int($f/@index)
       return element {QName(namespace-uri($lines[$fi]),"fw")} {$lines[$fi]}
};

declare function xed:process-maybe-p-lines($lines, $all-index, $h-index, $v){
 let $vi := xs:int($v/@index)
 let $next-head-is := for $h in $h-index 
           let $i := xs:int($h/@index)
           order by $i ascending
           where $i > $vi 
           return $h
  , $next-head-i := if ($next-head-is) then xs:int(subsequence($next-head-is, 1, 1)/@index)  else count($lines)
  ,$mp-is := filter ($all-index, function ($n) {$n/@type = "maybe-end-p" and xs:int($n/@index) >= $vi and xs:int($n/@index) <= $next-head-i})
   return (:<o>{ $all-index[position() = 1 to 10], :)
     if (count($mp-is) > 0) then 
       for $mp at $pos in $mp-is
       let $end := xs:int($mp/@index)
       , $start := if ($pos = 1) then $vi + 1 else xs:int($mp-is[$pos - 1]/@index) + 1
       , $len := $end - $start +1
       return (
        element {QName(namespace-uri($lines[1]),"p")} (:{subsequence ($lines, $vi + 1, $mi - $vi - 1)}:)
         {if ($len = 1) then $lines[$start] else subsequence($lines, $start, $len)}
         (: here we need to care for the lines between the p-end and the next heading 
         TODO check if they are fw ! :)
       , if ($pos = count($mp-is) and $next-head-i - $end -1 > 0 ) then (
        element {QName(namespace-uri($lines[1]),"p")} 
         {attribute {"type"} {"maybe-not-p"},
         subsequence($lines, $end + 1, $next-head-i - $end -1)}) else ())
     else 
       (: No maybe-p-end lines, so we take all in one p  :)
        let $start := $vi + 1
        , $end := $next-head-i
        , $len := $end - $start + 1
        return
        element {QName(namespace-uri($lines[1]),"p")} 
        {subsequence($lines, $start, $len)}
       (:}</o>:)
};

declare function xed:line2seg($nodes as node()*, $idprefix as xs:string){
for $node in $nodes
let  $p2 := "-" || $node/ancestor::tei:div[@type='gen']/@n
return 
  typeswitch($node)
  case element (tei:line) return 
    let $nnode := xed:process-inline-notes($node, 8)
    let $pcnt := count($node/preceding::tei:p[./ancestor::tei:div[2] = $node/ancestor::tei:div[2]]) + 1
    let $lcnt := count($node/preceding::tei:line[./ancestor::tei:div[1] = $node/ancestor::tei:div[1]]) + 1
    let $prefix :=  if (matches($idprefix, "-")) then $idprefix else  $idprefix || $p2 || local-name($node/parent::tei:*) 
    return
    if ($nnode/tei:note) then xed:move-notes-out($nnode, $prefix || ".s" || $lcnt) else
      element {QName(namespace-uri($node), "seg")}
      {attribute {"xml:id"} {$prefix || ".s" || $lcnt}
      , if (local-name($node/parent::*) = 'p' and $node/@indent = "1") then 
          attribute type {"comm"}
        else ()
      , attribute state {"locked"}
      ,for $n in $nnode/node() return if (local-name($n) = 'xx') then () else $n
      }
  case element (tei:p) return 
      let $pcnt := count($node/preceding::tei:p[./ancestor::tei:div[1] = $node/ancestor::tei:div[1]]) + 1
      return
      element {QName(namespace-uri($node), local-name($node))}
      {$node/@* except $node/@xml:id,
      attribute {"xml:id"} {$idprefix|| $p2 || "p" || $pcnt}
      , for $n in $node/node() return xed:line2seg($n, $idprefix || $p2 || "p" || $pcnt)}
  case element(*) return
      element {QName(namespace-uri($node), local-name($node))}
      {$node/@* ,
      xed:line2seg($node/node(), $idprefix)}
  case text() return $node
  default return $node
};

declare function xed:do-phase2-processing($doc as node()){
for $d at $x in $doc//tei:body/tei:div
 let $idprefix := tokenize(($d//tei:pb/@xml:id)[1], '-')[1]
 let $nd1 := xed:post-process-div($d, $x)
 let $nd2 := xed:line2seg($nd1, $idprefix)
return xed:save-nodes($d, $nd2)
};


declare function xed:remove-extra-lbs($lbs as node()*){
let $root := root($lbs[1])
let $res :=
  for $lb in $lbs
    let $line := xed:lb2line($lb)
  , $lt := $line//text() => string-join('') => normalize-space() => replace('^\d+', '') => replace(' ', '')  
  return if ($line/tei:pb and string-length($lt)=0) then (update delete $lb, 1)  else ()
return if (sum($res) > 0) then xed:remove-extra-lbs($root//tei:lb) else 0
};

(: for KR WYG texts, there are some with paragraphs marked with 2 spaces (type B) and others with the original layout (type A). 
We need to distinguish these types :)

declare function xed:insert-node-at($node as node(), $pos as xs:integer, $insert as node()){
  element {QName(namespace-uri($node), local-name($node))}
      {$node/@*,
      for $n in $node/node()
      return
      typeswitch($n)
      case element(*) return $n
      case text() return 
       let $l := string-join($n/preceding::text() intersect $node/node()) =>  normalize-space() => replace(" ", "") => string-length()
       return
       if ($pos <= ($l + normalize-space($n) => replace(" ", "") => string-length() )) then
       if ($pos = 0 and $l=0) then
        ($insert, $n)
       else
        if ($l + string-length($n) >= $pos and $pos > $l) then
         let $s := substring($n, 1, $pos - $l)
         , $s2 := substring($n, $pos - $l + 1)
         , $s2l := normalize-space($s2) => replace(" ", "") => string-length()
         return 
           ($s, $insert, $s2)
        else $n
        else $n
      default return $n
    }
      
};

declare function xed:stub($map as map(*)){
() 
};
