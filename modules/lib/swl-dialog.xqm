xquery version "3.1";

(:~
 : Library module for display of left hand dialog aka attribute floater
 :
 : @author Christian Wittern
 : @date 2024-10-31
 :)

module namespace lsd="http://hxwd.org/lib/swl-dialog";

import module namespace config="http://hxwd.org/config" at "../config.xqm";

import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";


declare function lsd:swl-form-dialog($context as xs:string, $model as map(*)) {
<div id="swl-form" class="card ann-dialog overflow-auto">
{if ($context = 'textview') then
 <div class="card-body">
    <h5 class="card-title"><span id="new-att-title">{if (sm:is-authenticated()) then "New Attribution:" else "Existing SW for " }<strong class="ml-2 chn-font"><span id="swl-query-span">Word or char to annotate</span>:</strong></span>
    <span id="domain-lookup-mark">
    <span class="badge badge-info ml-2" onclick="wikidata_search('wikidata')" title="Click here for a quick search in WikiData"> WD </span>
    { if (lpm:can-search-similar-lines()) then <span class="badge badge-info ml-2" onclick="wikidata_search('similar')" title="Search for similar lines"> 似 </span> else ()}
    <span>　　Lookup domain:<select id="domain-select" onChange="update_swlist()"><option value="core">Core</option>{for $d in xmldb:get-child-collections($config:tls-data-root||'/domain') return <option value="{$d}">{lu:capitalize-first($d)}</option>}</select></span>
    {if (1 = 0) then
    (: do not display for the time being  :) 
    <span>　　<span class="btn badge badge-light" type="button" data-toggle="collapse" data-target="#mark-buttons" >Mark</span>

    <span id="mark-buttons" class="collapse"><p>{for $d in collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@type='inline'] return 
    <button onClick="save_mark('{data($d/@xml:id)}','{$d//tei:head/text()}')" style="{data($d/@rend)}">{$d//tei:head/text()}</button>}</p></span>
    </span>
    else ()
    }
    </span>
    <button type="button" class="close" onclick="hide_new_att()" aria-label="Close" title="Close"><img class="icon" src="resources/icons/open-iconic-master/svg/circle-x.svg"/></button>
    </h5>
    <h6 class="text-muted">At:  <span id="swl-line-id-span" class="ml-2">Id of line</span>&#160;
    {lrh:format-button-common("bookmark_this_line()","Bookmark this location", "open-iconic-master/svg/bookmark.svg"), 
     if ($model("textid") and lpm:has-edit-permission($model("textid"))) then 
      lrh:format-button("display_punc_dialog('x-get-line-id')", "Edit properties of this text segment", "octicons/svg/lock.svg", "", "close", ("tls-editor", "tls-punc"))
     else (),
      lrh:format-button("display_named_dialog('x-get-line-id', 'pb-dialog')", "Add page break of a witness edition before selected character", "octicons/svg/milestone.svg", "", "close", ("tls-editor", "tls-punc")),
      lrh:format-button("display_named_dialog('x-get-line-id', 'edit-app-dialog')", "Add content of variant edition for selected character", "octicons/svg/note.svg", "", "close", ("tls-editor", "tls-punc"))
      
     }</h6>
    <h6 class="text-muted">Line: <span id="swl-line-text-span" class="ml-2 chn-font">Text of line</span>
     {lrh:format-button-common("window.open('"||$config:help-base-url||$config:help-map?floater||"', 'docs')","Click here to display the manual for this screen", "help.svg")}    
     {lrh:format-button-common("toggle_list_display()","Switch to different ordering of Lexical entries.", "octicons/svg/gear.svg")}
     {lrh:format-button-common("add_rd_here()","Add observation (regarding a text segment) starting on this line", "octicons/svg/comment.svg")}
    </h6>
    <!--  {lrh:format-button-common("add_parallel()","Add word relations starting on this line", "對")} -->
    <div class="card-text">
       
        <p> { if (sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then <span id="new-att-detail">
        <span class="badge badge-primary">Use</span> one of the following syntactic words (SW), 
        create a one of the following  
         ,add an <span class="font-weight-bold">existing</span> <span class="btn badge badge-primary ml-2" onclick="show_new_concept('existing', '')">Concept</span> to the word
         or create a <span class="btn badge badge-primary ml-2" onclick="show_new_concept('new', '')">New Concept</span>. You can also add a word relation: First set the left word with <span class="badge badge-secondary">LW</span>.
         </span>
         else <span id="new-att-detail">You do not have permission to make attributions.</span>
         }
         <span id="swl-jisho"></span>
        <ul id="swl-select" class="list-unstyled"></ul>
        </p>
      </div>
    </div>    
else 
 <div class="card-body">
    <h5 class="card-title"><span id="new-att-title">Existing SW for <strong class="ml-2"><span class="chn-font" id="swl-query-span"></span></strong></span>
     <button type="button" class="close" onclick="hide_new_att()" aria-label="Close" title="Close">
     <img class="icon" src="resources/icons/open-iconic-master/svg/circle-x.svg"/>  
     </button></h5>
    <div class="card-text">
    <p>Here are <b>S</b>yntactic <b>W</b>ords already defined in the database:</p>
        <ul id="swl-select" class="list-unstyled"></ul>
      </div>
    </div>    

}
</div>
};
