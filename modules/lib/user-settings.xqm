xquery version "3.1";

(:~
 : Library module for rendering html fragments
 :
 : @author Christian Wittern
 : @date 2023-10-24
 :)

module namespace lus="http://hxwd.org/lib/user-settings";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";


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
