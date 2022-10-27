xquery version "3.1";

module namespace dbu="http://exist-db.org/xquery/utility/db";

import module namespace config="http://exist-db.org/xquery/apps/config" at "repo-config.xqm";

declare variable $dbu:default-permissions := config:repo-permissions();

(:~
 : create collection(s) if they do not exist
 : any newly created collection will have the package-permissions set
 : will throw an error if the current user does not have the appropriate rights
 :
 : @param $path xs:string
 : @returns the path that was entered
 :)
declare
function dbu:ensure-collection($path as xs:string) as xs:string {
    if (xmldb:collection-available($path))
    then $path
    else
        tokenize($path, "/")
        => tail() 
        => fold-left("", dbu:create-collection-with-repo-permissions#2)
};

(:~
 : create collection(s) if they do not exist
 : any newly created collection will have the permissions given in the second parameter
 : will throw an error if the current user does not have the appropriate rights
 :
 : @param $path xs:string
 : @param $permissions map(xs:string, xs:string) with "owner", "group", "mode"
 : @returns the path that was entered
 :)
declare
function dbu:ensure-collection($path as xs:string, $permissions as map(*)) as xs:string {
    if (xmldb:collection-available($path))
    then $path
    else
        tokenize($path, "/")
        => tail() 
        => fold-left("", dbu:create-collection(?, ?, $permissions))
};

(:~
 : set owner, group and mode for a collection or resource to package defaults
 : will throw an error, if the current user does not have the appropriate rights
 :
 : @param $resource-or-collection xs:string
 : @returns the path that was entered
 :)
declare 
function dbu:set-repo-permissions ($resource-or-collection as xs:string) as xs:string {
    dbu:set-permissions($resource-or-collection, $dbu:default-permissions)
};

(:~
 : set owner, group and mode for a collection or resource
 : will throw an error, if the current user does not have the appropriate rights
 :
 : @param $resource-or-collection xs:string
 : @param $permissions map(xs:string, xs:string) with "owner", "group", "mode"
 : @returns the path that was entered
 :)
declare 
function dbu:set-permissions ($resource-or-collection as xs:string, $permissions as map(*)) as xs:string {
    sm:chown($resource-or-collection, $permissions?owner),
    sm:chgrp($resource-or-collection, $permissions?group),
    sm:chmod(xs:anyURI($resource-or-collection), $permissions?mode),
    $resource-or-collection
};

declare 
    %private
function dbu:create-collection-with-repo-permissions ($collection as xs:string, $next as xs:string) as xs:string {
    if (xmldb:collection-available(concat($collection, '/', $next)))
    then concat($collection, '/', $next)
    else
        xmldb:create-collection($collection, $next)
        => dbu:set-repo-permissions()
};


declare 
    %private
function dbu:create-collection ($collection as xs:string, $next as xs:string, $permissions as map(*)) as xs:string {
    if (xmldb:collection-available(concat($collection, '/', $next)))
    then concat($collection, '/', $next)
    else
        xmldb:create-collection($collection, $next)
        => dbu:set-permissions($permissions)
};
