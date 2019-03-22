xquery version "3.1";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

declare option output:method "json";
declare option output:media-type "application/json";

declare variable $user := sm:id()//sm:real/sm:username/text();

let $trid := request:get-parameter("trid", "xxxx")
, $tr := request:get-parameter("tr", "xx")
, $lang := request:get-parameter("lang", "en")
(:let $trid := "KR6q0003_T_000-0196b.8-tr"
, $tr := "Dummy 2"
,$lang := "en":)
,$id := substring($trid, 1, string-length($trid) -3)
,$txtid := tokenize($id, "_")[1]
,$trcoll := concat($config:tls-translation-root, "/", $lang)
,$trcollavailable := xmldb:collection-available($trcoll) or 
  (xmldb:create-collection($config:tls-translation-root, $lang),
  sm:chmod(xs:anyURI($trcoll), "rwxrwxr--"),
  sm:chown(xs:anyURI($trcoll), "tls"),
  sm:chgrp(xs:anyURI($trcoll), "tls-user") )
,$docpath := concat($trcoll, "/", $txtid, ".xml")
,$title := collection($config:tls-texts-root)//tei:TEI[@xml:id=$txtid]//tei:titleStmt/tei:title/text()
,$node := collection($trcoll)//tei:seg[@corresp=concat("#", $id)]
,$seg := <seg xmlns="http://www.tei-c.org/ns/1.0" corresp="#{$id}" xml:lang="{$lang}" resp="{$user}" modified="{current-dateTime()}">{$tr}</seg>
let $doc :=
  if (not (doc-available($docpath))) then
   doc(xmldb:store($trcoll, concat($txtid, ".xml"), 
   <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$txtid}-{$lang}">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Translation of {$title} into ({$lang})</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Translated parts</head><p xml:id="{$txtid}-start"></p></div>
      </body>
  </text>
</TEI>)) 
 else doc($docpath)
 
return
if ($node) then 
if (update replace $node with $seg) then "Success. Updated translation." else "Could not update translation." 
else 
if (update insert $seg  into $doc//tei:p[@xml:id=concat($txtid, "-start")]) then "Success. Saved translation." else ("Could not save translation. ", $docpath)
 