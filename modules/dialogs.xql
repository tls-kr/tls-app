xquery version "3.1";
(:~
: This module provides the functions that produce dialogs

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)
module namespace dialogs="http://hxwd.org/dialogs"; 

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
import module namespace functx="http://www.functx.com" at "../modules/functx.xql";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
(: import module namespace tlsapi="http://hxwd.org/tlsapi" at "../api/tlsapi.xql"; :)
import module namespace con='http://hxwd.org/con' at "../modules/concepts.xql"; 

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";

declare variable $dialogs:lmap := map{
"concept" : "Concepts",
"definition" : "Definition",
"notes" : "Criteria and general notes",
"old-chinese-criteria" : "Old Chinese Criteria",
"modern-chinese-criteria" : "Modern Chinese Criteria",
"tax-def" : map{
"taxonymy" : "Hypernym",
"antonymy" : "Antonym",
"hypernymy" : "Hyponym",
"see" : "See also"},
"source-references" : "Bibliography",
"warring-states-currency" : "Warring States Currency",
"register" : "Register",
"words" : "Words",
"none" : "Texts or Translation",
"old-chinese-contrasts" : "Old Chinese Contrasts",
"pointers" : "Pointers"
};

(: 2021-11-30: extending this functionality to cover observations of type block defined in facts.xml :)

declare function dialogs:add-rd-dialog($options as map(*)){
 let $blocktypes := collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:body/tei:div[@type='block']
 return
 <div id="add-rd-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Add <select id="block-type"  onChange="modify_rd_dialog()">{for $l in $blocktypes return 
            <option value="{data($l/@xml:id)}">{$l/tei:head/text()}</option>}</select>, starting at: &#160;<span class="font-weight-bold">{$options?word}</span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
                <h6 class="font-weight-bold">Begin:  
                <!-- <span id="concept-line-id-span" class="ml-2">{$options?line-id}</span>&#160; -->
                <span id="concept-line-text-span" class="chn-font ml-2">{$options?line}</span></h6>
                
                
            <div class="form-row">
              <div id="select-end-group" class="form-group col-md-4">
                <label for="select-end" class="font-weight-bold">Select end of assignment (
                <button class="btn badge badge-primary" type="button" onclick="get_more_lines('{$options?line-id}')" title="Press here to add more lines">＞</button>):</label>
                 <select class="form-control chn-font" id="select-end">
                   <option value="{$options?line-id}">{$options?line}</option>
                  {for $s in tlslib:next-n-segs($options?line-id, 20)
                    return
                    <option value="{$s/@xml:id}">{$s/text()}</option>
                   } 
                 </select>                 
              </div>
              <div id="input-note-group" class="col-md-8">
                    <label for="input-note" class="font-weight-bold">Note:</label>
                    <textarea id="input-note" class="form-control"></textarea>                   
              </div>
              
            </div>    

            <div class="form-row">
              <div id="rhetdev" class="form-group ui-widget col-md-4 obs-block">
                 <label for="select-rhetdev" class="font-weight-bold">Name of <span id="block-name">Rhetorical Device</span>: </label>
                 <input id="select-rhetdev" class="form-control" required="true" value=""/>
                 <span id="rhetdev-id-span" style="display:none;"></span>
              </div>
            </div>
           </div>
        <!-- footer -->
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_rdl('{$options?word}', '{$options?line-id}', '{$options?line}')">Save</button>
           </div>
        <!-- footer end -->
       </div>
     </div>
 </div>
};

declare function dialogs:new-concept-dialog($options as map(*)){
 let $ex := collection($config:tls-data-root || "/concepts")//tei:head[. = $options?concept]
 return
 if ($ex) then "Concept exists!" else 

 let $uuid := if (map:contains($options, "concept-id")) 
    then $options?concept-id else
    if (map:contains($options, "name")) then map:get($con:new-concepts($options?name), "id") else 
    "uuid-" || util:uuid()
   , $def := if ($uuid) then if (map:contains($con:new-concept-defs, $uuid)) then $con:new-concept-defs($uuid) else () else ()
   , $name := if(map:contains($options, "concept")) then $options?concept else 
    if (not($options?mode = "new" or $options?mode = "existing")) then $options?mode else ()
   return
   <div id="new-concept-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Define a new concept: <span class="font-weight-bold">{$name}</span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <div class="form-row">
              <div id="input-def-group" class="col-md-6">
                 <label for="name-och" class="font-weight-bold">Old Chinese name:</label>
                 <input id="name-och" class="form-control" required="true" value=""></input>
              </div>
              <div id="input-def-group" class="col-md-6">
                 <label for="name-zh" class="font-weight-bold">Modern Chinese name:</label>
                 <input id="name-zh" class="form-control" required="true" value=""></input>
              </div>
            </div>
            <div class="form-row">
              <div id="input-def-group" class="col-md-6">
                    <label for="input-def" class="font-weight-bold">Definition </label>
                    <textarea id="input-def" class="form-control">{$def}</textarea>                   
              </div>
              <div id="select-name-group" class="form-group ui-widget col-md-6">
                 <label for="select-name" class="font-weight-bold">Alternate labels</label>
                 <small class="text-muted"><br/>Comma separated list of other names for this concept</small>
                 <input id="select-labels" class="form-control" required="true" value=""></input>
                 <span id="name-id-span" style="display:none;">{$uuid}</span>
              </div>
            </div>
            <h6 class="font-weight-bold">Place this concept within the ontology</h6>
            <div id="staging" style="display:none;" class="form-row">
              <div id="stag-taxonymy" class="col-md-3"><label class="font-weight-bold mr-3" for="stag-taxonymy">Hypernym</label><span id="stag-taxonymy-span" class="staging-span"></span></div>
              <div id="stag-antonymy"  class="col-md-3"><label  class="font-weight-bold  mr-3" for="stag-antonymy">Antonymy</label><span id="stag-antonymy-span"  class="staging-span"></span></div>
              <div id="stag-hypernymy"  class="col-md-3"><label  class="font-weight-bold  mr-3" for="stag-hypernymy">Hyponym</label><span id="stag-hypernymy-span"  class="staging-span"></span></div>
              <div id="stag-see"  class="col-md-3"><label  class="font-weight-bold  mr-3" for="stag-see">See also</label><span id="stag-see-span" class="staging-span"></span></div>
            </div>
            <div class="form-row">
              <div id="select-tax-group" class="form-group col-md-4">
                <label for="select-tax">Type of relation: </label>
                 <select class="form-control" id="select-tax">
                  {for $l in map:keys($dialogs:lmap?tax-def)
                    order by $l
                    return
                    if ($l = "taxonymy") then
                    <option value="{$l}" selected="true">{$dialogs:lmap?tax-def($l)}</option>
                    else
                    <option value="{$l}">{$dialogs:lmap?tax-def($l)}</option>
                   } 
                 </select>                 
              </div>
              <div id="select-concept-group-nc" class="form-group ui-widget col-md-4">
                 <label for="select-concept-nc">Name of related concept: </label>
                 <input id="select-concept-nc" class="form-control" required="true" value=""/>
                 <span id="concept-id-span-nc" style="display:none;"></span>
                </div>
              <div class="form-group col-md-4">
                <label>Press here to add the concept</label>
                <button class="btn btn-primary" type="button" onclick="add_to_tax()" id="add-to-pointers">Add to ontology</button>
                <button class="btn btn-secondary" type="button" onclick="reset_tax()" title="Remove the selected concepts from the ontology and start fresh" id="reset-to-pointers">Reset</button>
              </div>   
              </div>  
            <div class="form-row">
              <div id="input-crit-group" class="col-md-6">
                    <label for="input-crit" class="font-weight-bold">Old Chinese Criteria </label>
                    <textarea id="input-crit" class="form-control"></textarea>                   
              </div>
              <div id="input-notes-group" class="col-md-6">
                    <label for="input-notes" class="font-weight-bold">Modern Chinese Criteria &amp; other notes</label>
                    <textarea id="input-notes" class="form-control"></textarea>                   
              </div>
            </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_new_concept('{$uuid}', '{$name}')">Save New Concept</button>
           </div>
         </div>
     </div>
</div>

};

declare function dialogs:review-swl-dialog($uuid as xs:string){
 let $swl := collection($config:tls-data-root || "/notes")//tls:ann[@xml:id=$uuid],
 (: "[M01]/[D01]/[Y0001] at [H01]:[m01]:[s01]" :)
 $seg-id:=$swl/parent::tei:seg/@xml:id,
 $creator-id := substring($swl/tls:metadata/@resp, 2),
 $score := if ($swl/tls:metadata/@score) then data($swl/tls:metadata/@score) else 0,
 $date := format-dateTime(xs:dateTime($swl/tls:metadata/@created),"[MNn] [D1o], [Y] at [h].[m01][Pn]"),
 $creator := doc("/db/apps/tls-data/vault/members.xml")//tei:person[@xml:id=$creator-id]
 return
 <div id="review-swl-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Review SWL <span class="pl-5">Current score: <span class="font-weight-bold">{$score}</span></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Existing SWL <small>created by {$creator//tei:persName/text()}, {$date}</small></h6>
            <div class="card-text">{tlslib:format-swl($swl, map{'type': 'row', 'context' : 'review'})}</div>
            <h6 class="font-weight-bold mt-2">Context</h6>
            {tlslib:get-text-preview($seg-id, map{"context" : 3, "format" : "plain"})}
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
             $cr2 := doc("/db/apps/tls-data/vault/members.xml")//tei:person[@xml:id=$cr2-id]//tei:persName/text()
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

(:~
 : associate a SW with a pronounciation. Retrieve the existing one and offer a change
      url : "api/responder.xql?func=dialogs:assign-guangyun&char="+para.zi+"&concept_id=" + para.concept_id + "&pinyin="+para.py+"&concept="+para.concept+"&wid="+para.wid, 

:)

declare function dialogs:assign-guangyun($para as map(*)){
let $type := if ($para?type) then $para?type else "concept"
return
<div id="assign-guangyun" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                {if ($para?concept='undefined') then 
                <h5 class="modal-title">Existing pinyin entries for: <strong class="ml-2"><span id="{$type}-query-span">{$para?char}</span></strong></h5>
                else
                <h5 class="modal-title">Assign pinyin for: <strong class="ml-2"><span id="{$type}-query-span">{$para?char}</span></strong> in <strong>{$para?concept}</strong></h5>
                }
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">
                    ×
                </button>
            </div>
            <div class="modal-body">
                 <div id="input-char-group">
                    <label for="input-char"><strong>Characters</strong> <br/><small class="text-muted">If you alter the characters, please press <button class="btn badge badge-primary ml-2" type="button" onclick="get_guangyun()">
                        廣韻
                    </button> to update the readings. </small></label>
                    <input id="input-char" class="form-control chn-font" value="{$para?char}"/>                   
                </div>

            <p class="text-muted"><small>{if (string-length($para?pinyin) > 0 and string-length($para?wid) > 0) then <span>Currently {$para?pinyin} is assigned. </span> else (), <span>Please select a pronounciation or enter a new one:</span>}</small></p>
                <div class="form-group chn-font" id="guangyun-group">               
                {tlslib:get-guangyun($para?char, 'xx', false())}
                </div>
                <small class="text-muted">Sources/Notes and Glosses are only used for readings not from 廣韻</small>
                <div class="form-row">
                <div id="sources-group" class="form-group ui-widget col-md-12">
                    <label for="sources"><strong>Sources/Notes:</strong> </label>
                    <input id="sources" class="form-control" required="true" value="{$para?sources}"/>
                </div>
                <!--
                <div id="select-semfeat-group" class="form-group ui-widget col-md-6">
                    <label for="select-semfeat">Semantic feature: </label>
                    <input id="select-semfeat" class="form-control" value="{$para?semfeat}"/>
                </div> -->
                </div>
                <small class="text-muted">Please add a short English gloss that allows to distinguish this reading</small>
                <div id="input-gloss-group">
                    <label for="input-gloss"><strong>Gloss:</strong> </label>
                    <textarea id="input-gloss" class="form-control">{$para?gloss}</textarea>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                {if ($para?concept='undefined') then () else
                <button type="button" class="btn btn-primary" onclick="save_updated_pinyin('{$para?concept_id}', '{$para?wid}','{$para?char}', '{$para?pos}')">Save changes</button>}
            </div>
        </div>
    </div>    
    <!-- temp -->
    
</div>    
};

declare function dialogs:update-gloss($para as map(*)){
let $type := if ($para?type) then $para?type else "concept"
return
<div id="update-gloss" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Update gloss for: <strong class="ml-2"><span id="{$type}-query-span">{$para?char}</span></strong> as <strong>{$para?pinyin}</strong>
                </h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">
                    ×
                </button>
            </div>
            <div class="modal-body">
                <small class="text-muted">Please add a short English gloss that allows to distinguish this reading</small>
                <div id="input-gloss-group">
                    <label for="input-gloss"><strong>Gloss:</strong> </label>
                    <textarea id="input-gloss" class="form-control">{$para?gloss}</textarea>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                <button type="button" class="btn btn-primary" onclick="save_updated_gloss('{$para?uuid}','{$para?char}', '{$para?pos}')">Save changes</button>
            </div>
        </div>
    </div>    
    <!-- temp -->
    
</div>    
};

declare function dialogs:new-syn-dialog($para as map(*)){
<div id="new-syn-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Define synonyms for concept {$para?concept} ({$para?char}) </h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold"></h6>
                <small class="text-muted">Add the contrasts and antonyms for this concept:</small>
                <div id="input-gloss-group">
                    <label for="input-crit"><strong>Old Chinese criteria:</strong> </label>
                    <textarea id="input-crit" class="form-control">{$para?crit}</textarea>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_syn({{'concept_id': '{$para?concept-id}', 'concept' : '{$para?concept}'}})">Save</button>
           </div>
         </div>
     </div>
</div>
};

declare function dialogs:edit-textdate($para as map(*)){
<div id="edit-textdate-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Creation date for text</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">{$para?textid}: {tlslib:get-title($para?textid)}</h6>
                <small class="text-muted">A text date consists of the (1) lower (<span class="font-weight-bold">not-before</span>) and (2) upper limits (<span class="font-weight-bold">not-after</span>) as well as (3) a human readable form. (1) and (2) should be positive integers for AD years and negative integers for BC years.</small>
                <div id="input-nb-group">
                    <label for="input-nb"><strong>(1) lower limit (not-before)</strong> </label>
                    <input id="input-nb" class="form-control" value="{if ($para?nb ne "undefined") then $para?nb else ()}"/>
                </div>
                <div id="input-na-group">
                    <label for="input-na"><strong>(2) upper limit (not-after)</strong> </label>
                    <input id="input-na" class="form-control" value="{if ($para?na ne "undefined") then $para?na else ()}"/>
                </div>
                <div id="input-prose-group">
                    <label for="input-prose"><strong>(3) Prose (displayed form)</strong> </label>
                    <textarea id="input-prose" class="form-control">{if ($para?prose ne "undefined") then $para?prose else ()}</textarea>
                </div>
                <div id="input-src-group">
                    <label for="input-src"><strong>Note</strong> </label>
                    <textarea id="input-src" class="form-control">{if ($para?src ne "undefined") then $para?src else ()}</textarea>
                </div>
            
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_textdate('{$para?textid}')">Save</button>
           </div>
         </div>
     </div>
</div>
};

declare function dialogs:dialog-stub(){
<div id="dialog-stub" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold"></h6>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_swl_review('{$uuid}')">Save</button>
           </div>
         </div>
     </div>
</div>
};

declare function dialogs:move-word($map as map(*)){
let $cid := collection($config:tls-data-root||"/concepts")//tei:*[@xml:id=$map?wid]/ancestor::tei:div[@type="concept"]
return
<div id="move-word-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Move {$map?word} from {$cid/tei:head/text()} to another concept</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Select the target concept:</h6>
            <div>
                <span id="concept-id-span" style="display:none;"></span>
                <div id="select-concept-group" class="form-group ui-widget">
                    <input id="select-concept" class="form-control" required="true" value=""/>
                </div>
            <p>There are {$map?count} attributions, so this might take a while.</p>
            </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="do_move_word('{$map?word}', '{$map?wid}', '{$map?type}')">Move</button>
           </div>
         </div>
     </div>
</div>
};

declare function dialogs:merge-word($map as map(*)){
let $eid := collection($config:tls-data-root||"/concepts")//tei:*[@xml:id=$map?wid]/ancestor::tei:entry
return
<div id="merge-word-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Delete {$map?word} and move existing annotation(s) to another SW</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Select the target:</h6>
              <div id="select-target-div" class="form-group">
                 <select class="form-control" id="select-target">
                  {for $s in $eid//tei:sense
                    where not ($map?wid = $s/@xml:id)
                    return
                    <option value="{$s/@xml:id}">{$s//tls:syn-func/text() || " | " || $s//tls:sem-feat/text() ||" " || $s//tei:def/text()}</option>
                   } 
                 </select>                 
              </div>
            
            <div>
            <p>There are {$map?count} attributions, so this might take a while.</p>
            </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="do_merge_word('{$map?wid}')">Merge</button>
           </div>
         </div>
     </div>
</div>
};



declare function dialogs:punc-dialog($map as map(*)){
 let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?uid]
 , $pseg := $seg/preceding::tei:seg[1]
 , $nseg := $seg/following::tei:seg[1]
 , $type := $seg/@type
 return
 <div id="punc-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Edit current text segment <small class="text-muted ">{$map?uid}</small></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Previous segment</h6>
            <div class="card-text chn-font"><small class="text-muted">{$pseg//text()}</small></div>
            <div class="form row">
            <div class="text-muted text-right mt-2 col-md-3">　</div>
            <div class="mt-2 col-md-2"><span class="text-muted">Splitting characters:</span> </div>
            <div class="mt-2 col-md-4"><span class="text-muted chn-font">{$config:seg-split-tokens}</span></div>
            </div>
            <div class="form row">
            <div class="font-weight-bold mt-2 col-md-3">Current text segment</div>
            <div class="text-muted mt-2 col-md-2">Type:</div>
            <div class="form-group col-md-4"><select class="form-control" id="type">
                  {for $s in map:keys($config:seg-types)
                    return
                    if ($type = $s ) then 
                    <option value="{$s}" selected="true">{map:get($config:seg-types, $s)}</option>                    
                    else
                    <option value="{$s}">{map:get($config:seg-types, $s)}</option>
                   } 
                 </select>                 </div>
                 </div>     
            <div class="card-text chn-font" contenteditable="true" id="current-seg">{tlslib:proc-seg-for-edit($seg)  => string-join('') => normalize-space() => replace(' ', '')}</div>
            <div class="form row"><div class="mt-2 col-md-12"><small>IMPORTANT: <span class="font-weight-bold">'$'</span> characters represent important information not shown here, please do not remove!</small></div></div>
            <h6 class="font-weight-bold">Following segment</h6>
            <div class="card-text chn-font"><small class="text-muted">{$nseg//text()}</small></div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', 'no_split')">Save but don't split</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', '')">Save text and close</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', '{$nseg/@xml:id}')">Save text and continue</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', 'merge')">Merge with following segment</button>
           </div>
     </div>
     </div>
</div>
};

declare function dialogs:app-dialog($map as map(*)){
 let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?uid]
 , $pseg := $seg/preceding::tei:seg[1]
 , $nseg := $seg/following::tei:seg[1]
 , $type := $seg/@type
 , $dialog-title := <h5>Edit current text segment <small class="text-muted ">{$map?uid}</small></h5> 
 return
 <div id="app-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">{$dialog-title}
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Previous segment</h6>
            <div class="card-text chn-font"><small class="text-muted">{$pseg//text()}</small></div>
            <div class="form row">
            <div class="font-weight-bold mt-2 col-md-3">Current text segment</div>
            <div class="text-muted mt-2 col-md-2">Type:</div>
            <div class="form-group col-md-4"><select class="form-control" id="type">
                  {for $s in map:keys($config:seg-types)
                    return
                    if ($type = $s ) then 
                    <option value="{$s}" selected="true">{map:get($config:seg-types, $s)}</option>                    
                    else
                    <option value="{$s}">{map:get($config:seg-types, $s)}</option>
                   } 
                 </select>                 </div>
                 </div>     
            <div class="card-text chn-font" contenteditable="true" id="current-seg">{tlslib:proc-seg-for-edit($seg)  => string-join('') => normalize-space() => replace(' ', '')}</div>
            <div class="form row"><div class="mt-2 col-md-12"><small>IMPORTANT: <span class="font-weight-bold">'$'</span> characters represent important information not shown here, please do not remove!</small></div></div>
            <h6 class="font-weight-bold">Following segment</h6>
            <div class="card-text chn-font"><small class="text-muted">{$nseg//text()}</small></div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', 'no_split')">Save but don't split</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', '')">Save text and close</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', '{$nseg/@xml:id}')">Save text and continue</button>
                <button type="button" class="btn btn-primary" onclick="save_punc('{$map?uid}', 'merge')">Merge with following segment</button>
           </div>
     </div>
     </div>
</div>
};


declare function dialogs:edit-text-permissions-dialog($map as map(*)) as node() {
let $textid := tokenize($map?location, "_")[1],
    $cur-allowed-users := doc("/db/users/tls-admin/permissions.xml")//tls:text-permissions[@text-id = $textid]/tls:allow-review/@user-id
return
<div id="edit-text-permissions-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Change editing permissions <small class="text-muted ">{$textid}</small></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
                <h6 class="font-weight-bold">Users that currently may edit this text:</h6>
                <div id="edit-text-permissions-dialog-remove-users-container">
                    {
                        for $gm in sm:get-group-members("tls-punc")
                        where ($cur-allowed-users = $gm)
                        return
                            <div id="editing-permissions-remove-{$textid}-{$gm}">{$gm} 
                                <button type="button" class="btn" onclick="remove_editing_permissions('{$textid}', '{$gm}')"
                                        title="Remove editing permission for user {$gm}">
                                    <img class="icon" src="resources/icons/open-iconic-master/svg/x.svg" /> 
                                </button>
                            </div>

                    }
                </div>
                <small class="text-muted ">( + all in the tls-editor group)</small>
                <br /><br />
                <h6 class="font-weight-bold">Users in tls-punc group without editing permission:</h6>

                <div class="form-group col-md-4"><select class="form-control" id="edit-text-permissions-dialog-add-users-select">
                    {
                        for $gm in sm:get-group-members("tls-punc")
                        where not($cur-allowed-users = $gm or sm:get-group-members("tls-editor") = $gm)
                        return
                            <option value="{$gm}">{$gm}</option>
                    } 
                </select></div>
                <button type="button" class="btn btn-primary" onclick="add_editing_permissions('{$textid}')">
                    Allow editing for this text
                </button>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
           </div>
        </div>
    </div>
</div>
};


declare function dialogs:pastebox($map as map(*)) as node(){
<div id="pastebox" class="card ann-dialog overflow-auto">
<div id="pastebox-content">
  <div><h5>Pastebox</h5></div>
  <p class="text-muted">Paste some text here and use the buttons to save the first line to the translation in Slot 1<br/>
  <span id="current-line"></span></p>
  <div class="btn-group mr-2  btn-group-sm" role="group" aria-label="First group">
    <button type="button" onclick="save_pastebox_line()" class="btn btn-primary" title="This will paste the first line as translation for the current line of the text. \nCan also be triggered by Ctl-n">Cut&amp;Save</button>
<!--    <button type="button" class="btn btn-secondary">Save&amp;Move</button>
    <button type="button" class="btn btn-secondary">CPSM</button> -->
    <button type="button" onclick="hide_pastebox()" class="btn btn-secondary">Close</button>
  </div>

<textarea id="input-pastebox" class="form-control" rows="20" cols="60" ></textarea>
</div>
</div>
};

declare function dialogs:add-parallel($options as map(*)){
 let $reltypes := collection($config:tls-data-root)//tei:TEI[@xml:id="word-relations"]//tei:body/tei:div[@type='word-rel-type']
 ,$line := tlslib:proc-seg(collection($config:tls-texts-root)//tei:seg[@xml:id=$options?line-id], map{"punc" : false()})
 ,$next := tlslib:next-n-segs($options?line-id, 6)
 ,$nc := string-to-codepoints(tlslib:proc-seg($next[1], map{"punc" : false()}))
 return
 <div id="add-parallel-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Add word relations</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <div class="form-row">
             <div class="form-group col-md-4">
                 <span class="font-weight-bold">First line:</span>  
            </div>
             <div class="form-group col-md-4">
                <!-- <span id="concept-line-id-span" class="ml-2">{$options?line-id}</span>&#160; -->
                <span id="concept-line-text-span" class="chn-font ml-2">{$line}</span>
            </div>
            </div>    

            <div class="form-row">
             <div class="form-group col-md-4">
                 <span class="font-weight-bold">Second line:</span>  
             </div>
             <div class="form-group col-md-4">
                <!-- <span id="concept-line-id-span" class="ml-2">{$options?line-id}</span>&#160; -->
                 <select class="form-control chn-font" id="select-end">
                    <option value="{$options?line-id}">{$line}</option>
                  {for $s at $pos in $next
                    return
                    if ($pos = 1) then
                    <option value="{$s/@xml:id}" selected="true">{tlslib:proc-seg($s, map{"punc" : false()})}</option>
                    else
                    <option value="{$s/@xml:id}">{tlslib:proc-seg($s, map{"punc" : false()})}</option>
                   } 
                 </select>                 
             </div>
             <div class="form-group col-md-2">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Update</button>
             </div>            
             </div>    

            <div class="form-row">
             <div class="form-group col-md-8">
             </div> 
            </div>
            <div class="form-row">
             <div class="form-group col-md-2">
                 <span class="font-weight-bold">Left word</span>  
             </div>
             <div class="form-group col-md-4">
                 <span class="font-weight-bold">Relation</span>  
             </div>
             <div class="form-group col-md-2">
                 <span class="font-weight-bold">Right word</span>  
             </div>
             <div class="form-group col-md-2">
                 <span class="font-weight-bold">Note</span>  
             </div>
           </div>
          {for $c at $pos in string-to-codepoints($line) 
          return
            <div class="form-row">
             <div class="form-group col-md-2">
                 <span id="{$options?line-id}-{$pos}" class="font-weight-normal">{codepoints-to-string($c)}</span>  
             </div>
             <div class="form-group col-md-4">
                <span class="font-weight-normal">
                 <span><select id="rel-type-{$pos}" >
                 <option value="none">None</option>
                 {for $l in $reltypes 
                let $h := $l/tei:head/text()
                order by $h
                return 
                 <option value="{data($l/@xml:id)}">{$h}</option>}
                 <option value="new">New relation</option>
                 </select></span></span>  
             </div>
             <div class="form-group col-md-2">
                <span>
                <select id="right-word-{$pos}">
                {for $p at $j in $next
                return
                 if ($j = $pos) then
                 <option value="rw-{$pos}-{$j}" selected="true">{codepoints-to-string($nc[$j])}</option>
                 else
                 <option value="rw-{$pos}-{$j}">{codepoints-to-string($nc[$j])}</option>
                 }
                </select>
                </span>
           <!--      <span id="{$next[1]/@xml:id}-{$pos}"class="font-weight-normal">{codepoints-to-string($nc[$pos])}</span>  -->
             </div>
             <div class="form-group col-md-2">
             <input id="note-rel-{$pos}" class="form-control" value=""/>
             </div>
           </div>
          
          }
 
            <div class="form-row">
              <div id="input-note-group" class="col-md-10">
                    <label for="input-note" class="font-weight-bold">Note:</label>
                    <textarea id="input-note" class="form-control"></textarea>                   
              </div>
              
            </div>    

            <div class="form-row">
              <div id="rhetdev" class="form-group ui-widget col-md-4 obs-block">
                 <label for="select-rhetdev" class="font-weight-bold">Name of <span id="block-name">Rhetorical Device</span>: </label>
                 <input id="select-rhetdev" class="form-control" required="true" value="PARALLELISM"/>
                 <span id="rhetdev-id-span" style="display:none;"></span>
              </div>
            </div>
           </div>
        <!-- footer -->
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_rdl('{$options?word}', '{$options?line-id}', '{$options?line}')">Save</button>
           </div>
        <!-- footer end -->
       </div>
     </div>
 </div>
};

(: "api/responder.xql?func=dialogs:word-rel-dialog&lw="+leftword+"&lwlineid="+lw_id+"&lwconcept="+lwobj.concept+"&lwconceptid="+lwobj.concept_id+"&lwwid="+lwobj.wid+"&rw="+rightword+"&rwlineid="+rw_id+"&rwconcept="+obj.concept+"&rwconceptid="+obj.concept_id+"&rwwid="+obj.wid,  :)

declare function dialogs:word-rel-dialog($options as map(*)){
 let $reltypes := collection($config:tls-data-root)//tei:TEI[@xml:id="word-relations"]//tei:body/tei:div[@type='word-rel-type']
 return
 <div id="word-rel-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Add word relation</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" onclick="reset_leftword()" title="Close">x</button>
            </div>
            <div class="modal-body">
            <div class="form-row">
             <div class="form-group col-md-8">
             </div> 
            </div>
            <div class="form-row">
             <div class="form-group col-md-3">
                 <span class="font-weight-bold">Left word</span>  
             </div>
             <div class="form-group col-md-2">
                 <span class="font-weight-bold">Relation</span>  
             </div>
             <div class="form-group col-md-3">
                 <span class="font-weight-bold">Right word</span>  
             </div>
             <div class="form-group col-md-4">
                 <span class="font-weight-bold">Note</span>  
             </div>
           </div>
            <div class="form-row">
             <div class="form-group col-md-3">
                 <span id="lwlineid" style="display:none;">{$options?lwlineid}</span>
                 <span id="leftword" class="font-weight-normal">{$options?lw}</span>  
                 <span id="lwconceptid" style="display:none;">{$options?lwconceptid}</span>
                 /<span id="lwconcept" class="font-weight-normal">{$options?lwconcept}</span>  
             </div>
             <div class="form-group col-md-2">
                <span class="font-weight-normal">
                 <span><select id="rel-type" >
                 {for $l in $reltypes 
                let $h := $l/tei:head/text()
                order by $h
                return 
                 <option value="{data($l/@xml:id)}">{$h}</option>}
                 </select></span></span>  
             </div>
             <div class="form-group col-md-3">
                 <span id="rwlineid" style="display:none;">{$options?rwlineid}</span>
                 <span id="rightword" class="font-weight-normal">{$options?rw}</span>  
                 <span id="rwconceptid" style="display:none;">{$options?rwconceptid}</span>
                 /<span id="rwconcept" class="font-weight-normal">{$options?rwconcept}</span>  
             </div>
             <div class="form-group col-md-4">
             <textarea id="note-inst" class="form-control" value=""/>
             </div>
           </div>
          
 
            <div class="form-row">
              <div id="input-note-group" class="col-md-12">
                    <label for="input-note" class="font-weight-bold">Note: <span class="text-muted">This note concerns this word relation for all instances. <br/>Notes concerning this specific instance should be added above.</span></label>
                    <textarea id="input-note" class="form-control"></textarea>                   
              </div>             
            </div>    

           </div>
        <!-- footer -->
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" onclick="reset_leftword()" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_wr({fn:serialize($options, map{"method" : "json"})})">Save</button>
           </div>
        <!-- footer end -->
       </div>
     </div>
 </div>

};
