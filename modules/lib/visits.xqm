(:~
: This module provides the internal functions that do not directly control the 
: template driven Web presentation
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace lvs="http://hxwd.org/lib/visits";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";

import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";





(: ~
 : on visiting a page, record the visit in the history.xml file
:)

declare function lvs:record-visit($targetseg as node()){
let $user := sm:id()//sm:real/sm:username/text(),
$groups := sm:get-user-groups($user),
$doc := if ( ("guest", "tls-test") = $groups) then () else lvs:get-visit-file(),
$date := current-dateTime()
, $textid := lmd:get-metadata($targetseg, "textid")
, $ex := $doc//tei:item[@xml:id=$textid]
, $item := <item xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$textid}" modified="{current-dateTime()}"><ref target="#{$targetseg/@xml:id}">{$targetseg/text()}</ref></item>
return 
if ($ex) then 
  update replace $ex with $item
else
  if ($doc) then
     update insert $item  into $doc//tei:list[@xml:id="recent-start"]
  else ()
};

(: 2024-10-31 we use the segment id here, not the node :)
declare function lvs:record-visit-remote($sid as xs:string, $text as xs:string?){
let $user := sm:id()//sm:real/sm:username/text(),
$groups := sm:get-user-groups($user),
$doc := if ( ("guest", "tls-test") = $groups) then () else lvs:get-visit-file(),
$date := current-dateTime()
, $textid := tokenize($sid, "_")[1]
, $ex := $doc//tei:item[@xml:id=$textid]
, $item := <item xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$textid}" modified="{current-dateTime()}"><ref target="#{$sid}" type="remote">{$text}</ref></item>
return 
if ($ex) then 
  update replace $ex with $item
else
  if ($doc) then
     update insert $item  into $doc//tei:list[@xml:id="recent-start"]
  else ()
};

declare function lvs:get-visit-file(){
  let $user := sm:id()//sm:real/sm:username/text(),
  $doc-path := $config:tls-user-root|| $user || "/recent.xml",
  $doc := if (not(doc-available($doc-path))) then 
    doc(xmldb:store($config:tls-user-root|| $user,  "recent.xml",
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="vis-{$user}">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Visited texts for {$user}</title>
         </titleStmt>
         <publicationStmt>
            <ab>published electronically as part of the TLS project at https://hxwd.org</ab>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> for {$user}.</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Visited pages</head>
      <list type="visits" xml:id="recent-start"></list>
      </div>
      </body>
  </text>
</TEI>))
    else doc($doc-path)
  return $doc
};

declare function lvs:visit-time($textid as xs:string){
  let $user := sm:id()//sm:real/sm:username/text(),
  $doc := if ($user=("guest", "test")) then () else doc($config:tls-user-root|| $user || "/recent.xml")
  return
  $doc//tei:list[@type="visits"]/tei:item[@xml:id=$textid]/@modified
};

declare function lvs:recent-visits(){
  let $user := sm:id()//sm:real/sm:username/text(),
  $doc := if ($user=("guest")) then () else doc($config:tls-user-root|| $user || "/recent.xml")
  return
  $doc//tei:list[@type="visits"]/tei:item
};

declare function lvs:list-visits(){
for $v in collection('/db/users')//tei:list[@xml:id='recent-start']/tei:item
let $u := substring-after(data($v/ancestor::tei:TEI/@xml:id), 'vis-')
let $t := xs:dateTime($v/@modified)
group by $u
let $tr := (for $tx in $t order by $tx descending return $tx)[1]
order by $tr descending
return 
    subsequence(for $l in $v
    let $t2 := xs:dateTime($l/@modified)
    , $textid := $l/@xml:id
    , $title := lu:get-title($textid)
    , $target := substring($l/tei:ref/@target, 2)
    where not ($textid = $config:ignored-text-ids)
        order by $t2 descending
    return <li u="{$u[1]}">{format-dateTime($t2, "[Y0001]-[M01]-[D01]/[H01]:[m01]:[s01]")}&#160;{tu:get-member-name($u[1])}&#160;({$u[1]})&#160;<br/> <a href="textview.html?location={$target}">{$title}</a></li>, 1, 1)
};
