xquery version "3.1";
(:~
: Text editing permissions.  This file needs to be owned by a dba user and have the setuid bit set. 
: 
: @author Florian Kessler florian.kessler@fau.de
: @version 1.0
: adopted for direct execution by CW
:)

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "../db-utility.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";


(: Add user to the list of users that are allowed to edit a certain text :)
declare function local:add-text-editing-permission($map as map(*)) {
  if ((sm:id()//sm:group = ("tls-admin"))) then
    let $userid := $map?userid,
        $textid := $map?textid
    return
      if (not($userid and $textid)) then
        "Error: Missing parameter"
      else if (not(sm:get-user-groups($userid) = "tls-punc")) then
        "Error: Only members of the 'tls-punc' group may be granted permission to edit texts"
      else if (not(collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid])) then
        "Error: A text with this id does not exist in the db."
      else
        (: The collection needs x fpr all users so that resources in it are accesible, whereas the resource itself needs r to be opened. :)
        let $tls-admin-collection := dbu:ensure-collection("/db/users/tls-admin/", map { "owner": "admin", "group": "tls-admin", "mode": "rwxrwx--x"}),
            $permissions := doc(dbu:ensure-resource($tls-admin-collection, "permissions.xml", <permissions xmlns="http://hxwd.org/ns/1.0"/>, map { "owner": "admin", "group": "tls-admin", "mode": "rwxrwxr--"}))/tls:permissions,
            $text-permissions := $permissions//tls:text-permissions[@text-id = $textid]
        return 
          (if (not($text-permissions)) then
            update insert <text-permissions xmlns="http://hxwd.org/ns/1.0" text-id="{$textid}" /> into $permissions
          else
            (),
          let $text-permissions2 := $permissions//tls:text-permissions[@text-id = $textid]
          return
            update insert <allow-review xmlns="http://hxwd.org/ns/1.0" user-id="{$userid}"/>  into $text-permissions2)
  else
    "Error: You do not have permission to modify permissions."
};

(: Remove user from the list of users that are allowed to edit a certain text :)
declare function local:remove-text-editing-permission($map as map(*)) {
  if ((sm:id()//sm:group = ("tls-admin"))) then
    let $userid := $map?userid,
        $textid := $map?textid
    return
      if (not($userid and $textid)) then
        "Error: Missing parameter"
      else 
        let $permission := doc("/db/users/tls-admin/permissions.xml")//tls:text-permissions[@text-id = $textid]/tls:allow-review[@user-id = $userid]
        return 
          if (not($permission)) then
            "Error: User did not previously have permission to edit text"  
          else
            update delete $permission
  else
    "Error: You do not have permission to modify permissions."
};

let $map := map:merge(
   for $p in (request:get-parameter-names(), "body")
   where not ($p = "func")
   return
   map:entry($p, request:get-parameter($p, "xx")))

return

if ($map?action = "add") 
  then local:add-text-editing-permission($map)
  else local:remove-text-editing-permission($map)
