xquery version "3.1";

declare function local:proc($uri as xs:string)
{ 
  sm:chmod(xs:anyURI($uri), "rwxrwx---"),
  sm:chgrp(xs:anyURI($uri), "tls-user"),
  sm:chown(xs:anyURI($uri), "tls"),

for $u in xmldb:get-child-collections($uri)
let $t := $uri || "/" || $u
return 
  local:proc($t)
  ,
for $u in xmldb:get-child-resources($uri)
let $t := $uri || "/" || $u
return
(
  sm:chmod(xs:anyURI($t), "rwxrwx---"),
  sm:chgrp(xs:anyURI($t), "tls-user"),
  sm:chown(xs:anyURI($t), "tls")
)
};


local:proc("/db/apps/tls-data/translations")