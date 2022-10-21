xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
 (: TODO: create user hierarchy if not existent. :)
declare variable $userhome := "/db/users/";

let $textid-in := request:get-parameter("textid", "xx"),
$textid := substring-after($textid-in, "input-") 
let $rating := request:get-parameter("rating", "xx")
let $is-delete := request:get-parameter("delete", "n") = "y"
let $user := sm:id()//sm:real/sm:username/text()
let $usercoll := $userhome || $user 
let $ratingsfile := "/ratings.xml",
$title := collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:titleStmt/tei:title/text()

let $tmpl := <textlist></textlist>

let $doc := if (doc-available($usercoll || $ratingsfile )) then doc($usercoll || $ratingsfile )
           else doc(xmldb:store($usercoll, $ratingsfile, $tmpl))
           
let $newnode := <text id="{$textid}" rating="{$rating}">{$title}</text>,
$currentnode := $doc//text[@id=$textid]
return 
    if ($is-delete) then
        if ($currentnode) then
            update delete $currentnode
        else
            ()
    else
        if ($currentnode) then
            update replace $currentnode with $newnode
        else
            update insert $newnode into $doc/textlist
