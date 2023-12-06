xquery version "3.1";

(:~
 : Library module for handling translation files.
 :
 : @author Christian Wittern
 : @date 2023-10-23
 :)

module namespace ltr="http://hxwd.org/lib/translation";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace lv="http://hxwd.org/lib/vault" at "vault.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace lvs="http://hxwd.org/lib/visits" at "visits.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";

declare variable $ltr:translation-type-labels := map {
 "transl" : "Translation"
 , "notes" : "Research Notes"
 , "comment" : "Comments"
};

declare variable $ltr:tr-map-indices := map{
   "type-label" : 5
 , "lang-label" : 3
 , "name-label" : 2
 , "doc-node" :  1
};

declare function ltr:get-translation-file($trid as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
let $tru := collection($config:tls-user-root|| $user || "/translations")/tei:TEI[@xml:id=$trid]
, $trc := collection($config:tls-translation-root)//tei:TEI[@xml:id=$trid]
, $trfile := if ($tru) then $tru else $trc
return $trfile
};

(: 2023-05-27 - store changes to existing trans file if $trid is not "" :)
declare function ltr:update-translation-file($lang as xs:string, $txtid as xs:string, $translator as xs:string, $trtitle as xs:string, $bibl as xs:string, $vis as xs:string, $copy as xs:string, $type as xs:string, $rel-id as xs:string, $trid as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
let $tru := collection($config:tls-user-root|| $user || "/translations")/tei:TEI[@xml:id=$trid]
, $trc := collection($config:tls-translation-root)//tei:TEI[@xml:id=$trid]
, $trfile := if ($tru) then $tru else $trc
, $fullname := sm:id()//sm:real/sm:fullname/text()
, $buri := document-uri(root($trfile))
, $oldvis := if ($tru) then "option3" else "option1"
,$lg := $config:languages($lang)
,$title := lu:get-title($txtid)
,$trx := if (not($translator = "yy")) then $translator else if ($vis = "option3") then $fullname else "TLS Project"
, $titlestmt :=if ($type = "transl") then 
         <titleStmt xmlns="http://www.tei-c.org/ns/1.0">
            {if (string-length($trtitle) > 0) then 
            <title>{$trtitle}</title>
            else
            <title>Translation of {$title} into ({$lg})</title>}
            <editor role="translator">{$trx}</editor>
         </titleStmt>
            else if ($type = "notes") then
         <titleStmt xmlns="http://www.tei-c.org/ns/1.0">
            <title>Research Notes for {$title}</title>
            <editor role="creator">{$trx}</editor>
         </titleStmt>
            else
         <titleStmt xmlns="http://www.tei-c.org/ns/1.0">
            <title>Comments to {$title}</title>
            <editor role="creator">{$trx}</editor>
         </titleStmt>
, $pubstmt := <publicationStmt xmlns="http://www.tei-c.org/ns/1.0">
            <ab>published electronically as part of the TLS project at https://hxwd.org</ab>
            {if ($copy = "option1") then 
            <availability status="1"><ab>This work is in the public domain</ab></availability> 
            else 
             if ($copy = "option2") then
            <availability status="2"><ab>This work has been licensed for use in the TLS</ab></availability> 
            else 
             if ($copy = "option3") then
            <availability status="3">This work has not been licensed for use in the TLS</availability> 
            else
            <availability status="4">The copyright status of this work is unclear</availability> 
            }
         </publicationStmt>
, $srcdesc :=<sourceDesc xmlns="http://www.tei-c.org/ns/1.0">
            {if (not($bibl = "") or not ($trtitle = "")) then 
            <bibl><title>{$trtitle}</title>{$bibl}</bibl> else 
            <p>Created by members of the TLS project</p>}
            
            {if ($type="transl") then 
             <ab>Translation of <bibl corresp="#{$txtid}">
                  <title xml:lang="och">{$title}</title>
               </bibl> into <lang xml:lang="{$lang}">{$lg}</lang>.</ab>
             else 
             <p>Comments and notes to <bibl corresp="#{$txtid}">
                  <title xml:lang="och">{$title}</title>
               </bibl>{if (string-length($rel-id) > 0) then ("for translation ", <ref target="#{$rel-id}"></ref>) else ()}.</p>
             }
         </sourceDesc>
, $mod := <creation resp="#{$user}"  xmlns="http://www.tei-c.org/ns/1.0">Header modified: <date>{current-dateTime()}</date> by {$user}</creation>
, $doupd := (
    update replace $trfile//tei:titleStmt with $titlestmt,
    update replace $trfile//tei:publicationStmt with $pubstmt,
    update replace $trfile//tei:sourceDesc with $srcdesc,
    update insert $mod into $trfile//tei:profileDesc
    )
, $move := if ($vis = $oldvis) then () else
        let $resource := tokenize($buri, "/")[last()]
        let $src-coll := substring-before($buri,$resource)
        return
        if ($vis = "option3") then 
         let $trg-coll := $config:tls-user-root|| $user || "/translations"
         return
          xmldb:move($src-coll, $trg-coll, $resource) 
        else 
         let $trg-coll := $config:tls-translation-root || "/" || $lang
         return
          xmldb:move($src-coll, $trg-coll, $resource) 
return ($vis, $oldvis, $trid)
};

(: 2022-02-21 - moved this from tlsapi to allow non-api use :)
declare function ltr:store-new-translation($lang as xs:string, $txtid as xs:string, $translator as xs:string, $trtitle as xs:string, $bibl as xs:string, $vis as xs:string, $copy as xs:string, $type as xs:string, $rel-id as xs:string){
  let $user := sm:id()//sm:real/sm:username/text()
  ,$fullname := sm:id()//sm:real/sm:fullname/text()
  ,$uuid := util:uuid()
  (: 2022-02-21 new option4 == store a Research Note file in /notes/research/ :)
  ,$newid := if ($vis = "option4") then $txtid else $txtid || "-" || $lang || "-" || tokenize($uuid, "-")[1]
  ,$lg := $config:languages($lang)
  ,$title := lu:get-title($txtid)
  ,$txt := collection($config:tls-texts-root)//tei:TEI[@xml:id=$txtid]
   (: we don't want this to happen just when somebody visits a text :)
  ,$cat := if ($vis = "option4") then () else lmd:checkCat($txt,  "tr-" || $lang) 
  ,$trcoll := if ($vis="option3") then $config:tls-user-root || $user || "/translations" 
    else if ($vis = "option4") then $config:tls-data-root || "/notes/research" 
    else $config:tls-translation-root || "/" || $lang
  ,$trcollavailable := xmldb:collection-available($trcoll) or 
   (if ($vis="option3") then
    xmldb:create-collection($config:tls-user-root || $user, "translations")
   else
   (xmldb:create-collection($config:tls-translation-root, $lang),
    sm:chmod(xs:anyURI($trcoll), "rwxrwxr--"),
(:    sm:chown(xs:anyURI($trcoll), "tls"),:)
    sm:chgrp(xs:anyURI($trcoll), "tls-user")
    )
  )
  , $trx := if (not($translator = "yy")) then $translator else if ($vis = "option3") then $fullname else "TLS Project"
  , $doc := 
    doc(xmldb:store($trcoll, $newid || ".xml", 
   <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$newid}" type="{$type}">
  <teiHeader>
      <fileDesc>
            {if ($type = "transl") then 
         <titleStmt>
            {if (string-length($trtitle) > 0) then 
            <title>{$trtitle}</title>
            else
            <title>Translation of {$title} into ({$lg})</title>}
            <editor role="translator">{$trx}</editor>
         </titleStmt>
            else if ($type = "notes") then
         <titleStmt>
            <title>Research Notes for {$title}</title>
            <editor role="creator">{$trx}</editor>
         </titleStmt>
            else
         <titleStmt>
            <title>Comments to {$title}</title>
            <editor role="creator">{$trx}</editor>
         </titleStmt>
            }
         <publicationStmt>
            <ab>published electronically as part of the TLS project at https://hxwd.org</ab>
            {if ($copy = "option1") then 
            <availability status="1"><ab>This work is in the public domain</ab></availability> 
            else 
             if ($copy = "option2") then
            <availability status="2"><ab>This work has been licensed for use in the TLS</ab></availability> 
            else 
             if ($copy = "option3") then
            <availability status="3">This work has not been licensed for use in the TLS</availability> 
            else
            <availability status="4">The copyright status of this work is unclear</availability> 
            }
         </publicationStmt>
         <sourceDesc>
            {if (not($bibl = "") or not ($trtitle = "")) then 
            <bibl><title>{$trtitle}</title>{$bibl}</bibl> else 
            <p>Created by members of the TLS project</p>}
            
            {if ($type="transl") then 
             <ab>Translation of <bibl corresp="#{$txtid}">
                  <title xml:lang="och">{$title}</title>
               </bibl> into <lang xml:lang="{$lang}">{$lg}</lang>.</ab>
             else 
             <p>Comments and notes to <bibl corresp="#{$txtid}">
                  <title xml:lang="och">{$title}</title>
               </bibl>{if (string-length($rel-id) > 0) then ("for translation ", <ref target="#{$rel-id}"></ref>) else ()}.</p>
             }
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation resp="#{$user}">Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      {if ($type = "transl") then 
      <div><head>Translated parts</head><p xml:id="{$txtid}-start"></p></div>
      else 
      <div><head>Comments</head><p xml:id="{$txtid}-start"></p></div>
      }
      </body>
  </text>
</TEI>))
return
if (not($vis="option3")) then 
 let $uri := document-uri($doc)
 return
 (
    sm:chmod(xs:anyURI($uri), "rwxrwxr--"),
(:    sm:chown(xs:anyURI($uri), "tls"),:)
    sm:chgrp(xs:anyURI($uri), "tls-user")
 )
 else ()
};


declare function ltr:transinfo($trid){
let $user := sm:id()//sm:real/sm:username/text()
let $tru := collection($config:tls-user-root|| $user || "/translations")/tei:TEI[@xml:id=$trid]
, $trc := collection($config:tls-translation-root)//tei:TEI[@xml:id=$trid]
, $trfile := if ($tru) then $tru else $trc
, $segs := $trfile//tei:seg
, $trm := map:merge( for $s in $segs 
           let $resp := replace(normalize-space($s/@resp), "#", "")
           group by $resp
           return 
           map:entry($resp, count($s)))
, $trs := <ul>{for $k in map:keys($trm)         
           let $cnt := $trm?($k)
           order by $cnt descending
           return 
           <li><b class="ml-2">{tu:get-member-name($k)}</b> <span class="ml-2">{$cnt}</span></li>}</ul>
, $first := ltr:get-translation-seg-by-time($trid, true())           
, $last := ltr:get-translation-seg-by-time($trid, false())           
return
<div class="col">{(
  lrh:display-row(map{"col2" : "Title", "col3" : lmd:get-metadata($trfile, "title")})
  ,lrh:display-row(map{"col2" : "Who can see this?", "col3" : if ($tru) then "Visibily to current user only" else "Visible to TLS Project members"})
  ,lrh:display-row(map{"col2" : "Translated Lines", "col3" : count($segs)})
  ,lrh:display-row(map{"col2" : "Translators/Operators", 
                      "col2-tit" : "This shows the person responsible in the system, not necessarily the original translator", 
                      "col3" : $trs})
  ,lrh:display-row(map{"col2" : "Oldest line:", "col3" : <a href="textview.html?location={substring($first/@corresp, 2)}">{data($first/@modified)}</a>})
  ,lrh:display-row(map{"col2" : "Most recent line:", "col3" : <a href="textview.html?location={substring($last/@corresp, 2)}">{data($last/@modified)}</a>})
)}</div>
};

declare function ltr:format-translation-label($tr as map(*), $trid as xs:string){
 let $type := $tr($trid)[$ltr:tr-map-indices?type-label]
 let $tr-label := string-join(($type , " by " , 
                   $tr($trid)[$ltr:tr-map-indices?name-label],  " (" ,
                   $tr($trid)[$ltr:tr-map-indices?lang-label],  ")"))
 return 
 $tr-label
};
(:~
 Display a selection menu for translations and commentaries, given the current slot and type
  the value of map $tr is a sequence of five items : root-node of translation, label, language, license code, item type, formated for label
:)
declare function ltr:render-translation-submenu($textid as xs:string, $slot as xs:string, $trid as xs:string, $tr as map(*)){
 let $keys := for $k in map:keys($tr)
           let $item-type := $tr($k)[$ltr:tr-map-indices?type-label]
           , $date := lmd:get-metadata($tr($k)[$ltr:tr-map-indices?doc-node], "date")[1]
           order by $date ascending
           where not($k = ($trid, "content-id")) return $k
    ,$type := if ($trid and map:contains($tr, $trid)) then $tr($trid)[$ltr:tr-map-indices?type-label] else "Translation"       
 return
 <div id="translation-headerline-{$slot}" class="btn-group" role="group" >
  <button type="button" class="btn btn-secondary" onclick="goto_translation_seg('{$trid}', 'first')" title="Go to first translated line">←</button> 
   <div class="dropdown" id="{$slot}" data-trid="{$trid}">
            <button class="btn btn-secondary dropdown-toggle" type="button" id="ddm-{$slot}" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            {if ($tr($trid)[$ltr:tr-map-indices?type-label]) then ltr:format-translation-label($tr, $trid) else "No translation available"}
            </button>
    <div class="dropdown-menu" aria-labelledby="dropdownMenuButton">
        {  for $k at $i in $keys
            return 
         if ($k = "canvas") then 
        <a class="dropdown-item" id="sel{$slot}-{$i}" onclick="get_canvas_for_page('{$slot}', '{$k}')" href="#">Show Canvas</a>
         
        else
         if (starts-with($k, "facs")) then 
        <a class="dropdown-item" id="sel{$slot}-{$i}" onclick="get_facs_for_page('{$slot}', '{$tr($k)[1]}', '{$tr($k)[2]}', '{$tr($k)[3]}')" href="#">Facsimile {$config:wits?($tr($k)[2])}</a>
         
        else
         if ($tr($k)[$ltr:tr-map-indices?type-label] = "Comments") then 
        <a class="dropdown-item" id="sel{$slot}-{$i}" onclick="get_tr_for_page('{$slot}', '{$k}')" href="#">{$tr($k)[$ltr:tr-map-indices?type-label] || " " }  {$tr($k)[$ltr:tr-map-indices?lang-label]}</a>
        else
        <a class="dropdown-item" id="sel{$slot}-{$i}" onclick="get_tr_for_page('{$slot}', '{$k}')" href="#">{ltr:format-translation-label($tr, $k)}</a>
        }
        {if (lu:can-create-translation-file()) then
        <a class="dropdown-item" onclick="new_translation('{$slot}')" href="#"> <button class="btn btn-warning" type="button">New translation / comments</button></a> 
         else ()
        }
        {if (count($keys) = 0) then 
         if (count(map:keys($tr)) > 0) then  
        <a class="dropdown-item disabled" id="sel-no-trans" href="#">No other translation available</a>
        else 
        <a class="dropdown-item disabled" id="sel-no-trans" href="#">No translation available</a>
        else ()
        }
  </div>
  </div>
   <button type="button" class="btn btn-secondary" title="More information" onclick="show_dialog('tr-info-dialog', {{'slot': '{$slot}', 'trid' : '{$trid}'}})">
    <img class="icon"  src="resources/icons/octicons/svg/info.svg"/>
   </button>
   <button type="button" class="btn btn-secondary" onclick="goto_translation_seg('{$trid}', 'last')"  title="Go to last translated line">→</button>
</div>
};



declare function ltr:find-translators($textid as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
  (: this is trying to work around a bug in fn:collection 
  TODO: This fails if the user is guest.  Make a guest collection /db/users/guest? No, guest can't access the translation
  :)
  , $t1 := collection($config:tls-user-root || $user || "/translations")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator'] 
  , $t2 := collection($config:tls-translation-root)//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator']
  , $rn := collection($config:tls-data-root||"/notes/research")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator']
  , $t3 := if (exists($rn)) then $rn else 
  (: create research notes file if necessary :)
  let $tmp := ltr:store-new-translation("en", $textid, "TLS Project", "Research Notes", "", "option4", "option2", "notes", "") 
  return 
    collection($config:tls-data-root||"/notes/research")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator']   
  return ($t1, $t2, $t3)
};

declare function ltr:get-translation-type($ed as node()){
let $t := $ed/ancestor::tei:TEI
return 
  if ($t/@type) then 
    $ltr:translation-type-labels?($t/@type) 
  else 
   if ($ed[@role="translator"]) then 
     $ltr:translation-type-labels?("transl")
   else
     $ltr:translation-type-labels?("notes")
};
(:  returns a map with translations 
   key is xml:id of translation file
   value is a sequence of five items : root-node of translation, label, language, license code, item type, formated for label
:)

declare function ltr:get-translations($textid as xs:string){
let $translators := ltr:find-translators($textid) 
 let $tr := map:merge(
  for $ed in  $translators
   let $t := $ed/ancestor::tei:TEI
   , $tid := data($t/@xml:id)
   , $type := ltr:get-translation-type($ed)
   , $lg := if ($type = "Translation") then
       $t//tei:bibl[@corresp="#"||$textid]/following-sibling::tei:lang/text() 
       else  
       if ($t//tei:bibl[@corresp="#"||$textid]/following-sibling::tei:ref) then 
        let $rel-tr:= substring($t//tei:bibl[@corresp="#"||$textid]/following-sibling::tei:ref/@target, 2) 
        , $this-tr := $translators[ancestor::tei:TEI[@xml:id=$rel-tr]] 
       return
        "to transl. by " || $this-tr/text()
       else "" 
   , $date := lmd:get-metadata($t, "date")[1]
   , $lic := lmd:get-metadata($t, "status")
   , $resp := if ($ed/text()) then replace(($ed/text())[1]=>string-join(''), '\d{4}', '')=>normalize-space() else "anon"
   , $ddate := if ($date < "9999") then " ("||$date||") " else ""
   return
   map:entry($tid, ($t, $resp|| $ddate, if ($lg) then $lg else "en", if ($lic) then xs:int($lic) else 3, $type))   )
   return $tr
};
  
declare function ltr:get-tr-for-page($loc_in as xs:string, $prec as xs:int, $foll as xs:int, $slot as xs:string, $content-id as xs:string){
let $loc := replace($loc_in, "-swl", "")
, $textid := tokenize($loc, "_")[1]
, $cl := if ($slot = "slot1") then "-tr" else "-ex"
, $edtp := if (contains($content-id, "_")) then xs:boolean(1) else xs:boolean(0)
, $dseg := lu:get-targetsegs($loc, $prec, $foll)
, $ret :=  let $transl := ltr:get-translations($textid),
   $troot := $transl($content-id)[1] 
   return
   map:merge(for $seg in $dseg 
     let $tr := $troot//tei:seg[@corresp="#"||$seg/@xml:id]/text()
      return 
      map:entry("#"||data($seg/@xml:id)||$cl, $tr))
 return $ret
};
  
  
declare function ltr:get-translation-seg($transid as xs:string, $first as xs:boolean){
let $doc := ltr:get-translation-file($transid)
, $segs := $doc//tei:seg
, $firstseg := if ($first) 
               then subsequence(for $s in $segs
                let $id := tu:format-segid($s/@corresp)
                order by $id ascending
                return $s, 1, 1)
               else subsequence(for $s in $segs
                let $id := tu:format-segid($s/@corresp)
                order by $id descending
                return $s, 1, 1)
  return $firstseg
};

declare function ltr:get-translation-seg-by-time($transid as xs:string, $first as xs:boolean){
let $doc := ltr:get-translation-file($transid)
, $segs := $doc//tei:seg
, $firstseg := if ($first) 
               then subsequence(for $s in $segs
                let $id := xs:dateTime($s/@modified)
                order by $id ascending
                return $s, 1, 1)
               else subsequence(for $s in $segs
                let $id := xs:dateTime($s/@modified)
                order by $id descending
                return $s, 1, 1)
  return $firstseg
};

(: save :)

(:~
 : Save the translation (or comment)
 : 3/11: Get the file from the correct slot!
:)
declare function ltr:save-tr($trid as xs:string, $tr-to-save as xs:string, $lang as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
let $id := substring($trid, 1, string-length($trid) -3)
,$txtid := tokenize($id, "_")[1]
,$tr := ltr:get-translations($txtid)
,$slot := if (ends-with($trid, '-tr')) then 'slot1' else 'slot2'
,$content-id := lrh:get-content-id($txtid, $slot, $tr)
,$transl := $tr($content-id)[1]
,$seg := <seg xmlns="http://www.tei-c.org/ns/1.0" corresp="#{$id}" xml:lang="{$lang}" resp="#{$user}" modified="{current-dateTime()}">{$tr-to-save}</seg>
,$node := $transl//tei:seg[@corresp="#" || $id]
,$visit := lvs:record-visit(lu:get-seg($id))
return
if ($node) then (
 update insert attribute modified {current-dateTime()} into $node,
 update insert attribute resp-del {"#" || $user} into $node,
 update insert attribute src-id {$content-id} into $node,
 update insert $node into (lv:get-crypt-file("trans")//tei:div/tei:p[last()])[1],
(: The return values are wrong: update always returns the empty sequence :)
 if (update replace $node[1] with $seg) then () else "Success. Updated translation." 
)
else 
if ($transl//tei:p[@xml:id=concat($txtid, "-start")]) then 
  update insert $seg  into $transl//tei:p[@xml:id=concat($txtid, "-start")] 
else
if ($transl) then
 (: mostly for existing translations.  Here we simple append it to the very end. :)
 update insert $seg  into ($transl//tei:p[last()])[1]
else "Could not save translation.  Please create a translation file first."
};


declare function ltr:reload-selector($map as map(*)){
 let $group := sm:id()//sm:group
 let $slot := $map?slot
 ,$textid := tokenize($map?location, "_")[1]
 ,$tr := ltr:get-translations($textid)
 ,$s := if ("tls-test" = $group) then  session:set-attribute($textid || "-" || $slot, $map?content-id) else lus:settings-save-slot($slot,$textid, $map?content-id)
 return
 ltr:render-translation-submenu($textid, $slot, $map?content-id, $tr)
};


