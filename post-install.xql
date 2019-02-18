xquery version "3.0";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};




declare function local:proc($uri as xs:string, $perm as xs:string)
{ 
  sm:chmod(xs:anyURI($uri), $perm),
  sm:chgrp(xs:anyURI($uri), "tls-user"),
  sm:chown(xs:anyURI($uri), "tls"),

for $u in xmldb:get-child-collections($uri)
let $t := $uri || "/" || $u
return 
  local:proc($t, $perm)
  ,
for $u in xmldb:get-child-resources($uri)
let $t := $uri || "/" || $u
return
(
  sm:chmod(xs:anyURI($t), $perm),
  sm:chgrp(xs:anyURI($t), "tls-user"),
  sm:chown(xs:anyURI($t), "tls")
)
};

(
(: execute api :)
sm:group-exists("tls-user") or sm:create-group("tls-user"),
sm:group-exists("tls-editor") or sm:create-group("tls-editor"),
sm:group-exists("tls-admin") or sm:create-group("tls-admin"),

sm:create-account("test", "test", "tls-user"),

for $m in sm:get-group-members("tls-user")
let $path := concat("/db/user/", $m)
return
	(
	local:mkcol("/db", concat("user/", $m)),
	sm:chown(xs:anyURI($path), $m),
	sm:chgrp(xs:anyURI($path), $m)
	)

,

local:proc($target || "/api", "rwxr-xr-x")

)
