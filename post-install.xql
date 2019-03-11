xquery version "3.1";
(:~ The post-install runs after contents are copied to db.
 :
 : @version 0.6.0
 : @see http://www.adamretter.org.uk/presentations/security-in-existdb_xml-prague_existdb_20120210.pdf
 : @see http://localhost:8080/exist/apps/doc/security.xml?field=all&id=D3.21.11#permissions
 :)


(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare variable $api := $target || "/api";
declare variable $ace := $target || '/modules/admin';

(: set perm on api :)
declare function local:special-permission($uri as xs:string, $perm as xs:string) as empty-sequence() {
for $res in xmldb:get-child-resources($uri)
let $path := $uri || "/" || $res
return
  ( sm:chown(xs:anyURI($path), "admin"),
    sm:chgrp(xs:anyURI($path), "dba"),
    sm:chmod(xs:anyURI($path), $perm) )
};

(: set execute on api for world :)
local:special-permission($api, "rwxrwxr-x"),

(: ace functions are admin only :)
sm:chown(xs:anyURI($ace), "admin"),
sm:chgrp(xs:anyURI($ace), "dba"),
sm:chmod(xs:anyURI($ace), 'rwxrwx---'),
local:special-permission($ace, 'rwxrwx---')
