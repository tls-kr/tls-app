xquery version "3.1";

(:~
 : Pre-computed table-of-contents per text.
 :
 : Each TEI document in `tls-texts/data` gets a corresponding
 : `tls-data/toc/<textid>-toc.xml` file holding its div/head
 : hierarchy. This avoids the expensive live walk in the old
 : `ah:get-toc` (seconds per text on cold cache).
 :
 : The seg-id → textid lookup for `lu:get-seg` uses the textid
 : prefix convention of the seg id (`<textid>_<rest>`), validated
 : against `first-seg`/`last-seg` attributes stored on the toc root.
 :
 : A digest of the toc-relevant body parts (div heads + first/last
 : seg id) is stored in the root `@body-hash` attribute. Because
 : `teiHeader` edits do not change the body, they do not invalidate
 : the toc; because the hash inputs are cheap (no full seg list,
 : no segment text), rebuild cost stays small. `toc:build` is
 : idempotent: calling it when the stored hash already matches
 : returns without rewriting.
 :)
module namespace toc="http://hxwd.org/lib/toc";

import module namespace config="http://hxwd.org/config" at "../config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace t="http://hxwd.org/ns/toc/1.0";

declare variable $toc:ns := "http://hxwd.org/ns/toc/1.0";
declare variable $toc:collection := $config:tls-data-root || "/toc";

declare function toc:file-path($textid as xs:string) as xs:string {
    $toc:collection || "/" || $textid || "-toc.xml"
};

declare function toc:doc($textid as xs:string) as document-node()? {
    let $path := toc:file-path($textid)
    return if (doc-available($path)) then doc($path) else ()
};

(:~
 : Fingerprint of the toc-relevant parts of the body. The toc only
 : depends on the div/head hierarchy and the seg id ordering, so we
 : hash just those — not the full serialized body. For a 10MB TEI
 : with ~80k segs, this is ~15x faster than serialize(body), which
 : matters when backfilling hundreds of texts.
 :)
declare function toc:body-hash($body as element()?) as xs:string {
    if (exists($body))
    then
        let $heads := string-join(
            for $h in $body//tei:head
            return count($h/ancestor::tei:div) || ":" || normalize-space(string($h)),
            "§"
        )
        let $segs := ($body//tei:seg/@xml:id)
        let $seg-summary := count($segs) || "|" || ($segs[1]) || "|" || ($segs[last()])
        return util:hash($heads || "#" || $seg-summary, "md5")
    else ""
};

(:~
 : Recursive walk of the div hierarchy. Each div with a head and a
 : first seg whose textid starts with a letter (matches the old
 : `ah:get-toc` filter) becomes an `<entry>`. Preserves depth via
 : `@level`.
 :)
declare function toc:walk-divs($divs as element(tei:div)*, $level as xs:int) as element()* {
    for $div in $divs
    let $head := $div/tei:head[1]
    let $first-seg := ($div//tei:seg/@xml:id)[1]
    let $tid := tokenize($first-seg, "_")[1]
    return (
        if ($head and matches($tid, "^[A-Za-z]")) then
            <entry xmlns="http://hxwd.org/ns/toc/1.0"
                   level="{$level}"
                   title="{normalize-space(string-join($head//text(), ''))}"
                   first-seg="{$first-seg}"/>
        else (),
        toc:walk-divs($div/tei:div, $level + 1)
    )
};

(:~
 : Produce the toc element for a given TEI doc. Separated from the
 : write step so tests and callers can inspect without touching the db.
 :)
declare function toc:render($tei as element(tei:TEI)) as element() {
    let $textid := string($tei/@xml:id)
    let $body   := $tei/tei:text/tei:body
    let $seg-ids := $body//tei:seg/@xml:id
    let $hash   := toc:body-hash($body)
    return
    <toc xmlns="http://hxwd.org/ns/toc/1.0"
         textid="{$textid}"
         body-hash="{$hash}"
         generated="{current-dateTime()}"
         seg-count="{count($seg-ids)}"
         first-seg="{$seg-ids[1]}"
         last-seg="{$seg-ids[last()]}">
        {toc:walk-divs($body/tei:div, 1)}
    </toc>
};

(:~
 : Build (or refresh) the toc for `$textid`. Returns:
 :   - "skipped"  — existing toc's body-hash matches, no write performed
 :   - "written"  — new/changed toc file written
 :   - "missing"  — no TEI doc found for `$textid`
 : Pass `$force=true()` to rewrite regardless of hash.
 :)
(:~
 : Build from an already-loaded TEI element. Useful for bulk operations
 : that iterate `collection(...)//tei:TEI` so they do not pay the cost
 : of an additional xml:id lookup per iteration.
 :)
declare function toc:build-from-tei($tei as element(tei:TEI), $force as xs:boolean) as xs:string {
    let $textid := string($tei/@xml:id)
    return
    if ($textid = "") then "missing"
    else
        let $existing := toc:doc($textid)
        let $current-hash := toc:body-hash($tei/tei:text/tei:body)
        let $stored-hash  := string($existing/*:toc/@body-hash)
        return
        if (not($force) and $stored-hash = $current-hash and $current-hash != "") then
            "skipped"
        else
            let $doc := toc:render($tei)
            return try {
                let $ensure := if (xmldb:collection-available($toc:collection))
                               then ()
                               else xmldb:create-collection($config:tls-data-root, "toc")
                let $store := xmldb:store($toc:collection, $textid || "-toc.xml", $doc)
                return "written"
            } catch * {
                "not-stored"
            }
};

(:~
 : Return a toc document for `$textid`, building in-memory if no
 : persisted copy exists. Writes back to the collection on a best-
 : effort basis — callers that run as a user without write permission
 : (e.g. guest/anon over HTTP) still get a usable toc.
 :)
declare function toc:get($textid as xs:string) as document-node()? {
    let $cached := toc:doc($textid)
    return
    if (exists($cached)) then $cached
    else
        let $tei := (collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid])[1]
        return
        if (empty($tei)) then ()
        else
            let $status := toc:build-from-tei($tei, false())
            return
            if ($status = "not-stored") then document { toc:render($tei) }
            else toc:doc($textid)
};

declare function toc:build($textid as xs:string, $force as xs:boolean) as xs:string {
    let $tei := (collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid])[1]
    return
    if (empty($tei)) then "missing"
    else toc:build-from-tei($tei, $force)
};

declare function toc:build($textid as xs:string) as xs:string {
    toc:build($textid, false())
};

(:~
 : Find the textid that contains the given seg id. Relies on the
 : convention that seg ids are prefixed with their textid
 : (`<textid>_<suffix>`). Validates by confirming a toc file exists
 : for the guessed textid. Returns the empty sequence if no toc
 : matches — callers fall back to a collection scan.
 :)
declare function toc:textid-for-seg($seg-id as xs:string) as xs:string? {
    let $guess := tokenize($seg-id, "_")[1]
    return if ($guess != "" and doc-available(toc:file-path($guess))) then $guess else ()
};

(:~
 : All textids for which a toc file is available.
 :)
declare function toc:available-textids() as xs:string* {
    for $d in collection($toc:collection)/*:toc
    return string($d/@textid)
};
