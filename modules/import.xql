xquery version "3.1";
(:~
: This module provides for import of foreign xml into the database
: 2022-11-03
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace imp="http://hxwd.org/xml-import"; 

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace  cb="http://www.cbeta.org/ns/1.0";
declare namespace h="http://www.w3.org/1999/xhtml";

import module namespace config="http://hxwd.org/config" at "config.xqm"; 
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace xed="http://hxwd.org/xml-edit" at "xml-edit.xql";
import module namespace http="http://expath.org/ns/http-client";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "db-utility.xqm";
import module namespace log="http://hxwd.org/log" at "log.xql";

declare variable $imp:ignore-elements := ("body", "docNumber", "juan", "jhead", "byline" ,"mulu") ;
declare variable $imp:log := $config:tls-log-collection || "/import";

declare variable $imp:kanji-groups := <groups>
    <group name="ExtA" lower="㐀" upper="䷿" lower-dec="13312" upper-dec="19967"/>
    <group name="BMP" lower="一" upper="鿿" lower-dec="19968" upper-dec="40959"/>
    <group name="ExtraA" lower="豈" upper="﫿" lower-dec="63744" upper-dec="64255"/>
    <group name="ExtraB" lower="︰" upper="﹏" lower-dec="65072" upper-dec="65103"/>
    <group name="ExtB" lower="𠀀" upper="𪛟" lower-dec="131072" upper-dec="173791"/>
    <group name="ExtC" lower="𪜀" upper="𫜿" lower-dec="173824" upper-dec="177983"/>
    <group name="ExtD" lower="𫝀" upper="𫠟" lower-dec="177984" upper-dec="178207"/>
    <group name="ExtE" lower="𫠠" upper="𯟿" lower-dec="178208" upper-dec="194559"/>
    <group name="ExtF" lower="" upper="" lower-dec="57344" upper-dec="63743"/>
    <group name="PuaCBETA" lower="󰀀" upper="󿿽" lower-dec="983040" upper-dec="1048573"/>
    <group name="PuaKRP" lower="􀀀" upper="􏿽" lower-dec="1048576" upper-dec="1114109"/>
</groups>;



declare function imp:maybe-make-collections($coll as xs:string){
let $tokens := tokenize($coll, "/")
, $parents:= for $t at $pos in $tokens
let $c := string-join($tokens[position() < $pos], "/")
return $c
return $parents
(:where string-length($c) > 0:)
(:return if (xmldb:collection-available($c)) then () else xmldb:create-collection(string-join($tokens[position() < $pos - 1], "/"), $c)
return
if (xmldb:collection-available($coll)) then () else xmldb:create-collection(string-join($tokens[position() < last() - 1], "/"), $tokens[last()]):)
};

declare function imp:clean-string-length($node as node()*){
let $s := $node//text() => string-join('') => normalize-space() => replace(' ', '') => replace('/', '')
return $s => string-length()
};

declare function imp:not-empty($node as node()*){
imp:clean-string-length($node) > 0
};

declare function imp:get-target-elements($node as node()){
let $els := distinct-values(for $t in $node//text() 
 let $n := local-name($t/parent::*) 
 where not ($n = $imp:ignore-elements)
 return $n)
return $els
};

declare function imp:prepare-element($node as node()){
let $tl := imp:clean-string-length($node)
let $s := string-join(
    for $n in $node/node()
    let $ln := local-name($n)
    return 
    if (string-length($ln) > 0) then 
     (:extra split on pb for long strings $/, disabled, since it interferes with CBETA, sigh :)
     if ($ln = 'pb' and not ($node/tei:c) and $tl > 50) then "$" else "$" else $n ) =>normalize-space() => replace(' ', '')
return $s
};

declare function imp:add-cb-seg($node as node(), $pref as xs:string){
let $pstr := string-join(imp:prepare-element($node))
, $res := string-join(for $r at $pos in tokenize($pstr, '\$') return $r || "$" || $pos || "$", '')
, $juan := ($node/preceding::cb:juan)[last()]/@n 
, $jid := if ($juan) then $juan else "000" 
, $lb := if ($node/@xml:id) then substring($node/@xml:id , 6) else $node/preceding::tei:lb[1]/@n
, $id  := $jid || "-" || $lb
, $astr := analyze-string ($res, $config:seg-split-tokens)
, $segs := for $m at $pos in $astr//fn:non-match
     let $nm := $m/following-sibling::fn:*[1]
     , $t := replace(string-join($nm/text(), ''), '/', '')
     , $tx := tlslib:add-nodes($m/text(), $node/child::*)
     , $sl := string-join($tx, '')=>normalize-space() => replace(' ', '') 
     , $nid := $pref  || $id ||".s" || ($pos )  
        where string-length($sl) > 0
        return
            element {QName(namespace-uri($node), "seg")} {
               $node/@* except ($node/@xml:id , $node/@cb:place) ,
               if ($node/ancestor::*:div[1]/@type = 'commentary') then 
                 attribute {"type"} {"comm"}  else (),
               attribute xml:id {$nid}, 
               ($tx, 
               if (local-name($nm) = 'match' and string-length($t) > 0) then <c n="{$t}"/> else () )}
return $segs
};


(: invoke imp:move-notes-out() and save and log the results etc :)
declare function imp:process-seg($seg as node()){
let $s1 := xed:process-inline-notes($seg, 8)
, $s2 := xed:move-notes-out($s1, $s1/@xml:id) 
, $l := imp:clean-string-length($seg)
, $l1 := imp:clean-string-length($s1)
, $l2 := imp:clean-string-length($s2) 
return if ($l = $l2) then xed:save-nodes($seg, $s2) else "Error! Could not process node: " || $l || "," || $l1 || "," || $l2 || ": " || $seg/@xml:id
};

declare function imp:do-note-processing($doc as node()){
for $n in $doc//tei:seg[tei:note]
return imp:process-seg($n)
};


declare function imp:remove-attr-ns($node as node()*){
  for $n in $node
  let $u := namespace-uri($n)
  return
  if ($u = "http://www.w3.org/XML/1998/namespace") then 
    $n
  else
    attribute {local-name($n)} {$n}
};


declare function imp:rec-adjust-pb($nodes as node()* , $ns as xs:string, $pref as xs:string){
 for $node in $nodes return
 typeswitch($node)
 case element (tei:pb) return
            let $s := $node/@xml:id => tokenize("\.")
            return
            element {QName($ns, local-name($node))} {
             $node/@* except $node/@xml:id
             ,attribute {"facs"} {substring($s[1],2)}
             ,attribute {"xml:id"} {$pref || substring($s[1],2) || "-" || string-join($s[position()>1], ".")}
             }
 case element (*) return 
            element {QName($ns, local-name($node))} {
             $node/@*, 
             imp:rec-adjust-pb($node/node(), $ns, $pref) }            
 default return $node
};


declare function imp:recursive-update-ns($nodes as node()*, $ns as xs:string, $pref as xs:string){
 for $node in $nodes return
 typeswitch($node)
 case element (tei:p) return 
             element {QName($ns, local-name($node))} { $node/@* , imp:add-cb-seg($node, $pref)}
 case element (tei:byline) return 
             element {QName($ns, local-name($node))} { $node/@* , imp:add-cb-seg($node, $pref)}
 case element (tei:l) return  
             element {QName($ns, local-name($node))} { $node/@* , imp:add-cb-seg($node, $pref)} 
(:             let $id := $pref || $node/parent::tei:lg/@xml:id || "." || count($node/preceding-sibling::*) 
             return
             element {QName($ns, "seg")} { 
                $node/@*, 
                attribute xml:id {$id},
                attribute {"type"} {"l"},
               $node/node()}:)
 case element (tei:head) return        
             element {QName($ns, local-name($node))} { $node/@* , imp:add-cb-seg($node, $pref)}
 case element (cb:jhead) return        
             element {QName($ns, "fw")} { $node/@* , imp:add-cb-seg($node, $pref)}
 case element (*) return element {QName($ns, local-name($node))} {
             imp:remove-attr-ns($node/@*) , 
             imp:recursive-update-ns($node/node(), $ns, $pref) }            
 default return $node
};

(: for KR we pass the text id as cbid :)
declare function imp:get-local-copy($cbid as xs:string, $krid as xs:string){
let $doc := (if (starts-with($cbid, "KR")) then imp:dl-krp-text($cbid) else imp:dl-cbeta-text($cbid))
, $targetcoll := xmldb:create-collection($config:tls-texts-root || "/KR/", substring($krid, 1, 3) || "/" || substring($krid, 1, 4) )
, $uri :=  xmldb:store($targetcoll, $krid || ".xml", $doc)
, $acl := (sm:chmod(xs:anyURI($uri), "rwxrwxr--"),
    sm:chgrp(xs:anyURI($uri), "tls-user"))
return $uri
};

(: updates to the header in files imported from CBETA 
TODO: also update the creation date, e.g. from 
https://raw.githubusercontent.com/mbingenheimer/cbetaCorpusSorted/main/chinese-chinese/-00-listC-C.md
and 
https://raw.githubusercontent.com/mbingenheimer/cbetaCorpusSorted/main/indian-chinese/listI-C.md
use these lists for dates and text type , e.g. translated or original
:)
declare function imp:update-metadata($doc as node(), $kid as xs:string, $title as xs:string){
let $cbid := $doc/tei:TEI/@xml:id
, $idno := update insert attribute xml:id {$cbid} into $doc//tei:idno[@type="CBETA"]
, $newid := update replace $doc/tei:TEI/@xml:id with $kid
, $state := update insert attribute state {"red"} into $doc/tei:TEI
, $user := sm:id()//sm:real/sm:username/text()
, $nt := <titleStmt xmlns="http://www.tei-c.org/ns/1.0">
			<title>{$title}</title>
{$doc//tei:titleStmt/tei:author, $doc//tei:titleStmt/tei:respStmt}
		</titleStmt>
, $dt := update replace $doc//tei:titleStmt with $nt
, $rev := <change  xmlns="http://www.tei-c.org/ns/1.0" when="{current-dateTime()}"> <name>{$user}</name>Various changes for compatibility with the TLS Application, derived from the version published by CBETA on GitHub.</change>          
, $rv := update insert $rev into  $doc//tei:revisionDesc
return 
()
};

declare function imp:do-conversion($kid as xs:string, $cbid as xs:string){
let $krt := doc($config:tls-add-titles)
(:, $kid := $krt//work[./altid = $cbid]/@krid :)
 , $doc := doc(imp:get-local-copy($cbid, $kid))
 , $state := xed:set-state($doc, "red")
  (: this is for the CBETA texts :)
 , $upd := if (starts-with($kid, "KR6")) then (let $pref := $kid || "_CBETA_" 
   , $h := imp:update-metadata($doc, $kid, $krt//work[@krid=$kid]/title/text())
   , $bd :=  imp:rec-adjust-pb($doc//tei:text/tei:body, "http://www.tei-c.org/ns/1.0", $pref) 
   , $res := update replace $doc//tei:text/tei:body with imp:recursive-update-ns($bd, "http://www.tei-c.org/ns/1.0", $pref) return () ) 
  else (
   (: here we deal with the KR texts :)
   let $phase1 := imp:do-prepare-krp($doc)
   , $phase2 := xed:line-doc($doc)
   , $remove-line := xed:do-phase2-processing($doc)
   return 
   $remove-line
   )
return $kid
};

declare function imp:do-prepare-krp($doc as node()){
 let $doc-uri := document-uri(root($doc))
 , $bd := $doc//tei:text/tei:body
 , $res := update replace $bd with imp:prepare-krp($bd) 
 , $doc := doc($doc-uri)
 , $remove-lbs := xed:remove-extra-lbs($doc//tei:lb)

return ()
};

declare function imp:prepare-krp($nodes as node()*){
  for $node in $nodes  return 
  typeswitch($node)
  case element(tei:g) return
     let $r := xs:int(substring($node/@ref, 4))
       , $t := $node/text()
     return
       if (string-length($t) > 0) then $t else codepoints-to-string($r+$config:pua-base-krp)
   case text() return
      let $as := analyze-string($node, "　+")
      for $n in $as/node() return
        if (local-name($n)='match') then 
         element {QName(xs:anyURI("http://www.tei-c.org/ns/1.0"), "space")} { 
         attribute n {$n},
         attribute quantity {string-length($n)}}
        else $n/text()
    case element (*) return element {QName(namespace-uri($node), local-name($node))} {
             imp:remove-attr-ns($node/@*) , 
             imp:prepare-krp($node/node()) }            

  default return $node
};

declare function imp:dl-cbeta-text($cbid as xs:string){
let $cbeta-gh-base := "https://raw.githubusercontent.com/cbeta-org/xml-p5/master/"
, $path := substring($cbid, 1, 1) || "/" || substring($cbid, 1, 3) || "/" || $cbid || ".xml" 
let $res :=  
            http:send-request(<http:request http-version="1.1" href="{xs:anyURI($cbeta-gh-base||$path)}" method="get">
                                <http:header name="Connection" value="close"/>
                              </http:request>)
return $res[2]
};

declare function imp:dl-krp-text($kid as xs:string){
let $krp-base := "https://www.kanripo.org/tlskr/"
let $res :=  
            http:send-request(<http:request http-version="1.1" href="{xs:anyURI($krp-base||$kid)}" method="get">
                                <http:header name="Connection" value="close"/>
                              </http:request>)
return $res[2]
};


declare function imp:de-duplicate-ids($doc as node()){
let $ds := $doc//tei:body//tei:seg
, $dupl-ids := for $s in $ds 
               let $c := count($ds[@xml:id=$s/@xml:id])
               where $c > 1
               return (update replace $s/@xml:id with $s/@xml:id || ".1",  $s/@xml:id || ".1")  
return <dedup>{$dupl-ids}</dedup>
};

declare function imp:check-document($doc as node()){
let $ds := $doc//tei:body//tei:seg
, $vardb := doc($config:tls-twjp-vardb)
, $segs := count($ds)
, $seg-ids := count(distinct-values($ds/@xml:id))
, $seg-noid := count($ds[not(@xml:id)])
, $els := for $e in distinct-values(for $d in $doc//tei:body//node() return local-name($d)) 
           order by $e 
           return $e
, $segl := for $s in $ds
           let $l := string-length(string-join($s/text()))
           return $l           
, $chars := string-join($ds) => normalize-space()
, $ccnt := for $c in string-to-codepoints($chars)
           let $cv := codepoints-to-string($c)
           , $kg := $imp:kanji-groups//group[$c[1] >= xs:int(@lower-dec) and $c[1] <= xs:int(@upper-dec)]/@name
           , $vt := $vardb//c[.=$cv[1]]
           , $type := if ($vt/@subtype) then $vt/@subtype else if ($vt/@type) then $vt/@type else "nor"
           group by $cv
           order by $c[1]
           return <char g="{$kg[1]}" n="{$c[1]}" cnt="{count($c)}" type="{$type[1]}">{$cv}</char>
(: , $cg := for $c in $ccnt 
          let $k := xs:int(($c/@n)[1])
          group by $g := $imp:kanji-groups//group[$k >= xs:int(@lower-dec) and $k <= xs:int(@upper-dec)]
          return <group name="{$g/@name}">
          {for $ck in $c return <k k="{$k}">{$ck}</k>} 
          </group>:)
          
 , $dedup:= if($segs = $seg-ids + $seg-noid) then () else imp:de-duplicate-ids($doc)           
, $rep := <report id="{$doc/@xml:id}" date="{util:system-dateTime()}">
<title>{$doc//tei:titleStmt/tei:title/text()}</title>
{$dedup}
<r status="{if($segs = $seg-ids + $seg-noid) then "OK" else "Error"}">Segs:  {$segs, $seg-ids, $seg-noid}</r>
<r>Seg length: {max($segl), min($segl)}</r>
<r>Para: {count($doc//tei:body//tei:p)}</r>
<r>Punc: {count($doc//tei:body//tei:c)}</r>
<r>Elements: {$els}</r>
<r>Characters: {string-length($chars)}, {count($ccnt)} </r>
<r>{$ccnt}</r>
</report>
return (xmldb:store("/db/apps/tls-texts/rep3", concat($doc/@xml:id, ".xml"), $rep), $doc/@xml:id) 
};

declare function imp:stub($node as node()){
() 
};
