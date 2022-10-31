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
 : Create collection and resource therein if they do not exist. 
 : Both will have the permission passed as the last parameter.
 : If the resource does not exist, it is created and filled with the content of the third parameter
 : 
 : @param $collection-path
 : @param $resource-name
 : @param $default item() Default contents of the resource if it has to be created
 : @param $permissions map(xs:string, xs:string) with "owner", "group", "mode"
 :)

declare
function dbu:ensure-resource($collection-path as xs:string, $resource-name as xs:string, $default as item(), $permissions as map(*)) as xs:string {
    let $collection := dbu:ensure-collection($collection-path, $permissions)
    return
    if (xmldb:get-child-resources($collection) = $resource-name) then
        concat($collection, "/", $resource-name)
    else
        let $rst := xmldb:store($collection, $resource-name, $default)
        return dbu:set-permissions($rst, $permissions)
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

