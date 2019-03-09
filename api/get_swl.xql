xquery version "3.1";

(: so this is now the xquery that displays the dialog for 
 - new concept for character:  type=concept
 - new word within concept for character: type=word
 - revision of existing swl:  type=swl
 the available information differs slightly, this will collected into a map and sent over to tlsapi
 
 the name is now slightly misleading, but I'll keep it for now:-)
 
:)

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";



(: let $title := "Adding concept for" :)

let $uuid := request:get-parameter("uid", "xx")
,$type := request:get-parameter("type", "swl")
,$word := request:get-parameter("word", "xx")
,$wid := request:get-parameter("wid", "xx")
,$line-id := request:get-parameter("line-id", "xx")
,$line := request:get-parameter("line", "xx")
,$concept := request:get-parameter("concept", "xx")
,$concept-id := request:get-parameter("concept-id", "xx")

(:let $uuid := "7b5a735a-6d13-4013-9a73-5a6d1310131b",
$type := "swl"
,$word := "xx"
,$line := "xx"
,$line-id := "xx":)
,$swl:= if ($uuid = "xx") then <empty/> else collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$uuid]
,$para := map{
"char" : if ($word = "xx") then $swl//tei:form/tei:orth/text() else $word,
"line-id" : if ($line-id = "xx") then tokenize(substring($swl//tei:link/@target, 2), " #")[1] else $line-id,
"line" : if ($line = "xx") then $swl//tls:srcline/text() else $line,
"concept" : if ($concept = "xx") then data($swl/@concept) else $concept,
"concept-id" : if ($concept-id = "xx") then data($swl/@xml:id) else $concept-id,
"synfunc-id" : data($swl//tls:syn-func/@corresp)=>substring(2),
"synfunc" : data($swl//tei:sense/tei:gramGrp/tls:syn-func/text()),
"semfeat-id" : data($swl//tls:sem-feat/@corresp)=>substring(2),
"semfeat" : data($swl//tei:sense/tei:gramGrp/tls:sem-feat/text()),
"pinyin" : $swl/tei:form/tei:pron[@xml:lang="zh-Latn-x-pinyin"]/text(),
"def" : data($swl//tei:sense/tei:def/text()),
"wid" : $wid,
"title" : if ($type = "concept") then "" else 
          if ($type = "swl") then "Editing Attribution for" else
          ""
}

return
tlsapi:swl-dialog($para, $type)