xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

let $notes-path := concat($config:tls-data-root, "/notes/new/")
let $line-id := request:get-parameter("line", "xx")
let $sense-id := request:get-parameter("sense", "xx")
let $user := sm:id()//sm:real/sm:username/text()

return

if (($line-id != "xx") and ($sense-id != "xx")) then
let $line := collection($config:tls-texts-root)//tei:seg[@xml:id=$line-id],
$tr := collection($config:tls-translation-root)//tei:*[@corresp=concat('#', $line-id)],
$title-en := $tr/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
$title := $line/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
$sense := collection($config:tls-data-root)//tei:sense[@xml:id=$sense-id],
$concept := $sense/ancestor::tei:div/tei:head/text(),
$uid := util:uuid(),
$newswl :=
<tls:ann xmlns="http://www.tei-c.org/ns/1.0" concept="{$concept}" xml:id="{$uid}">
<link target="#{$line-id} #{$sense-id}"/>
<tls:text>
<tls:srcline title="{$title}" target="#{$line-id}">{$line/text()}</tls:srcline>
<tls:line title="{$title-en}">{$tr/text()}</tls:line>
</tls:text>
<form  corresp="{$sense/parent::tei:entry/tei:form/@corresp}">
{$sense/parent::tei:entry/tei:form/tei:orth,
$sense/parent::tei:entry/tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]}
</form>
<sense corresp="#{$sense-id}">
{$sense/*}
</sense>
<tls:metadata resp="#{$user}" created="{current-dateTime()}">
<respStmt>{if (("tls-editor") = sm:id()//sm:group/text()) then 
<resp>added and approved</resp> else
<resp>added</resp>}
<name>{$user}</name>
</respStmt>
</tls:metadata>
</tls:ann>,
$path := concat($config:tls-data-root, "/notes/new/", substring($uid, 1, 2))
return (
if (xmldb:collection-available($path)) then () else
(xmldb:create-collection($notes-path, substring($uid, 1, 2)),
sm:chmod(xs:anyURI($path), "rwxrwxr--"),
sm:chown(xs:anyURI($path), $user),
sm:chgrp(xs:anyURI($path), "tls-user")
),
let $res := (xmldb:store($path, concat($uid, ".xml"), $newswl)) 
return
if ($res) then (
sm:chmod(xs:anyURI($res), "rwxrwxr--"),
sm:chown(xs:anyURI($res), $user),
sm:chgrp(xs:anyURI($res), "tls-editor"),
"OK")
else
"Some error occurred, could not save resource")
else
"Wrong parameters received"

