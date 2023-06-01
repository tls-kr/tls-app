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
return
doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$uid]//tei:persName/text() 
};

declare function tu:get-member-initials($id){
let $name := tu:get-member-name($id)
return ($name, string-join(for $n in tokenize($name)
           return upper-case(substring($n, 1, 1)), ""))
};

declare function tu:format-segid($segid as xs:string){
let $res := analyze-string($segid, "_([\d]+)-(\d+)([a-z])\.?(\d+)")//fn:match/fn:group/text()
return string-join(($res[1], format-number(xs:int($res[2]), "000"), $res[3], format-number(xs:int($res[4]), "000")) , ""  )
};

declare function tu:path-component($p){
string-join((tokenize($p, "/")) [position() < last()], "/")
};
