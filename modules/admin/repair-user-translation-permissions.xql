xquery version "3.1";

(:~
 : Repair legacy per-user translation collections.
 :
 : Run as a DBA. Private translations are stored in
 : /db/users/$user/translations, so the collection and its resources need to
 : be owned by $user. This repairs collections accidentally owned by the
 : package user and resources with stale owner/group values.
 :)

declare namespace sm="http://exist-db.org/xquery/securitymanager";

declare variable $local:user-root := "/db/users";
declare variable $local:group := "tls-user";
declare variable $local:collection-mode := "rwxr-x--x";
declare variable $local:resource-mode := "rw-r-----";

declare function local:permission($path as xs:string) as element(sm:permission)? {
  sm:get-permissions(xs:anyURI($path))/sm:permission
};

declare function local:repair-resource($path as xs:string, $owner as xs:string) as element(resource)? {
  let $before := local:permission($path)
  return
    if (
      $before/@owner = $owner and
      $before/@group = $local:group and
      $before/@mode = $local:resource-mode
    ) then
      ()
    else
      (
        sm:chown(xs:anyURI($path), $owner),
        sm:chgrp(xs:anyURI($path), $local:group),
        sm:chmod(xs:anyURI($path), $local:resource-mode),
        <resource path="{$path}"
                  before-owner="{$before/@owner}"
                  before-group="{$before/@group}"
                  before-mode="{$before/@mode}"
                  owner="{$owner}"
                  group="{$local:group}"
                  mode="{$local:resource-mode}"/>
      )
};

declare function local:repair-collection($user as xs:string) as element(collection)? {
  let $path := $local:user-root || "/" || $user || "/translations"
  return
    if (not(xmldb:collection-available($path))) then
      ()
    else
      let $before := local:permission($path)
      let $resources :=
        for $resource in xmldb:get-child-resources($path)
        return local:repair-resource($path || "/" || $resource, $user)
      return
        if (
          $before/@owner = $user and
          $before/@group = $local:group and
          $before/@mode = $local:collection-mode and
          empty($resources)
        ) then
          ()
        else
          (
            sm:chown(xs:anyURI($path), $user),
            sm:chgrp(xs:anyURI($path), $local:group),
            sm:chmod(xs:anyURI($path), $local:collection-mode),
            <collection path="{$path}"
                        before-owner="{$before/@owner}"
                        before-group="{$before/@group}"
                        before-mode="{$before/@mode}"
                        owner="{$user}"
                        group="{$local:group}"
                        mode="{$local:collection-mode}">
              {$resources}
            </collection>
          )
};

<repair>
{
  for $user in xmldb:get-child-collections($local:user-root)
  order by lower-case($user)
  return local:repair-collection($user)
}
</repair>
