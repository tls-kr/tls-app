xquery version "3.1";
(:~
: This module provides the internal functions that do not directly control the 
: template driven Web presentation
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace tu="http://hxwd.org/utils";

import module namespace config="http://hxwd.org/config" at "config.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function tu:string-to-ncr($s as xs:string) as xs:string{
 string-join(for $a in string-to-codepoints($s)
 return "&#x26;#x" || number($a) || ";" 
 , "")
};

declare function tu:cleanstring($str as xs:string*){
$str => string-join() => normalize-space() => replace(' ', '')
};

(: find the file that was called to display the current page, without .html extension :)
declare function tu:html-file(){
(request:get-uri() => tokenize("/"))[last()] => replace("\.html", "")
};

(:~ 
: Helper functions
:)

declare function tu:get-member-name($id){
let $uid:= if (starts-with($id, "#")) then substring($id, 2) else $id
, $name := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$uid]//tei:persName/text() 
return
if (string-length($name) > 0) then $name else $uid
};

declare function tu:get-member-initials($id){
let $name := tu:get-member-name($id)
return (string($name), string-join(for $n in tokenize($name)
           return upper-case(substring($n, 1, 1)), ""))
};

declare function tu:format-segid($segid as xs:string){
let $res := analyze-string(tokenize($segid, "_")[3], "\d+")
return
string-join(for $r in $res//fn:*
 return
 if (local-name($r) = 'match') then format-number(xs:int($r), "0000") else $r/text() )
};

declare function tu:path-component($p){
string-join((tokenize($p, "/")) [position() < last()], "/")
};

declare function tu:index-date($node as node()) as xs:int{
 let $nb := xs:int($node/@notbefore)
 , $na := xs:int($node/@notafter)
 return
 xs:int(($na + $nb) div 2)
};
  


declare function tu:get-setting($value, $default){
let $user := sm:id()//sm:real/sm:username/text()
, $user-coll := collection($config:tls-user-root|| $user)
return
   switch ($value) 
     case ('search-default') return 
        if ($user-coll//tei:item[@xml:id=$value]) 
          then $user-coll//tei:item[@xml:id=$value]/text()
          else $default
     default return ("No setting available for "||$value)
     
};