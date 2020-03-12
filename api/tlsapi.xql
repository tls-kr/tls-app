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

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";

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
:)

declare function tlsapi:make-attribution($line-id as xs:string, $sense-id as xs:string, 
 $user as xs:string, $currentword as xs:string) as element(){
let $line := collection($config:tls-texts-root)//tei:seg[@xml:id=$line-id],
$tr := collection($config:tls-translation-root)//tei:*[@corresp=concat('#', $line-id)],
$textid := tokenize($line-id, "_")[1],
$title-en := $tr/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
$title := $line/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
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
<tls:srcline title="{$title}" target="#{$line-id}" pos="{functx:index-of-string(string-join($line/text(), ""), $word)}">{$line/text()}</tls:srcline>
<tls:line title="{$title-en}" src="{map:get($config:translation-map, $textid)}">{$tr/text()}</tls:line>
</tls:text>
<form  corresp="{$sense/parent::tei:entry/tei:form/@corresp}" orig="{$currentword}">
{$sense/parent::tei:entry/tei:form/tei:orth,
$sense/parent::tei:entry/tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]}
</form>
<sense corresp="#{$sense-id}">
{$sense/*}
</sense>
<tls:metadata resp="#{$user}" created="{current-dateTime()}">
<respStmt>{if (("tls-editor") = sm:id()//sm:group/text()) then 
<resp>added and approved</resp> else
<resp>added</resp>}
<name>{$user}</name>
</respStmt>
</tls:metadata>
</tls:ann>
return
$newswl
};

(: instead of using a uuid-named file hierarchy, this version uses one file per text to store the annotations :)
declare function tlsapi:save-swl-to-docs($line-id as xs:string, $sense-id as xs:string, 
$user as xs:string, $currentword as xs:string) {
let $data-root := "/db/apps/tls-data"
let $targetcoll := if (xmldb:collection-available($data-root || "/notes/doc")) then $data-root || "/notes/doc" else 
    concat($data-root || "/notes", xmldb:create-collection($data-root || "/notes", "doc"))
,$textid := tokenize($line-id, "_")[1]
,$docname :=  $textid || "-ann.xml"
,$newswl:=tlsapi:make-attribution($line-id, $sense-id, $user, $currentword)
,$targetdoc :=   if (doc-available(concat($targetcoll,"/",$docname))) then
                    doc(concat($targetcoll,"/", $docname)) else 
                    (
   doc(xmldb:store($targetcoll, $docname, 
  <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$textid}-ann">
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
  </teiHeader>
  <text>
      <body>
      <div><head>Annotations</head><p xml:id="{$textid}-start"></p></div>
      </body>
  </text>
</TEI>))
 ,sm:chmod(xs:anyURI($targetcoll || "/" || $docname), "rwxrwxr--")
)

let $targetnode := collection($targetcoll)//tei:seg[@xml:id=$line-id]
,$texturi := if (starts-with($textid, "CH")) then 
                xs:anyURI("/db/apps/tls-texts/chant/" || substring($textid, 1, 3) || "/" || $textid || ".xml") else ()

return 
if (sm:has-access($targetcoll, "w")) then
(
if ($targetnode) then 
 update insert $newswl into $targetnode
else

 update insert <seg  xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$line-id}"><line>{$newswl//tls:srcline/text()}</line>{$newswl}</seg> into 
 $targetdoc//tei:p[@xml:id=concat($textid, "-start")]
 
 ,data($newswl/@xml:id)
 ,sm:chmod(xs:anyURI($targetcoll || "/" || $docname), "rwxrwxr--")
 (: for the CHANT files: grant access when attribution is made :)
 ,if ($texturi) then sm:chmod($texturi, "rwxrwxr--") else ()
 )
 else "No access"
};



declare function tlsapi:save-swl-with-path($line-id as xs:string, $sense-id as xs:string, 
$notes-path as xs:string, $user as xs:string, $currentword as xs:string){

if (($line-id != "xx") and ($sense-id != "xx")) then
let $newswl:=tlsapi:make-attribution($line-id, $sense-id, $user, $currentword)
,$uuid := $newswl/tls:ann/@xml:id
,$path := concat($notes-path, substring($uuid, 6, 2))
return (
if (xmldb:collection-available($path)) then () else
(xmldb:create-collection($notes-path, substring($uuid, 6, 2)),
sm:chown(xs:anyURI($path), $user),
sm:chgrp(xs:anyURI($path), "tls-user"),
sm:chmod(xs:anyURI($path), "rwxrwxr--")
),
let $res := (xmldb:store($path, concat($uuid, ".xml"), $newswl)) 
return
if ($res) then (
sm:chown(xs:anyURI($res), $user),
sm:chgrp(xs:anyURI($res), "tls-editor"),
sm:chmod(xs:anyURI($res), "rwxrwxr--"),
"OK")
else
"Some error occurred, could not save resource")
else
"Wrong parameters received"
};


declare function tlsapi:save-swl($line-id as xs:string, $sense-id as xs:string){
let $notes-path := concat($config:tls-data-root, "/notes/new/")
let $user := sm:id()//sm:real/sm:username/text()
let $currentword := ""
return
(:tlsapi:save-swl-with-path($line-id, $sense-id, $notes-path, $user, $currentword):)
tlsapi:save-swl-to-docs($line-id, $sense-id, $user, $currentword)

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
,$para := map{
"char" : if ($rpara?word = "xx") then $swl//tei:form/tei:orth/text() else $rpara?word,
"line-id" : if ($rpara?line-id = "xx") then tokenize(substring($swl//tei:link/@target, 2), " #")[1] else $rpara?line-id,
"line" : if ($rpara?line = "xx") then $swl//tls:srcline/text() else $rpara?line,
"concept" : if ($rpara?concept = "xx") then data($swl/@concept) else $rpara?concept,
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
tlsapi:swl-dialog($para, $rpara?type)
};

declare function tlsapi:swl-dialog($para as map(), $type as xs:string){

<div id="editSWLDialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                {if ($type = "concept") then
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
                   {if ($type = "concept") then 
                <div class="form-group" id="guangyun-group">                
                    <span class="text-muted" id="guangyun-group-pl"> Press the 廣韻 button above and select the pronounciation</span>
                </div> else if ($type = "swl") then
                <div class="form-group" id="guangyun-group">     
                   {tlsapi:get-guangyun($para?char, $para?pinyin)}
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
                   {if ($type = "concept") then 
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

declare function tlsapi:get-guangyun($chars as xs:string, $pron as xs:string){
(: loop through the characters of the string $chars :)
for $char at $cc in  analyze-string($chars, ".")//fn:match/text()
return
<div id="guangyun-input-dyn-{$cc}">
<h5><strong class="ml-2">{$char}</strong></h5>
{let $r:= collection(concat($config:tls-data-root, "/guangyun"))//tx:attested-graph/tx:graph[contains(.,$char)]
return 
if ($r) then
for $g at $count in $r
let $e := $g/ancestor::tx:guangyun-entry,
$p := for $s in $e//tx:mandarin/tx:jin 
       return 
       if (string-length(normalize-space($s)) > 0) then $s else (),
$py := normalize-space(string-join($p, ';'))
return

<div class="form-check">
   { if (contains($py, $pron)) then (: todo: handle pron for binomes and more :)
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}" checked="checked"/>
   else
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}"/>
   }
   <label class="form-check-label" for="guangyun-input-{$cc}-{$count}">
     {$e/tx:gloss/text()} -  {$py}
   </label>
  </div>
  else 
  <div class="form-check">
  <input class="guangyun-input-checked" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-1" type="text" value="{$char}:"/>
   <label class="form-check-label" for="guangyun-input-{$cc}-1">
     No entry found in Guangyun. Please enter the pinyin after the character and : 
   </label>
  </div>
}
</div>
};

(: prepare the parameters for edit-sf-dialog :)
declare function tlsapi:get-sf($senseid as xs:string){
let $sense := collection($config:tls-data-root)//tei:sense[@xml:id=$senseid]
,$synfunc-id := data($sense/tei:gramGrp/tls:syn-func/@corresp)=>substring(2)
,$sfdef := tlslib:get-sf-def($synfunc-id)
,$para := map{
"def" : $sense/tei:def/text(),
"synfunc" : data($sense/tei:gramGrp/tls:syn-func/text()),  
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
<div id="edit-sf-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Change <span class="">syntactic function</span> for <span>{$para?zi}&#160;({$para?pinyin})</span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    ×
                </button>
            </div>
            <div class="modal-body"> 
                <h6 class="text-muted">Sense:  <span id="def-span" class="ml-2">{$para?def}</span></h6>
                <h6 class="text-muted">Current SF:  <span id="old-sf-span" class="ml-2">{$para?synfunc}</span></h6>
                <h6 class="text-muted">SF Definition:  <span id="def-old-sf-span" class="ml-2">{$para?sfdef}</span></h6>
            <div>
            <span id="sense-id-span" style="display:none;">{$para?sense-id}</span>
            <span id="synfunc-id-span" style="display:none;">{$para?synfunc-id}</span>
                <div class="form-row">
                <div id="select-synfunc-group" class="form-group ui-widget col-md-6">
                    <label for="select-synfunc">New syntactic function: </label>
                    <input id="select-synfunc" class="form-control" required="true" value="{$para?synfunc}"></input>
                </div>
                <!--
                <div id="select-semfeat-group" class="form-group ui-widget col-md-6">
                    <label for="select-semfeat">Semantic feature: </label>
                    <input id="select-semfeat" class="form-control" value="{$para?semfeat}"/>
                </div> -->
                </div>
                <div id="input-def-group">
                    <label for="input-def">Definition (if creating new SF)</label>
                    <textarea id="input-def" class="form-control"></textarea>                   
                </div>
            </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                <button type="button" class="btn btn-primary" onclick="save_sf()">Save</button>
          </div>
       
       </div>
       </div>   
</div>
};

(:~
: This is called when a term is selected in the textview // get_sw in tls-app.js
:)
declare function tlsapi:get-sw($word as xs:string, $context as xs:string) as item()* {
let $words := collection(concat($config:tls-data-root, '/concepts/'))//tei:orth[. = $word]
let $user := sm:id()//sm:real/sm:username/text()
, $doann := contains($context, 'textview')  (: the page we were called from can annotate :)
, $taxdoc := doc($config:tls-data-root ||"/core/taxchar.xml")
(: creating a map as a combination of the concepts in taxchar and the existing concepts :)
, $wm := map:merge((
    for $w in $words
    let $concept := $w/ancestor::tei:div/tei:head/text(),
    $concept-id := $w/ancestor::tei:div/@xml:id,
    $py := $w/parent::tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]/text(),
    $zi := $w/parent::tei:form/tei:orth/text()
    return map:entry($concept-id, map {"concept": $concept, "py" : $py, "zi" : $zi})
    ,
    for $c in $taxdoc//tei:div[tei:head[. = $word]]//tei:ref
        let $s := $c/ancestor::tei:list/preceding::tei:item[@type='pron'][1]/text()
        let $pys := tokenize(normalize-space($s), '\s+')        
        , $py := if (tlslib:iskanji($pys[1])) then $pys[2] else $pys[1]
        return map:entry(substring($c/@target, 2), map {"concept": $c/text(), "py" : $py, "zi" : $word})
    ))          
return
if (map:size($wm) > 0) then
for $id in map:keys($wm)
let $concept := map:get($wm($id), "concept"),
$w := collection(concat($config:tls-data-root, '/concepts/'))//tei:div[@xml:id = $id]//tei:orth[. = $word]
,$cdef := $w/ancestor::tei:div/tei:div[@type="definition"]/tei:p/text(),
$wid := $w/ancestor::tei:entry/@xml:id,
$form := $w/parent::tei:form/@corresp,
$zi := map:get($wm($id), "zi"),
$py := map:get($wm($id), "py"),
$scnt := count($w/ancestor::tei:entry/tei:sense)
(:group by $concept:)
order by $concept
return
<li class="mb-3">
{if ($zi) then
<span><strong>{$zi}</strong>&#160;({$py})&#160;</span> else ()}
<strong><a href="concept.html?uuid={$id}" title="{$cdef}" class="{if ($scnt = 0) then 'text-muted' else ()}">{$concept}</a></strong> 

{if ($doann and sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then 
 if ($wid) then     
 <button class="btn badge badge-secondary ml-2" type="button" 
 onclick="show_newsw({{'wid':'{$wid}','py': '{$py}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">
           New SW
      </button>
else 
<button class="btn badge badge-secondary ml-2" type="button" 
onclick="show_newsw({{'wid':'xx', 'py': '{$py}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">
           New Word
      </button>
   else ()}

{if ($scnt > 0) then      
<span>      
<button title="click to reveal {count($w/ancestor::tei:entry/tei:sense)} syntactic words" class="btn badge badge-light" type="button" data-toggle="collapse" data-target="#{$id}-concept">{$scnt}</button>
<ul class="list-unstyled collapse" id="{$id}-concept" style="swl-bullet">{for $s in $w/ancestor::tei:entry/tei:sense
let $sf := $s//tls:syn-func,
$sfid := substring($sf/@corresp, 2),
$sm := $s//tls:sem-feat/text(),
$def := $s//tei:def/text(),
$sid := $s/@xml:id,
$edit := sm:id()//sm:groups/sm:group[. = "tls-editor"] and $doann,
$click := if ($edit) then concat("get_sf('" , $sid , "')") else "",
$atts := count(collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = "#" || $sid])
order by $sf
(:  :)
return
<li>
<span id="pop-{$s/@xml:id}" class="small btn">●</span>

<a href="#" onclick="{$click}" title="{tlslib:get-sf-def($sfid)}">{$sf/text()}</a>&#160;{$sm}: 
<span class="swedit" id="def-{$sid}" contenteditable="{if ($edit) then 'true' else 'false'}">{ $def}</span>
    {if ($edit) then 
     <button class="btn badge badge-warning ml-2" type="button" onclick="save_def('def-{$sid}')">
           Save
     </button>
    else ()}
     { if (sm:is-authenticated()) then 
     (
     if ($user != 'test' and $doann) then
     <button class="btn badge badge-primary ml-2" type="button" onclick="save_this_swl('{$s/@xml:id}')">
           Use
      </button> else (),
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$sid}-resp" onclick="show_att('{$sid}')">
      <span class="ml-2">SWL: {$atts}</span>
      </button>
      
      )
      else () }
      <div id="{$sid}-resp" class="collapse container"></div>
</li>
}
</ul>
</span> 
else ()
}
</li>
else 
<li class="list-group-item">No word selected or no existing syntactic word found.</li>
};

declare function tlsapi:get-text-preview($loc as xs:string){

let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id = $loc],
$title := $seg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
$pseg := $seg/preceding::tei:seg[fn:position() < 5],
$fseg := $seg/following::tei:seg[fn:position() < 5],
$dseg := ($pseg, $seg, $fseg)
return
<div class="popover" role="tooltip">
<div class="arrow"></div>
<h3 class="popover-header">
<a href="textview.html?location={$loc}">{$title}</a></h3>
<div class="popover-body">
    {
for $d in $dseg 
return 
    tlslib:display-seg($d, map{"ann": "false", "loc": $loc})
    }
</div>
</div>
};
(: Save a new SW to an existing concept.   UPDATE: word is also created if ncessessary :) 
declare function tlsapi:save-newsw($rpara as map(*)) {
 let $user := sm:id()//sm:real/sm:username/text()
 let $concept-word := collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]//tei:entry[@xml:id=$rpara?wuid],
 $concept-doc := if ($concept-word) then $concept-word else collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]//tei:div[@type="words"],
 $wuid := if ($concept-word) then $rpara?wuid else "uuid-" || util:uuid(),
 $suid := concat("uuid-", util:uuid()),
 $newsense := 
<sense xml:id="{$suid}" resp="#{$user}" tls:created="{current-dateTime()}" xmlns="http://www.tei-c.org/ns/1.0" 
xmlns:tls="http://hxwd.org/ns/1.0">
<gramGrp><pos>{upper-case(substring($rpara?synfunc-val, 1,1))}</pos>
  <tls:syn-func corresp="#{$rpara?synfunc}">{translate($rpara?synfunc-val, ' ', '+')}</tls:syn-func>
  {if ($rpara?semfeat) then 
  <tls:sem-feat corresp="#{$rpara?semfeat}">{translate($rpara?semfeat-val, ' ', '')}</tls:sem-feat>
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

declare function tlsapi:save-to-concept($rpara as map(*)) {

let $user := sm:id()//sm:real/sm:username/text()
(:  if no gy record is found, we return a string like this for guangyun-id "黃:huangxxx蘗:bo" :)
let $gys :=    
   for $gid in tokenize(normalize-space($rpara?guangyun-id), "xxx") 
   let $r :=  collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$gid]
   return
   if ($r) then $r else $gid

 
 let $form :=
(:   let $e := collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$gid],:)
    let $oc := for $gy in $gys
        let $rec := if ($gy instance of element()) then $gy//tx:old-chinese/tx:pan-wuyun/tx:oc/text() else ()
        return if ($rec) then $rec else "--"
    ,$mc := for $gy in $gys 
        let $rec := if ($gy instance of element()) then $gy//tx:middle-chinese//tx:baxter/text() else ()
        return if ($rec) then $rec else "--"
    ,$p := for $gy in $gys 
         let $rec := if ($gy instance of element()) then
            for $s in $gy//tx:mandarin/*
             return
             if (string-length(normalize-space($s)) > 0) then $s/text() else () else ()
         return 
         if ($rec) then $rec else
         tokenize($gy, ":")[2] ,
    $gr := for $gy in $gys
      let $r := if ($gy instance of element()) then normalize-space($gy//tx:attested-graph/tx:graph/text()) else ()
      return
      if ($r) then $r else tokenize($gy, ":")[1] 
return
    <form xmlns="http://www.tei-c.org/ns/1.0" corresp="#{replace($rpara?guangyun-id, "xxx", " #")}">
    <orth>{string-join($gr, "")}</orth>
    <pron xml:lang="zh-Latn-x-pinyin">{string-join($p, " ")}</pron>
    <pron xml:lang="zh-x-mc" resp="rec:baxter">{string-join($mc, " ")}</pron>
    <pron xml:lang="zh-x-oc" resp="rec:pan-wuyun">{string-join($oc, " ")}</pron>
    </form>,

 
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
 tlslib:show-att-display($a)
else 
 <p class="font-weight-bold">No attributions found</p>
};
(:~
 Delete a syntactic word location.  We return the line-id, so that we can display the updated attributions.
:)
declare function tlsapi:delete-swl($uid as xs:string) {
let $swl := collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$uid]
,$link := substring(tokenize($swl/tei:link/@target)[1], 2)
,$res := update delete $swl
return $link
};

declare function tlsapi:delete-word-from-concept($id as xs:string, $type as xs:string) {
let $item := if ($type = 'word') then 
   collection($config:tls-data-root|| "/concepts")//tei:entry[@xml:id=$id]
   else
   collection($config:tls-data-root|| "/concepts")//tei:sense[@xml:id=$id]
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
, $str := 'collection("/db/apps/tls-data")//tls:' || $type || '[@corresp ="' || $key || '"]'
let $res := for $r in util:eval($str)
     (:where exists($r/ancestor::tei:sense):)
     return $r

return

if (count($res) > 0) then
for $r in subsequence($res, 1, 10)
  let $sw := $r/ancestor::tei:sense
  return
  tlslib:display-sense($sw, -1)
else 

concat("No usage examples found for key: ", $key, " type: ", $type )

};

(: safe_sf.xql tlsapi:save-sf($sense-id, $synfunc-id, $def) :)
declare function tlsapi:save-sf($sense-id as xs:string, $synfunc-id as xs:string, $synfunc-val as xs:string, $def as xs:string){
let $newsf-id := if ($synfunc-id = 'xxx') then (
  tlslib:new-syn-func ($synfunc-val, $def)
) else ($synfunc-id)
,$pos := <pos xmlns="http://www.tei-c.org/ns/1.0">{upper-case(substring($synfunc-val, 1, 1))}</pos>
,$sf :=  <tls:syn-func corresp="#{$newsf-id}">{$synfunc-val}</tls:syn-func>
,$sense := collection($config:tls-data-root)//tei:sense[@xml:id = $sense-id]
,$upd := update replace $sense/tei:gramGrp/tei:pos with $pos 
,$upd := update replace $sense/tei:gramGrp/tls:syn-func with $sf
,$gramgrp := $sense/tei:gramGrp
,$a := for $s in collection($config:tls-data-root)//tls:ann/tei:sense[@corresp = "#" || $sense-id]
  return
  update replace $s/tei:gramGrp with $gramgrp

return 
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
 : Save the translation (or comment)
 : 3/11: Get the file from the correct slot!
:)
declare function tlsapi:save-tr($trid as xs:string, $tr as xs:string, $lang as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
let $id := substring($trid, 1, string-length($trid) -3)
,$txtid := tokenize($id, "_")[1]
,$slots := if (ends-with($trid, '-tr')) then 'slot1' else 'slot2'
,$slot := session:get-attribute($slots)
,$transl := root(collection("/db/apps/tls-data")//tei:bibl[@corresp="#"||$txtid]/ancestor::tei:fileDesc//tei:editor[@role='translator'][$slot])
,$trcoll := concat($config:tls-translation-root, "/", $lang)
,$trcollavailable := xmldb:collection-available($trcoll) or 
  (xmldb:create-collection($config:tls-translation-root, $lang),
  sm:chown(xs:anyURI($trcoll), "tls"),
  sm:chgrp(xs:anyURI($trcoll), "tls-user"),
  sm:chmod(xs:anyURI($trcoll), "rwxrwxr--")
  )
,$docpath := if ($transl) then document-uri($transl) else concat($trcoll, "/", $txtid, "-", $lang, ".xml")
,$title := collection($config:tls-texts-root)//tei:TEI[@xml:id=$txtid]//tei:titleStmt/tei:title/text()
,$seg := <seg xmlns="http://www.tei-c.org/ns/1.0" corresp="#{$id}" xml:lang="{$lang}" resp="{$user}" modified="{current-dateTime()}">{$tr}</seg>
let $doc :=
  if (not (doc-available($docpath))) then
   doc(xmldb:store($trcoll, concat($txtid, "-", $lang, ".xml"), 
   <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$txtid}-{$lang}">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Translation of {$title} into ({$lang})</title>
            <editor role="translator">TLS Project</editor>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
            <p>Translation of <bibl corresp="#{$txtid}">
                  <title xml:lang="och">{$title}</title>
               </bibl> into <lang xml:lang="en">English</lang>.</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Translated parts</head><p xml:id="{$txtid}-start"></p></div>
      </body>
  </text>
</TEI>)) 
 else doc($docpath)
,$node := $doc//tei:seg[@corresp=concat("#", $id)]
 
return
(: The return values are wrong: update always returns the empty sequence :)
if ($node) then 
if (update replace $node[1] with $seg) then "Success. Updated translation." else "Could not update translation." 
else 
if ($doc//tei:p[@xml:id=concat($txtid, "-start")]) then 
  update insert $seg  into $doc//tei:p[@xml:id=concat($txtid, "-start")] 
else 
 (: mostly for existing translations.  Here we simple append it to the very end. :)
 update insert $seg  into ($doc//tei:p[last()])[1]
};



(: The bookmark will also serve as template for intertextual links and anthology, which is why we also save word and line :)
 
declare function tlsapi:save-bookmark($word as xs:string, $line-id as xs:string, $line as xs:string) {
let $user := sm:id()//sm:real/sm:username/text()
,$docpath := $config:tls-user-root || $user|| "/bookmarks.xml"
,$txtid := tokenize($line-id, "_")[1]
,$juan := tlslib:get-juan($line-id)
,$title := tlslib:get-title($txtid)
,$item := <item xmlns="http://www.tei-c.org/ns/1.0" modified="{current-dateTime()}"><ref target="{$line-id}">{$title} {$juan}</ref>
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
      <list xml:id="bookmarklist-{$user}">
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
