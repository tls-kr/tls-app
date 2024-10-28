xquery version "3.1";

(:~
 : Library module for permissions
 :
 : @author Christian Wittern
 : @date 2023-12-06
 :)

module namespace lpm="http://hxwd.org/lib/permissions";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(: Checks whether the currently logged in user has editing permission for a specific text. Users have editing permission if they are
   a member of the "tls-editor" or "tls-adming" group, or are a member of the "tls-punc" group, and have explicit permission to edit $text-id. :)
declare function lpm:has-edit-permission($text-id as xs:string) as xs:boolean {
  if (sm:id()//sm:group = ("tls-editor", "tls-admin")) then
    true()
  else
   if (sm:id()//sm:real/sm:username/text() = "guest") then false () else 
   if (sm:id()//sm:group = ("test", "tls-test")) then false() else 
    let $permissions := doc($config:tls-user-root || "tls-admin/permissions.xml")
    return $text-id and 
        sm:id()//sm:group = "tls-punc" and 
        $permissions//tls:text-permissions[@text-id = $text-id]/tls:allow-review[@user-id = sm:id()//sm:username/text()]
};

(: Returns whether the 內部 should be displayed for a user. It is always shown when they are member of the "tls-editor" group, otherwise,
   it is shown in the textview context when a user has permission to edit that particular text. :)
declare function lpm:should-display-navbar-review($context as xs:string, $model as map(*)) as xs:boolean {
  sm:id()//sm:group = "tls-editor" or ($context = "textview" and $model("textid") and lpm:has-edit-permission($model("textid")))
};

declare function lpm:can-use-linked-items(){
 "dba" = sm:id()//sm:group
};

declare function lpm:can-write-debug-log(){
 "dba" = sm:id()//sm:group
};

declare function lpm:can-use-ai(){
 "dbax" = sm:id()//sm:group
};

declare function lpm:can-delete-applications(){
 ("dba") = sm:id()//sm:group
};

declare function lpm:is-owner($node){
 let $user := sm:id()//sm:real/sm:username/text()
 return
     $user = sm:get-permissions(base-uri($node))/sm:permission/@owner
};

declare function lpm:can-translate(){
 ("tls-user") = sm:id()//sm:group
};

(: this includes permissions to edit the translation info, while the translation itself can be edited by members of the tls-user group  :)
declare function lpm:can-delete-translations($trid){
 let $trc := collection($config:tls-translation-root)//tei:TEI[@xml:id=$trid]
 return
  lpm:is-owner($trc) or (sm:id()//sm:group/text() = ("tls-editor", "tls-admin"))
};

declare function lpm:can-search-similar-lines(){
 "dba" = sm:id()//sm:group
};

declare function lpm:is-testuser(){
contains(sm:id()//sm:group, ('tls-test', 'guest'))
};

declare function lpm:should-show-translation(){
not(contains(sm:id()//sm:group/text(), "guest"))
};