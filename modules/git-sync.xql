xquery version "3.1";
import module namespace http="http://expath.org/ns/http-client";
import module namespace ghx="http://exist-db.org/lib/githubxq";
import module namespace log="http://hxwd.org/log" at "log.xql";
import module namespace config="http://hxwd.org/config" at "config.xqm";

declare variable $git-config := if(doc('../access-config.xml')) then doc('../access-config.xml') else <response status="fail"><message>Load config.xml file please.</message></response>;

declare variable $gitSecret := if($git-config//gitToken-variable != '') then 
                                    environment-variable($git-config//gitToken-variable/text())
                              else $git-config//gitToken/text();
declare variable $gitKey := if($git-config//private-key-variable != '') then 
                                    environment-variable($git-config//private-key-variable/text())
                              else $git-config//private-key/text();
declare variable $exist-collection := $git-config//exist-collection/text();

(: Github repository :)
declare variable $repo-name := $git-config//repo-name/text();
                              
declare variable $git-log := $config:tls-log-collection || "/git";

let $exempt := ("/db/apps/tls-app/modules/view.xql", "/db/apps/tls-app/controller.xql")
let $data := request:get-data()
let $file-data := ghx:execute-webhook($data, $exist-collection, $repo-name, "master",  $gitSecret, $gitKey)

return 

for $f in $file-data 
let $perm :=  if ($f = $exempt) then () else ( sm:chown(xs:anyURI($f), "tls"),
    sm:chgrp(xs:anyURI($f), "tls-user"),
    sm:chmod(xs:anyURI($f), "rw-rw-r--") )

return log:info($git-log, $f)