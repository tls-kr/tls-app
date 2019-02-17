xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

let $textid-in := request:get-parameter("textid", "xx"),
$textid := substring-after($textid-in, "input-") 
let $rating := request:get-parameter("rating", "xx")
let $user := sm:id()//sm:real/sm:username/text()

let $ratingsfile := "ratings.xml"


let $tmpl := <textlist></textlist>

let $perm :=
    try
   { xmldb:get-permissions($config:tls-user-root, $ratingsfile)}
    catch * 
   { xmldb:store($config:tls-user-root, $ratingsfile, $tmpl)  }

let $rdoc := doc(concat($config:tls-user-root, "/", $ratingsfile))
let $newnode := <text id="{$textid}" rating="{$rating}"/>,
$currentnode := $rdoc//text[@id=$textid]
return 
if ($currentnode) then
update replace $currentnode with $newnode
else
update insert $newnode into $doc/textlist
