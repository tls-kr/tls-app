xquery version "3.1";

(:~
 : Library module for saving to the vault
 :
 : @author Christian Wittern
 : @date 2023-10-24
 :)

module namespace lv="http://hxwd.org/lib/vault";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";


declare function lv:get-crypt-file($type as xs:string){
  let $cm := substring(string(current-date()), 1, 7),
  $doc-name := if (string-length($type) > 0 ) then $type || "-" || $cm || ".xml" else $cm || ".xml",
  $doc-path :=  $config:tls-data-root || "/vault/crypt/" || $doc-name,
  $doc := if (not(doc-available($doc-path))) then 
    let $res := 
    xmldb:store($config:tls-data-root || "/vault/crypt/" , $doc-name, 
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="del-{$type}-{$cm}-crypt">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Recorded items for month {$cm}</title>
         </titleStmt>
         <publicationStmt>
            <ab>published electronically as part of the TLS project at https://hxwd.org</ab>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date>.</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Items</head>
      <p xml:id="del-{$cm}-start"></p>
      </div>
      </body>
  </text>
</TEI>)
    return
    (sm:chmod(xs:anyURI($res), "rw-rw-rw-"),
     sm:chgrp(xs:anyURI($res), "tls-user"),
(:     sm:chown(xs:anyURI($res), "tls"),:)
    doc($res)
    )
    else
    doc($doc-path)
  return $doc
};

