xquery version "3.1";

(:~
 : Library module for linking items (lines. texts..).
 :
 : @author Christian Wittern
 : @date 2023-11-30
 :)

module namespace lli="http://hxwd.org/lib/link-items";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace tlslib="http://hxwd.org/lib" at "../tlslib.xql";


import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace lv="http://hxwd.org/lib/vault" at "vault.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "../db-utility.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare variable $lli:item-types := map{
 "aut" : "Author" ,
 "trl" : "Translator" ,
 "edi" : "Editor",
 "cmp" : "Compiler"  ,
 "com" : "Commentator" 
};

declare function lli:format-items($seg-id as xs:string) {
    let $cseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$seg-id]
    , $title := lmd:get-metadata($cseg, "title")
    , $head := lmd:get-metadata($cseg, "head")
    , $textid := lmd:get-metadata($cseg, "textid")
    , $tr := collection($config:tls-translation-root)//tei:seg[@corresp="#"||$seg-id]
return
<div>
<div title="{$textid}">{$title} / {$head}</div>
{
for $sh in $cseg/preceding-sibling::tei:seg[position()<1] 
  return 
    lrh:proc-seg($sh, map{"punc" : true(), "textid" : $textid}),
    <mark>{lrh:proc-seg($cseg, map{"punc" : true(), "textid" : $textid})}</mark>,
for $sh in ($cseg/following-sibling::tei:seg)[position()<1] 
  return 
    lrh:proc-seg($sh, map{"punc" : true(), "textid" : $textid })

}
</div>
};

(: form input elements need to have a 'name' attribute for the jquery serialize() function to work  CW 2023-04-20 :)

declare function lli:new-link-dialog($map as map(*)){
 let $uuid :=  if (starts-with($map?uuid, "uuid")) then $map?uuid else "uuid-" || util:uuid()
   , $word := $map?word
   , $def := ""
   , $textid := if (string-length($map?textid)>0) then $map?textid else ()
   , $items := ($map?line, for $t in tokenize($map?items,",") where not (contains($t, 'baseline'))return substring-after($t, "res-"))
   , $context-lines := 10
   return
   <div id="new-link-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <form id="new-link-form">
        <div class="modal-content">
            <div class="modal-header"><h5><span>Add links to other places</span> 
             </h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <div class="form-row">
              <div id="select-lang-group" class="form-group col-md-4">
              <input type="hidden" name="textid" value="{$textid}"/>
              <input type="hidden" name="line" value="{$map?line}"/>
                <label for="select-lang" class="font-weight-bold">Headword: </label>
                <input name="head" class="form-control"  value="{$map?word}"/>

              </div>
              <div id="select-lang-group" class="form-group col-md-4">
                <label for="select-lang" class="font-weight-bold">Topics: </label>
                <input name="topics" class="form-control"  value=""/>
              </div>
             <div class="col-md-4">
                <label for="select-lang" class="font-weight-bold">Comment:</label>
                 <input name="comment" class="form-control"  value=""></input>
              </div>

            </div>
              <h6  class="font-weight-bold">Items</h6>
              {for $item at $pos in $items
               let $seg:= lu:get-seg($item)
              return
             (<div class="form-row" id="role-group-{$pos}">
              <div id="select-start-group" class="form-group col-md-4">
                <label for="select-start-{$pos}" class="font-weight-bold">({$pos}) Select start (
                <button class="btn badge badge-primary" type="button" onclick="get_more_lines('select-start-{$pos}', {0 - $context-lines})" title="Press here to add more lines">＞</button>):</label>
                 <select class="form-control chn-font" id="select-start-{$pos}" name="select-start--{$pos}" onchange="add_context_lines('select-start-{$pos}')">
                 <option value="none">　</option>
                  {for $s at $p in tlslib:next-n-segs($item, 0 - $context-lines )
                    return
                    <option value="{$s/@xml:id}#{$context-lines - $p}">{lrh:proc-seg($s, map{"punc" : true()})}</option>
                   } 
                 </select>                 
              </div>
              <div id="item" class="form-group col-md-4">
              <label class="font-weight-bold">Matched line</label><br/>
              <input type="hidden" name="item--{$pos}" value="{$item}"/>
              <span>{lrh:proc-seg(lu:get-seg($item), map{"punc" : true()})}</span>
              </div>      
              <div id="select-end-group" class="form-group col-md-4">
                <label for="select-end-{$pos}" class="font-weight-bold">Select end (
                <button class="btn badge badge-primary" type="button" onclick="get_more_lines('select-end-{$pos}', {$context-lines})" title="Press here to add more lines">＞</button>):</label>
                 <select class="form-control chn-font" id="select-end-{$pos}" name="select-end--{$pos}" onchange="add_context_lines('select-end-{$pos}')">
                 <option value="none">　</option>
                  {for $s at $p in tlslib:next-n-segs($item, $context-lines)
                    return
                    <option value="{$s/@xml:id}#{$p}" >{lrh:proc-seg($s, map{"punc" : true()})}</option>
                   } 
                 </select>                 
              </div>
             <div class="form-row" id="staging-group-{$pos}">
              <div class="form-group col-md-12">
              <span><span id="title-{$pos}"  class="font-weight-bold">{lmd:get-metadata($seg, "title")} / {lmd:get-metadata($seg, "head")}</span><br/>
              <span id="target-{$pos}" class="link-items" data-id="{$item}">
              <span id="staging-area-start-{$pos}"> </span>
              <span id="staging-area-{$pos}"><mark>{lrh:proc-seg($seg, map{"punc" : true()})}</mark></span>
              <span id="staging-area-end-{$pos}"> </span>
              </span></span>
              </div>
              </div>
             </div>,
             <div class="form-row" id="more-fields">
              <div class="form-group col-md-4">
               <label for="select-role--{$pos}" class="font-weight-bold">Type</label>
                 <select class="form-control" name="select-role--{$pos}">
                 <option value="none">　</option>
                  {for $l in map:keys($lli:item-types)
                    let $r := lower-case($lli:item-types($l))
                    order by $l
                    return
                    if ($r = $item) then
                    <option value="{$l}" selected="true">{$lli:item-types($l)}</option>
                    else
                    <option value="{$l}">{$lli:item-types($l)}</option>
                   } 
                 </select>
              </div>              
              <div class="form-group col-md-8">
               <label for="item-note--{$pos}" class="font-weight-bold">Item note</label>
              <textarea name="item-note--{$pos}" class="form-control"></textarea> 
              </div>
             </div>
             )
             }
            <h6  class="font-weight-bold">General notes</h6>
            <div class="form-row">
              <div id="input-notes-group" class="col-md-12">
              <textarea name="input-notes" class="form-control"></textarea>                   
              </div>
            </div>
            
            <h6  class="font-weight-bold">Visibility</h6>
<div class="form-row">
    <div class="form-group col-md-4">
        <div class="form-check">
            <input class="form-check-input" type="radio" name="visradio" id="visrad1"
                value="option1" checked="true" />
            <label class="form-check-label" for="visrad1"> Show to everybody </label>
        </div>
    </div>
    <div class="form-group col-md-4">
        <div class="form-check disabled">
            <input class="form-check-input" type="radio" name="visradio" id="visrad2"
                value="option2" disabled="true" />
            <label class="form-check-label" for="visrad2">Show to registered users</label>
        </div>
    </div>
    <div class="form-group col-md-4">
        <div class="form-check">
            <input class="form-check-input" type="radio" name="visradio" id="visrad3"
                value="option3" />
            <label class="form-check-label" for="visrad3"> Keep it to me only </label>
        </div>
    </div>
</div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_link_items()">Save</button>
           </div>            
          </div>
         </form> 
        </div>
</div>
};
            
declare function lli:save-link-items($map as map(*)){
 let $uuid :=  if (starts-with($map?uuid, "uuid")) then $map?uuid else "uuid-" || util:uuid()
 , $public := $map?vis = "option1" 
 , $doc := doc(lli:get-links-file($uuid, $public))
 (: now we have the template, see what we need to add :)
 , $items := for $l in map:keys($map) 
   where starts-with($l, "item--")
   order by $l
   return $l
 , $head := if (string-length(string-join($doc/tei:head)) > 0) then () else
            if (string-length($map?head) = 0) then () else
            <head xmlns="http://www.tei-c.org/ns/1.0">{$map?head}</head>
  , $lines := for $item in $items 
              let $send := substring-after($item, "--")
              , $start := map:get($map, "select-start--" || $send)
              , $end := map:get($map, "select-end--" || $send)
              , $line := map:get($map, $item)
              , $baseline := $line = $map?line
              return
              <tls:line xmlns:tls="http://hxwd.org/ns/1.0" start="{$start}" end="{$end}" line="{$line}" baseline="{$baseline}">{lrh:proc-seg(lu:get-seg($line), map{"punc" : true()})}</tls:line>
   
             
return $lines 
};

declare function lli:get-links-file($uuid as xs:string, $public as xs:boolean){
let $user := sm:id()//sm:real/sm:username/text()
let $links-collection := lli:uuid2path(if ($public) then $config:tls-links-root else $config:tls-user-root || $user || "/notes/links", $uuid) 
let $existing-links-file := collection($links-collection)/tls:linkList[@xml:id=$uuid]
return 
if ($existing-links-file) then $existing-links-file else
let $template := 
<tls:linkList xmlns:tls="http://hxwd.org/ns/1.0" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$uuid}">
    <head><!-- this might eg be the search term used to construct this list --></head>
    <tls:topics><!-- list of topics, hashtags? --></tls:topics>
    <def><!-- A formal definition of any kind, derived? from this list --></def>
    <note><!-- research note --></note>
    <tls:lineGroup>
    </tls:lineGroup>
    <tls:metadata resp="#{$user}" created="{current-dateTime()}">
        <respStmt>
            <resp>added</resp>
            <name notBefore="{current-dateTime()}">{$user}</name>
        </respStmt>
    </tls:metadata>
</tls:linkList>

return xmldb:store($links-collection, $uuid || ".xml", $template)

};
            
declare function lli:uuid2path($collection as xs:string, $uuid as xs:string) as xs:string{
let $f := substring(substring-after($uuid, "uuid-"), 1, 1)
, $col := $collection || "/" || $f || "/" 
return dbu:ensure-collection($col)
};

            