xquery version "3.1";
(:~
: This module provides the functions that are called through javascript
: from the webpages to provide interactive functionality
: of the TLS. 

: In most cases, a stub of the same name as the function exists in the /api
: directory, this collects the parameters and calls the corresponding function 
: here
: 
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)
module namespace tlsapi="http://hxwd.org/tlsapi"; 

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
import module namespace functx="http://www.functx.com" at "../modules/functx.xql";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace dialogs="http://hxwd.org/dialogs" at "../modules/dialogs.xql"; 
import module namespace krx="http://hxwd.org/krx-utils" at "../modules/krx-utils.xql";
import module namespace xed="http://hxwd.org/xml-edit" at "../modules/xml-edit.xql";
import module namespace imp="http://hxwd.org/xml-import" at "../modules/import.xql"; 
import module namespace wd="http://hxwd.org/wikidata" at "../modules/wikidata.xql"; 
import module namespace src="http://hxwd.org/search" at "../modules/search.xql";

import module namespace lmd="http://hxwd.org/lib/metadata" at "../modules/lib/metadata.xqm";
import module namespace ltr="http://hxwd.org/lib/translation" at "../modules/lib/translation.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "../modules/lib/utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "../modules/lib/render-html.xqm";
import module namespace lv="http://hxwd.org/lib/vault" at "vault.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "../modules/lib/permissions.xqm";
import module namespace ltp="http://hxwd.org/lib/textpanel" at "../modules/lib/textpanel.xqm";
import module namespace lsf="http://hxwd.org/lib/syn-func" at "../modules/lib/syn-func.xqm";
import module namespace lw="http://hxwd.org/word" at "../modules/lib/word.xqm";
import module namespace ltx="http://hxwd.org/taxonomy" at "../modules/lib/taxonomy.xqm";

import module namespace remote="http://hxwd.org/remote" at "../modules/lib/remote.xqm";


declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";
declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace fn="http://www.w3.org/2005/xpath-functions";

(:~
Data for the callback function used for autocompletion
 @param $type is the type, which directly translates to the division type of the data
 @param $term is the term for which we look for autocomplete possibilities 
:)
declare function tlsapi:autocomplete($type as xs:string, $term as xs:string){
let $callback := request:get-parameter("callback", "xx")
let $payload := 
  for $t in collection($config:tls-data-root)//tei:div[@type=$type]/tei:head
  where contains($t/text(), $term)
  order by string-length($t/text()) ascending
  return
  concat('{"id": "', $t/ancestor::tei:div[1]/@xml:id, '", "label": "', $t/text(), '"}')
return 
concat($callback, "([", string-join($payload, ","), "]);")
};

(:~
 assemble a new attribution out of the information given.
 called from the save-swl-* functions.
:)

declare function tlsapi:make-attribution($line-id as xs:string, $line as xs:string, $sense-id as xs:string, 
 $user as xs:string, $currentword as xs:string, $pos as xs:string, $tit as xs:string) as element(){
let $textid := tokenize($line-id, "_")[1],
(: we generally use the translation from slot1 :)
$trm := ltr:get-translations($textid),
$trid := lrh:get-content-id($textid, 'slot1', $trm),
$tr-in := $trm($trid)[1]//tei:seg[@corresp='#' || $line-id]
, $tr :=  if (string-length($tr-in) > 0) then $tr-in else (collection($config:tls-translation-root)//tei:seg[@corresp="#" || $line-id])[1]
, $tr-resp := lmd:get-metadata($tr, "resp"),
$title-en := lmd:get-metadata($tr, "title"),
(: $line := collection($config:tls-texts-root)//tei:seg[@xml:id=$line-id],:)
(: 2024-10-31 might have to rethink this: we are now getting all titles from the catalog, not from the text header. :)
$title := lmd:get-metadata-from-catalog($line-id, "title"),
$sense := collection($config:tls-data-root)//tei:sense[@xml:id=$sense-id],
$concept := $sense/ancestor::tei:div/tei:head/text(),
$concept-id := $sense/ancestor::tei:div/@xml:id, 
$wordtmp := $sense/parent::tei:entry/tei:form/tei:orth/text(),
(:$word := string-join(if (count($wordtmp) = 1) then $wordtmp else 
        for $w in $wordtmp
         return if (contains($line, $w)) then $w else "", ""),:)
$word := $wordtmp[1],
$uuid := concat("uuid-", util:uuid()),
$newswl :=
<tls:ann xmlns="http://www.tei-c.org/ns/1.0" concept="{$concept}" concept-id="{$concept-id}" xml:id="{$uuid}">
<link target="#{$line-id} #{$sense-id}"/>
<tls:text>
<tls:srcline title="{$tit}" target="#{$line-id}" pos="{$pos}">{$line}</tls:srcline>
<tls:line title="{$title-en}" transl-id="{$trid}" src="{$tr-resp}">{$tr/text()}</tls:line>
</tls:text>
<form  corresp="{$sense/parent::tei:entry/tei:form/@corresp}" orig="{$currentword}">
{$sense/parent::tei:entry/tei:form/tei:orth,
$sense/parent::tei:entry/tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]}
</form>
<sense corresp="#{$sense-id}">
{$sense/*}
</sense>
<tls:metadata resp="#{$user}" created="{current-dateTime()}">
<respStmt>
<resp>added</resp>
<name notBefore ="{current-dateTime()}">{$user}</name>
</respStmt>
</tls:metadata>
</tls:ann>
return
$newswl
};

(: instead of using a uuid-named file hierarchy, this version uses one file per text to store the annotations :)
declare function tlsapi:save-swl-to-docs($line-id as xs:string, $line as xs:string, $sense-id as xs:string, 
$user as xs:string, $currentword as xs:string, $pos as xs:string, $tit as xs:string) {
let $targetcoll := if (xmldb:collection-available($config:tls-data-root || "/notes/doc")) then $config:tls-data-root || "/notes/doc" else 
    concat($config:tls-data-root || "/notes", xmldb:create-collection($config:tls-data-root || "/notes", "doc"))
,$textid := tokenize($line-id, "_")[1]
,$seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$line-id]
return
if ($seg/@state='locked') then "Line is locked.  Please add punctuation before attempting to attribute."
else (
let $docname :=  $textid || "-ann.xml"
 ,$cat := try{lmd:checkCat($seg,  "swl")} catch * {()} 
,$newswl:=tlsapi:make-attribution($line-id, $line, $sense-id, $user, $currentword, $pos, $tit)
,$targetdoc :=   if (doc-available(concat($targetcoll,"/",$docname))) then
                    doc(concat($targetcoll,"/", $docname)) else 
                    (
   doc(xmldb:store($targetcoll, $docname, 
  element {QName(xs:anyURI("http://www.tei-c.org/ns/1.0"), "TEI")}
  { 
  attribute xml:id {$textid||"-ann"},
  if (not($seg)) then attribute type {"remote"} else (), 
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Annotations for {string($newswl//tls:srcline/@title)}</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>,
  <text>
      <body>
      <div><head>Annotations</head><p xml:id="{$textid}-start"></p></div>
      </body>
  </text>
  }))
 ,sm:chmod(xs:anyURI($targetcoll || "/" || $docname), "rwxrwxr--")
)

let $targetnode := collection($targetcoll)//tei:seg[@xml:id=$line-id]
,$texturi := if (starts-with($textid, "CH")) then 
                xs:anyURI($config:tls-texts-root || "/chant/" || substring($textid, 1, 3) || "/" || $textid || ".xml") else ()

return 
if (sm:has-access($targetcoll, "w")) then
(
if ($targetnode) then 
 update insert $newswl into $targetnode
else

 update insert <seg  xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$line-id}"><line>{$newswl//tls:srcline/text()}</line>{$newswl}</seg> into 
 $targetdoc//tei:p[@xml:id=concat($textid, "-start")]
 
(: ,data($newswl/@xml:id):)
 ,sm:chmod(xs:anyURI($targetcoll || "/" || $docname), "rwxrwxr--")
 (: for the CHANT files: grant access when attribution is made :)
 ,if ($texturi) then sm:chmod($texturi, "rwxrwxr--") else ()
 , "Attribution has been saved. Thank you for your contribution."
 )
 else "No access"
 )
};

(: this version saves to the text as anchor node :)

declare function tlsapi:save-swl-to-text($line-id as xs:string, $sense-id as xs:string, 
$user as xs:string, $currentword as xs:string, $pos as xs:string) {
let $targetnode := collection($config:tls-texts-root)//tei:seg[@xml:id=$line-id]
,$textid := tokenize($line-id, "_")[1]
,$ipos := xs:int($pos)

return ()
};

declare function tlsapi:save-swl-with-path($line-id as xs:string, $line as xs:string, $sense-id as xs:string, 
$notes-path as xs:string, $user as xs:string, $currentword as xs:string, $pos as xs:string ){

if (($line-id != "xx") and ($sense-id != "xx")) then
let $newswl:=tlsapi:make-attribution($line-id, $line, $sense-id, $user, $currentword, $pos, "")
,$uuid := $newswl/tls:ann/@xml:id
,$path := concat($notes-path, substring($uuid, 6, 2))
return (
if (xmldb:collection-available($path)) then () else
(xmldb:create-collection($notes-path, substring($uuid, 6, 2)),
(:sm:chown(xs:anyURI($path), $user),:)
sm:chgrp(xs:anyURI($path), "tls-user"),
sm:chmod(xs:anyURI($path), "rwxrwxr--")
),
let $res := (xmldb:store($path, concat($uuid, ".xml"), $newswl)) 
return
if ($res) then (
(:sm:chown(xs:anyURI($res), $user),:)
sm:chgrp(xs:anyURI($res), "tls-editor"),
sm:chmod(xs:anyURI($res), "rwxrwxr--"),
"OK")
else
"Some error occurred, could not save resource")
else
"Wrong parameters received"
};


declare function tlsapi:save-swl($line-id as xs:string, $line as xs:string, $sense-id as xs:string, $pos as xs:string, $tit as xs:string){
let $notes-path := concat($config:tls-data-root, "/notes/new/")
let $user := sm:id()//sm:real/sm:username/text()
let $currentword := ""
, $return :=
(:tlsapi:save-swl-with-path($line-id, $sense-id, $notes-path, $user, $currentword):)
tlsapi:save-swl-to-docs($line-id, $line, $sense-id, $user, $currentword, $pos, $tit)
(: update the swl count on this sense/word :)
, $s := collection($config:tls-data-word-root)//tei:sense[@xml:id = $sense-id]
, $update := lw:update-sense-id-ann-count($sense-id, 1)
return $return

};

(: so this is now the xquery that displays the dialog for 
 - new concept for character:  type=concept
 - new word within concept for character: type=word
 - revision of existing swl:  type=swl
 the available information differs slightly, this will collected into a map and sent over to tlsapi
 
 the name is now slightly misleading, but I'll keep it for now:-)
 
:)
declare function tlsapi:get-swl($rpara as map(*)){

let $swl:= if ($rpara?uuid = "xx") then <empty/> else collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$rpara?uuid]
,$concept-defined := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id=$rpara?concept-id]
,
$para := map{
"char" : if ($rpara?word = "xx") then $swl//tei:form/tei:orth/text() else $rpara?word,
"line-id" : if ($rpara?line-id = "xx") then tokenize(substring($swl//tei:link/@target, 2), " #")[1] else $rpara?line-id,
"line" : if ($rpara?line = "xx") then $swl//tls:srcline/text() else $rpara?line,
"concept" : if ($rpara?concept = "xx") then
  if (not(empty($concept-defined))) then $concept-defined/tei:head/text() else 
  data($swl/@concept) else $rpara?concept,
"concept-id" : if ($rpara?concept-id = "xx") then data($swl/@xml:id) else $rpara?concept-id,
"synfunc-id" : data($swl//tls:syn-func/@corresp)=>substring(2),
"synfunc" : data($swl//tei:sense/tei:gramGrp/tls:syn-func/text()),
"semfeat-id" : data($swl//tls:sem-feat/@corresp)=>substring(2),
"semfeat" : data($swl//tei:sense/tei:gramGrp/tls:sem-feat/text()),
"pinyin" : if ($rpara?py = "xx") then $swl/tei:form/tei:pron[@xml:lang="zh-Latn-x-pinyin"]/text() else $rpara?py,
"def" : data($swl//tei:sense/tei:def/text()),
"wid" : $rpara?wid,
"title" : if ($rpara?type = "concept") then "" else 
          if ($rpara?type = "swl") then "Editing Attribution for" else
          ""
}
return
if ($concept-defined or $rpara?mode="existing") then 
 tlsapi:swl-dialog($para, $rpara?type)
else
 (: TODO: first check if concept exists, maybe with another name? --> labels :)
 dialogs:new-concept-dialog($para)
};

declare function tlsapi:swl-dialog($para as map(), $type as xs:string){

<div id="editSWLDialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                {if ($type = "concept" or string-length($para?pinyin) = 0) then
                <h5 class="modal-title">{$para?title} <strong class="ml-2"><span id="{$type}-query-span">{$para?char}</span></strong>
                    <button class="btn badge badge-primary ml-2" type="button" onclick="get_guangyun()">
                        廣韻
                    </button>
                </h5>
                else if ($type = "swl") then
                <h5 class="modal-title">{$para?title} <strong class="ml-2"><span id="{$type}-query-span">{$para?char}</span></strong>
                </h5>
                else
                <h5 class="modal-title">Adding SW for {$para?char} to concept <strong class="ml-2"><span id="newsw-concept-span">{$para?concept}</span></strong></h5>
                }
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">
                    ×
                </button>
            </div>
            <div class="modal-body">
                {if ($type = ("concept", "swl", "word")) then
                (<h6 class="text-muted">At:  <span id="concept-line-id-span" class="ml-2">{$para?line-id}</span></h6>,
                <h6 class="text-muted">Line: <span id="concept-line-text-span" class="ml-2">{$para?line}</span></h6>
                ) else () }
                <div>
                    <span id="concept-id-span" style="display:none;">{$para?concept-id}</span>
                   {if ($type = ("word")) then (
                    <span id="word-id-span" style="display:none;">{$para?wid}</span>,
                    <span id="py-span" style="display:none;">{$para?pinyin}</span>)
                    else ()
                    }
                    <span id="synfunc-id-span" style="display:none;">{$para?synfunc-id}</span>
                    <span id="semfeat-id-span" style="display:none;">{$para?semfeat-id}</span>
                    
                </div>
                   {if ($type = "concept"  or string-length($para?pinyin) = 0) then 
                <div class="form-group" id="guangyun-group">                
                    <span class="text-muted" id="guangyun-group-pl"> Press the 廣韻 button above and select the pronounciation</span>
                </div> else if ($type = "swl") then
                <div class="form-group" id="guangyun-group">     
                   {tlslib:get-guangyun($para?char, $para?pinyin, true())}
                </div>
                else (),
                if ($type = ("concept", "swl")) then
                <div id="select-concept-group" class="form-group ui-widget">
                    <label for="select-concept">Concept: </label>
                    <input id="select-concept" class="form-control" required="true" value="{$para?concept}"/>
                </div>
                    else ()}                
                <div class="form-row">
                <div id="select-synfunc-group" class="form-group ui-widget col-md-6">
                    <label for="select-synfunc">Syntactic function: </label>
                    <input id="select-synfunc" class="form-control" required="true" value="{$para?synfunc}"/>
                </div>
                <div id="select-semfeat-group" class="form-group ui-widget col-md-6">
                    <label for="select-semfeat">Semantic feature: </label>
                    <input id="select-semfeat" class="form-control" value="{$para?semfeat}"/>
                </div>
                </div>
                <div id="input-def-group">
                    <label for="input-def">Definition </label>
                    <textarea id="input-def" class="form-control">{$para?def}</textarea>                   
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                   {if ($type = "concept" or string-length($para?pinyin) = 0) then 
                <button type="button" class="btn btn-primary" onclick="save_to_concept()">Save changes</button>
                else if ($type = "swl") then
                <button type="button" class="btn btn-primary" onclick="save_swl()">Save SWL</button>
                else                
                <button type="button" class="btn btn-primary" onclick="save_newsw()">Save SW</button>
                }
            </div>
        </div>
    </div>    
    <!-- temp -->
    
</div>    
};

(:~
: Called from tlsapi:swl-dialog to fill in the guangyun pronounciation, returns 
: input fields for form
:)

(: prepare the parameters for edit-sf-dialog :)
declare function tlsapi:get-sf($senseid as xs:string, $type as xs:string){
let $sense := collection($config:tls-data-root)//tei:sense[@xml:id=$senseid]
,$synfunc-id := if ($type = 'syn-func') then data($sense/tei:gramGrp/tls:syn-func/@corresp)=>substring(2) 
   else data($sense/tei:gramGrp/tls:sem-feat/@corresp)=>substring(2)
,$sfdef := lsf:get-sf-def($synfunc-id, $type)
,$para := map{
"def" : $sense/tei:def/text(),
"type" : $type,
"synfunc" : if ($type = 'syn-func') then data($sense/tei:gramGrp/tls:syn-func/text()) else data($sense/tei:gramGrp/tls:sem-feat/text()),  
"synfunc-id" : $synfunc-id,
"zi" : $sense/parent::tei:entry/tei:form/tei:orth[1]/text(),
"pinyin" : $sense/parent::tei:entry/tei:form/tei:pron[@xml:lang="zh-Latn-x-pinyin"]/text(),
"sense-id" : $senseid,
"sfdef" : $sfdef
}
return tlsapi:edit-sf-dialog($para)
(:return $para:)
};

(: 2019-12-01: the following is a stub for changing the sf of a swl. If not existing, it has to be created, including def :)
declare function tlsapi:edit-sf-dialog($para as map()){
let $label := if ($para?type='syn-func') then 'syntactic function' else 'semantic feature'
return
<div id="edit-sf-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Change <span class="">{$label}</span> for <span>{$para?zi}&#160;({$para?pinyin})</span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    ×
                </button>
            </div>
            <div class="modal-body"> 
                <h6 class="text-muted">Sense:  <span id="def-span" class="ml-2">{$para?def}</span></h6>
                <h6 class="text-muted">Current value:  <span id="old-sf-span" class="ml-2">{$para?synfunc}</span></h6>
                <h6 class="text-muted">Current definition:  <span id="def-old-sf-span" class="ml-2">{$para?sfdef}</span></h6>
            <div>
            <span id="sense-id-span" style="display:none;">{$para?sense-id}</span>
            <span id="synfunc-id-span" style="display:none;">{$para?synfunc-id}</span>
                <div class="form-row">
                <div id="select-synfunc-group" class="form-group ui-widget col-md-6">
                    <label for="select-synfunc">New {$label}: </label>
                    <input id="select-synfunc" class="form-control" required="true" value="{$para?synfunc}"></input>
                </div>
                <!--
                <div id="select-semfeat-group" class="form-group ui-widget col-md-6">
                    <label for="select-semfeat">Semantic feature: </label>
                    <input id="select-semfeat" class="form-control" value="{$para?semfeat}"/>
                </div> -->
                </div>
                <div id="input-def-group">
                    <label for="input-def">Definition (if creating new item)</label>
                    <textarea id="input-def" class="form-control"></textarea>                   
                </div>
            </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                <button type="button" class="btn btn-primary" onclick="save_sf('{$para?type}')">Save</button>
          </div>
       
       </div>
       </div>   
</div>
};


(: retrieve the corresponding segs for other editions :)
declare function local:get-krxsegs($loc as xs:string, $content-id as xs:string, $dseg as node()*){
for $seg in $dseg
   return
   map:merge(for $seg in $dseg 
     let $tr := krx:get-varseg-ed($loc, $content-id)
      return 
      map:entry("#"||data($seg/@xml:id)||$cl, $tr))
};


(: this is abandoned as of 2021-10-12, we loop through the swl class on a page instead, see show_swl_for_line :)
declare function tlsapi:get-swl-for-page($loc as xs:string, $prec as xs:int, $foll as xs:int){
  let $dseg := lu:get-targetsegs($loc, $prec, $foll)
   for $d in $dseg
   let $link := "#" || data($d/@xml:id)
return

for $swl in collection($config:tls-data-root|| "/notes")//tls:srcline[@target=$link]
let $pos := if (string-length($swl/@pos) > 0) then xs:int(tokenize($swl/@pos)[1]) else 0
order by $pos
return
("{'id': '" || data($d/@xml:id)||"','html':'" , lrh:format-swl($swl/ancestor::tls:ann, map{'type' : 'row'}) , "'}")
};


(: Save a new SW to an existing concept.   UPDATE: word is also created if ncessessary :) 
declare function tlsapi:save-newsw($rpara as map(*)) {
 let $user := sm:id()//sm:real/sm:username/text()
 let $concept-word := collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]//tei:entry[@xml:id=$rpara?wuid],
 $concept-doc := if ($concept-word) then $concept-word else collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]//tei:div[@type="words"],
 $wuid := if ($concept-word) then $rpara?wuid else "uuid-" || util:uuid(),
 $semfeat-id := if ($rpara?semfeat = "xx" or $rpara?semfeat = "") then 
 (
  if (collection($config:tls-data-root)//tei:div[@type="sem-feat"]/tei:head[.=normalize-space($rpara?semfeat-val)]) then
  data(collection($config:tls-data-root)//tei:div[@type="sem-feat"]/tei:head[.=normalize-space($rpara?semfeat-val)]/@xml:id)
  else
  tlslib:new-syn-func($rpara?semfeat-val, "", "sem-feat")
) 
 else $rpara?semfeat,


 $suid := concat("uuid-", util:uuid()),
 $newsense := 
<sense xml:id="{$suid}" resp="#{$user}" tls:created="{current-dateTime()}" xmlns="http://www.tei-c.org/ns/1.0" 
xmlns:tls="http://hxwd.org/ns/1.0">
<gramGrp><pos>{upper-case(substring($rpara?synfunc-val, 1,1))}</pos>
  <tls:syn-func corresp="#{$rpara?synfunc}">{translate($rpara?synfunc-val, ' ', '+')}</tls:syn-func>
  {if (string-length($rpara?semfeat-val) > 0 ) then 
  <tls:sem-feat corresp="#{$semfeat-id}">{$rpara?semfeat-val}</tls:sem-feat>
  else ()}
  </gramGrp>
  <def>{$rpara?def}</def></sense>,
 $newnode := if ($concept-word) then $newsense else
 <entry type="word" xml:id="{$wuid}" xmlns="http://www.tei-c.org/ns/1.0" >
  <form><orth>{$rpara?word}</orth>
  <pron xml:lang="zh-Latn-x-pinyin">{$rpara?py}</pron>
  </form>
  <def></def>
  {$newsense}
 </entry>
return
(: this is a hack, validation needs to be properly done on the form before posting :)
if (string-length($rpara?synfunc-val) = 0) then
<response>
<user>{$user}</user>
<sense_id>not_saved</sense_id>
<result>No syntactic function given</result>
</response>
else
<response>
<user>{$user}</user>
<result>{update insert $newnode into $concept-doc}</result>
<sense_id>{$suid}</sense_id>
</response>

};

(: todo actually delete the form :)
declare function tlsapi:delete-zi-from-word($rpara as map(*)){
(: &wid="+wid+"&pos="+pos+"&char="+ch, "html",  :)
let $pos := xs:int($rpara?pos)
let $orth := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:entry[@xml:id=$rpara?wid]/tei:form[$pos]/tei:orth[.=$rpara?char]
, $form := $orth/ancestor::tei:form
return
(update delete $form, "OK")
};

declare function tlsapi:update-pinyin($rpara as map(*)) {
(: important: the existing char(s) is in $rpara?char, the new one in $rpara?zi:)
let $wid := $rpara?wid
, $zi := $rpara?zi
 (: check if we got the count right :)
, $gc := for $gid in tokenize(normalize-space($rpara?guangyun-id), "xxx")
     let $nid := if (contains($gid, ":")) then 
                  let $t := tokenize($gid, ":")[2] 
                   return 
                    if (string-length($t) > 0 and string-length($rpara?gloss)) then 
                     tlslib:save-new-syllable(map{"char" : tokenize($gid, ":")[1], "jin" : $t, "note": $rpara?notes, "sources" : $rpara?sources, "gloss" : $rpara?gloss})
                    else ()
                 else $gid 
    return $nid
return
if (starts-with($wid, "uuid")) then
  (: we have no gloss, but we are adding a new pronounciation--error :)
  if (string-length($rpara?gloss) = 0 and not(ends-with($rpara?guangyun-id, ":")))  then
   "Please give a gloss for this reading."
   else

  if (count($gc) = string-length($zi)) then
    let $word := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:entry[@xml:id=$wid]
    , $oldform := $word/tei:form[tei:orth[. = $rpara?char]]
    , $newform := tlslib:make-form(string-join($gc, "xxx"), $zi)
    , $save := if ($oldform) then (update replace $oldform with $newform) else ()
    return
   "OK" || $newform//tei:pron[@xml:lang="zh-Latn-x-pinyin"]/text()
  else
   "Number of pinyin definitions not correct." || count($gc) || " - " || string-length($zi)
else
"Concept not found"
};

declare function tlsapi:update-gloss($rpara as map(*)) {
let $uuid := $rpara?uuid
, $gloss := $rpara?gloss
return 
if (string-length($gloss) = 0) then
 "No gloss given"
else
 let $node := collection($config:tls-data-root||"/guangyun")//tx:guangyun-entry[@xml:id=$uuid]
 ,$gn := <gloss xmlns="http://exist-db.org/tls">{$gloss}</gloss>
 return
 if (empty($node)) then
   "Entry not found"
 else 
   (
   update replace $node/tx:gloss with $gn,
   "OK" || $gloss
   )
};
(: save the new syn, called from save_syn // if the crit exists, we will replace it :)
declare function tlsapi:save-syn($rpara as map(*)) {
let $user := sm:id()//sm:real/sm:username/text()
, $concept-doc := collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]
, $crit := $concept-doc//tei:div[@type='old-chinese-criteria']
, $notes := $concept-doc//tei:div[@type='notes']
, $new := <div xmlns="http://www.tei-c.org/ns/1.0" type="old-chinese-criteria" resp="#{$user}" tls:created="{current-dateTime()}">{for $p in  tokenize($rpara?crit, '\n') return <p>{$p}</p>}</div>
return 
if (string-length($crit)>0) then 
 update replace $crit with $new
else 
 (
 update insert $new into $notes,
 "OK" || $new
 )
};

declare function tlsapi:save-to-concept($rpara as map(*)) {

let $user := sm:id()//sm:real/sm:username/text()
let $form := tlslib:make-form($rpara?guangyun-id, $rpara?word),
 
 $concept-doc := collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]//tei:div[@type="words"],
 $wuid := concat("uuid-", util:uuid()),
 $suid := concat("uuid-", util:uuid()),
 $newnode :=
<entry xmlns="http://www.tei-c.org/ns/1.0" 
xmlns:tls="http://hxwd.org/ns/1.0"
type="word" xml:id="{$wuid}" resp="#{$user}" tls:created="{current-dateTime()}">
{$form}
<sense xml:id="{$suid}" resp="#{$user}" tls:created="{current-dateTime()}">
<gramGrp><pos>{upper-case(substring($rpara?synfunc-val, 1,1))}</pos>
  <tls:syn-func corresp="#{$rpara?synfunc}">{$rpara?synfunc-val}</tls:syn-func>
  {if ($rpara?semfeat) then 
  <tls:sem-feat corresp="#{$rpara?semfeat}">{$rpara?semfeat-val}</tls:sem-feat>
  else ()}
  </gramGrp>
  <def>{$rpara?def}</def></sense>
</entry>
return
<response>
<user>{$user}</user>
<result>{update insert $newnode into $concept-doc}</result>
<sense_id>{$suid}</sense_id>
</response>

};

declare function tlsapi:show-att($uid as xs:string){
let $key := "#" || $uid
let $atts := collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = $key]
return
if (count($atts) > 0) then
 for $a in $atts return 
 let $when := data($a/tls:text/@tls:when)
 order by $when descending
 return 
 lrh:show-att-display($a)
else 
 <p class="font-weight-bold">No attributions found</p>
};

(:~
 Increase rating of a syntactic word location.  We return the line-id, so that we can display the updated attributions.
 params: type = type of thing to rate (eg swl), uid = uid of thing
 @score is the community approval of the correctness of this attribution
 @rating is the importance as a paradigmatic example
:)
declare function tlsapi:incr-rating($map as map(*)) {
let  $user := sm:id()//sm:real/sm:username/text()
, $action := 'incr-rating'
, $comment := ''
return
if ($map?type eq 'swl') then 
 let $swl := collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$map?uid]
,  $rating := if ($swl/tls:metadata/@rating) then xs:int($swl/tls:metadata/@rating) else 0
, $link := substring(tokenize($swl/tei:link/@target)[1], 2)
, $node := <respStmt xmlns="http://www.tei-c.org/ns/1.0">
 <name>{$user}</name>
 <resp notBefore="{current-dateTime()}">{$action}</resp>
 {if (string-length($comment) > 0) then <note>{$comment}</note> else ()}
</respStmt>
, $res :=  (  if ($swl/tls:metadata/@rating) then 
     update replace $swl/tls:metadata/@rating with if ($rating > 2) then 0 else $rating + 1 else
     update insert attribute rating {if ($rating > 1) then 0 else $rating + 1}  into $swl/tls:metadata
   , update insert $node into $swl/tls:metadata
     )
 return $link
 else ()

};

(:~
 Delete a syntactic word location.  We return the line-id, so that we can display the updated attributions.
:)
declare function tlsapi:delete-swl($type as xs:string, $uid as xs:string) {
if ($type eq 'swl') then 
let $swl := collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$uid]
,$link := substring(tokenize($swl/tei:link/@target)[1], 2)
,$sid := substring(tokenize($swl/tei:link/@target)[2], 2)
,$res := update delete $swl
,$update := lw:update-sense-id-ann-count($sid, -1)
return $link
else 
(: here we are deleting a rhetoric device location :)
if ($type eq 'rdl') then 
let $swl := collection($config:tls-data-root|| "/notes")//tls:span[@xml:id=$uid]
,$link := substring(tokenize($swl//tls:srcline/@target)[1], 2)
,$res := update delete $swl
return $link
(: here we are deleting a drug :)
else if ($type eq 'drug') then 
let $swl := collection($config:tls-data-root|| "/notes")//tls:drug[@xml:id=$uid]
,$link := substring(tokenize($swl/@target)[1], 2)
,$res := update delete $swl
return $link

else if ($type eq 'bib') then
let $bib := collection($config:tls-data-root|| "/bibliography")//mods:mods[@ID=$uid]
, $link := $uid
, $res := xmldb:remove(util:collection-name($bib), $uid || ".xml")
return
$link
else
()
};


declare function tlsapi:review-swl-dialog($uuid as xs:string){
let $swl := collection($config:tls-data-root || "/notes")//tls:ann[@xml:id=$uuid],
(: "[M01]/[D01]/[Y0001] at [H01]:[m01]:[s01]" :)
$seg-id:=$swl/parent::tei:seg/@xml:id,
$creator-id := substring($swl/tls:metadata/@resp, 2),
$score := if ($swl/tls:metadata/@score) then data($swl/tls:metadata/@score) else 0,
$date := format-dateTime(xs:dateTime($swl/tls:metadata/@created),"[MNn] [D1o], [Y] at [h].[m01][Pn]"),
$creator := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$creator-id]
return
<div id="review-swl-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Review SWL <span class="pl-5">Current score: <span class="font-weight-bold">{$score}</span></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Existing SWL <small>created by {$creator//tei:persName/text()}, {$date}</small></h6>
            <div class="card-text">{lrh:format-swl($swl, map{'type': 'row', 'context' : 'review'})}</div>
            <h6 class="font-weight-bold mt-2">Context</h6>
            {ltp:get-text-preview($seg-id, map{"context" : 3, "format" : "plain"})}
            <!--
            <h6 class="font-weight-bold mt-2">Other possibilities</h6>
            <div class="form-row">
              <div id="select-synfunc-group" class="form-group ui-widget col-md-6">
                 <label for="select-synfunc">other syntactic function: </label>
                 <input id="select-synfunc" class="form-control" required="false" />
                 <span id="synfunc-id-span" style="display:none;"></span>
              </div>
              <div id="select-semfeat-group" class="form-group ui-widget col-md-6">
                  <label for="select-semfeat">other semantic feature: </label>
                  <input id="select-semfeat" class="form-control" />
                  <span id="semfeat-id-span" style="display:none;"></span>
              </div>
            </div> -->
            {if (count($swl/tls:metadata/tei:respStmt) > 1) then 
            <div>
            <h6 class="font-weight-bold mt-2">Previous comments</h6>
            {for $d in subsequence($swl/tls:metadata/tei:respStmt, 2) 
             let $cr2-id := $d/tei:name/text(),
             $action:= $d/tei:resp/text(),
             $cr2-date := format-dateTime(xs:dateTime($d/tei:resp/@notBefore),"[MNn] [D1o], [Y] at [h].[m01][Pn]"),
             $cr2 := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$cr2-id]//tei:persName/text()
             return
             <p><span class="font-weight-bold" title="{$cr2}">@{$cr2-id}</span>({$cr2-date})-><span class="rp-5 {if ($action = 'approve') then 'bg-success' else if ($action = 'change') then 'bg-warning' else 'bg-danger'}">{$action}</span> &#160;&#160;<span class="bg-light">{$d/tei:note/text()}</span> </p>
}</div>
            else ()}
              <div id="select-concept-group" class="form-group ui-widget">
                    <label for="input-comment" class="font-weight-bold mt-2">Comment:<br/><small>If you want to suggest a different CONCEPT, vote for deletion here and create a new SWL.</small></label>
                    <textarea id="input-comment" class="form-control" required="false" value=""/>
              </div>
            <div>
            <div class="btn-group btn-group-toggle" data-toggle="buttons">
                <label class="btn btn-success active">
                    <input type="radio" name="actions" id="approve" autocomplete="off" checked="true">Approve</input>
                </label>
                <label class="btn btn-warning">
                    <input type="radio" name="actions" id="change" autocomplete="off"> Suggest changes</input>
                </label>
                <label class="btn btn-danger">
                    <input type="radio" name="actions" id="delete" autocomplete="off"> Mark for deletion</input>
                </label>
</div>            </div>  
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                <button type="button" class="btn btn-primary" onclick="save_swl_review('{$uuid}')">Save Review</button>
           </div>
     </div>
     </div>
</div>
};


declare function tlsapi:save-swl-review($uuid as xs:string, $comment as xs:string, $action as xs:string){
let $swl := collection($config:tls-data-root || "/notes")//tls:ann[@xml:id=$uuid],
 $user := sm:id()//sm:real/sm:username/text(),
 $previous-action := $swl/tls:metadata/tei:respStmt[last()],
 $score := if ($swl/tls:metadata/@score) then xs:int($swl/tls:metadata/@score) else 0,
 $newscore := if ($action = 'approve') then 
   if (not($previous-action/tei:name/text() = $user)) then
   if ($swl/tls:metadata/@score) then 
     update replace $swl/tls:metadata/@score with $score + 1 else
     update insert attribute score {$score + 1}  into $swl/tls:metadata 
   else -99
   else if ($action = 'delete') then 
     if ($score < 0) then 
     (: move to crypt :)
      -2
     else 
      update insert attribute score {-1}  into $swl/tls:metadata 
   else (),
 $node := <respStmt xmlns="http://www.tei-c.org/ns/1.0">
 <name>{$user}</name>
 <resp notBefore="{current-dateTime()}">{$action}</resp>
 {if (string-length($comment) > 0) then <note>{$comment}</note> else ()}
</respStmt>
return 
 (: we first update, then, if necessary, move to crypt :)
 if ($newscore = -99) then 
  "Error: you can not approve your own SWL."  
 else 
 (update insert $node into $swl/tls:metadata,
 if ($newscore = -2) then 
  if (not($previous-action/tei:name/text() = $user)) then
  let $swl := collection($config:tls-data-root || "/notes")//tls:ann[@xml:id=$uuid],
  $cm := substring(string(current-date()), 1, 7),
  $doc := lv:get-crypt-file("trans")
  return 
  (update insert $swl into $doc//tei:p[@xml:id="del-" || $cm || "-start"],
   update delete $swl,
   "The SWL has been moved to the crypt.  Thank you for making TLS better!")
  else 
 "Error: You can not second your own deletion!"
 else 
 "Review has been saved. Thank you for your effort!"
 )
};

declare function tlsapi:goto-translation-seg($map as map(*)){
 let $first := if ($map?dir = 'first') then true() else false()
 let $targetseg := try {ltr:get-translation-seg($map?trid, $first)} catch * {()}
 
 return 
  if (string-length($targetseg/@corresp) = 0) 
   then "?location=" || tokenize($map?trid, "_")[1]
   else
  "textview.html?location="||substring($targetseg/@corresp, 2)
};


(:~
: Dialog for new translation stub
: $trid in the case of updating the translation metadata
:)

declare function tlsapi:new-translation($slot as xs:string, $loc as xs:string?, $trid as xs:string?){
let $user := sm:id()//sm:real/sm:username/text()
let $tru := collection($config:tls-user-root|| $user || "/translations")/tei:TEI[@xml:id=$trid]
, $trc := collection($config:tls-translation-root)//tei:TEI[@xml:id=$trid]
, $trfile := if ($tru) then $tru else $trc
, $vis := if ($tru) then "option3" else "option1"
, $cop := data($trfile//tei:availability/@status)
, $ref := substring($trfile//tei:ref/@target, 2)
, $segcount := count($trfile//tei:seg)
let $textid := tokenize($loc, "_")[1],
$title := lmd:get-metadata-from-catalog($loc, "title"),
$tr := ltr:get-translations($textid)
, $type := $trfile/@type
, $trlg := if ($trfile//tei:sourceDesc//tei:lang/@xml:lang) then data($trfile//tei:sourceDesc//tei:lang/@xml:lang) else "en"
return
<div id="new-translation-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">{if ($trfile) then <h5>Edit translation file metadata for {$title} ({$segcount} lines)</h5> else <h5>Start a new translation or comment file for {$title}</h5>}
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <div class="form-row">
             <div class="form-group col-md-6 font-weight-bold">
             <label class="form-check-label" for="typrad1">Information about the translation / work   </label></div>
             <div class="form-group col-md-2 font-weight-bold">Type of work:</div>
             <div class="form-group col-md-2 font-weight-bold">
             <div class="form-check form-check-inline">
             {if ($type = 'comment') then 
              <input class="form-check-input" type="radio" name="typradio" id="typrad1" value="transl"/>
              else
              <input class="form-check-input" type="radio" name="typradio" id="typrad1" value="transl" checked="true"/>}
              <label class="form-check-label" for="typrad1">Translation</label>
             </div>
             </div>
             <div class="form-group col-md-2 font-weight-bold">
             <div class="form-check form-check-inline">
             {if ($type = 'comment') then 
              <input class="form-check-input" type="radio" name="typradio" id="typrad2" value="comment"  checked="true"/>
              else
              <input class="form-check-input" type="radio" name="typradio" id="typrad2" value="comment"/>}
              <label class="form-check-label" for="typrad2">Comments</label>
              </div> 
              </div>
            </div>
            <div class="form-row">
              <div id="select-lang-group" class="form-group ui-widget col-md-3">
                 <label for="select-lang">Translation language: </label>
                 <select class="form-control" id="select-lang">
                  {for $l in map:keys($config:languages)
                    order by $l
                    return
                    if ($l = $trlg) then
                    <option value="{$l}" selected="true">{$config:languages($l)}</option>
                    else
                    <option value="{$l}">{$config:languages($l)}</option>
                   } 
                 </select>                 
              </div>
              <div id="select-transl-group" class="form-group ui-widget col-md-3">
                  <label for="select-transl">Creator (if it is not you:-): </label>
                  <input id="select-transl" class="form-control" value="{$trfile//tei:titleStmt/tei:editor[@role='translator']/text()}"/>
              </div>
              <div id="select-type-group1" class="form-group ui-widget col-md-6">
                 <label for="select-rel">For comments, are they related to a translation?</label>
                 <select class="form-control" id="select-rel">
                    <option value="none" selected="true">None</option>
                  {for $c in map:keys($tr)
                    let $this := $tr($c)
                    let $l := $this[3]
                    order by $l
                    return
                    if ($c = $ref) then
                    <option value="{$c}" title="{$c}" selected="true">by {$this[2]} ({$this[3]})</option>
                    else
                    <option value="{$c}" title="{$c}">by {$this[2]} ({$this[3]})</option>
                   } 
                 </select>                 
              </div>             
            </div>
            <h6 class="font-weight-bold">Visibility</h6>
              <p>We hope and expect that the work will be available to all TLS users.  However, we realize there are reasons to keep it private, even if temporarily. You can change this later.</p>
           <div class="form-row">
             <div class="form-group col-md-4">
             <div class="form-check">
             {if ($vis = "option1") then 
              <input class="form-check-input" type="radio" name="visradio" id="visrad1" value="option1" checked="true"/>
              else
              <input class="form-check-input" type="radio" name="visradio" id="visrad1" value="option1"/>}
             <label class="form-check-label" for="visrad1">
               Show to everybody
             </label>
              </div>
             </div> 
             <div class="form-group col-md-4">
             <div class="form-check disabled">
            <input class="form-check-input" type="radio" name="visradio" id="visrad2" value="option2" disabled="true"/>
            <label class="form-check-label" for="visrad2">Show to registered users</label>
               </div>
              </div>
             <div class="form-group col-md-4">
             <div class="form-check">
             {if ($vis = "option1") then 
             <input class="form-check-input" type="radio" name="visradio" id="visrad3" value="option3"/>
             else 
             <input class="form-check-input" type="radio" name="visradio" id="visrad3" value="option3" checked="true"/>}
             <label class="form-check-label" for="visrad3">
             Keep it to me only
             </label>
           </div>
           </div>
</div>
            <h6 class="font-weight-bold">Bibliographic information</h6>
             <p class="text-muted">If you are entering a previously published translation, please give the bibliographic details here, at least title, publishing place and year.</p>
            <div class="form-row">
              <div id="select-trtitle-group" class="form-group ui-widget col-md-6">
                  <label for="select-trtitle">Title: </label>
                  <input id="select-trtitle" class="form-control" value="{if ($trfile//tei:sourceDesc/tei:bibl/tei:title) then $trfile//tei:sourceDesc/tei:bibl/tei:title/text() else $trfile//tei:titleStmt/tei:title/text()}"/>
              </div>
              <div id="select-concept-group" class="form-group ui-widget col-md-6" >
                    <label for="input-biblio" >Publisher, place and year</label>
                    <input id="input-biblio" class="form-control" value="{normalize-space(string-join($trfile//tei:sourceDesc/tei:bibl/text(), ''))}"/>
              </div>
              </div>

           <div class="form-row">
             <div class="form-group col-md-3">
             <div class="form-check">
             {if ($cop = "1") then
              <input class="form-check-input" type="radio" name="copradio" id="coprad1" value="option1" checked="true"/>
              else
              <input class="form-check-input" type="radio" name="copradio" id="coprad1" value="option1"/>}
             <label class="form-check-label" for="coprad1">
               No copyright
             </label>
              </div>
             </div> 
             <div class="form-group col-md-3">
             <div class="form-check">
             {if ($cop = "2") then
            <input class="form-check-input" type="radio" name="copradio" id="coprad2" value="option2" checked="true"/>
            else 
            <input class="form-check-input" type="radio" name="copradio" id="coprad2" value="option2"/>}
            <label class="form-check-label" for="coprad2">Licensed</label>
               </div>
              </div>
             <div class="form-group col-md-3">
             <div class="form-check">
             {if ($cop = "3") then
            <input class="form-check-input" type="radio" name="copradio" id="coprad3" value="option3" checked="true"/>
            else
            <input class="form-check-input" type="radio" name="copradio" id="coprad3" value="option3"/>}
            <label class="form-check-label" for="coprad3">Not Licensed</label>
               </div>
              </div>
             <div class="form-group col-md-3">
             <div class="form-check">
             {if ($cop = "4") then
             <input class="form-check-input" type="radio" name="copradio" id="coprad4" value="option4" checked="true"/>
             else
             <input class="form-check-input" type="radio" name="copradio" id="coprad4" value="option4"/>}
             <label class="form-check-label" for="coprad4">
             Status unclear
             </label>
           </div>
           </div>
</div>

<p class="text-muted">Save the translation, then you can select this translation for input after reloading the page.</p>
            <div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                <button type="button" class="btn btn-primary" onclick="store_new_translation('{$slot}','{$textid}', '{$trid}')">Save</button>
           </div>
     </div>
     </div>
              </div>
              </div>
</div>
};


declare function tlsapi:delete-word-from-concept($id as xs:string, $type as xs:string) {
if ($type = ('concept', 'syn-func') ) then ltx:delete-category($id) else
let $item := if ($type = 'word') then 
   (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:entry[@xml:id=$id]
   else
   (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:sense[@xml:id=$id]
,$itemcount := sum(
    if ($type = 'word') then
      for $i in $item/tei:sense
      return count(collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = "#"||$i/@xml:id])
    else count(collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = "#"||$item/@xml:id]))
,$ret := if ($itemcount = 0) then 
 (update delete $item, "OK") else "There are " || $itemcount || " Attributions, can not delete."
 return $ret
};

(:~
: For syn-func and sem-feat: show examples of usage
: TODO get the stuff from the CONCEPTS, then collect usage examples.?
:)

declare function tlsapi:show-use-of($uid as xs:string, $type as xs:string){
let $key := "#" || $uid
, $str := 'collection($config:tls-data-root||"/notes")//tls:' || $type || '[@corresp ="' || $key || '"]'
let $res := for $r in util:eval($str)
     (:where exists($r/ancestor::tei:sense):)
     return $r

return

if (count($res) > 0) then
(<li>Found {count($res)} attributions</li>, 
for $r in subsequence($res, 1, 30)
  let $sw := $r/ancestor::tei:sense
  , $cr := $sw/@corresp
  group by $cr
  return
  tlslib:display-sense($sw[1], -1, true())
)  
else 

concat("No usage examples found for key: ", $key, " type: ", $type )

};

(: safe_sf.xql tlsapi:save-sf($sense-id, $synfunc-id, $def, $type) :)
(: 2021-03-17 we now also handle sem-feat, the variable names do not reflect this :)
declare function tlsapi:save-sf($sense-id as xs:string, $synfunc-id as xs:string, $synfunc-val as xs:string, $def as xs:string, $type as xs:string){
let $newsf-id := if ($synfunc-id = 'xxx') then (
  if (collection($config:tls-data-root)//tei:div[@type=$type]/tei:head[.=normalize-space($synfunc-val)]) then
  collection($config:tls-data-root)//tei:div[@type=$type]/tei:head[.=normalize-space($synfunc-val)]/@xml:id
  else
  tlslib:new-syn-func ($synfunc-val, $def, $type)
) else ($synfunc-id)
,$pos := <pos xmlns="http://www.tei-c.org/ns/1.0">{upper-case(substring($synfunc-val, 1, 1))}</pos>
,$sf :=  if ($type = 'syn-func') then 
          <tls:syn-func corresp="#{$newsf-id}">{$synfunc-val}</tls:syn-func>
        else
          <tls:sem-feat corresp="#{$newsf-id}">{$synfunc-val}</tls:sem-feat>
(: here we update the concept :)
,$sense := collection($config:tls-data-root)//tei:sense[@xml:id = $sense-id]
,$upd := if ($type='syn-func') then update replace $sense/tei:gramGrp/tei:pos with $pos else ()
,$upd := if ($type='syn-func') then 
   update replace $sense/tei:gramGrp/tls:syn-func with $sf
   else
   if (exists($sense/tei:gramGrp/tls:sem-feat)) then
   update replace $sense/tei:gramGrp/tls:sem-feat with $sf
   else 
   update insert $sf into $sense/tei:gramGrp
   
,$gramgrp := $sense/tei:gramGrp
,$a := for $s in collection($config:tls-data-root)//tls:ann/tei:sense[@corresp = "#" || $sense-id]
  return
  (: this behaves badly.  disabling for now :)
(:  update replace $s/tei:gramGrp with $gramgrp:)
   ()
   
return 
if ($synfunc-id = 'xxx') then $newsf-id else
count(collection($config:tls-data-root)//tls:ann/tei:sense[@corresp = "#" || $sense-id])
};

declare function tlsapi:save-def($defid as xs:string, $def as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
let $id := substring($defid, 5)
,$sense := collection($config:tls-data-root)//tei:sense[@xml:id = $id]
,$defel := <def xmlns="http://www.tei-c.org/ns/1.0" resp="#{$user}" updated="{current-dateTime()}">{$def}</def>
,$upd := update replace $sense/tei:def with $defel
(: 2020-02-23 : update of the existing attributions defered
,$a := for $s in collection($config:tls-data-root)//tls:ann/tei:sense[@corresp = "#" || $id]
  return
  update replace $s/tei:def with $defel
:)
return 
$defel
(:if (update replace $node with $seg) then "Success. Updated translation." else "Could not update translation." 
if (update replace $sense/tei:def with $defel) then "Success" else "Problem"
:)
};

(:~ 
 : 2021-03-23
 : Save the notes in concepts

:)

declare function tlsapi:save-note($trid as xs:string, $tr-to-save as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
,$in := tokenize($tr-to-save, "<br><br>")
,$id := tokenize($trid, "_")[2]
,$type := tokenize($trid, "_")[1]
,$oldnode := if ($type='note') then 
collection($config:tls-data-root)//tei:div[@xml:id=$id]//tei:note
else
collection($config:tls-data-root)//tei:div[@xml:id=$id]//tei:div[@type=$type]
,$node := if ($type='note') then 
<note xmlns="http://www.tei-c.org/ns/1.0" type="{$type}" resp="#{$user}" modified="{current-dateTime()}">
{for $p in $in
where string-length($p) > 0
return
<p>{$p}</p>
}
</note>
else
<div xmlns="http://www.tei-c.org/ns/1.0" type="{$type}" resp="#{$user}" modified="{current-dateTime()}">
{for $p in $in
where string-length($p) > 0
return
<p>{$p}</p>
}
</div>
, $u1 := (if ($type = 'note') then 
           update insert attribute rhet-dev {$id} into $oldnode
        else
           update insert attribute concept {$id} into $oldnode,
         update insert attribute resp {"#"||$user} into $oldnode,
         update insert attribute modified {current-dateTime()} into $oldnode
         )

, $upd := if ($type = 'note') then update insert $oldnode into (lv:get-crypt-file("rhetdev-notes")//tei:div/tei:p[last()])[1]
  else update insert $oldnode into (lv:get-crypt-file("notes")//tei:div/tei:p[last()])[1]
, $save := update replace $oldnode with $node
return
"OK"
};

(:~
 : 2021-06-18 save-zh
 : 2023-04-28 TODO this seems dangerous, does not take into account possible child elements of seg
:)
declare function tlsapi:save-zh($map as map(*)){
let $user := sm:id()//sm:real/sm:username/text()
,$id := $map?id
,$txtid := tokenize($id, "_")[1]
,$zh-to-save := $map?line
,$node := collection($config:tls-texts-root)//tei:seg[@xml:id=$id]
,$seg := <seg xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}" resp="#{$user}" modified="{current-dateTime()}">{$zh-to-save}</seg>
return
if ($txtid and lpm:has-edit-permission($txtid)) then
  if ($node) then (
  update insert attribute modified {current-dateTime()} into $node,
  update insert attribute resp-change {"#" || $user} into $node,
  update insert $node into (lv:get-crypt-file("text")//tei:div/tei:p[last()])[1],
  if (update replace $node[1] with $seg) then () else "Success. Updated text." 
  )
  else 
  "Could not save text."
else
  "You do not have permission to edit this text."
};

declare function tlsapi:zh-delete-line($map as map(*)){
let $id := $map?id
,$txtid := tokenize($id, "_")[1]
,$user := sm:id()//sm:real/sm:username/text()
,$node := collection($config:tls-texts-root)//tei:seg[@xml:id=$id]
(: todo: check if this node has been referenced? :)
return
if ($txtid and lpm:has-edit-permission($txtid)) then
  if ($node) then (
  update insert attribute modified {current-dateTime()} into $node,
  update insert attribute resp-change {"#" || $user} into $node,
  update insert attribute change {"deletion"} into $node,
  update insert $node into (lv:get-crypt-file("text")//tei:div/tei:p[last()])[1],
  if (update delete $node[1]) then () else "Success. Deleted line." 
  )
  else 
  "Could not delete line."
else
  "You do not have permission to edit this text."
};

(: this is called with the currently last seg :)
declare function tlsapi:morelines($map as map(*)){
  let $targetseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?lineid]
  , $dseg := $targetseg/following::tei:seg[position()< 31]
  , $model := map{"textid" : tokenize($map?lineid, "_")[1]}
  ,  $tr := ltr:get-translations($model?textid)
  ,  $slot1-id := lrh:get-content-id($model?textid, 'slot1', $tr)
  ,  $slot2-id := lrh:get-content-id($model?textid, 'slot2', $tr)
return
(<div class="row" id="{$map?lineid}-{$map?cnt}"></div>,
ltp:chunkcol-left($dseg, $model, $tr, $slot1-id, $slot2-id, $map?lineid, xs:int($map?cnt)))
};


(: The bookmark will also serve as template for intertextual links and anthology, which is why we also save word and line :)
 
declare function tlsapi:save-bookmark($word as xs:string, $line-id as xs:string, $line as xs:string) {
let $user := sm:id()//sm:real/sm:username/text()
,$docpath := $config:tls-user-root || $user|| "/bookmarks.xml"
,$txtid := tokenize($line-id, "_")[1]
,$juan := tlslib:get-juan($line-id)
,$title := lu:get-title($txtid)
,$uuid := "uuid-" || util:uuid() 
,$item := <item xmlns="http://www.tei-c.org/ns/1.0" modified="{current-dateTime()}" xml:id="{$uuid}"><ref target="#{$line-id}"><title>{$title}</title>:{$juan}</ref>
<seg>{$line}</seg>
<term>{$word}</term></item>
let $doc :=
  if (not (doc-available($docpath))) then
   doc(xmldb:store($config:tls-user-root || $user, "bookmarks.xml", 
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$user}-bookmarks">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Bookmarks for user {$user}</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Bookmarks</head>
      <list type="bookmark" xml:id="bookmarklist-{$user}">
      </list>
      </div>
      </body>
  </text>
</TEI>)) 
 else doc($docpath)
return 
if (update insert $item  into $doc//tei:list[@xml:id="bookmarklist-"||$user]) then 
("Success. Saved bookmark.")
else ("Could not save bookmark. ", $docpath)

};

(:  
 :)
declare function tlsapi:move-to-page($map as map(*)){
let $px := tokenize($map?page, '_')
, $textid := tokenize($map?location, "_")[1]
, $pb := collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:pb[@ed=$px[2] and @n = $px[3]]
, $seg := ($pb/preceding::tei:seg|$pb/ancestor-or-self::tei:seg)[last()]
return data($seg/@xml:id)
};
 
 
declare function local:pblink($slot, $ed, $node, $marker){
let $segid := if ($marker = '&lt;') then data(reverse($node/preceding::tei:seg|$node/ancestor-or-self::tei:seg)[1]/@xml:id) 
  else data(($node/following::tei:seg)[1]/@xml:id)
return
<li class="page-item"><small><a class="page-link" onclick="get_facs_for_page('{$slot}', '{$config:tls-facs-root || $config:ed-img-map?($ed) || $node/@facs}', '{$ed}', '{$segid}')">{$marker}</a></small></li>
};

declare function tlsapi:get-facs-for-page($map as map(*)){
 let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?segid]
 return if (not($seg)) then (remote:get-facs-for-page($map)) else
 let $slot := $map?slot
 ,$textid := tokenize($map?segid, "_")[1]
 ,$ed := $map?pbed
 ,$pb := ($seg//tei:pb[@ed=$ed] | ($seg/preceding::tei:pb[@ed=$ed])[last()])[1]
(: ,$fac := $pb/@facs:)
 ,$img := $config:tls-facs-root || $config:ed-img-map?($ed) || $pb/@facs
 , $p1 := reverse($pb/preceding::tei:pb[@ed=$ed])[6]
 return 
 <div id="viewer-wrap-{$slot}" class="card ann-dialog" style="top: 50px; left: {$map?left}px; width: {$map?width}px; height: 50px;">
 <button type="button" class="close" onclick="hide_form('viewer-wrap-{$slot}')" aria-label="Close" title="Close"><img class="icon" src="resources/icons/open-iconic-master/svg/circle-x.svg"/></button>
    <span>{$config:wits?(data($ed))}</span><span type="button" onclick="move_to_page('{$slot}')" aria-label="GoTo" title="Go to displayed page"><img class="icon" src="resources/icons/open-iconic-master/svg/arrow-circle-bottom.svg"/></span>
    <span id="current-page-{$slot}" style="display:None">{'pb_' || $ed || '_' || data($pb/@n)}</span>
    <ul class="pagination">
    {local:pblink($slot, $ed, $p1, '&lt;')}    
    {for $c in reverse(reverse(($pb/preceding::tei:pb[@ed=$ed]))[position()< 6])
    let $n := tokenize(data($c/@n), '-')[last()]
    , $cimg := $config:tls-facs-root || $config:ed-img-map?($ed) || $c/@facs
    return
    <li class="page-item"><small><a id="pb_{$ed}_{data($c/@n)}" class="page-link" onclick="set_new_tileSources('{$slot}', 'pb_{$ed}_{data($c/@n)}', {{type : 'image', url : '{$cimg}'}})">{$n}</a></small></li>
    }    
    <li class="page-item"><small><a  id="pb_{$ed}_{data($pb/@n)}" class="page-link font-weight-bold" onclick="set_new_tileSources('{$slot}', 'pb_{$ed}_{data($pb/@n)}', {{type : 'image', url : '{$img}'}})">{tokenize(data($pb/@n), '-')[last()]}</a></small></li>
    {for $c in ($pb/following::tei:pb[@ed=$ed])[position()< 6]
    let $n := tokenize(data($c/@n), '-')[last()]
    , $cimg := $config:tls-facs-root || $config:ed-img-map?($ed) || $c/@facs
    return
    <li class="page-item"><small><a id="pb_{$ed}_{data($c/@n)}" class="page-link" onclick="set_new_tileSources('{$slot}', 'pb_{$ed}_{data($c/@n)}', {{type : 'image', url : '{$cimg}'}})">{$n}</a></small></li>
    }
    {local:pblink($slot, $ed, $p1, '&gt;')}
    </ul>

 <div id="viewer{$slot}" class="card ann-dialog overflow-auto" style="top: 100px; left: {$map?left}px; width: {$map?width}px; height: {$map?height}px;">  
 <script type="text/javascript">
    var viewer{$slot} = OpenSeadragon({{
     id: "viewer{$slot}", 
     prefixUrl: "resources/openseadragon-bin-4.1.0/images/", 
     tileSources: {{
        type: 'image',
        url: "{$img}",
        crossOriginPolicy : "Anonymous"
     }}
    // , sequenceMode: true
    }});
     viewer{$slot}.addHandler('open', () => {{
      let closeButton = new OpenSeadragon.Button({{
        tooltip: 'Close',
        srcRest: 'resources/icons/open-iconic-master/png/circle-x-6x.png',
        srcGroup: 'resources/icons/open-iconic-master/png/circle-x-6x.png',
        srcHover: 'resources/icons/open-iconic-master/png/circle-x-6x.png',
        srcDown: 'resources/icons/open-iconic-master/png/circle-x-6x.png',
        onClick: 'window.hide_form("viewer{$slot}")'
      }});

      // viewer{$slot}.addControl(closeButton.element, {{ anchor: OpenSeadragon.ControlAnchor.TOP_LEFT }});
    }});</script> 
 </div>
 </div>
};


declare function tlsapi:save-new-concept($map as map(*)){
let $ont-ant := if ($map?ont_ant) then 
  <list type="antonymy" xmlns="http://www.tei-c.org/ns/1.0" >
  {for $e in tokenize($map?ont_ant, "xxx")
   let $f := tokenize($e, "::")
   return 
   <item xmlns="http://www.tei-c.org/ns/1.0"><ref target="#{$f[2]}">{$f[1]}</ref></item>
  }
  </list>
  else (),
 $ont-hyp := if ($map?ont_hyp) then 
  <list type="hypernymy" xmlns="http://www.tei-c.org/ns/1.0" >
  {for $e in tokenize($map?ont_hyp, "xxx")
   let $f := tokenize($e, "::")
   return 
   <item xmlns="http://www.tei-c.org/ns/1.0"><ref target="#{$f[2]}">{$f[1]}</ref></item>
  }
  </list>
  else (),
 $ont-see := if ($map?ont_see) then 
  <list type="see" xmlns="http://www.tei-c.org/ns/1.0" >
  {for $e in tokenize($map?ont_see, "xxx")
   let $f := tokenize($e, "::")
   return 
   <item xmlns="http://www.tei-c.org/ns/1.0"><ref target="#{$f[2]}">{$f[1]}</ref></item>
  }
  </list>
  else (),
 $ont-tax := if ($map?ont_tax) then 
  <list type="taxonymy" xmlns="http://www.tei-c.org/ns/1.0" >
  {for $e in tokenize($map?ont_tax, "xxx")
   let $f := tokenize($e, "::")
   return 
   <item xmlns="http://www.tei-c.org/ns/1.0"><ref target="#{$f[2]}">{$f[1]}</ref></item>
  }
  </list>
  else (),
  $labels := if ($map?labels) then 
  <list type="altnames" xmlns="http://www.tei-c.org/ns/1.0" >
  {for $l in tokenize($map?labels, ",")
  return 
   <item xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($l)}</item>
  }
  </list> else (),
 $och := if ($map?och) then <item xmlns="http://www.tei-c.org/ns/1.0" xml:lang="och">{$map?och}</item> else (),
 $zh := if ($map?zh) then <item xmlns="http://www.tei-c.org/ns/1.0" xml:lang="zh">{$map?zh}</item> else (),
 $uuid := if ($map?concept_id) then $map?concept_id else "uuid-" || util:uuid()

  (: <?xml-model href="../schema/tls.rnc" type="application/relax-ng-compact-syntax"?>, :)
let $new-concept := (
<div xmlns="http://www.tei-c.org/ns/1.0" xmlns:mods="http://www.loc.gov/mods/v3" xmlns:tls="http://hxwd.org/ns/1.0" xmlns:xlink="http://www.w3.org/1999/xlink" type="concept" xml:id="{$uuid}">
<head>{$map?concept}</head>{$labels}
<list type="translations">{$och,$zh}</list>
<div type="definition">
<p>{$map?def}</p></div>
<div type="notes">    
 <div type="old-chinese-criteria"><p>{$map?crit}</p></div>
 <div type="modern-chinese-criteria"><p>{$map?notes}</p></div>
</div>    
<div type="pointers">
{$ont-ant,$ont-hyp,$ont-see,$ont-tax}
</div>
<div type="source-references">
        <listBibl>
        </listBibl>
    </div>
<div type="words">
</div>
</div>)
let $uri := xmldb:store($config:tls-data-root || "/concepts", translate($map?concept, ' ', '_') ||".xml", $new-concept)
return (
    sm:chmod(xs:anyURI($uri), "rwxrwxr--"),
(:    sm:chown(xs:anyURI($uri), "tls"),:)
    sm:chgrp(xs:anyURI($uri), "tls-user")
    )
};
(: originally written for saving the sf-definitions in browse mode 
2020-10-14: updated for editing also the concept definitions in browse mode
2021-03-21: updating rhet-dev definitions, these contain multiple paragraphs.  What a mess!
:)
declare function tlsapi:save-sf-def($map as map(*)){

let $type := $map?type
, $sfdoc := if ($type ='-sf') 
  then doc($config:tls-data-root || "/core/syntactic-functions.xml")
  else if ($type='-sm') then doc($config:tls-data-root || "/core/semantic-features.xml")
  else doc($config:tls-data-root || "/core/rhetorical-devices.xml")
, $sfnode := if ($type='-rd') then $sfdoc//tei:div[@xml:id=$map?id]/tei:div[@type='definition'] 
   else $sfdoc//tei:div[@xml:id=$map?id]
let $sf := 
if (empty($sfnode)) then (
 if ($type = "-la") then
 (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id=$map?id]
 else
 (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id=$map?id]/tei:div[@type='definition']
 )
 else $sfnode,
$head := $sf/tei:head,
$firstp := $sf/tei:p,
$user := sm:id()//sm:real/sm:username/text(),
$def := if ($type = '-la') then 
<head xmlns="http://www.tei-c.org/ns/1.0" resp="#{$user}" modified="{current-dateTime()}">{normalize-space($map?def)}</head>
else
if ($type = '-rd') then
 <div type="definition" xmlns="http://www.tei-c.org/ns/1.0" resp="#{$user}" modified="{current-dateTime()}">
 {for $p in tokenize(normalize-space($map?def), "<br>") 
  where string-length($p) > 0
 return
 <p>{$p}</p>
 }
 </div>
else 
<p xmlns="http://www.tei-c.org/ns/1.0" resp="#{$user}" modified="{current-dateTime()}">{normalize-space($map?def)}</p>
return 
  (
 (: das sieht ziemlich fatal aus, was soll das? 
 if ($firstp) then update delete $firstp else (), :) 
 if (empty($sfnode)) then
 if ($type = '-la') then 
   (
   (: updating the label :)
   update replace $head with $def,
   (: also update the ref elements in other concepts :)
   for $r in (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:ref[@target="#"||$map?id]
   return 
   update replace $r with <ref xmlns="http://www.tei-c.org/ns/1.0" resp="#{$user}" modified="{current-dateTime()}" target="#{$map?id}">{normalize-space($map?def)}</ref> 
   )
 else
 (: notwithstanding the naming, this is updating the definition in the concept :)   
   update insert $def into $sf 
 else 
 (: $sfnode is not empty :)
 if ($type= '-rd') then (
 (: keep the record :)
  update insert attribute resp {"#"||$user} into $sfnode,
  update insert attribute modified {current-dateTime()} into $sfnode,
  update insert attribute rd-id {$map?id} into $sfnode,
  update insert $sfnode into (lv:get-crypt-file("rhetdev-def")//tei:div/tei:p[last()])[1], 
  (: ok, now update :)
  update replace $sfnode with $def
 ) 
 else
 update insert $def following $head
 )
};

declare function tlsapi:delete-pron($map as map(*)){
let $uuid := $map?uuid
,$e := collection($config:tls-data-root||"/guangyun")//tx:guangyun-entry[@xml:id=$uuid]
,$uri := document-uri( root( $e ) )
,$doc := tokenize($uri, "/")[last()]
,$coll := substring-before($uri, $doc)
,$cnt := count((collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:form[@corresp="#"||$uuid])
return
if ($cnt = 0) then
  (xmldb:remove($coll, $doc), "OK")
else   
  "Entry is in use, can not delete."
};

declare function tlsapi:do-delete-sf($map as map(*)){
let $sfdoc := if ($map?type = "syn-func") 
    then doc($config:tls-data-root || "/core/syntactic-functions.xml") 
    else doc($config:tls-data-root || "/core/semantic-features.xml"),
  $sf := $sfdoc//tei:div[@xml:id=$map?uid]
return
  if ($sf) then update delete $sf 
   else if ($map?ok = "true") then 
   (: yes we delete the sf and all dependents :)
    (update delete $sf,
      let $key := "#" || $map?uid
         ,$str := 'collection($config:tls-data-root||"/notes")//tls:' || $map?type || '[@corresp ="' || $key || '"]'
      for $r in util:eval($str)
        let $sw := $r/ancestor::tls:ann
        return update delete $sw
    )
else () 
};

declare function tlsapi:quick-search($map as map(*)){
 let $cat := map:merge(for $c in tokenize($map?filter, ";") 
                           let $ck := tokenize($c, ":")
                           return map:entry($ck[1], $ck[2]))
 let $uuid :=  if (starts-with($map?uuid, "uuid")) then $map?uuid else "uuid-" || util:uuid()
 let $hits := 
      if ($map?target = 'texts') then
            let $res := src:ngram-query($map?query, $map?mode, $map?search-type, $map?textid, $cat)
            return $res?hits
      else if ($map?target = 'wikidata') then 
            wd:search($map)
      else if ($map?target = 'similar') then 
            src:find-similar-segments($map?line)
      else ()
, $dispx := subsequence($hits, $map?start, $map?count)
, $disp := util:expand($dispx)//exist:match/ancestor::tei:seg
, $title := lu:get-title($map?textid)
, $start := xs:int($map?start)
, $count := xs:int($map?count)
, $total := count($hits)
(: do_quick_search(1 + 25, 25, 5, "rating, texts") 
function do_quick_search(start, count, stype, mode, target){
:)
, $prevp := if ($start = 1) then "" else 
  let $ts := $start - $count 
    return
   ``[
do_quick_search('`{$ts}`', '`{$count}`', '`{$map?search-type}`', '`{$map?mode}`', '`{$map?target}`')
]``
, $nextp := if ($total < $start + $count) then "" else 
   let $ts := $start + $count
   return
   ``[
do_quick_search('`{$ts}`', '`{$count}`', '`{$map?search-type}`', '`{$map?mode}`', '`{$map?target}`')
]``
, $qs := tokenize($map?query, "\s")
, $q1 := substring($qs[1], 1, 1)

return
if ($map?target = ('wikidata', 'similar')) then $hits
else
<div><p><input type="hidden" name="qs-uuid" value="{$uuid}"/><span class="font-weight-bold">{$start}</span> to <span class="font-weight-bold">{min(($start + $count -1, $total))}</span> of <span class="font-weight-bold">{$total}</span> <span class="font-weight-bold"> p</span> with <span class="font-weight-bold">{count($disp)}</span> hits  {if ($map?search-type eq "5") then "in "||$title else "in all texts" }. {
if ($map?search-type eq "5") then 
   (<button class="btn badge badge-light" onclick="do_quick_search(1, 25, 1, 'date', 'texts')">Search in all texts (by textdate)</button>,
   <button class="btn badge badge-light" onclick="do_quick_search(1, 25, 1, 'rating', 'texts')">Search in all texts (<span class="bold" style="color:red;">★</span> texts first)</button>) else 
   <button class="btn  badge badge-light" onclick="do_quick_search(1, 25, 5,'{$map?mode}', 'texts')">Search in {$title} only</button>}
 {if ($map?search-type eq "1") then
    if ($map?mode eq "rating") then 
    <button class="btn badge badge-light" onclick="do_quick_search(1, 25, {$map?search-type}, 'date', 'texts')">Sort by textdate</button> else 
    <button class="btn  badge badge-light" onclick="do_quick_search(1, 25, {$map?search-type}, 'rating', 'texts')">Sort <span class="bold" style="color:red;">★</span> texts first</button>
else ()
}</p>
{
for $h at $n in $disp
    let $loc := $h/@xml:id
    ,$cseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$loc]
    ,$head :=  lmd:get-metadata($cseg, "head")
    ,$title := lmd:get-metadata($cseg, "title")
    ,$textid := tlslib:get-textid($loc)
    ,$tr := collection($config:tls-translation-root)//tei:seg[@corresp="#"||$loc]
    ,$m1 := substring(($h/exist:match)[1]/text(), 1, 1)
    ,$col1 :=  if (lpm:can-use-linked-items()) then "col-md-1" else "col-md-2"
    where $m1 = $q1
(:  :)

return
<div class="row">
<div class="{$col1}">{xs:int($map?start)+$n - 1}</div>
{ if (lpm:can-use-linked-items()) then 
<div class="col-md-1"><input class="form-check-input" type="checkbox" name="res-check" value="" id="res-{$loc}"/></div> else ()}
<div class="col-md-3"><a href="textview.html?location={$loc}&amp;query={$map?query}">{$title, " / ", $head}</a></div>
<div class="col-md-7">{ 
for $sh in $h/preceding-sibling::tei:seg[position()<4] return lrh:proc-seg($sh, map{"punc" : true(), "textid" : $textid}),
        lrh:proc-seg($h, map{"punc" : true(), "textid" : $textid}),
        (: this is a hack, it will probably show the most recent translation if there are more, but we want to make this predictable... :)
        for $sh in $h/following-sibling::tei:seg[position()<4] return lrh:proc-seg($sh, map{"punc" : true(), "textid" : $textid }),
        if ($tr) then (<br/>, $tr) else ()}</div>
</div>
}
<nav aria-label="Page navigation">
  <ul class="pagination">
    <li class="page-item"><a class="page-link {if ($start = 1) then "disabled" else ()}" onclick="{$prevp}" href="#">&#171;</a></li>
    <li class="page-item"><a class="page-link" onclick="{$nextp}" href="#">&#187;</a></li>
    { if (lpm:can-use-linked-items()) then 
    <li> <span class="btn" onclick="show_new_link_dialog('{$uuid}')">Link selected items to this line</span></li>
    else ()
    }
  </ul>
 
</nav>

</div>
};

declare function tlsapi:delete-bm($map as map(*)){
let $user := sm:id()//sm:real/sm:username/text()
,$bmdoc := doc($config:tls-user-root || $user|| "/bookmarks.xml")
,$bm := $bmdoc//tei:item[@xml:id = $map?uuid]
return
if ($bm) then (update delete $bm, "OK") else "Could not delete bookmark."
};

(: 2021-11-30 : generalizing to cover block-level observation, type is given in $map?type :)

declare function tlsapi:save-rdl($map as map(*)){
let $uuid := concat("uuid-", util:uuid())
, $type := $map?type
, $user := sm:id()//sm:real/sm:username/text()
, $lnode := if ($type= 'rhetdev') then doc($config:tls-data-root ||"/notes/rdl/rdl.xml")//tls:span[position()=last()] 
   else 
    if (doc($config:tls-data-root ||"/notes/facts/"||$type ||".xml")) 
     then doc($config:tls-data-root ||"/notes/facts/"||$type ||".xml")//tls:span[position()=last()]
   else tlslib:get-obs-node($type)
, $title := lu:get-title(tokenize($map?line_id, '_')[1])
, $rdlnode := if ($type = 'rhetdev') then
	<tls:span xmlns:tls="http://hxwd.org/ns/1.0" type="rdl" xml:id="{$uuid}" rhet-dev="{$map?rhet_dev}" rhet-dev-id="{$map?rhet_dev_id}" resp="#{$user}" modified="{current-dateTime()}">
		<tls:text role="span-start">
			<tls:srcline title="{$title}" target="#{$map?line_id}">{$map?line}</tls:srcline>
		</tls:text>
		{if ($map?line_id ne $map?end_val) then
		<tls:text role="span-end">
			<tls:srcline title="{$title}" target="#{$map?end_val}">{normalize-space($map?end)}</tls:srcline>
		</tls:text>
		else ()}
		{if (string-length($map?note) gt 0) then 
		<tls:note>{$map?note}</tls:note>
		else ()
		}
	</tls:span>
    else 
    <tls:span xmlns:tls="http://hxwd.org/ns/1.0" name="{tlslib:remove-punc($map?rhet_dev)}" type="{$type}" xml:id="{$uuid}" resp="#{$user}" modified="{current-dateTime()}">
		<tls:text role="span-start">
			<tls:srcline title="{$title}" target="#{$map?line_id}">{$map?line}</tls:srcline>
		</tls:text>
		{if ($map?line_id ne $map?end_val) then
		<tls:text role="span-end">
			<tls:srcline title="{$title}" target="#{$map?end_val}">{normalize-space($map?end)}</tls:srcline>
		</tls:text>
		else ()}
		{if (string-length($map?note) gt 0) then 
		<tls:note>{$map?note}</tls:note>
		else ()}
		{if ($type eq "med-recipe") then 
		tlslib:analyze-recipe($uuid, $map)
		else ()}
		
    </tls:span>
(:, $analyze := if ($type eq "med-recipe") then tlslib:analyze-recipe($uuid, $map) else ()   :)  
return
(
update insert $rdlnode following $lnode ,
$rdlnode
)
};

declare function tlsapi:get-more-lines($map as map(*)){
let $cnt := xs:int($map?cnt)
, $len := xs:int($map?len)
, $start := abs($cnt) + $len
let $ret := for $s at $pos in lu:next-n-segs($map?line, $cnt)
return
if ($cnt < 0 ) then 
<option value="{$s/@xml:id}#{$start - $pos}">{lrh:proc-seg($s, map{"punc" : true()})}</option>
else 
<option value="{$s/@xml:id}#{$len + $pos}">{lrh:proc-seg($s, map{"punc" : true()})}</option>
return
$ret
};

declare function tlsapi:show-obs($map as map(*)){
<ul>{
let $show := 
for $obs in collection($config:tls-data-root || "/notes/facts")//tls:span[@type=$map?templ-id]
let $date := xs:dateTime($obs/@modified),
$target := substring($obs/tei:ref/@target, 2)
order by $date descending
where string-length($obs) > 0
return $obs
for $obs in subsequence($show, 1, 5) return
<li title="Created {$obs/@resp} at {$obs/@modified}"><span class="font-weight-bold"><a href="textview.html?location={substring(data($obs/tls:text[@role='span-start']/tls:srcline/@target),2)}">{data($obs/@name)}</a></span><span class="text-muted">({data($obs/tls:text[@role='span-start']/tls:srcline/@title)})</span>
{if ($obs//tls:contents) then 
<ul>{
for $d in $obs//tls:contents/tls:drug return
<li><a href="concept.html?uuid={$d/@concept-id}{$d/@ref}">{$d/text()}</a><span class="text-muted">({data($d/@quantity)}, {data($d/@flavor)})</span></li>
}</ul>
else ()}
</li>
}</ul>
};

declare function tlsapi:save-textcat($map as map(*)){
    let $head := collection($config:tls-texts-root)//tei:TEI[@xml:id=$map?textid]
    return
    if (string-length($map?textcat)>0) then lmd:checkCat($head, $map?textcat) else ()
};

declare function tlsapi:save-textdate($map as map(*)){
let $user := sm:id()//sm:real/sm:username/text()
   ,$dates := if (exists(doc($config:tls-user-root || $user || "/textdates.xml")//date)) then 
      doc($config:tls-user-root || $user || "/textdates.xml")//data else 
      doc($config:tls-texts-meta  || "/textdates.xml")//data
    ,$node := $dates[@corresp="#" || $map?textid]
    ,$head := collection($config:tls-texts-root)//tei:TEI[@xml:id=$map?textid]
    ,$savecat := if (string-length($map?datecat)>0) then lmd:checkCat($head,  $map?datecat) else ()
    ,$na := if (string-length($map?na) > 0) then $map?na else $map?nb
    ,$pr := if ($map?prose ne "　") then $map?prose else if($na eq $map?nb) then $na else $map?nb || " to " || $na
    ,$nh := if (string-length($map?src) > 0) then <span id="textdate-note" class="text-muted"> {$map?src}</span> else ()
    ,$tit := lu:get-title($map?textid)
    ,$n := if (string-length($map?src) > 0) then <note>{$map?src}</note> else ()
    ,$nnode := <data resp="#{$user}" modified="{current-dateTime()}" notbefore="{$map?nb}" notafter="{$na}" corresp="#{$map?textid}" title="{$tit}">{$pr}{$n}</data>
    ,$upd :=
    if (exists($node)) then 
    update replace $node with $nnode
    else
    update insert $nnode into $dates[1]/ancestor::root
    return 
    <span  id="textdate" data-not-before="{$map?nb}" data-not-after="{$na}">{$pr} {$nh}</span>
};

declare function tlsapi:save-taxchar($map as map(*)){
let $user := sm:id()//sm:real/sm:username/text()
, $doc := if ($map?type = 'taxword') then
   doc($config:tls-data-root||"/core/taxword.xml")
  else 
   doc($config:tls-data-root||"/core/taxchar.xml")
, $data := $map?body
, $xml := tlslib:char-tax-html2xml($data/div, $map?type)
, $id := $data/div/@tei-id
, $node := $doc//tei:div[@xml:id=$id]
, $updnode := $doc//tei:div[@xml:id=$id]
, $excess := 
    if (count(tokenize($id)) > 1) then 
     let $new-id := tokenize($id)[1]
     return
      update replace $updnode/@xml:id with $new-id 
    else ()
return
(: if (count(tokenize($id)) > 1) then "Error: Problem in character taxonomy file.  Can not save." else:)
(
if ($node) then (
 update insert attribute modified {current-dateTime()} into $node,
 update insert attribute resp-change {"#" || $user} into $node,
 update rename $node/@xml:id as 'src-id',
 update insert $node following (lv:get-crypt-file($map?type)//tei:div[last()])[1],
 update replace $updnode with $xml
) else (
 update insert $xml following ($doc/tei:div[1]/tei:div[last()])[1]
),

<div id="{$id}">
{$xml}</div>
)
};

(: Save a segment with user added punctuation.  
Parameters: line_id = xml:id of segment
cont = 'false' or 'true'; when true display the dialog again with the next segment
type = one of the seg-types, defined in config.xqm
new-seg = Punctuated text (Passed in request body, see below)
:)
declare function tlsapi:save-punc($map as map(*)){
let  $seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?line_id]
, $txtid := tokenize($map?line_id, "_")[1]
, $new-seg :=  $map?body
, $res := string-join(for $r at $pos in tokenize($new-seg, '\$') return $r || "$" || $pos || "$", '')
, $str := analyze-string ($res, $config:seg-split-tokens)
return
if (not($txtid and lpm:has-edit-permission($txtid))) then "Error: You do not have permission to update edit this text."
else if (not(tlslib:check-edited-seg-valid($new-seg, $seg))) then "Error: Text integrity check failed. Can not save edited text."
else 
    let $seg-with-updated-type := 
    if ($map?type != $seg/@type) then 
        let $res := xed:change-seg-type($seg, $map?type)
        , $p := $seg/parent::*
        return ()
    else
        ()
    return
    (: Need to query the segment again, because changing its type to heading might modify the element :)
    let $seg-with-new-type := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?line_id]
    return
    if ($map?action = "no_split") then 
        let $tx := tlslib:reinsert-nodes-after-edit($res, $seg-with-new-type)
        , $segs := <seg xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$map?line_id}" type="{$map?type}">{$tx}</seg>
        return update replace $seg with $segs
    else 
        let $segs := for $m at $pos in $str//fn:non-match
            let $nm := $m/following-sibling::fn:*[1]
            , $t := replace(string-join($nm/text(), ''), '/', '')
            , $tx := tlslib:reinsert-nodes-after-edit($m/text(), $seg-with-new-type)
            , $sl := string-join($tx, '') => normalize-space() => replace(' ', '') 
            , $nid := if ($pos > 1) then tlslib:generate-new-line-id($map?line_id, $pos - 1) else $map?line_id 
            where string-length($sl) > 0
            return
            <seg xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$nid}" type="{$map?type}">{$tx, 
                if (local-name($nm) = 'match' and string-length($t) > 0) then <c n="{$t}"/> else ()}</seg>
        return (
        if (count($segs) > 1) then
            let $firstseg := $segs[1]/@xml:id
            return (
                update insert subsequence($segs, 2) following $seg-with-new-type
                , update replace $seg-with-new-type with $segs[1])
        else
            update replace $seg-with-new-type with $segs
        , $segs[last()]/@xml:id)
};

(: :)
declare function tlsapi:merge-following-seg($map as map(*)){
let $segid := $map?line_id,
    $txtid := tokenize($segid, "_")[1],
    $new-seg :=  $map?body,
    $seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$segid]
return
    if (not($txtid and lpm:has-edit-permission($txtid))) then "Error: You do not have permission to update edit this text."
    else if ($new-seg = ()) then "Error: Please use the function under 內部 to completely delete segment" 
    else if (not(tlslib:check-edited-seg-valid($new-seg, $seg))) then "Error: Text integrity check failed. Can not save edited text."
    else 
        (: Use save-punc to update the edited part, without splitting. :)
        let $save-punc-rst := tlsapi:save-punc(map:put($map, "action", "no_split")),
            $updated-seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$segid],
            $fseg := $updated-seg/following::tei:seg[1],
            $nseg := <seg xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$segid}" type="{$map?type}">{$updated-seg/node(), $fseg/node()}</seg>
        return (
            update replace $seg with $nseg, 
            update delete $fseg
        )
};

declare function tlsapi:text-request($map as map(*)){
let $user := sm:id()//sm:real/sm:username/text()
, $text := doc($config:tls-add-titles)//work[@krid=$map?kid]
, $req := if ($text/@request) then $text/@request || "," || $user else $user
return 
 if ($text/@request) then update replace $text/@request with $req 
  else (update insert attribute request {$req} into $text,
  update insert attribute request-date {current-dateTime()} into $text
  )
};

declare function tlsapi:add-text($map as map(*)){
let $cbid := $map?cbid
, $w := doc($config:tls-add-titles)//work[@krid=$map?kid]
, $cv := try {imp:do-conversion($map?kid, $cbid) } catch * {()}
, $tls := attribute tls-added {current-dateTime()}
return 
 if ($cv = $map?kid) then 
  (update rename $w/@request as "requested-by", 
   if ($w/@tls-added) then update replace $w/@tls-added with $tls 
   else update insert $tls into $w ) 
 else "Error:  can not import text"
};

declare function tlsapi:save-wr($map as map(*)){
let $node := collection($config:tls-data-root)//tei:TEI[@xml:id="word-relations"]//tei:body/tei:div[@xml:id=$map?relid]/tei:div[@type="word-rels"]
, $d2 := $node//tei:div[@type="word-rel-ref" and .//tei:item[@corresp="#"||$map?lwwid] and .//tei:item[@corresp="#"||$map?rwwid]]/parent::tei:div 
, $lwtextline := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?lwlineid]
, $rwtextline := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?rwlineid]/text()
, $title := $lwtextline/ancestor::tei:TEI//tei:titleStmt/tei:title/text()
, $user := sm:id()//sm:real/sm:username/text()
return
if ($node) then 
 let $new := if ($d2) then 
            <div xml:id="uuid-{util:uuid()}" type="word-rel-ref" created="{current-dateTime()}" resp="#{$user}" xmlns="http://www.tei-c.org/ns/1.0">
              {if (string-length($map?note_inst) > 0) then 
              <p type="note-inst">{$map?note_inst}</p> else ()}
              <list>
                <item p="left-word" txt="{$title}" corresp="#{$map?lwwid}" concept="{$map?lwconcept}" concept-id="{$map?lwconceptid}" line-id="{$map?lwlineid}" textline="{$lwtextline/text()}" offset="{$map?lwoffset}" range="{string-length($map?lw)}">{$map?lw}</item>
                <item p="right-word" txt="{$title}" corresp="#{$map?rwwid}" concept="{$map?rwconcept}" concept-id="{$map?rwconceptid}"  line-id="{$map?rwlineid}" textline="{$rwtextline}" offset="{$map?rwoffset}" range="{string-length($map?lw)}">{$map?rw}</item>
              </list>
            </div>
          else 
           <div type="word-rel" xmlns="http://www.tei-c.org/ns/1.0">
              {if (string-length($map?note) > 0) then 
              <p type="word-rel-note">{$map?note}</p> else ()}
            <link target="#{$map?lwwid} #{$map?rwwid}"/>
            <div xml:id="uuid-{util:uuid()}" type="word-rel-ref" created="{current-dateTime()}" resp="#{$user}">
              {if (string-length($map?note_inst) > 0) then 
              <p type="note-inst">{$map?note_inst}</p> else ()}
              <list>
                <item p="left-word" txt="{$title}" corresp="#{$map?lwwid}" concept="{$map?lwconcept}" concept-id="{$map?lwconceptid}" line-id="{$map?lwlineid}" textline="{$lwtextline/text()}" offset="{$map?lwoffset}" range="{string-length($map?lw)}">{$map?lw}</item>
                <item p="right-word" txt="{$title}" corresp="#{$map?rwwid}" concept="{$map?rwconcept}" concept-id="{$map?rwconceptid}"  line-id="{$map?rwlineid}" textline="{$rwtextline}" offset="{$map?rwoffset}" range="{string-length($map?rw)}">{$map?rw}</item>
              </list>
            </div>
            </div>
     , $target := if ($d2) then $d2 else $node
 (: TODO: check if this word-relation already exists, if yes, add it to the div/@type=word-rel, otherwise create a new one on that level :)
 return update insert $new into $target
(: return $new:)
else "Error: Word relation type not found."
};

(: wrid points to a div of the type word-rel-ref, thus  :)
declare function tlsapi:delete-word-relation($map as map(*)){
let $node := collection($config:tls-data-root)//tei:TEI[@xml:id="word-relations"]//tei:body//tei:div[@xml:id=$map?wrid]
, $line := distinct-values(for $l in $node//tei:item/@line-id return data($l))
return
if ($node) then 
(
 update delete $node,
 "[" || string-join(for $l in $line return '"' || $l || '"', ",") || "]"
)
else '["Error: Word relation not found."]'
};

(:
api/responder.xql?func=dialogs:word-rel-dialog&lw="+leftword+"&lwlineid="+lw_id+"&lwconcept="+lwobj.concept+"&lwconceptid="+lwobj.concept_id+"&lwwid="+lwobj.wid+"&rw="+rightword+"&rwlineid="+rw_id+"&rwconcept="+obj.concept+"&rwconceptid="+obj.concept_id+"&rwwid="+obj.wid+"&rwoffset="+pos+"&lwoffset="+lwpos, 
:)
(: or maybe I just ask for a new relation and go with that... :) 
declare function tlsapi:change-word-relation($map as map(*)){
let $node := collection($config:tls-data-root)//tei:TEI[@xml:id="word-relations"]//tei:body//tei:div[@xml:id=$map?wrid]
, $lw := ""
, $rw := ""
, $options := map{
"lw" : "",
"lwlineid" : "",
"lwconcept" : data($lw/@concept),
"lwconceptid" : data($lw/@concept-id),
"rw" : "",
"rwlineid" : "",
"rwconcept" : data($rw/@concept),
"rwconceptid" : data($rw/@concept-id)
}
return
dialogs:word-rel-dialog($options)
};



declare function tlsapi:show-wr($map as map(*)){
let $key := "#" || $map?uid
,$word-rel := doc($config:tls-data-root || "/core/word-relations.xml")//tei:div[@xml:id=$map?uid]/ancestor::tei:div[@type='word-rel']
, $wrs := $word-rel//tei:list
return
if (count($wrs) > 0) then
 for $wr in $wrs  
  let $lwn := ($wr/tei:item)[1]
  , $rwn := ($wr/tei:item)[2]
 , $txt := data($lwn/@txt)
 , $ll := try {<span>{substring(data($lwn/@textline), 1, xs:int($lwn/@offset) - 1)}<b>{substring(data($lwn/@textline), xs:int($lwn/@offset), xs:int($lwn/@range))}</b>{substring(data($lwn/@textline), xs:int($lwn/@offset) + xs:int($lwn/@range))}</span> } catch * {<span>{data($lwn/@textline)}</span>}
 , $rl := try {<span>{substring(data($rwn/@textline), 1, xs:int($rwn/@offset) - 1)}<b>{substring(data($rwn/@textline), xs:int($rwn/@offset), xs:int($rwn/@range))}</b>{substring(data($rwn/@textline), xs:int($rwn/@offset) + xs:int($rwn/@range))}</span> } catch * {<span>{data($rwn/@textline)}</span>}
 , $lnk := if (string-length($lwn/@line-id) > 0) then ($lwn/@line-id)[1] else if (string-length($rwn/@line-id) > 0) then ($rwn/@line-id)[1] else ()
 return 
 if (string-length($ll) > 0) then 
   <div class="row bg-light table-striped">
     <div class="col-sm-3">
       {if ($lnk) then 
        <a href="textview.html?location={$lnk}" class="font-weight-bold">{$txt}{xs:int(tokenize(tokenize($lnk, "_")[3], "-")[1])}</a>
        else $txt}
    </div>
    <div class="col-sm-7">
        <span data-target="{$lnk}" data-toggle="popover">{$ll}</span> / <span>{$rl}</span>
    </div>
    
   </div>
 else ()  
else 
 <p class="font-weight-bold">No attributions found</p>
};

declare function tlsapi:save-pb($map as map(*)){
let $seg := collection($config:tls-texts)//tei:seg[@xml:id=$map?uid]
, $cb := $seg/preceding::tei:cb[@ed=$map?wit and @n=$map?pb]
, $pb := if ($cb) then 
    <pb xmlns="http://www.tei-c.org/ns/1.0" n="{$map?pb}" ed="{$map?wit}" facs="{$cb/@facs}"/>
    else
    <pb xmlns="http://www.tei-c.org/ns/1.0" n="{$map?pb}" ed="{$map?wit}"/>    
, $newseg := xed:insert-node-at($seg, xs:integer($map?pos), $pb)
, $save := (update replace $seg with $newseg, 
           if ($cb) then update delete $cb  else ())
return "Success"
};

declare function tlsapi:showtab($map as map(*)){
let $d := collection($config:tls-data-root)//tei:div[@xml:id=$map?uuid]//div
return $d
};


declare function tlsapi:stub($map as map(*)){
() 
};
