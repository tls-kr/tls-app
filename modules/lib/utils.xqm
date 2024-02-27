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

