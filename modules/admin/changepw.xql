xquery version "3.1";
(:~
: Text editing permissions.  This file needs to be owned by a dba user and have the setuid bit set. 
: 
: @author Christian Wittern cwittern@gmail.com
: @version 1.0
:)

let $user := request:get-parameter("user", "xx")
, $pw := request:get-parameter("passwd", "xx")

return
if ($pw = "xx" or $user = "xx") then
  "Error, could not change password." 
else 
   try{ (sm:passwd($user, $pw), "Success: Password changed to new value") } catch * {"Internal error, password not changed."}