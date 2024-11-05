xquery version "3.1";
(:~
: This module provides the internal functions that do not directly control the 
: template driven Web presentation
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace lu="http://hxwd.org/lib/utils";

import module namespace config="http://hxwd.org/config" at "../config.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";

(: gradient of colors, colors are given as rgb sequences in dec :)

declare function lu:get-gradient($start-color, $end-color, $max, $count){
  let $m := $count div $max
  return
  if ($m > 0.5) then
   (61, 99, 127)
   else if ($m > 0.2) then
   (197, 200, 127)
   else if ($m > 0.1) then
   (172, 228, 127)
(:  for $i in (1, 2, 3)   return string(($count div $max)  * $start-color[$i] + (1 - ($count div $max)  * $end-color[$i])):)
  else (255,255,255) 
};

(:~
: check if a string consists completely of kanji
: @param $string  a string to be tested
:)

declare function lu:iskanji($string as xs:string) as xs:boolean {
let $kanji := '&#x3400;-&#x4DFF;&#x4e00;-&#x9FFF;&#xF900;-&#xFAFF;&#xFE30;-&#xFE4F;&#x00020000;-&#x0002A6DF;&#x0002A700;-&#x0002B73F;&#x0002B740;-&#x0002B81F;&#x0002B820;-&#x0002F7FF;',
$pua := '&#xE000;-&#xF8FF;&#x000F0000;-&#x000FFFFD;&#x00100000;-&#x0010FFFD;'
return 
matches(replace($string, '\s', ''), concat("^[", $kanji, $pua, "]+$" ))
};

(: check if most characters are kanji :)
declare function lu:mostly-kanji($string as xs:string) as xs:boolean {
if (string-length($string) > 0) then
let $q := sum(for $s in string-to-codepoints($string)
    return
    if ($s > 500) then 1 else 0 )
return
if ($q div string-length($string) > 0.5) then xs:boolean("1") else xs:boolean(0)
else xs:boolean(0)
};

declare function lu:capitalize-first ( $arg as xs:string? )  as xs:string? {
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
 } ;




(:~
: Lookup the title for a given textid
: @param $txtid
:)
declare function lu:get-title($txtid as xs:string?){
let $title := string-join(collection($config:tls-texts-root) //tei:TEI[@xml:id=$txtid]//tei:titleStmt/tei:title/text(), "・")
return $title
};

(:~
: Get the document for a given textid
: @param $txtid
:)
declare function lu:get-doc($txtid as xs:string){
collection($config:tls-texts-root)//tei:TEI[@xml:id=$txtid]
};

declare function lu:get-seg($sid as xs:string){
collection($config:tls-texts-root)//tei:seg[@xml:id=$sid]
};

declare function lu:next-n-segs($startseg as xs:string, $n as xs:int?){
let $targetseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$startseg]
return
if ($n < 0) then
$targetseg/preceding::tei:seg[fn:position() <= abs($n)]
else if ($n > 1) then
$targetseg/following::tei:seg[fn:position() <= $n]
else ()
};


declare function lu:can-create-translation-file(){
"tls-user" = sm:id()//sm:group
};

(:~
: This is called when a term is selected in the textview // get_sw in tls-app.js
:)

declare function lu:get-targetsegs($loc as xs:string, $prec as xs:int, $foll as xs:int){
    let $targetseg := if (contains($loc, '_')) then
       collection($config:tls-texts-root)//tei:seg[@xml:id=$loc]
     else
      let $firstdiv := (collection($config:tls-texts-root)//tei:TEI[@xml:id=$loc]//tei:body/tei:div)[1]
      return if ($firstdiv//tei:seg) then ($firstdiv//tei:seg)[1] else  ($firstdiv/following::tei:seg)[1] 

    let $fseg := if ($foll > 0) then $targetseg/following::tei:seg[fn:position() < $foll] 
        else (),
      $pseg := if ($prec > 0) then $targetseg/preceding::tei:seg[fn:position() < $prec] 
        else (),
      $dseg := ($pseg, $targetseg, $fseg)
return $dseg
};

declare function lu:get-seg-sequence-by-id($start-seg-id, $end-seg-id){
let $coll := collection($config:tls-texts-root)
let $start-seg := $coll//tei:seg[@xml:id = $start-seg-id]
, $end-seg := $coll//tei:seg[@xml:id = $end-seg-id]
return
 ($start-seg , $start-seg/following::tei:seg intersect $end-seg/preceding::tei:seg , $end-seg)
};

declare function lu:session-att($name, $default){
   if (contains(session:get-attribute-names(),$name)) then 
    session:get-attribute($name) else 
    (session:set-attribute($name, $default), $default)
};


(: 
xquery version "3.1";

let $start-time := util:system-time()
let $query-needing-measurement := (: insert query or function call here :)
let $end-time := util:system-time()
let $duration := $end-time - $start-time
let $seconds := $duration div xs:dayTimeDuration("PT1S")
return
    "Query completed in " || $seconds || "s."
:)

