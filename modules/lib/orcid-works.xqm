xquery version "3.1";
module namespace ow="http://hxwd.org/lib/orcid-works";

import module namespace config="http://hxwd.org/config" at "../config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare variable $ow:root := $config:tls-data-root || '/orcid-works';
declare variable $ow:types := ('translation', 'annotation', 'editing');

declare function ow:valid($user as xs:string, $month as xs:string, $type as xs:string) as xs:boolean {
  matches($user, '^[A-Za-z0-9@._-]+$') and
  matches($month, '^[0-9]{4}-(0[1-9]|1[0-2])$') and $type = $ow:types and
  $month lt substring(string(current-date()), 1, 7)
};

declare function ow:key($user as xs:string, $month as xs:string, $type as xs:string) as xs:string {
  encode-for-uri($user) || '-' || $month || '-' || $type
};

declare function ow:path($user as xs:string, $month as xs:string, $type as xs:string) as xs:string {
  $ow:root || '/' || ow:key($user, $month, $type) || '.xml'
};

declare function ow:events($user as xs:string, $month as xs:string, $type as xs:string) as element(item)* {
  if (not(ow:valid($user, $month, $type))) then ()
  else if ($type = 'translation') then
    for $s in collection($config:tls-translation-root)//tei:seg[@resp = '#' || $user][starts-with(@modified, $month)]
    let $doc := $s/ancestor::tei:TEI[1]
    let $uri := string(base-uri($s))
    let $id := substring-after(string($s/@corresp), '#')
    where $id != '' and not(matches($uri, '/(ai|queue|by-hand)/')) and
          not(contains($uri, '/vault/')) and normalize-space(string($s)) != ''
    return <item when="{string($s/@modified)}" source="{$id}" title="{normalize-space(string($doc//tei:titleStmt/tei:title[1]))}">{normalize-space(string($s))}</item>
  else if ($type = 'annotation') then
    for $a in collection($config:tls-data-root || '/notes')//*[self::tls:ann or self::tls:span][tls:metadata/@resp = '#' || $user][starts-with(tls:metadata/@created, $month)]
    let $source := substring-after(string(($a//tls:srcline/@target)[1]), '#')
    where $source != '' and normalize-space(string($a)) != ''
    return <item when="{string($a/tls:metadata/@created)}" source="{$source}" title="Annotation">{normalize-space(string($a))}</item>
  else
    for $e in collection($config:tls-data-root || '/vault/crypt')//tei:change[@type = 'text-edit'][@who = '#' || $user][starts-with(@when, $month)]
    let $source := substring-after(string($e/@target), '#')
    where $source != ''
    return <item when="{string($e/@when)}" source="{$source}" title="Text edit">{normalize-space(string($e))}</item>
};

(: Discover completed months from the same public, attributable sources used
   to build an installment. :)
declare function ow:available($user as xs:string) as element(available)* {
  for $type in $ow:types
  let $dates :=
    if ($type = 'translation') then
      for $s in collection($config:tls-translation-root)//tei:seg[@resp = '#' || $user][@modified]
      let $uri := string(base-uri($s))
      where starts-with(string($s/@corresp), '#') and normalize-space(string($s)) != '' and
            not(matches($uri, '/(ai|queue|by-hand)/')) and not(contains($uri, '/vault/'))
      return string($s/@modified)
    else if ($type = 'annotation') then
      for $a in collection($config:tls-data-root || '/notes')//*[self::tls:ann or self::tls:span][tls:metadata/@resp = '#' || $user]
      where starts-with(string(($a//tls:srcline/@target)[1]), '#') and normalize-space(string($a)) != ''
      return string($a/tls:metadata/@created)
    else
      for $e in collection($config:tls-data-root || '/vault/crypt')//tei:change[@type = 'text-edit'][@who = '#' || $user]
      where starts-with(string($e/@target), '#')
      return string($e/@when)
  for $month in distinct-values(for $date in $dates return substring($date, 1, 7))
  where ow:valid($user, $month, $type)
  let $count := count($dates[starts-with(., $month)])
  where $count gt 0
  order by $month descending, $type
  return <available month="{$month}" type="{$type}" count="{$count}"/>
};

declare function ow:publish($user as xs:string, $month as xs:string, $type as xs:string) as element(work) {
  if (not(ow:valid($user, $month, $type))) then error(xs:QName('ow:INVALID'), 'Invalid or unfinished month')
  else if (doc-available(ow:path($user, $month, $type))) then doc(ow:path($user, $month, $type))/work
  else
    let $items := ow:events($user, $month, $type)
    let $name := normalize-space(string(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))))
    let $title := 'TLS ' || $type || ' contributions, ' || $month
    let $work := <work user="{$user}" month="{$month}" type="{$type}" published="{current-date()}" title="{$title}" contributor="{if ($name != '') then $name else $user}">{$items}</work>
    return
      if (empty($items)) then error(xs:QName('ow:EMPTY'), 'No verified public contributions in this month')
      else (
        if (not(xmldb:collection-available($ow:root))) then (
          xmldb:create-collection($config:tls-data-root, 'orcid-works'),
          sm:chgrp(xs:anyURI($ow:root), 'tls-user'),
          sm:chmod(xs:anyURI($ow:root), 'rwxrwxr-x')
        ) else (),
        xmldb:store($ow:root, ow:key($user, $month, $type) || '.xml', $work),
        sm:chmod(xs:anyURI(ow:path($user, $month, $type)), 'rw-r--r--'),
        $work
      )[last()]
};

declare function ow:title($work as element(work)) as xs:string {
  let $count := count($work/item)
  return string($work/@title) ||
    (if ($work/@type = 'annotation') then
      ' (' || $count || ' ' || (if ($count = 1) then 'annotation' else 'annotations') || ')'
     else '')
};

declare function ow:bib($work as element(work), $url as xs:string) as xs:string {
  let $escape := function($v as xs:string) as xs:string {
    replace(replace(replace($v, '[{}\\]', ' '), '[\r\n]+', ' '), '\s+', ' ')
  }
  let $count := count($work/item)
  return string-join((
    '@misc{' || ow:key(string($work/@user), string($work/@month), string($work/@type)) || ',',
    '  author = {' || $escape(string($work/@contributor)) || '},',
    '  title = {' || $escape(ow:title($work)) || '},',
    if ($work/@type = 'annotation') then '  note = {' || $count || ' ' || (if ($count = 1) then 'annotation' else 'annotations') || ' in this monthly installment},' else (),
    '  year = {' || substring(string($work/@month), 1, 4) || '},',
    '  month = {' || substring(string($work/@month), 6, 2) || '},',
    '  publisher = {TLS Project},',
    '  url = {' || $url || '}',
    '}'
  ), codepoints-to-string(10))
};

declare function ow:render-work($node as node()*, $model as map(*)) {
  let $user := normalize-space(request:get-parameter('contributor', ''))
  let $month := normalize-space(request:get-parameter('month', ''))
  let $type := normalize-space(request:get-parameter('type', ''))
  let $work := if (ow:valid($user, $month, $type) and
                   doc-available(ow:path($user, $month, $type)))
               then doc(ow:path($user, $month, $type))/work else ()
  return
    if (empty($work)) then (response:set-status-code(404),
      <div><h1>Publication not found</h1><p><a href="settings.html">Return to TLS</a></p></div>)
    else <article>
      <h1>{ow:title($work)}</h1>
      <p>Contributor: {string($work/@contributor)}. Published {string($work/@published)} by the TLS Project.</p>
      <p>This installment preserves the public contributions recorded for {string($work/@month)}.</p>
      <ol>{for $item in $work/item order by string($item/@when)
        return <li><a href="textview.html?location={encode-for-uri(string($item/@source))}">{string($item/@title)} · {string($item/@source)}</a>
          <small> {string($item/@when)}</small><p>{string($item)}</p></li>}</ol>
      <p><a href="modules/orcid-works.xql?contributor={encode-for-uri($user)}&amp;month={$month}&amp;type={$type}&amp;format=bib">Download BibTeX (.bib) for ORCID</a> (sign in to TLS if prompted).</p>
    </article>
};
