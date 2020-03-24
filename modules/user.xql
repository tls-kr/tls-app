xquery version "3.1";
(: update the list of members in the vault.  Needs to be run by a dba user :)
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

let $vault := "/db/apps/tls-data/vault"
let $members := "/members.xml"
let $newdoc :=    doc(xmldb:store($vault, $members, 
   <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="members-list">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>List of TLS Members</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by administrators of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date></creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
         <listPerson>
            <head>List of Members of the TLS Project</head>
         </listPerson>
      </body>
  </text>
</TEI>)),
$chm := (sm:chmod(xs:anyURI($vault || $members), "rw-r--r--"),
sm:chown(xs:anyURI($vault || $members), "tls"),
sm:chgrp(xs:anyURI($vault || $members), "tls-user"))

for $u in sm:list-users()
let $fullname := sm:get-account-metadata($u, xs:anyURI("http://axschema.org/namePerson"))
,$groups := sm:get-user-groups($u),
$role := if (contains($groups, "tls-editor")) then "tls-editor" else "tls-user"
,$newnode := <person xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$u}" role="{$role}">
               <name>
                  <abbr>{$u}</abbr> <!-- internally used username -->
                  <persName>{$fullname}</persName> <!-- full name -->
               </name>
            </person>
where contains($groups, "tls-user")
return 
update insert $newnode into $newdoc//tei:listPerson
