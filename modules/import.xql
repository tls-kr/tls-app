
xquery version "3.1";

module namespace imp="http://hxwd.org/xml-import"; 


declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace  cb="http://www.cbeta.org/ns/1.0";

import module namespace config="http://hxwd.org/config" at "/db/apps/tls-app/modules/config.xqm" ; 
import module namespace tlslib="http://hxwd.org/lib"  at "/db/apps/tls-app/modules/tlslib.xql";

declare variable $imp:ignore-elements := ("body", "docNumber", "juan", "jhead", "byline" ,"mulu") ;

(: (
xmldb:create-collection("/db/apps/tls-texts", "KR"),
xmldb:create-collection("/db/apps/tls-texts/KR", "KR6"),
xmldb:create-collection("/db/apps/tls-texts/KR/KR6", "KR6d")) :)

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

declare function imp:get-target-elements($node as node()){
let $els := distinct-values(for $t in $node//text() 
 let $n := local-name($t/parent::*) 
 where not ($n = $imp:ignore-elements)
 return $n)
return $els
};

declare function imp:prepare-element($node as node()){
let $tl := string-length(string-join($node//text(), ''))
let $s := string-join(
    for $n in $node/node()
    let $ln := local-name($n)
    return 
    if (string-length($ln) > 0) then 
     (:extra split on pb for long strings :)
     if ($ln = 'pb' and $tl > 20) then "$/" else "$" else $n ) =>normalize-space() => replace(' ', '')
return $s
};

declare function imp:add-seg($node as node(), $pref as xs:string){
let $pstr := string-join(imp:prepare-element($node))
, $res := string-join(for $r at $pos in tokenize($pstr, '\$') return $r || "$" || $pos || "$", '')
, $id := if ($node/@xml:id) then $node/@xml:id => replace('_master_', '_tls_') else local-name($node) || "-" || ($node/preceding::tei:lb)[1]/@n
, $astr := analyze-string ($res, $config:seg-split-tokens)
, $segs := for $m at $pos in $astr//fn:non-match
     let $nm := $m/following-sibling::fn:*[1]
     , $t := replace(string-join($nm/text(), ''), '/', '')
     , $tx := tlslib:add-nodes($m/text(), $node/child::*)
     , $sl := string-join($tx, '')=>normalize-space() => replace(' ', '') 
     , $nid := $pref  || $id ||"-s" || ($pos )  
        where string-length($sl) > 0
        return
          <seg xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$nid}">{$tx, 
            if (local-name($nm) = 'match' and string-length($t) > 0) then <c n="{$t}"/> else ()}</seg>
return $segs
};

declare function imp:move-notes-out($node as node()){
let $nodes := $node/node()
, $id := $node/@xml:id
, $note-i := (0,  for $s in $node/tei:note
     return
     index-of($nodes, $s))
  (: these are the extra text() nodes after the last note :)
, $extra := $nodes[position() = $note-i[last()] + 1 to count($nodes)]
, $res := (
  for $i at $pos in $note-i 
   let $s1 := $nodes[position () = $i+1 to $note-i[$pos + 1] - 1]
   (: $s2 is the note node, which is used to separate the preceding and following text() into separate segs :)
   , $s2 := $nodes[$note-i[$pos + 1]]
   return
    (if ($s1) then <seg state="locked" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}.{$pos * 2 -1}">{$s1}</seg> else (),
    if ($s2) then <seg state="locked" xmlns="http://www.tei-c.org/ns/1.0" type="comm" subtype="nested" xml:id="{$id}.{$pos * 2}">{$s2/text()}</seg> else ()), 
    (: this is coming after the loop :)
    if ($extra) then <seg state="locked" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}.{count($note-i) * 2 -1}" >{$extra}</seg> else ()     
    )
return $res
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

declare function imp:recursive-update-ns($nodes as node()*, $ns as xs:string, $pref as xs:string){
 for $node in $nodes return
 typeswitch($node)
 case element (tei:p) return 
             element {QName($ns, local-name($node))} { $node/@* , imp:add-seg($node, $pref)}
 case element (tei:byline) return 
             element {QName($ns, local-name($node))} { $node/@* , imp:add-seg($node, $pref)}
 case element (tei:l) return        
             element {QName($ns, local-name($node))} { $node/@* , imp:add-seg($node, $pref)}
 case element (cb:jhead) return        
             element {QName($ns, "fw")} { $node/@* , imp:add-seg($node, $pref)}

 case element (*) return element {QName($ns, local-name($node))} {
             imp:remove-attr-ns($node/@*) , 
             imp:recursive-update-ns($node/node(), $ns, $pref) }            
 default return $node
};

declare function imp:get-local-copy($cbid as xs:string, $krid as xs:string){
let $doc := collection("/db/apps/tls-texts/test")//tei:TEI[@xml:id=$cbid]
, $targetcoll := xmldb:create-collection($config:tls-texts-root || "/KR", substring($krid, 1, 3) || "/" || substring($krid, 1, 4) )
, $docuri := document-uri(root($doc))
, $srccoll := util:collection-name($doc)
, $uri :=  xmldb:store($targetcoll, $krid || ".xml", $doc)
, $acl := (sm:chmod(xs:anyURI($uri), "rwxrwxr--"),
    sm:chgrp(xs:anyURI($uri), "tls-user"))

return $uri
};

declare function imp:update-metadata($doc as node(), $kid as xs:string, $title as xs:string){
let $newid := update replace $doc/tei:TEI/@xml:id with $kid
, $nt := <titleStmt xmlns="http://www.tei-c.org/ns/1.0">
			<title>{$title}</title>
{$doc//tei:titleStmt/tei:author, $doc//tei:titleStmt/tei:respStmt}
		</titleStmt>
, $body := $doc//tei:text/tei:body
, $dt := update replace $doc//tei:titleStmt with $nt
          
return 
()
};

declare function imp:do-conversion($cbid as xs:string){
let $krt := doc("/db/apps/tls-texts/test/krp-titles.xml")
, $kid := $krt//work[./altid = $cbid]/@krid
, $doc := doc(imp:get-local-copy($cbid, $kid))
, $h := imp:update-metadata($doc, $kid, $krt//work[@krid=$kid]/title/text())
, $pref := if (starts-with($kid, "KR6")) then $kid || "_CBETA_" else ()
, $bd := $doc//tei:text/tei:body
, $res := update replace $bd with imp:recursive-update-ns($bd, "http://www.tei-c.org/ns/1.0", $pref)
(:, $body := $doc//tei:text/tei:body
, $target-els := imp:get-target-elements($body):)
(:, $chars := $body =>normalize-space() => replace(' ', '') => string-length():)
(:, $conv := 
         for $p in $body//tei:p
         let $ln := local-name($p)
         return
         if ($ln = "p") then 
            let  $segs := imp:add-seg($p, $pref)
            , $res := 
             element {QName(namespace-uri($p), $ln)} {
             $p/@* ,
             $segs}
           return 
          update replace $p with $res
         else ()
:)
return ()
};


declare function imp:stub($node as node()){
() 
};
