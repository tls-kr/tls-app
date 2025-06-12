xquery version "3.1";
(:~
: This module provides the functions that produce dialogs

: @author Christian Wittern  cwittern at yahoo.com
: @version 1.0
:)
module namespace dialogs="http://hxwd.org/dialogs"; 

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
import module namespace functx="http://www.functx.com" at "../modules/functx.xql";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
(: import module namespace tlsapi="http://hxwd.org/tlsapi" at "../api/tlsapi.xql"; :)
import module namespace con='http://hxwd.org/con' at "../modules/concepts.xql"; 

import module namespace lu="http://hxwd.org/lib/utils" at "lib/utils.xqm";
import module namespace ltr="http://hxwd.org/lib/translation" at "lib/translation.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace ltp="http://hxwd.org/lib/textpanel" at "lib/textpanel.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "lib/render-html.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "lib/permissions.xqm";
import module namespace lsi="http://hxwd.org/special-interest" at "lib/special-interest.xqm";

import module namespace remote="http://hxwd.org/remote" at "lib/remote.xqm";

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
"taxonymy" : "Hyponym",
"hypernymy" : "Hypernym",
"antonymy" : "Antonym",
"see" : "See also"},
"source-references" : "Bibliography",
"warring-states-currency" : "Warring States Currency",
"register" : "Register",
"words" : "Words",
"none" : "Texts or Translation",
"old-chinese-contrasts" : "Old Chinese Contrasts",
"pointers" : "Pointers"
, "tr-info-dialog" : map{"title" : "Information about translation "
                         ,"dsize" : "modal-lg" 
                         }
, "passwd-dialog" : map{"title" : "Change Password"}                         
};

(:~
Frame for a modal dialog. The name is used in the id of the dialog and is passed along from the show_dialog javascript functiion
:)

declare function dialogs:modal-frame($name, $map){
<div id="{$name}" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog {$map?dsize}" role="document">
      <form id="{$name}-form">
        <div class="modal-content">
            <div class="modal-header"><h5>{$map?title}</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">{$map?subtitle}</h6>
            {$map?body}
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                {$map?buttons}
           </div>
         </div>
        </form>
     </div>
</div>
};

(:~ 
User setting for limiting the maximal number of search results
:)
declare function local:search-settings($name, $options){
let $search-options := map{"search-sortmax": 5000, "search-cutoff" : 0.2, "search-ratio" : "None"}
, $body := for $o in map:keys($search-options)  
     let $sval:=lus:get-settings()//tls:item[@type=$o]/@value
     , $cval := if ($sval) then $sval else map:get($search-options, $o)
     return
     lrh:form-input-row($name, map{"input-id" : $o, "input-value" : $cval, "type" : "text"}) 
, $buttons := ( <button type="button" class="btn btn-primary" onclick="update_setting('{$options?setting}', 'setting')">Save</button> )
return
      dialogs:modal-frame($name, 
      map{
        "dsize" : "", 
        "body":     $body, 
        "buttons" : $buttons, 
        "options" : $options,
        "title":  ("Search settings ", <b>{$options}</b>)
      })           
 
};
(:~ 
Displays the dialog with information about the translation
:)

declare function local:tr-info-dialog($name, $options){
let $body := ltr:transinfo($options?trid)
, $isresearchnote := not(contains($options?trid, "-"))
, $title :=  if ($isresearchnote) then "Research Note" else "Information about translation"
, $buttons := if ($isresearchnote) then () else  
              (if (lpm:can-delete-translations($options?trid)) then
                 <button type="button" class="btn btn-primary" onclick="display_tr_file_dialog('{$name}','{$options?slot}', '{$options?trid}')">Edit Translation Data</button> else (),
               if (lpm:can-delete-translations($options?trid)) then
<button type="button" class="btn btn-danger" onclick="delete_tr_file('{$name}','{$options?slot}', '{$options?trid}')">Delete translation</button>
         else ())
return                 
      dialogs:modal-frame($name, 
      map{
        "dsize" : "modal-lg", 
        "body": $body, 
        "buttons" : $buttons, 
        "options" : $options,
        "title": $title 
      })           
};


(:~
Change password.  
sth is not working here. :)
declare function local:passwd-dialog($name, $options){
let $body := (lrh:form-input-row($name, map{"input-id" : "password", "hint" : "Please enter the new password:", "type" : "password", "required" : true() })
             ,lrh:form-input-row($name, map{"input-id" : "passwd-2", "hint" : "Please repeat the new password:" , "type" : "password", "required" : true()}))
                 
, $buttons := (<button type="button" class="btn btn-secondary" onclick="showhide_passwd('password,passwd-2')">Show/Hide</button>,<button type="button" class="btn btn-primary" onclick="change_passwd('{$options}')">Submit</button>,<input type="hidden" name="duration" value="P7D"/>, <input type="hidden" name="user" value="{$options}"/>)
return                 
      dialogs:modal-frame($name, 
      map{
        "dsize" : "", 
        "body": $body, 
        "buttons" : $buttons, 
        "options" : $options,
        "title":  ("Change Password for user ", <b>{$options}</b>)
      })           
};

(:~ 
Information about text.  Updated for remote texts.
:)

declare function local:text-info($name, $options){
  dialogs:modal-frame($name, 
      map{
        "body": if ($options?mode='remote') then remote:call-remote-get(map{'server' : 'https://hxwd.org/krx/textinfo/', 'path' : $options?textid}) else tlslib:textinfo($options?textid), 
        "options" : $options,
        "title":  "Text information"
      })           
};

(:~ 
Change a user setting.  2024-11-25: Needs update for new settings format. 
:)

declare function local:update-setting($name, $options){
let $body := (lrh:form-input-row($name, map{"input-id" : "setting", "input-value": $options?value,  "hint" : $options?hint, "type" : "text", "required" : true()}) )
, $buttons := ( <button type="button" class="btn btn-primary" onclick="update_setting('{$options?setting}', 'setting')">Save</button> )
return                 
      dialogs:modal-frame($name, 
      map{
        "dsize" : "", 
        "body": $body, 
        "buttons" : $buttons, 
        "options" : $options,
        "title":  "Update setting for " || $options?setting
      })           
};


declare function local:stub-dialog($name, $options){
let $body := ()
, $buttons := ( )
return                 
      dialogs:modal-frame($name, 
      map{
        "dsize" : "modal-lg", 
        "body": $body, 
        "buttons" : $buttons, 
        "options" : $options,
        "title":  ""
      })           
};
(:~ 
Add a new ressource that can be used from various places in the database.
:)

declare function local:external-resource($name, $options){
let $body := lsi:resource-dialog-body($options)
, $buttons := if ($options?id) 
          then  ( <button type="button" class="btn btn-primary" onclick="save_external('{$options?id}', 'setting')">Save</button> ) 
          else ( <button type="button" class="btn btn-primary" onclick="save_external('xx', 'setting')">Add</button> )
, $title := if ($options?id) then "Edit external ressource " else "Add new external ressource "
return
      dialogs:modal-frame($name, 
      map{
        "dsize" : "", 
        "body":     $body, 
        "buttons" : $buttons, 
        "options" : $options,
        "title":  $title
      })           
 
};

declare function local:add-tag($name, $options){
let $body := (lrh:form-input-row($name, map{"input-id" : "add-tag", "input-value": $options?value,  "hint" : $options?hint, "type" : "text", "required" : true()}) )
, $buttons := ( <button type="button" class="btn btn-primary" onclick="save_tag('{$options?setting}', 'setting')">Save</button> )
return                 
      dialogs:modal-frame($name, 
      map{
        "dsize" : "", 
        "body": $body, 
        "buttons" : $buttons, 
        "options" : $options,
        "title":  "Add tag for " || $options?setting
      })           
};


(:~  This is the entry function, called from the javascript frontend:)

declare function dialogs:dispatcher($para as map(*)){
let $options := parse-json($para?options)
return switch($para?name)
               case "tr-info-dialog" return local:tr-info-dialog($para?name, $options)
               case "passwd-dialog" return local:passwd-dialog($para?name, $options)
               case "text-info" return local:text-info($para?name, $options)
               case "add-tag" return local:add-tag($para?name, $options)
               case "update-setting" return local:update-setting($para?name, $options)
               case "search-settings" return local:search-settings($para?name, $options)
               case "external-resource" return local:external-resource($para?name, $options)
               default return "Dialog not registered!"
};


(:~
Add a new observation: rhet-dev or other
2021-11-30: extending this functionality to cover observations of type block defined in facts.xml :)

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
                <button class="btn badge badge-primary" type="button" onclick="get_more_lines('select-end', 20)" title="Press here to add more lines">＞</button>):</label>
                 <select class="form-control chn-font" id="select-end">
                   <option value="{$options?line-id}">{$options?line}</option>
                  {for $s at $pos in lu:next-n-segs($options?line-id, 20)
                    return
                    <option value="{$s/@xml:id}#{$pos}">{$s/text()}</option>
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

declare function dialogs:add-ref-dialog($options as map(*)){
   <div id="new-concept-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Add a new resource reference <span class="font-weight-bold">{$name}</span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Source references</h6>
            <div class="form-row">
              <div id="input-bibl-group-id" class="col-md-3">
                    <label for="input-bibl-id" class="font-weight-bold">ID</label>
              </div>
              <div id="input-bibl-group-tit" class="col-md-6">
                    <label for="input-bibl-tit" class="font-weight-bold">Title</label>
              </div>
              <div id="input-bibl-group-pg" class="col-md-3">
                    <label for="input-bibl-pg" class="font-weight-bold">Page</label>
                <span id="add-line" class="float-right badge badge-light mt-2" onclick="con_add_new_line({count($bibs) + 1}, 'bibl-group-{count($bibs)}')">Add new Ref.</span>
            </div>
            </div>
            {if (not($bibs)) then <div class="form-row" id="bibl-group-0"/> else for $b at $pos in  $ex//tei:listBibl/tei:bibl 
            return
            (<div id="bibl-group-{$pos}"><div class="form-row"  style="border-top-style:solid;">
              <div id="input-bibl-group-id-{$pos}" class="col-md-3" >
                    <input id="input-bibl-id-{$pos}" data-cid="{substring($b/tei:ref/@target, 2)}" class="bibl form-control" value="{normalize-space($b/tei:ref/text())}"/>                   
              </div>
              <div id="input-bibl-group-tit-{$pos}" class="col-md-6">
                    <input id="input-bibl-tit-{$pos}" class="form-control" value="{$b/tei:title/text()}"/>                   
              </div>
              <div id="input-bibl-group-pg-{$pos}" class="col-md-2">
                    <input id="input-bibl-pg-{$pos}" class="form-control" value="{$b/tei:biblScope/text()}"/>                   
              </div>       
              <div class="col-md-1">
                    <span id="rem-line-{$pos}" title="Remove this line" class="float-right badge badge-light mt-2" onclick="bib_remove_line('bibl-group-{$pos}')">X</span>
              </div>
              
            </div>
            
            </div>)}
           </div>            
          </div>
         </div>
       </div>
};

(:~ Add new concept. [[TODO]]  2024-11-25:  Needs update  :)

declare function dialogs:new-concept-dialog($options as map(*)){
 let $tmap := map{'concept' : "Concept", 'rhet-dev': "Rhetorical Device"}
 let $target := $options?type
 
 let $ex := if ($target = 'concept') then 
    collection($config:tls-data-root || "/concepts")//tei:div[tei:head[. = $options?concept]]
    else 
    doc($config:tls-data-root||"/core/rhetorical-devices.xml")//tei:div[tei:head[. = $options?concept]]
 return
(: if ($ex) then $tmap?($target) || " exists!" else :)

 let $uuid := if (map:contains($options, "concept-id")) 
    then $options?concept-id else
    if (map:contains($options, "name")) then map:get($con:new-concepts($options?name), "id") else 
    "uuid-" || util:uuid()
  , $bibs := $ex//tei:listBibl/tei:bibl  
  , $notes := for $d in $ex/tei:note/tei:p return normalize-space($d/text()) 
  , $def := if ($ex) then for $d in $ex/tei:div[@type="definition"]/tei:p return normalize-space($d/text()) else
    if ($uuid) then if (map:contains($con:new-concept-defs, $uuid)) then $con:new-concept-defs($uuid) else () else ()
  , $name := if(map:contains($options, "concept")) then $options?concept else 
    if (not($options?mode = "new" or $options?mode = "existing")) then $options?mode else ()
   return
   <div id="new-concept-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Define/Edit a new {$tmap?($target)}: <span class="font-weight-bold">{$name}</span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            {if ($target = 'concept') then 
            <div class="form-row">
              <div id="input-def-group" class="col-md-6">
                 <label for="name-och" class="font-weight-bold">Old Chinese name:</label>
                 <input id="name-och" class="form-control" required="true" value="{$ex/tei:list[@type="translations"]/tei:item[@xml:lang='och']/text()}"/>
              </div>
              <div id="input-def-group" class="col-md-6">
                 <label for="name-zh" class="font-weight-bold">Modern Chinese name:</label>
                 <input id="name-zh" class="form-control" required="true" value="{$ex/tei:list[@type="translations"]/tei:item[@xml:lang='zh']/text()}"/>
              </div>
            </div>
            else 
             <div class="form-row">
                 <input id="name-och" style="display:none;" class="form-control" value=""/>
                 <span id="name-id-span" style="display:none;">{$uuid}</span>
              <div id="input-def-group" class="col-md-6">
                 <label for="name-zh" class="font-weight-bold">Chinese name:</label>
                 <input id="name-zh" class="form-control" required="true" value="{$ex/tei:list[@type="translations"]/tei:item[@xml:lang='zh']/text()}"/>
              </div>
              <div id="select-name-group" class="form-group ui-widget col-md-6">
                 <label for="select-name" class="font-weight-bold">Alternate labels</label>
                 <input id="select-labels" class="form-control" required="true" value=""></input>
                 <small class="text-muted">Comma separated list of other names for this {lower-case($tmap?($target))}</small>
              </div>
            </div>
            }
            {if ($target = 'concept') then 
            <div class="form-row">
              <div id="input-def-group" class="col-md-6">
                    <label for="input-def" class="font-weight-bold">Definition </label>
                    <textarea id="input-def" class="form-control">{string-join($def, '&#xA;')}</textarea>                   
              </div>
              <div id="select-name-group" class="form-group ui-widget col-md-6">
                 <label for="select-name" class="font-weight-bold">Alternate labels</label>
                 <small class="text-muted"><br/>Comma separated list of other names for this {lower-case($tmap?($target))}</small>
                 <input id="select-labels" class="form-control" required="true" value=""></input>
                 <span id="name-id-span" style="display:none;">{$uuid}</span>
              </div>
            </div>
            else 
            <div class="form-row">
              <div id="input-def-group" class="col-md-12">
                    <label for="input-def" class="font-weight-bold">Definition </label>
                    <textarea rows="{max((count($def)*2,3) )}"  id="input-def" class="form-control">{string-join($def, '&#xA;')}</textarea>                   
              </div>
            </div>
            }
            <h6 class="font-weight-bold mt-3" >Place this {lower-case($tmap?($target))} within the ontology</h6>
            <div id="staging" style="display:true;" class="form-row">
                    {for $l in map:keys($dialogs:lmap?tax-def)
                    let $it := $ex//tei:list[@type=$l]/tei:item/tei:ref
                    return
              <div id="stag-{$l}"  class="col-md-3"><label  class="font-weight-bold  mr-3" for="stag-{$l}">{$dialogs:lmap?tax-def($l)}</label>
              <span id="stag-{$l}-span"  class="staging-span">{if ($it) then
              for $i in $it
              return
              <span class="badge badge-dark staged" data-cid="{substring($i/@target, 2)}" >{$i/text()}</span>
              else ()}</span></div>
                   } 
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
                 <label for="select-concept-nc">Name of related {lower-case($tmap?($target))}: </label>
                 <input id="select-concept-nc" class="form-control" required="true" value=""/>
                 <span id="concept-id-span-nc" style="display:none;"></span>
                </div>
              <div class="form-group col-md-4">
                <label>Press here to add the concept</label>
                <button class="btn btn-primary" type="button" onclick="add_to_tax()" id="add-to-pointers">Add to ontology</button>
                <button class="btn btn-secondary" type="button" onclick="reset_tax()" title="Remove the selected concepts from the ontology and start fresh" id="reset-to-pointers">Reset</button>
              </div>   
              </div>
            <!-- source references -->
            <h6 class="font-weight-bold">Source references</h6>
            <div class="form-row">
              <div id="input-bibl-group-id" class="col-md-3">
                    <label for="input-bibl-id" class="font-weight-bold">ID</label>
              </div>
              <div id="input-bibl-group-tit" class="col-md-6">
                    <label for="input-bibl-tit" class="font-weight-bold">Title</label>
              </div>
              <div id="input-bibl-group-pg" class="col-md-3">
                    <label for="input-bibl-pg" class="font-weight-bold">Page</label>
                <span id="add-line" class="float-right badge badge-light mt-2" onclick="con_add_new_line({count($bibs) + 1}, 'bibl-group-{count($bibs)}')">Add new Ref.</span>
            </div>
            </div>
            {if (not($bibs)) then <div class="form-row" id="bibl-group-0"/> else for $b at $pos in  $ex//tei:listBibl/tei:bibl 
            return
            (<div id="bibl-group-{$pos}"><div class="form-row"  style="border-top-style:solid;">
              <div id="input-bibl-group-id-{$pos}" class="col-md-3" >
                    <input id="input-bibl-id-{$pos}" data-cid="{substring($b/tei:ref/@target, 2)}" class="bibl form-control" value="{normalize-space($b/tei:ref/text())}"/>                   
              </div>
              <div id="input-bibl-group-tit-{$pos}" class="col-md-6">
                    <input id="input-bibl-tit-{$pos}" class="form-control" value="{$b/tei:title/text()}"/>                   
              </div>
              <div id="input-bibl-group-pg-{$pos}" class="col-md-2">
                    <input id="input-bibl-pg-{$pos}" class="form-control" value="{$b/tei:biblScope/text()}"/>                   
              </div>       
              <div class="col-md-1">
                    <span id="rem-line-{$pos}" title="Remove this line" class="float-right badge badge-light mt-2" onclick="bib_remove_line('bibl-group-{$pos}')">X</span>
              </div>
            </div>
            <div class="form-row">
              <div class="col-md-1">
              <span class="badge badge-light mt-2">Note:</span>
              </div>
              <div id="input-bibl-group-not-{$pos}" class="col-md-11">
                    <input id="input-bibl-not-{$pos}" class="form-control" value="{$b/tei:note/tei:p/text()}"/>                   
              </div>
            </div>
            </div>
            )
            }
            {if ($target = 'concept') then 
            <div class="form-row"  style="border-top-style:solid;">
              <div id="input-crit-group" class="col-md-6">
                    <label for="input-crit" class="font-weight-bold">Old Chinese Criteria </label>
                    <textarea id="input-crit" class="form-control"></textarea>                   
              </div>
              <div id="input-notes-group" class="col-md-6">
                    <label for="input-notes" class="font-weight-bold">Modern Chinese Criteria &amp; other notes</label>
                    <textarea id="input-notes" class="form-control"></textarea>                   
              </div>
            </div> else 
            <div class="form-row"  style="border-top-style:solid;">
              <div id="input-crit-group" class="col-md-12">
                    <label for="input-crit" class="font-weight-bold">Notes</label>
                    <textarea rows="{max((count($notes)*2,3) )}"  id="input-crit" class="form-control">{string-join($notes, '&#xA;')}</textarea>                   
              </div>
            </div>            
            }
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_new_concept('{$uuid}', '{$name}', '{$target}')">Save {$tmap?($target)}</button>
           </div>
         </div>
     </div>
</div>

};

(:~ This is implementing a peer review for a swl :)

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

(:~ Add or update a new pinyin reading for a word:)

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
let $cat := doc($config:tls-texts-meta||"/taxonomy.xml")//tei:category[@xml:id="tls-dates"]//tei:category 
return
<div id="edit-textdate-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Creation date for text</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">{$para?textid}: {lu:get-title($para?textid)}</h6>
                <small class="text-muted">A text date consists of the (1) lower (<span class="font-weight-bold">not-before</span>) and (2) upper limits (<span class="font-weight-bold">not-after</span>) as well as (3) a human readable form. (1) and (2) should be positive integers for AD years and negative integers for BC years.  <br/>In addition, we associate the text with a date-category in the <a href="documentation.html?section=taxonomy#tls-dates--head">date taxonomy</a>.</small>
                <div id="input-cat-group">
                    <label for="select-date-cat"><strong>Date category:</strong> </label>
                <select id="select-date-cat" class="form-control">{for $c in $cat 
                order by $c/@xml:id descending
                return 
                if (string-length($para?datecat) > 0 and $para?datecat = $c/@xml:id) then 
                <option value="{$c/@xml:id}" selected="true">{$c/tei:catDesc/text()}</option>
                else
                <option value="{$c/@xml:id}">{$c/tei:catDesc/text()}</option>
                }</select>
                </div>
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

declare function dialogs:edit-textcat($para as map(*)){
let $cat := doc($config:tls-texts-meta||"/taxonomy.xml")//tei:category[@xml:id="kr-categories"]//tei:category 
, $textcat := tokenize($para?textcat)
return
<div id="edit-textcat-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Category for this text</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">{$para?textid}: {lu:get-title($para?textid)}</h6>
                <small class="text-muted">Position in the classified catalog</small>
                <div id="input-cat-group">
                    <label for="input-nb"><strong>Catalog category:</strong> </label>
                <select id="select-text-cat" class="form-control" multiple="true">{for $c in $cat 
                where string-length($c/@xml:id) > 3
                order by $c/@xml:id ascending
                return 
                if ($c/@xml:id = $textcat) then 
                <option value="{$c/@xml:id}" selected="true">{$c/@xml:id/string()}　{$c/tei:catDesc/text()}</option>
                else
                <option value="{$c/@xml:id}">{$c/@xml:id/string()}　{$c/tei:catDesc/text()}</option>}</select>
                </div>
                <!--
                <div id="input-src-group">
                    <label for="input-src"><strong>Note</strong> </label>
                    <textarea id="input-src" class="form-control">{if ($para?src ne "undefined") then $para?src else ()}</textarea>
                </div>
               -->
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_textcat('{$para?textid}')">Save</button>
           </div>
         </div>
     </div>
</div>
};

declare function dialogs:add-url-dialog($para as map(*)){
<div id="add-url-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
      <form id="add-url-form">
        <div class="modal-content">
            <div class="modal-header"><h5>Add link (URL) to bibliographic reference</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold"></h6>
            <div class="form-row">
                <div id="input-desc-group" class="col-md-12">
                    <label for="input-desc"><strong>Short description of the item</strong> </label>
                    <input id="input-desc" name="desc" class="form-control" value=""/>
                </div>
            </div>
            
            <div class="form-row">
                <div id="input-url-group" class="col-md-12">
                    <label for="input-url"><strong>Please paste the URL to a digital version of this work here:</strong> </label>
                    <input id="input-url" name="url" class="form-control" value=""/>
                </div>
            </div>

            <div class="form-row">
                <div id="input-note-group" class="col-md-12">
                    <label for="input-note"><strong>Additional note</strong> </label>
                    <textarea id="input-note" name="note" class="form-control"></textarea>
                </div>
            </div>

            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="biburl_save('{$para?modsid}')">Save</button>
           </div>
         </div>
        </form>
     </div>
</div>
};



declare function dialogs:add-bibref-dialog($para as map(*)){
<div id="add-bibref-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Add bibliographic reference</h5>
                <button type="button" class="close" onclick="bibref_attach('cancel')" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold"></h6>
            <div class="form-row">
                <div id="input-group" class="col-md-10">
                    <small for="input-bib"><strong>Search bibliography for</strong> </small>
                    <input id="input-bib" class="form-control" value=""/>
                </div>    
                <div id="input-group-btn" class="col-md-2">
                    <small for="input-bib"><strong>　　　　　</strong> </small>
                    <button class="btn badge badge-primary ml-2" type="button" onclick="bibref_search()">
                        Go!
                    </button>
                </div>
            </div>
            <div class="form-row">
            <ul id="bib-results">
            </ul>
            </div>
            <div class="form-row">
                <div id="input-bib-group" class="col-md-12">
                    <label for="input-page"><strong>Page reference</strong> </label>
                    <input id="input-page" class="form-control" value=""/>
                </div>
            </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" onclick="bibref_attach('cancel')">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="bibref_attach('select')">Select</button>
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
(:~ 
  Originally for moving a word to a different concept, but now also for attaching a concept to a different place in the concept hierarchy
:)
declare function dialogs:move-word($map as map(*)){
let $cid := if ($map?type='word') then 
             collection($config:tls-data-word-root)//tei:*[@xml:id=$map?wid]/ancestor::tei:entry/@concept/string() 
            else if ($map?type='sw') then
collection($config:tls-data-word-root)//tei:*[@xml:id=$map?wid]/ancestor::tei:entry/tei:form/tei:orth/text()                                   
            else  
             collection($config:tls-data-root||"/concepts")//tei:div[@xml:id=$map?wid] 
, $head := if ($map?type='word') then 
             <h5>Move {$map?word} from {$cid} to another concept</h5>
           else
             if ($map?count eq '1' or $map?type = 'sw') then
             <h5>Attach {$cid} to another concept</h5>
             else 
             <h5>Create new concept, attach to {$cid}</h5>
             
return
<div id="move-word-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">{$head}
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <h6 class="font-weight-bold">Select the target concept:</h6>
            <div>
                <span id="concept-id-span" style="display:none;"></span>
                <div id="select-concept-group" class="form-group ui-widget">
                    <input id="select-concept" class="form-control" required="true" value=""/>
                </div>
            {
              if (xs:int($map?count) > 1) then    
               <p>There are {$map?count} attributions, so this might take a while.</p>
               else if ($map?type = 'concept') then
               <p>The concept will be moved with all attached concepts.  </p>
               else ()
            }
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
let $eid := collection($config:tls-data-word-root)//tei:*[@xml:id=$map?wid]/ancestor::tei:entry
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
            <p>There are {$map?count} attributions, so this might take a while.<br/>
            <b>Careful:</b> this can not be undone.</p>
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

declare function dialogs:pb-dialog($map as map(*)){
 let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id=$map?uid]
 , $wl := $seg/ancestor::tei:TEI//tei:witness

 return
 <div id="pb-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header"><h5>Add pagebreak <small class="text-muted ">{$map?uid}</small></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            {if ($wl) then
            <div class="modal-body">
            <div class="form row">
            <div class="col-md-3">Text line</div>
            <div class="col-md-2">Position</div>
            <div class="col-md-5">Pagebreak will be inserted before</div>
            </div>
            <div class="form row">
            <div class="col-md-3">{$map?line}</div>
            <div class="col-md-2">{$map?pos}</div>
            <div class="col-md-5">{$map?sel}</div>
            </div>
            <div class="form row">
            <div class="col-md-3"></div>
            <div class="font-weight-bold mt-2 col-md-2">Select witness:</div>
            <div class="form-group col-md-3"><select class="form-control" id="witness" name="witness">
                  {for $w in $wl
                    return
                    <option value="{$w/@xml:id}">{$w/text()}</option>
                   } 
                 </select>                 
                 </div>
             </div>     
            <div class="form row">
            <div class="col-md-3"><span>Preceding page:</span><br/>
             {for $w in $wl
               let $ed := data($w/@xml:id)
               let $pb := ($seg//tei:pb[@ed=$ed]|$seg/preceding::tei:pb[@ed=$ed])[last()]
               where exists($pb)
               return <span class="text-muted "><small>{$w/text()}:</small>{data($pb/@n)}<br/></span>
               }
            </div>
            <div class="font-weight-bold mt-2 col-md-2">Page number:</div>
            <div class="col-md-3">
             {for $w in $wl
               let $ed := data($w/@xml:id)
               let $pb := ($seg//tei:pb[@ed=$ed]|$seg/preceding::tei:pb[@ed=$ed])[last()]
               where exists($pb)
               return <span><small>{$w/text()}:</small>{data($pb/@n)}</span>
               }
            </div>
            <div class="col-md-2">
            <input id="page-num" class="form-control" required="true" value=""/>
            </div>
            <div class="col-md-3"><span>Following page:</span><br/>
             {for $w in $wl
               let $ed := data($w/@xml:id)
               let $pb := ($seg//tei:pb[@ed=$ed]|$seg/following::tei:pb[@ed=$ed])[1]
               where exists($pb)
               return <span class="text-muted "><small>{$w/text()}:</small>{data($pb/@n)}<br/></span>
               }
            </div>
            </div>
            </div>
            else
            local:no-witness($seg/ancestor::tei:TEI/@xml:id)
            }
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                {if ($wl) then
                <button type="button" class="btn btn-primary" onclick="save_pb()">Save</button>
                else ()}
            </div>     
        </div>
    </div>
</div>
};

declare function local:no-witness($textid as xs:string){
         <div class="modal-body">
            <h6><span class="bg-warning">Warning:</span>　<b>No textual witnesses defined</b></h6>
            <div class="form row">
            <div class="col-md-12 mt-2"><p>To add page information or register variants carried by specific textual witnesses, the witnesses for a text need to make known to the system.  The list of witnesses is maintained as part of the text, {lu:get-title($textid)} in this case.</p>
            <p>Click on the following link to search the bibliography for textual witnesses.  If they are not yet found in the bibliography, you will be able to add a new item and then indicate this as a textual witness. </p>
            <p><a class="badge badge-pill badge-light" title="Search bibliography" href="search.html?query={lu:get-title($textid)}&amp;textid={$textid}&amp;search-type=10">Search bibliography</a></p></div>
            </div>
         </div>
};

declare function dialogs:edit-app-dialog($map as map(*)){
(: CBETA texts do not have a xml:id on app, so we are using the from attribute here :)
 let $app := if (string-length($map?appid) > 0) then 
   let $doc := lu:get-doc($map?textid)
   return $doc//tei:app[@from="#"||$map?appid] else ()
 let $seg := if ($app) then $app/ancestor::tei:TEI//tei:seg[tei:anchor[@xml:id = substring($app/@to, 2)]] else collection($config:tls-texts-root)//tei:seg[@xml:id=$map?uid]
 , $wl := $seg/ancestor::tei:TEI//tei:witness
 , $lem := if (string-length($map?sel)>0) then $map?sel else $app/tei:lem//text() 
 return
 <div id="edit-app-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
      <form id="edit-app-form">
        <div class="modal-content">
            <div class="modal-header"><h5>Add/edit variant on line <span class="font-weight-bold">{$seg//text()}</span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            {if ($wl) then
            <div class="modal-body">
            <div class="form row">
            <div class="col-md-3">Lemma text:</div>
            <div class="col-md-3">{$lem}</div>
            <div class="col-md-3"><small class="text-muted">This is shown in the main text</small></div>
            </div>
            <h6 class="font-weight-bold">Variant readings:</h6>
            {for $w in $wl
             let $rdg := $app/tei:rdg["#"||$w/@xml:id = tokenize(@wit)]
            return
            <div class="form row">
            <div class="col-md-3">Witness {$w/text()}</div>
            <div class="col-md-3"><input id="rdg---{$w/@xml:id}" name="rdg---{$w/@xml:id}" class="form-control" required="true" value="{if ($rdg) then  $rdg/text() else $map?sel}"/></div>
            </div>
            }
            <div class="form row">
            <div class="col-md-9"><p class="text-muted">The <b>lemma</b> carries the established text, while the various witnesses register the <b>reading</b> of the specific witness. If a witness has the same reading as the lemma, it should be left that way here (these will be ignored when saving the apparatus).</p></div>
            </div>
            <div class="form row">
            <div class="font-weight-bold mt-2 col-md-1">Note:</div>
            <div class="col-md-8"><textarea id="note" name="note" class="form-control">{$app/tei:note/text()}</textarea>
            <span id="bibl-refs">{for $r in $app/tei:note/tei:bibl//text() return $r}</span>
            {if (count($app/tei:note/tei:bibl) = 0 and sm:is-authenticated()) then 
              <span class="text-muted"><br/>For source references, please include the page number.</span>
             else ()
            }</div>
            <div class="col-md-2">{ 
            if (sm:is-authenticated()) then 
              let $cnt := count($app/tei:note/tei:bibl)
               return  
                if ($cnt = 0) then 
                <span><a class="badge badge-pill badge-light"  href="#" onclick="add_bibref_dialog('{$cnt}')" title="Add source reference">Add source reference</a></span>
                else ()
            else ()}</div>
            </div>
            </div>
            else local:no-witness($seg/ancestor::tei:TEI/@xml:id)}
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                {if ($wl) then                
                <button type="button" class="btn btn-primary" onclick="save_txc()">Save</button>
                else ()}
            </div>     
        </div>
       </form>
    </div>
</div>
};

(: the reference is a bibl of the form: 
<bibl><ref target="#uuid-60d39cc0-d76b-4275-8490-886ace4204be">BUCK 1988</ref>
<title>A Dictionary of Selected Synonyms in the Principal Indo-European Languages</title>
<biblScope unit="page">9.11</biblScope></bibl>
The title can be omitted
:)


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
 ,$line := lrh:proc-seg(collection($config:tls-texts-root)//tei:seg[@xml:id=$options?line-id], map{"punc" : false()})
 ,$next := lu:next-n-segs($options?line-id, 6)
 ,$nc := string-to-codepoints(lrh:proc-seg($next[1], map{"punc" : false()}))
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
                    <option value="{$s/@xml:id}" selected="true">{lrh:proc-seg($s, map{"punc" : false()})}</option>
                    else
                    <option value="{$s/@xml:id}">{lrh:proc-seg($s, map{"punc" : false()})}</option>
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
