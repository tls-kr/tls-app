xquery version "3.1";

(:~
 : Library module for user settings
 : (display of interface is in render-html.xqm
 : @author Christian Wittern
 : @date 2023-10-24
 :)

module namespace lus="http://hxwd.org/lib/user-settings";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
(:import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";:)
import module namespace lsi="http://hxwd.org/special-interest" at "special-interest.xqm";


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
,'wd' : '0'   
,'sig-bud' : 'KR6'   
};



declare function lus:settings-top($node as node()*, $model as map(*))
{
let $user := sm:id()//sm:real/sm:username/text()
, $settings := lus:get-settings()
, $px := sm:get-account-metadata($user, xs:anyURI("http://axschema.org/namePerson"))
return
map{'user' : $user,
    'settings': $settings,
    'px' : $px}
};

declare function lus:user-name($node as node()*, $model as map(*)){ $model?px };


declare %templates:wrap function lus:settings($node as node()*, $model as map(*)) {
<div>
<h2>Customizable settings for {$model?px}</h2>
<p>
 
</p>

</div>
};



declare function lus:settings-external($node as node()*, $model as map(*)){
<div>
<div class="row">
<p><span class="badge" onclick="show_dialog('external-resource',{{'dummy':'3'}})"  type="button">Add</span> additional resources or <b>select</b> which to show.</p>
</div>
<div class="row">
<div class="col">
<span>Available resources:</span>
<h3>Basic</h3>
{lsi:list-resources-form(map{'type' : 'internal-resources'})}
<h3>Additional</h3>
{lsi:list-resources-form(map{'type' : 'external-resources'})}
</div>
</div>
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

declare function lus:get-user-section($type as xs:string, $context as xs:string?){
let $settings := lus:get-settings()
return
 switch($type)
 case 'wd'
 case 'bud-sig'
 case 'sf-display'
 case 'synfunc-buttons' return 
    let $preference := data($settings//tls:section[@type=$type]/@content)
    return
     if ($preference) then $preference else $lus:default?($type)
 default return ""
};

(:~ check if a user specified a setting, otherwise use the default setting :)
declare function lus:get-user-item($type as xs:string){
let $settings := lus:get-settings()
, $preference := $settings//tls:item[@type=$type]/@value/string()
, $default := doc($config:tls-app-interface||"/settings.xml")//tls:item[@type=$type]/@value/string()
return
if ($preference) then $preference else if ($default) then $default else '0'
};

declare function lus:set-user-item($map as map(*)){
let $settings := lus:get-settings()
, $oldnode := $settings//tls:item[@type=$map?type]
, $oldsection := $settings//tls:section[@type=$map?section]
, $newvalue := if ($map?action = 'add') then 
   string-join(for  $t in ($map?preference, tokenize($oldnode/@value, ','))
     where not ( $t = ('0', '1') )
     return $t, ',')
   else if ($map?action = 'delete') then 
   string-join(for $t in tokenize($oldnode/@value, ',') 
     where $t ne $map?preference return $t, ',')
   else $map?preference
, $newvalue := if (string-length($newvalue) = 0) then '0' else $newvalue    
, $upditem := <item xmlns="http://hxwd.org/ns/1.0" created="{$oldnode/@created}" modified="{current-dateTime()}" type="{$map?type}" value="{$newvalue}"/>
, $newitem := <item xmlns="http://hxwd.org/ns/1.0" created="{current-dateTime()}" modified="{current-dateTime()}" type="{$map?type}" value="{$newvalue}"/>
, $newsection := <section xmlns="http://hxwd.org/ns/1.0" type="{$map?section}"><item xmlns="http://hxwd.org/ns/1.0" created="{current-dateTime()}" modified="{current-dateTime()}" type="{$map?type}" value="{$newvalue}"/></section>

return 
(
 if ($oldnode) then 
   update replace $oldnode with $upditem
 else 
  if ($oldsection) then
    update insert $newitem  into  $oldsection
  else  
    update insert $newsection into  $settings/tls:settings
, "OK"
)
};

declare function lus:set-user-section($type as xs:string, $preference as xs:string){
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
let $pref := lus:get-user-section('sf-display', $map?context)
, $choices := ('by-concept','by-syn-func', 'by-frequency')
, $new :=  let $tmp := index-of($choices, $pref) + 1 
            return 
             if ($tmp > count($choices)) then 1 else $tmp
return 
    lus:set-user-section('sf-display', $choices[$new])
};

declare function lus:get-sf-display-setting(){
let $settings := lus:get-settings()
, $preference := data($settings//tls:section[@type='sf-display']/@content)
return 
 if ($preference) then $preference else 'by-concept'
};

declare function lus:set-sf-display-setting($preference as xs:string){
let $settings := lus:get-settings()
, $node := <section xmlns="http://hxwd.org/ns/1.0" type="sf-display" content="{$preference}"/>
, $oldnode := $settings//tls:section[@type='sf-display']
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
