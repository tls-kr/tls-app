xquery version "3.1";

module namespace orcid="http://hxwd.org/orcid";

declare variable $orcid:links := '/db/orcid-links';
declare variable $orcid:id-pattern := '^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$';

(: Store a read-only view of the private link file for signed-in TLS users. :)
declare function orcid:record-link($username as xs:string, $id as xs:string) {
    if (not(sm:is-dba(string(sm:id()//sm:real/sm:username))) or
        not(matches($username, '^[A-Za-z0-9@._-]+$')) or
        not(sm:user-exists($username)) or not(matches($id, $orcid:id-pattern))) then
        error(xs:QName('orcid:INVALID_LINK'), 'Cannot record ORCID link')
    else
        let $collection := $orcid:links
        let $resource := $collection || '/' || $username || '.xml'
        return (
            if (not(xmldb:collection-available($collection))) then
                xmldb:create-collection('/db', 'orcid-links') else (),
            sm:chown(xs:anyURI($collection), 'admin'),
            sm:chgrp(xs:anyURI($collection), 'tls-user'),
            sm:chmod(xs:anyURI($collection), 'rwxr-x---'),
            xmldb:store($collection, $username || '.xml', <link user="{$username}" id="{$id}"/>),
            sm:chown(xs:anyURI($resource), 'admin'),
            sm:chgrp(xs:anyURI($resource), 'tls-user'),
            sm:chmod(xs:anyURI($resource), 'rw-r-----')
        )
};

declare function orcid:clear-link($username as xs:string) as empty-sequence() {
    if (not(sm:is-dba(string(sm:id()//sm:real/sm:username))) or
        not(matches($username, '^[A-Za-z0-9@._-]+$'))) then
        error(xs:QName('orcid:FORBIDDEN'), 'A DBA account is required')
    else if (xmldb:collection-available($orcid:links) and
             doc-available($orcid:links || '/' || $username || '.xml')) then
        xmldb:remove($orcid:links, $username || '.xml')
    else ()
};

declare function orcid:current-id() as xs:string? {
    let $username := string(sm:id()//sm:real/sm:username)
    let $path := $orcid:links || '/' || $username || '.xml'
    return
        if ($username = '' or $username = 'guest' or not(doc-available($path))) then ()
        else
            let $link := doc($path)/link[@user = $username]
            let $id := string($link/@id)
            return if (matches($id, $orcid:id-pattern)) then $id else ()
};

(: Run once after deployment to populate read-only records for existing links. :)
declare function orcid:sync-links() {
    if (not(sm:is-dba(string(sm:id()//sm:real/sm:username)))) then
        error(xs:QName('orcid:FORBIDDEN'), 'A DBA account is required')
    else
        let $path := normalize-space(environment-variable('TLS_ORCID_LINKS_PATH'))
        return
            if ($path = '' or not(starts-with($path, '/')) or not(file:exists($path))) then
                error(xs:QName('orcid:LINK_FILE'), 'TLS_ORCID_LINKS_PATH is unavailable')
            else
                for $line in tokenize(file:read-unicode($path), '\r\n|\n|\r')
                let $id := substring-before($line, '=')
                let $username := substring-after($line, '=')
                where matches($id, $orcid:id-pattern) and
                      matches($username, '^[A-Za-z0-9@._-]+$') and
                      sm:user-exists($username)
                return orcid:record-link($username, $id)
};

(: Called by the ORCID callback as the system subject for generated accounts. :)
declare function orcid:ensure-user($username as xs:string, $name as xs:string) {
    if (not(matches($username, '^orcid-[0-9]{15}[0-9X]$')) or not(sm:user-exists($username))) then
        error(xs:QName('orcid:INVALID_USER'), 'Invalid ORCID account')
    else
        let $home := '/db/users'
        let $usercoll := $home || '/' || $username
        let $full-name := normalize-space(sm:get-account-metadata($username, xs:anyURI('http://axschema.org/namePerson')))
        return (
            if (not(xmldb:collection-available($home))) then xmldb:create-collection('/db', 'users') else (),
            if (not(xmldb:collection-available($usercoll))) then xmldb:create-collection($home, $username) else (),
            sm:chmod(xs:anyURI($usercoll), 'rwxrwxr--'),
            sm:chgrp(xs:anyURI($usercoll), 'tls-user'),
            sm:chown(xs:anyURI($usercoll), $username),
            if ($full-name = '') then
                sm:set-account-metadata($username, xs:anyURI('http://axschema.org/namePerson'), $name)
            else ()
        )
};

(: DBA maintenance: remove a generated ORCID account and all of its home collection. :)
declare function orcid:remove-user($username as xs:string) as xs:string {
    if (not(sm:is-dba(string(sm:id()//sm:real/sm:username)))) then
        error(xs:QName('orcid:FORBIDDEN'), 'A DBA account is required')
    else if (not(matches($username, '^orcid-[0-9]{15}[0-9X]$'))) then
        error(xs:QName('orcid:INVALID_USER'), 'Expected a generated ORCID username')
    else
        let $path := normalize-space(environment-variable('TLS_ORCID_LINKS_PATH'))
        let $home := '/db/users/' || $username
        let $digits := substring($username, 7)
        let $id := string-join((substring($digits, 1, 4), substring($digits, 5, 4),
                                substring($digits, 9, 4), substring($digits, 13, 4)), '-')
        return
            if ($path = '' or not(starts-with($path, '/')) or not(file:exists($path))) then
                error(xs:QName('orcid:LINK_FILE'), 'TLS_ORCID_LINKS_PATH is unavailable')
            else
                let $contents := file:read-unicode($path)
                let $lines := tokenize($contents, '\r\n|\n|\r')
                let $mapped := $lines[matches(., '^[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]=')
                                      and substring-after(., '=') = $username]
                let $entry := $id || '=' || $username
                return
                    if (exists($mapped[. != $entry])) then
                        error(xs:QName('orcid:LINK_MISMATCH'), 'Another ORCID iD maps to this account')
                    else
                        let $updated := string-join($lines[. != $entry], codepoints-to-string(10))
                                        || codepoints-to-string(10)
                        let $written := if (exists($mapped)) then
                            file:serialize(text { $updated }, $path, ('method=text', 'encoding=UTF-8'))
                            else true()
                        return
                            if (not($written) or (exists($mapped) and file:read-unicode($path) != $updated)) then
                                error(xs:QName('orcid:LINK_WRITE'), 'Could not update the ORCID link file')
                            else (
                                orcid:clear-link($username),
                                if (xmldb:collection-available($home)) then xmldb:remove($home) else (),
                                if (sm:user-exists($username)) then sm:remove-account($username) else (),
                                'Removed ORCID account ' || $username
                            )
};
