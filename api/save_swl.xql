xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace ttm="http://tls.kanripo.org/ns/1.0";
declare namespace t2= "http://tls.kanripo.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(:declare option output:method "html5";
declare option output:media-type "text/html";
:)

import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
declare variable $login := xmldb:login("/db/apps", "chris", "tls55");
let $notes-path := concat($config:tls-data-root, "/notes/new/")
let $line-id := request:get-parameter("line", "xx")
let $sense-id := request:get-parameter("sense", "xx")
let $user := "chris"
return

if (($line-id != "xx") and ($sense-id != "xx")) then
let $line := collection($config:tls-texts-root)//tei:seg[@xml:id=$line-id],
$tr := system:as-user("chris", "tls55", collection($config:tls-translation-root)//tei:*[@corresp=concat('#', $line-id)]),
$title-en := $tr/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
$title := $line/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
$sense := collection($config:tls-data-root)//tei:sense[@xml:id=$sense-id],
$concept := $sense/ancestor::tei:div/tei:head/text(),
$newswl :=
<tls:swl xmlns="http://www.tei-c.org/ns/1.0" concept="{$concept}">
<link target="#{$line-id} #{$sense-id}"/>
<tls:text>
<tls:srcline title="{$title}" target="#{$line-id}">{$line/text()}</tls:srcline>
<tls:line title="{$title-en}">{$tr/text()}</tls:line>
</tls:text>
<form>
{$sense/parent::tei:entry/tei:form/tei:orth,
$sense/parent::tei:entry/tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]}
</form>
<sense corresp="#{$sense-id}">
{$sense/*}
</sense>
<tls:metadata user="{$user}" created="{current-dateTime()}">
<respStmt><resp>approved</resp>
<name>{$user}</name>
</respStmt>
</tls:metadata>
</tls:swl>,
$uid := util:uuid(),
$path := concat($config:tls-data-root, "/notes/new/", substring($uid, 1, 2))
return (
if (xmldb:collection-available($path)) then () else
xmldb:create-collection($notes-path, substring($uid, 1, 2)),
if (system:as-user("chris", "tls55", xmldb:store($path, $uid, $newswl))) then 
"OK"
else
"Some error occurred, could not save resource")
else
"Wrong parameters received"

