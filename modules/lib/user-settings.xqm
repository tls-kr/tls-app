xquery version "3.1";

(:~
 : Library module for user settings
 :
 : @author Christian Wittern
 : @date 2023-10-24
 :)

module namespace lus="http://hxwd.org/lib/user-settings";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";

import module namespace templates="http://exist-db.org/xquery/templates" ;

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(: 0 = always off
   1 = always on
   <string(s), sep by ,> gives the context(s) in which to display, or the value of the setting 
:)

declare variable $lus:default := map{
 'sf-display' : 'by-concept' 
,'swl-buttons' : '1'    
,'wd-display' : '0'   
,'sig-bud' : 'KR6'   
};



declare function lus:settings-top($node as node()*, $model as map(*))
{
let $user := sm:id()//sm:real/sm:username/text()
, $settings := lus:get-settings()
, $px := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$user]//tei:persName/text()
return
map{'user' : $user,
    'settings': $settings,
    'px' : $px}
};

declare function lus:user-name($node as node()*, $model as map(*)){ $model?px };


declare
    %templates:wrap
function lus:settings($node as node()*, $model as map(*))
{
let $user := sm:id()//sm:real/sm:username/text()
, $settings := lus:get-settings()
, $px := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$user]//tei:persName/text()
return
<div>
<div>
<input type="checkbox" name="theme" data-toggle="toggle" checked="true" aria-label="Dark theme"/>
Dark theme
</div>
</div>
};

declare function lus:settings-display($node as node()*, $model as map(*))
{
<div>
<p>bla</p>
</div>
};

declare function lus:settings-bookmarks($node as node()*, $model as map(*))
{
<div>
<p>Currently defined bookmarks.  Click on the <img src="resources/icons/open-iconic-master/svg/x.svg"/> to delete a bookmark.</p>
<ul>
{for $b in doc($config:tls-user-root || $model?user || "/bookmarks.xml")//tei:item
  let $segid := $b/tei:ref/@target,
  $id := $b/@xml:id,
  $date := xs:dateTime($b/@modified)
  order by $date descending

return
<li id="{$id}">{lrh:format-button("delete_bm('"||$id||"')", "Delete this bookmark.", "open-iconic-master/svg/x.svg", "", "", "tls-user")}
<a href="textview.html?location={substring($segid, 2)}">{$b/tei:ref/tei:title/text()}: {$b/tei:seg}</a></li>
}
</ul>
</div>
};


(:~
 : this creates a new empty stub for various user settings (if necessary) and returns the doc
:)
declare function lus:get-settings() {
let $user := sm:id()//sm:real/sm:username/text()
, $filename := "settings.xml"
,$docpath := $config:tls-user-root || $user || "/" || $filename
let $doc := try{
  if (not (doc-available($docpath))) then
   doc(xmldb:store($config:tls-user-root || $user, $filename, 
<settings xmlns="http://hxwd.org/ns/1.0" xml:id="{$user}-settings">
<section type="bookmarks"></section>
<section type="slot-config"></section>
<section type="search"></section>
</settings>)) 
 else doc($docpath) } catch * {()}
return 
if ($doc//tls:section[@type="search"]) then $doc
else (
try {
update insert <section xmlns="http://hxwd.org/ns/1.0" type="search"></section> into $doc/tls:settings
} catch * {()}, 
$doc
)
};

declare function lus:get-user-setting($type as xs:string, $context as xs:string?){
let $settings := lus:get-settings()
return
 switch($type)
 case 'sf-display'
 case 'synfunc-buttons' return 
    let $preference := data($settings//tls:section[@type=$type]/@content)
    return
     if ($preference) then $preference else $lus:default?($type)
 default return ""
};

declare function lus:set-user-setting($type as xs:string, $preference as xs:string){
let $settings := lus:get-settings()
, $node := <section xmlns="http://hxwd.org/ns/1.0" type="{$type}" content="{$preference}"/>
, $oldnode := $settings//tls:section[@type=$type]
return 
 if ($oldnode) then 
   update replace $oldnode with $node
 else 
update insert $node 
       into  $settings/tls:settings
};



(:  by-concept , by-syn-func
2024-10-24:  Make this a cycle through more options
:)
declare function lus:toggle-list-display($map as map(*)){
let $pref := lus:get-user-setting('sf-display', $map?context)
, $choices := ('by-concept','by-syn-func', 'by-frequency')
, $new :=  let $tmp := index-of($choices, $pref) + 1 
            return 
             if ($tmp > count($choices)) then 1 else $tmp
return 
    lus:set-user-setting('sf-display', $choices[$new])
};

declare function lus:get-sf-display-setting(){
let $settings := lus:get-settings()
, $preference := data($settings//tls:section[@type='sf-display']/@content)
return 
 if ($preference) then $preference else 'by-concept'
};

declare function lus:set-sf-display-setting($preference as xs:string){
let $settings := lus:get-settings()
, $node := <section xmlns="http://hxwd.org/ns/1.0" type="sf-display" content="{$preference}"/>, $oldnode := $settings//tls:section[@type='sf-display']
return 
 if ($oldnode) then 
   update replace $oldnode with $node
 else 
update insert $node 
       into  $settings/tls:settings
};

declare function lus:get-slot1-id($textid as xs:string){
let $settings := lus:get-settings()
return data($settings//tls:item[@textid=$textid and @slot='slot1']/@content)
};

(:~
 : saves the content-id of a content selected for a s slot for a text
:)
declare function lus:settings-save-slot($slot as xs:string, $textid as xs:string, $content-id as xs:string) {
let $settings := lus:get-settings(),
  $current-setting := $settings//tls:section[@type='slot-config']/tls:item[@textid=$textid and @slot=$slot] 
let $proc := 
if ($current-setting) then 
 (update value $current-setting/@content with $content-id,
 update value $current-setting/@modified with current-dateTime())
else 
 let $newitem := <item xmlns="http://hxwd.org/ns/1.0" created="{current-dateTime()}" modified="{current-dateTime()}" slot="{$slot}" textid="{$textid}" content="{$content-id}"/>
 return
 update insert $newitem into $settings//tls:section[@type='slot-config']
 return
 (:  we return the content-id for the case where this is used in a then clause of if statement:)
 $content-id
};
