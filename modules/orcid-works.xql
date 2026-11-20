xquery version "3.1";
import module namespace ow="http://hxwd.org/lib/orcid-works" at "lib/orcid-works.xqm";
import module namespace orcid="http://hxwd.org/orcid" at "orcid-link.xql";

declare option exist:serialize "method=html5 media-type=text/html";

let $user := string(sm:id()//sm:real/sm:username)
let $owner := $user != '' and $user != 'guest'
let $requested := normalize-space(request:get-parameter('contributor', request:get-parameter('user', '')))
let $month := normalize-space(request:get-parameter('month', ''))
let $type := normalize-space(request:get-parameter('type', ''))
let $format := request:get-parameter('format', '')
let $method := request:get-method()
let $subject := if ($requested != '') then $requested else $user
let $valid := ow:valid($subject, $month, $type)
let $path := if ($valid) then ow:path($subject, $month, $type) else ''
let $token := if ($owner) then
  let $saved := string(session:get-attribute('tls.orcid-works.csrf'))
  return if ($saved != '') then $saved else
    let $new := util:uuid()
    return (session:set-attribute('tls.orcid-works.csrf', $new), $new)[last()]
  else ''
let $published := if ($valid and doc-available($path)) then doc($path)/work else ()
let $created := if ($method = 'POST' and $owner and $subject = $user and
                    $token != '' and request:get-parameter('csrf', '') = $token and $valid)
  then try { ow:publish($user, $month, $type) } catch * { () }
  else ()
let $work := ($published, $created)[1]
let $base := replace(request:get-url(), '\?.*$', '')
let $url := replace($base, 'modules/orcid-works\.xql$', 'orcid-work.html') ||
            '?contributor=' || encode-for-uri($subject) || '&month=' || $month || '&type=' || $type
let $bib-url := 'orcid-works.xql?contributor=' || encode-for-uri($subject) || '&month=' || $month || '&type=' || $type || '&format=bib'
return
if ($format = 'bib' and exists($work)) then (
  response:set-header('Content-Type', 'application/x-bibtex; charset=UTF-8'),
  response:set-header('Content-Disposition', 'attachment; filename="tls-' || ow:key($subject, $month, $type) || '.bib"'),
  util:declare-option('exist:serialize', 'method=text media-type=application/x-bibtex'),
  ow:bib($work, $url)
) else
<html><head><meta charset="UTF-8"/><title>TLS research outputs</title></head><body>
  <p><a href="../settings.html">Settings</a> · <a href="../index.html">TLS</a></p>
  <h1>TLS research outputs</h1>
  {if ($work) then (
    <article><h2>{ow:title($work)}</h2>
    <p>Contributor: {string($work/@contributor)}. Published {string($work/@published)} by the TLS Project.</p>
    <p>This installment preserves the public contributions recorded for {string($work/@month)}.</p>
    <ol>{for $item in $work/item order by string($item/@when)
      return <li><a href="../textview.html?location={encode-for-uri(string($item/@source))}">{string($item/@title)} · {string($item/@source)}</a>
        <small> {string($item/@when)}</small><p>{string($item)}</p></li>}</ol>
    <p><a href="{$bib-url}">Download BibTeX (.bib) for ORCID</a></p></article>
  ) else if ($requested != '' or ($month != '' and $type != '')) then (
    response:set-status-code(404), <p>No published installment exists for this selection. Months without verifiable public contributions are omitted.</p>
  ) else ()}
  {if ($owner and $requested = '') then
    <section><h2>Publish a monthly installment</h2>
      <p>Available completed months are listed below. Only dated, attributable public material can be included. Once published, an installment stays fixed.</p>
      <p>Older translation revisions and text edits without reliable dated attribution cannot be reconstructed and are omitted. Text edits are recorded from this release onward.</p>
      <p>{if (orcid:current-id()) then 'Connected ORCID iD: ' || orcid:current-id() else 'Connect your ORCID iD in Settings.'}</p>
      {let $available := ow:available($user)
       return if (empty($available)) then <p>No completed months with verifiable public contributions were found.</p>
       else <ul>{for $a in $available
         let $m := string($a/@month)
         let $t := string($a/@type)
         let $existing := doc-available(ow:path($user, $m, $t))
         return <li><strong>{$m}</strong> · {$t} ({string($a/@count)} contributions)
           {if ($existing) then (
             <a href="../orcid-work.html?contributor={encode-for-uri($user)}&amp;month={$m}&amp;type={$t}">View published installment</a>,
             ' · ',
             <a href="orcid-works.xql?contributor={encode-for-uri($user)}&amp;month={$m}&amp;type={$t}&amp;format=bib">Download BibTeX (.bib)</a>
           )
            else <form method="post" action="orcid-works.xql" style="display:inline">
              <input type="hidden" name="csrf" value="{$token}"/>
              <input type="hidden" name="month" value="{$m}"/>
              <input type="hidden" name="type" value="{$t}"/>
              <button type="submit">Publish</button>
            </form>}</li>}</ul>}
      <h2>Your published installments</h2>
      <ul>{if (xmldb:collection-available($ow:root)) then
        for $w in collection($ow:root)/work[@user = $user]
        order by string($w/@month) descending
        return <li>
          <a href="../orcid-work.html?contributor={encode-for-uri($user)}&amp;month={string($w/@month)}&amp;type={string($w/@type)}">{ow:title($w)}</a>
          {' · '}
          <a href="orcid-works.xql?contributor={encode-for-uri($user)}&amp;month={string($w/@month)}&amp;type={string($w/@type)}&amp;format=bib">Download BibTeX (.bib)</a>
        </li>
      else ()}</ul>
      <p>Import the downloaded file in ORCID under Works → Add → Add BibTeX. Review its metadata before importing.</p>
    </section> else ()}
</body></html>
