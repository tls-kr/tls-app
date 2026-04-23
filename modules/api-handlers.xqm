xquery version "3.1";
(:~
 : OpenAPI route handlers for the TLS application.
 :
 : Handlers take the roaster request map and delegate to the business-logic
 : modules (`tlsapi`, `ltr`, `lsf`, `ltp`, `lvs`, `tlslib`, ...). Endpoints
 : declared in `../api.json` resolve to the `ah:*` functions below.
 :)
module namespace ah="http://hxwd.org/api-handlers";

import module namespace config ="http://hxwd.org/config"   at "config.xqm";
import module namespace tlsapi ="http://hxwd.org/tlsapi"   at "../api/tlsapi.xql";
import module namespace ltr    ="http://hxwd.org/lib/translation" at "lib/translation.xqm";
import module namespace ai     ="http://hxwd.org/lib/gemini-ai"   at "lib/gemini-ai.xqm";
import module namespace lsf    ="http://hxwd.org/lib/syn-func"    at "lib/syn-func.xqm";
import module namespace ltp    ="http://hxwd.org/lib/textpanel"   at "lib/textpanel.xqm";
import module namespace lrh    ="http://hxwd.org/lib/render-html" at "lib/render-html.xqm";
import module namespace lu     ="http://hxwd.org/lib/utils"       at "lib/utils.xqm";
import module namespace lvs    ="http://hxwd.org/lib/visits"      at "lib/visits.xqm";
import module namespace tlslib ="http://hxwd.org/lib"     at "tlslib.xql";
import module namespace tu     ="http://hxwd.org/utils"   at "tlsutils.xql";
import module namespace dialogs="http://hxwd.org/dialogs" at "dialogs.xql";
import module namespace wd     ="http://hxwd.org/wikidata"        at "wikidata.xql";
import module namespace bib    ="http://hxwd.org/biblio"          at "biblio.xql";
import module namespace sgn    ="http://hxwd.org/signup"          at "signup.xql";
import module namespace txc    ="http://hxwd.org/text-crit"       at "text-crit.xql";
import module namespace lli    ="http://hxwd.org/lib/link-items"  at "lib/link-items.xqm";
import module namespace lsi    ="http://hxwd.org/special-interest" at "lib/special-interest.xqm";
import module namespace ltg    ="http://hxwd.org/tags"            at "lib/tags.xqm";
import module namespace ltx    ="http://hxwd.org/taxonomy"        at "lib/taxonomy.xqm";
import module namespace lus    ="http://hxwd.org/lib/user-settings" at "lib/user-settings.xqm";
import module namespace toc    ="http://hxwd.org/lib/toc"         at "lib/toc.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(: ===================================================================
 : Wave A — self-contained endpoints
 : =================================================================== :)

(:~
 : GET /api/record_visit?location=<seg-id>
 : Fire-and-forget page visit recording.
 :)
declare function ah:record-visit($request as map(*)) {
    let $sid := ($request?parameters?location, "")[1]
    let $seg := if ($sid) then lu:get-seg($sid) else ()
    return
        if (exists($seg)) then (lvs:record-visit($seg), "ok") else "skip"
};

(:~
 : GET /api/get_toc?textid=<id>
 : Returns the table-of-contents HTML for a text, session-cached per textid.
 : Reads from the pre-computed toc file; falls back to on-the-fly build
 : if a toc doesn't yet exist (first load after a new text is added).
 :)
declare function ah:get-toc($request as map(*)) {
    let $textid := ($request?parameters?textid, "")[1]
    return
    if (session:exists() and contains(session:get-attribute-names(), $textid || "-toc")) then
        session:get-attribute($textid || "-toc")
    else
        let $toc-doc := toc:get($textid)
        let $html := subsequence(
            for $e in $toc-doc/*:toc/*:entry
            let $seg := string($e/@first-seg)
            return
            <a class="dropdown-item" title="{$seg}"
               href="textview.html?location={$seg}&amp;prec=0&amp;foll=30">{string($e/@title)}</a>
            , 1, 100)
        return (
            if (session:exists()) then session:set-attribute($textid || "-toc", $html) else (),
            $html
        )
};

(:~
 : GET /api/show_swl_for_lines?lines=<csv-of-ids>
 : Batched annotations for a set of segment ids.
 :)
declare function ah:show-swl-for-lines($request as map(*)) {
    let $line-ids := tokenize(($request?parameters?lines, "")[1], ",")
    return
    array {
      for $line-id in $line-ids[normalize-space(.) != ""]
      let $link := "#" || $line-id
      let $annotations :=
        collection($config:tls-data-root || "/notes")//tls:ann[.//tls:srcline[@target=$link]] |
        collection($config:tls-data-root || "/notes")//tls:span[.//tls:srcline[@target=$link]] |
        collection($config:tls-data-root || "/notes")//tls:drug[@target=$link] |
        doc($config:tls-data-root || "/core/word-relations.xml")//tei:item[@line-id=$line-id]
      where exists($annotations)
      return map {
        "id": $line-id,
        "html": serialize(
          for $swl in $annotations
          return lrh:format-swl($swl, map{"type": "row", "line-id": $line-id}),
          map {"method": "html", "omit-xml-declaration": true()}
        )
      }
    }
};

(: ===================================================================
 : Wave B — thin stubs delegating to `tlsapi:*` and library modules
 : =================================================================== :)

declare function ah:autocomplete($request as map(*)) {
    tlsapi:autocomplete(
        ($request?parameters?type, "xx")[1],
        ($request?parameters?term, "xx")[1]
    )
};

declare function ah:save-bookmark($request as map(*)) {
    tlsapi:save-bookmark(
        ($request?parameters?word, "xx")[1],
        ($request?parameters?("line-id"), "xx")[1],
        ($request?parameters?line, "xx")[1]
    )
};

declare function ah:save-swl($request as map(*)) {
    tlsapi:save-swl(
        ($request?parameters?("line-id"), "xx")[1],
        ($request?parameters?line, "xx")[1],
        ($request?parameters?sense, "xx")[1],
        ($request?parameters?pos, "0")[1],
        ($request?parameters?tit, "xx")[1]
    )
};

declare function ah:save-note($request as map(*)) {
    tlsapi:save-note(
        ($request?parameters?trid, "xxxx")[1],
        ($request?parameters?tr, "xx")[1]
    )
};

declare function ah:save-def($request as map(*)) {
    tlsapi:save-def(
        ($request?parameters?defid, "xxxx")[1],
        ($request?parameters?def, "xx")[1]
    )
};

declare function ah:save-sf($request as map(*)) {
    let $sfval := ($request?parameters?sf_val, "xx")[1]
    let $def   := ($request?parameters?def, "xx")[1]
    return
    tlsapi:save-sf(
        ($request?parameters?("sense-id"), "xxxx")[1],
        ($request?parameters?sf_id, "xx")[1],
        replace(normalize-space($sfval), "\$x\$", "+"),
        replace(normalize-space($def), "\$x\$", "+"),
        ($request?parameters?type, "xx")[1]
    )
};

declare function ah:save-tr($request as map(*)) {
    ltr:save-tr(
        ($request?parameters?trid, "xxxx")[1],
        ($request?parameters?tr, "xx")[1],
        ($request?parameters?lang, "en")[1]
    )
};

declare function ah:delete-swl($request as map(*)) {
    tlsapi:delete-swl(
        ($request?parameters?type, "xx")[1],
        ($request?parameters?uid,  "xx")[1]
    )
};

declare function ah:delete-word-from-concept($request as map(*)) {
    tlsapi:delete-word-from-concept(
        ($request?parameters?wid,  "xx")[1],
        ($request?parameters?type, "xx")[1],
        ($request?parameters?ref,  "xx")[1]
    )
};

declare function ah:save-newsw($request as map(*)) {
    let $p := $request?parameters
    let $rpara := map {
        "concept-id"  : ($p?concept,       "xx")[1],
        "line-id"     : ($p?line,          "xx")[1],
        "word"        : ($p?word,          "xx")[1],
        "wuid"        : ($p?wid,           "xx")[1],
        "py"          : ($p?py,            "xx")[1],
        "guangyun-id" : ($p?guangyun,      "xx")[1],
        "concept-val" : ($p?("concept-val"), "xx")[1],
        "synfunc"     : ($p?synfunc,       "xx")[1],
        "synfunc-val" : replace(normalize-space(($p?("synfunc-val"), "xx")[1]), "\$x\$", "+"),
        "semfeat"     : ($p?semfeat,       "xx")[1],
        "semfeat-val" : replace(normalize-space(($p?("semfeat-val"), "xx")[1]), "\$x\$", "+"),
        "def"         : replace(normalize-space(($p?def, "xx")[1]), "\$x\$", "+")
    }
    return tlsapi:save-newsw($rpara)
};

declare function ah:save-swl-review($request as map(*)) {
    let $comment := ($request?parameters?com, "")[1]
    let $action  := ($request?parameters?action, "approve")[1]
    let $com := if ($comment = "undefined") then "" else $comment
    let $act := if ($action  = "undefined") then "approve" else $action
    return
    tlsapi:save-swl-review(
        ($request?parameters?uid, "xx")[1],
        $com, $act
    )
};

declare function ah:save-to-concept($request as map(*)) {
    let $p := $request?parameters
    let $rpara := map {
        "concept-id"  : ($p?concept,        "xx")[1],
        "line-id"     : ($p?line,           "xx")[1],
        "word"        : ($p?word,           "xx")[1],
        "wuid"        : ($p?wid,            "xx")[1],
        "guangyun-id" : ($p?("guangyun-id"), "xx")[1],
        "concept-val" : ($p?("concept-val"), "xx")[1],
        "synfunc"     : ($p?synfunc,        "xx")[1],
        "synfunc-val" : ($p?("synfunc-val"), "xx")[1],
        "semfeat"     : ($p?semfeat,        "xx")[1],
        "semfeat-val" : ($p?("semfeat-val"), "xx")[1],
        "def"         : ($p?def,            "xx")[1]
    }
    return tlsapi:save-to-concept($rpara)
};

(:~
 : POST /api/save_ratings?textid=&rating=&delete=
 : Stores per-user text ratings in /db/users/<user>/ratings.xml.
 :)
declare function ah:save-ratings($request as map(*)) {
    let $userhome := "/db/users/"
    let $textid-in := ($request?parameters?textid, "xx")[1]
    let $textid := substring-after($textid-in, "input-")
    let $rating := ($request?parameters?rating, "xx")[1]
    let $is-delete := ($request?parameters?delete, "n")[1] = "y"
    let $user := sm:id()//sm:real/sm:username/text()
    let $usercoll := $userhome || $user
    let $ratingsfile := "/ratings.xml"
    let $title := collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:titleStmt/tei:title/text()
    let $tmpl := <textlist></textlist>
    let $doc := if (doc-available($usercoll || $ratingsfile)) then doc($usercoll || $ratingsfile)
                else doc(xmldb:store($usercoll, $ratingsfile, $tmpl))
    let $newnode := <text id="{$textid}" rating="{$rating}">{$title}</text>
    let $currentnode := $doc//text[@id=$textid]
    return
        if ($is-delete) then
            if ($currentnode) then update delete $currentnode else ()
        else
            if ($currentnode) then update replace $currentnode with $newnode
            else update insert $newnode into $doc/textlist
};

declare function ah:get-sw($request as map(*)) {
    lsf:get-sw-dispatch(
        ($request?parameters?word,    "xx")[1],
        ($request?parameters?context, "xx")[1],
        ($request?parameters?domain,  "core")[1],
        ($request?parameters?leftword, "")[1]
    )
};

declare function ah:get-sf($request as map(*)) {
    tlsapi:get-sf(
        ($request?parameters?senseid, "xx")[1],
        ($request?parameters?type,    "xx")[1]
    )
};

declare function ah:get-swl($request as map(*)) {
    let $p := $request?parameters
    let $rpara := map {
        "uuid"       : ($p?uid,          "xx")[1],
        "type"       : ($p?type,         "swl")[1],
        "word"       : ($p?word,         "xx")[1],
        "mode"       : ($p?mode,         "new")[1],
        "wid"        : ($p?wid,          "xx")[1],
        "py"         : ($p?py,           "xx")[1],
        "line-id"    : ($p?("line-id"),  "xx")[1],
        "line"       : ($p?line,         "xx")[1],
        "concept"    : ($p?concept,      "xx")[1],
        "concept-id" : ($p?("concept-id"), "xx")[1]
    }
    return tlsapi:get-swl($rpara)
};

declare function ah:get-swl-for-page($request as map(*)) {
    tlsapi:get-swl-for-page(
        ($request?parameters?location, "xx")[1],
        xs:int(($request?parameters?prec,  "2")[1]),
        xs:int(($request?parameters?foll, "28")[1])
    )
};

declare function ah:get-tr-for-page($request as map(*)) {
    let $loc        := ($request?parameters?location, "xx")[1]
    let $prec       := xs:int(($request?parameters?prec, "15")[1])
    let $foll       := xs:int(($request?parameters?foll, "15")[1])
    let $slot       := ($request?parameters?slot, "slot1")[1]
    let $content-id := ($request?parameters?("content-id"), "")[1]
    let $aipar      := ($request?parameters?ai, "undefined")[1]
    return
    if ($aipar = "undefined") then
        ltr:get-tr-for-page($loc, $prec, $foll, $slot, $content-id)
    else
        ai:make-tr-for-page($loc, $prec, $foll, $slot, $content-id, $aipar)
};

declare function ah:get-tr-submenu($request as map(*)) {
    let $textid := ($request?parameters?textid, "")[1]
    let $slot   := ($request?parameters?slot, "slot1")[1]
    return
    try {
        let $tr := ltr:get-translations($textid)
        let $content-id := lrh:get-content-id($textid, $slot, $tr)
        return ltr:render-translation-submenu($textid, $slot, $content-id, $tr)
    } catch * {
        <div id="translation-headerline-{$slot}" class="btn-group" role="group">
            <span class="text-muted small">Translation menu unavailable</span>
        </div>
    }
};

declare function ah:get-guangyun($request as map(*)) {
    tlslib:get-guangyun(
        ($request?parameters?char, "xx")[1],
        "",
        ($request?parameters?gyonly, true())[1]
    )
};

declare function ah:get-text-preview($request as map(*)) {
    ltp:get-text-preview(
        ($request?parameters?loc, "xx")[1],
        map {}
    )
};

declare function ah:new-translation($request as map(*)) {
    tlsapi:new-translation(
        ($request?parameters?slot,     "slot1")[1],
        ($request?parameters?location, "xx")[1],
        ($request?parameters?trid,     "xx")[1]
    )
};

declare function ah:store-new-translation($request as map(*)) {
    let $p := $request?parameters
    let $bibl       := ($p?bibl,     "")[1]
    let $trtitle    := ($p?trtitle,  "")[1]
    let $lang       := ($p?lang,     "en")[1]
    let $translator := ($p?transl,   "yy")[1]
    let $textid     := ($p?textid,   "")[1]
    let $vis        := ($p?vis,      "")[1]
    let $copy       := ($p?copy,     "")[1]
    let $type       := ($p?type,     "")[1]
    let $rel-id     := ($p?rel,      "")[1]
    let $trid       := ($p?trid,     "")[1]
    return
        if ($trid = "ai") then
            ltr:new-ai-translation($lang, $textid, $translator, $rel-id, $bibl)
        else if (string-length($trid) > 0 and $trid != "xx") then
            ltr:update-translation-file($lang, $textid, $translator, $trtitle, $bibl, $vis, $copy, $type, $rel-id, $trid)
        else
            ltr:store-new-translation($lang, $textid, $translator, $trtitle, $bibl, $vis, $copy, $type, $rel-id)
};

declare function ah:review-swl-dialog($request as map(*)) {
    tlsapi:review-swl-dialog(($request?parameters?uid, "xx")[1])
};

declare function ah:show-att($request as map(*)) {
    tlsapi:show-att(($request?parameters?uid, "xx")[1])
};

declare function ah:show-swl-for-line($request as map(*)) {
    let $line-id := ($request?parameters?line, "xx")[1]
    let $link := "#" || $line-id
    for $swl in (
        collection($config:tls-data-root || "/notes")//tls:ann[.//tls:srcline[@target=$link]]
        | collection($config:tls-data-root || "/notes")//tls:span[.//tls:srcline[@target=$link]]
        | collection($config:tls-data-root || "/notes")//tls:drug[@target=$link]
        | doc($config:tls-data-root || "/core/word-relations.xml")//tei:item[@line-id=$line-id]
    )
    return lrh:format-swl($swl, map {"type": "row", "line-id": $line-id})
};

declare function ah:show-use-of($request as map(*)) {
    tlsapi:show-use-of(
        ($request?parameters?uid,  "xx")[1],
        ($request?parameters?type, "xx")[1]
    )
};

(:~
 : GET /api/search_att?sense-id=&start=&count=&mode=
 : Attribution search across the corpus, filtered by sense/concept.
 :)
declare function ah:search-att($request as map(*)) {
    let $sense-id   := ($request?parameters?("sense-id"), "uuid-20c9da30-27bc-4b0a-ab0a-787663fdf4b2")[1]
    let $start      := xs:int(($request?parameters?start, "1")[1])
    let $count      := xs:int(($request?parameters?count, "100")[1])
    let $mode       := ($request?parameters?mode, "date")[1]
    let $sense      := collection($config:tls-data-root)//tei:sense[@xml:id = $sense-id]
    let $concept-id := $sense/ancestor::tei:entry/@tls:concept-id/string()
    let $ann :=
        for $c in collection($config:tls-data-root || "/notes")//tls:ann[@concept-id=$concept-id]
        return $c//tls:srcline/@target
    let $label := concat($sense/tei:gramGrp/tls:syn-func, " ", $sense/tei:gramGrp/tls:sem-feat, " ", $sense/tei:def)
    let $entry := $sense/ancestor::tei:entry
    let $orth := $entry/tei:form/tei:orth
    let $user := sm:id()//sm:real/sm:username/text()
    let $ratings := doc("/db/users/" || $user || "/ratings.xml")//text
    let $dates :=
        if (exists(doc("/db/users/" || $user || "/textdates.xml")//data)) then
            doc("/db/users/" || $user || "/textdates.xml")//data
        else
            doc($config:tls-texts-meta || "/textdates.xml")//data
    let $ret :=
        for $o in $orth/text()
        for $p in collection($config:tls-texts-root)//tei:p[ngram:contains(., $o)]
        let $src := $p/ancestor::tei:TEI//tei:titleStmt/tei:title/text()
        for $line in util:expand($p)//exist:match/ancestor::tei:seg
        let $target := $line/@xml:id
        let $locs := substring-before(tokenize(substring-before($target, "."), "_")[last()], "-")
        let $textid := tokenize($target, "_")[1]
        let $loc := try { if (string-length($locs) > 0) then xs:int($locs) else $locs } catch * { 0 }
        let $tr := collection($config:tls-translation-root)//tei:seg[@corresp="#" || $target]
        let $flag := substring($textid, 1, 3)
        let $r :=
            if ($mode = "rating") then
                if ($ratings[@id=$textid]) then xs:int($ratings[@id=$textid]/@rating) else 0
            else
                switch ($flag)
                    case "CH1" return 0
                    case "CH2" return 300
                    case "CH7" return 700
                    case "CH8" return -200
                    default return
                        if (string-length($dates[@corresp="#" || $textid]/@notafter) > 0)
                        then tu:index-date($dates[@corresp="#" || $textid])
                        else 0
        order by $r descending
        where $tr and not (contains("#" || $target, $ann))
        return
        <div class="row bg-light table-striped">
            <div class="col-sm-2">
                <a href="textview.html?location={$target}" class="font-weight-bold">{$src, $loc}</a>
                { if (sm:is-authenticated()) then
                    let $posx := string-length(substring-before($line, $o)) + 1
                    return
                        <button title="{$label}" class="btn badge badge-primary ml-2" type="button"
                                onclick="do_save_swl_line('{$sense-id}','{$target}', '{$posx}', '{$line}', '{$src}' )">Use</button>
                  else () }
            </div>
            <div class="col-sm-3"><span data-target="{$target}" data-toggle="popover">{
                substring-before($line, $o),
                <mark>{$o}</mark>,
                substring-after($line, $o)}</span></div>
            <div class="col-sm-7"><span>{$tr[1]}</span></div>
        </div>
    let $cnt := count($ret)
    return
    if ($cnt > 0) then
        <div>
            <p class="ml-2 font-weight-bold">Found {$cnt} matches, returning {min((xs:int($count), $cnt))}.</p>
            {subsequence($ret, $start, $count)}
        </div>
    else
        <p class="font-weight-bold">No matches found.</p>
};

(: ===================================================================
 : Wave C — functions previously dispatched via api/responder.xql
 :
 : Every target takes a single map(*). We build that map from the live
 : HTTP request (preserving the responder.xql semantics where ALL query
 : parameters are available to the target) rather than declaring each
 : parameter in api.json.
 : =================================================================== :)

declare function ah:request-params() as map(*) {
    map:merge(
        for $p in request:get-parameter-names()
        return map:entry($p, request:get-parameter($p, ""))
    )
};

(: dialogs: * :)
declare function ah:dialogs-pastebox($r as map(*))                   { dialogs:pastebox(ah:request-params()) };
declare function ah:dialogs-word-rel-dialog($r as map(*))            { dialogs:word-rel-dialog(ah:request-params()) };
declare function ah:dialogs-merge-word($r as map(*))                 { dialogs:merge-word(ah:request-params()) };
declare function ah:dialogs-move-word($r as map(*))                  { dialogs:move-word(ah:request-params()) };
declare function ah:dialogs-new-concept-dialog($r as map(*))         { dialogs:new-concept-dialog(ah:request-params()) };
declare function ah:dialogs-new-syn-dialog($r as map(*))             { dialogs:new-syn-dialog(ah:request-params()) };
declare function ah:dialogs-add-parallel($r as map(*))               { dialogs:add-parallel(ah:request-params()) };
declare function ah:dialogs-add-rd-dialog($r as map(*))              { dialogs:add-rd-dialog(ah:request-params()) };
declare function ah:dialogs-assign-guangyun($r as map(*))            { dialogs:assign-guangyun(ah:request-params()) };
declare function ah:dialogs-update-gloss($r as map(*))               { dialogs:update-gloss(ah:request-params()) };
declare function ah:dialogs-edit-textcat($r as map(*))               { dialogs:edit-textcat(ah:request-params()) };
declare function ah:dialogs-edit-textdate($r as map(*))              { dialogs:edit-textdate(ah:request-params()) };
declare function ah:dialogs-punc-dialog($r as map(*))                { dialogs:punc-dialog(ah:request-params()) };
declare function ah:dialogs-dispatcher($r as map(*))                 { dialogs:dispatcher(ah:request-params()) };
declare function ah:dialogs-edit-text-permissions-dialog($r as map(*)) { dialogs:edit-text-permissions-dialog(ah:request-params()) };
declare function ah:dialogs-add-bibref-dialog($r as map(*))          { dialogs:add-bibref-dialog(ah:request-params()) };
declare function ah:dialogs-add-url-dialog($r as map(*))             { dialogs:add-url-dialog(ah:request-params()) };
declare function ah:dialogs-pb-dialog($r as map(*))                  { dialogs:pb-dialog(ah:request-params()) };
declare function ah:dialogs-edit-app-dialog($r as map(*))            { dialogs:edit-app-dialog(ah:request-params()) };

(: tlslib: * :)
declare function ah:tlslib-merge-sw-word($r as map(*))               { tlslib:merge-sw-word(ah:request-params()) };
declare function ah:tlslib-move-done($r as map(*))                   { tlslib:move-done(ah:request-params()) };
declare function ah:tlslib-move-word-to-concept($r as map(*))        { tlslib:move-word-to-concept(ah:request-params()) };
declare function ah:tlslib-save-setting($r as map(*))                { tlslib:save-setting(ah:request-params()) };
declare function ah:tlslib-word-rel-table($r as map(*))              { tlslib:word-rel-table(ah:request-params()) };

(: bib: * :)
(: GET and POST bookmarklets both target bib:add-zotero-entry — two wrappers for unique operationIds. :)
declare function ah:bib-add-zotero-entry-get($r as map(*))           { bib:add-zotero-entry(ah:request-params()) };
declare function ah:bib-add-zotero-entry-post($r as map(*))          { bib:add-zotero-entry(ah:request-params()) };
declare function ah:bib-new-entry-dialog($r as map(*))               { bib:new-entry-dialog(ah:request-params()) };
declare function ah:bib-quick-search($r as map(*))                   { bib:quick-search(ah:request-params()) };
declare function ah:bib-save-entry($r as map(*))                     { bib:save-entry(ah:request-params()) };
declare function ah:bib-url-save($r as map(*))                       { bib:url-save(ah:request-params()) };

(: wd: * :)
declare function ah:wd-save-qitem($r as map(*))                      { wd:save-qitem(ah:request-params()) };
declare function ah:wd-search($r as map(*))                          { wd:search(ah:request-params()) };

(: sgn: * :)
declare function ah:sgn-approve($r as map(*))                        { sgn:approve(ah:request-params()) };
declare function ah:sgn-send-reminder-mail($r as map(*))             { sgn:send-reminder-mail(ah:request-params()) };

(: ltr: * :)
declare function ah:ltr-approve($r as map(*))                        { ltr:approve(ah:request-params()) };
declare function ah:ltr-delete-translation($r as map(*))             { ltr:delete-translation(ah:request-params()) };
declare function ah:ltr-get-other-translations($r as map(*))         { ltr:get-other-translations(ah:request-params()) };
declare function ah:ltr-reload-selector($r as map(*))                { ltr:reload-selector(ah:request-params()) };
declare function ah:ltr-save-att-tr($r as map(*))                    { ltr:save-att-tr(ah:request-params()) };

(: lli: * :)
declare function ah:lli-new-link-dialog($r as map(*))                { lli:new-link-dialog(ah:request-params()) };
declare function ah:lli-save-link-items($r as map(*))                { lli:save-link-items(ah:request-params()) };

(: lus: * :)
declare function ah:lus-set-user-item($r as map(*))                  { lus:set-user-item(ah:request-params()) };
declare function ah:lus-toggle-list-display($r as map(*))            { lus:toggle-list-display(ah:request-params()) };

(:~
 : GET /api/get_slot_config?textid=<id>&slot=<slot1|slot2>
 : Returns the currently persisted content-id for ($textid, $slot) as JSON.
 : Exists primarily so tests can assert slot stickiness across requests
 : without scraping rendered textview HTML.
 :)
declare function ah:lus-get-slot-config($request as map(*)) {
    let $textid := ($request?parameters?textid, "")[1]
    let $slot   := ($request?parameters?slot, "slot1")[1]
    let $cid    := lus:get-slot-id($slot, $textid)
    return map {
        "textid":     $textid,
        "slot":       $slot,
        "content-id": if (exists($cid)) then $cid else ()
    }
};

(:~
 : Fast save-only path for the translation-slot choice. ltr:reload-selector
 : also saves, but it runs ltr:get-translations (30-50s, 3 full-collection
 : scans) in the same XQuery transaction. When the user navigates away
 : before that query completes, the HTTP request is aborted and the
 : XQuery Update transaction rolls back, so the save is lost. This
 : endpoint performs only the persist step so the save commits in <100ms.
 : Callers should still fire ltr_reload_selector afterwards for the
 : dropdown-HTML refresh — that's slow but non-critical.
:)
declare function ah:lus-save-slot-config($request as map(*)) {
    let $textid     := ($request?parameters?textid, "")[1]
    let $slot       := ($request?parameters?slot, "slot1")[1]
    let $content-id := ($request?parameters?("content-id"), "")[1]
    let $group      := sm:id()//sm:group
    let $saved      :=
        if ("tls-test" = $group)
        then session:set-attribute($textid || "-" || $slot, $content-id)
        else lus:settings-save-slot($slot, $textid, $content-id)
    return map {
        "textid":     $textid,
        "slot":       $slot,
        "content-id": $content-id
    }
};

(: ltx: * :)
declare function ah:ltx-modify-category($r as map(*))                { ltx:modify-category(ah:request-params()) };

(: ltg: * :)
declare function ah:ltg-save-tags($r as map(*)) {
    let $p := ah:request-params()
    return ltg:save-tags(($p?tag_id, $p?uid, "")[1], $p)
};

(: lsi: * :)
declare function ah:lsi-save-resource($r as map(*))                  { lsi:save-resource(ah:request-params()) };

(: txc: * :)
declare function ah:txc-save-txc($r as map(*))                       { txc:save-txc(ah:request-params()) };

(: tlsapi:* (unprefixed in responder.xql) :)
declare function ah:add-text($r as map(*))                           { tlsapi:add-text(ah:request-params()) };
declare function ah:change-word-relation($r as map(*))               { tlsapi:change-word-relation(ah:request-params()) };
declare function ah:delete-bm($r as map(*))                          { tlsapi:delete-bm(ah:request-params()) };
declare function ah:delete-pron($r as map(*))                        { tlsapi:delete-pron(ah:request-params()) };
declare function ah:delete-word-relation($r as map(*))               { tlsapi:delete-word-relation(ah:request-params()) };
declare function ah:delete-zi-from-word($r as map(*))                { tlsapi:delete-zi-from-word(ah:request-params()) };
declare function ah:do-delete-sf($r as map(*))                       { tlsapi:do-delete-sf(ah:request-params()) };
declare function ah:get-facs-for-page($r as map(*))                  { tlsapi:get-facs-for-page(ah:request-params()) };
declare function ah:get-more-lines($r as map(*))                     { tlsapi:get-more-lines(ah:request-params()) };
declare function ah:goto-translation-seg($r as map(*))               { tlsapi:goto-translation-seg(ah:request-params()) };
declare function ah:incr-rating($r as map(*))                        { tlsapi:incr-rating(ah:request-params()) };
declare function ah:merge-following-seg($r as map(*))                { tlsapi:merge-following-seg(ah:request-params()) };
declare function ah:morelines($r as map(*))                          { tlsapi:morelines(ah:request-params()) };
declare function ah:move-to-page($r as map(*))                       { tlsapi:move-to-page(ah:request-params()) };
declare function ah:quick-search($r as map(*))                       { tlsapi:quick-search(ah:request-params()) };
declare function ah:save-new-concept($r as map(*))                   { tlsapi:save-new-concept(ah:request-params()) };
declare function ah:save-new-rhet-dev($r as map(*))                  { tlsapi:save-new-rhet-dev(ah:request-params()) };
declare function ah:save-pb($r as map(*))                            { tlsapi:save-pb(ah:request-params()) };
declare function ah:save-punc($r as map(*))                          { tlsapi:save-punc(ah:request-params()) };
declare function ah:save-rdl($r as map(*))                           { tlsapi:save-rdl(ah:request-params()) };
declare function ah:save-sf-def($r as map(*))                        { tlsapi:save-sf-def(ah:request-params()) };
declare function ah:save-syn($r as map(*))                           { tlsapi:save-syn(ah:request-params()) };
declare function ah:save-taxchar($r as map(*))                       { tlsapi:save-taxchar(ah:request-params()) };
declare function ah:save-textcat($r as map(*))                       { tlsapi:save-textcat(ah:request-params()) };
declare function ah:save-textdate($r as map(*))                      { tlsapi:save-textdate(ah:request-params()) };
declare function ah:save-wr($r as map(*))                            { tlsapi:save-wr(ah:request-params()) };
declare function ah:save-zh($r as map(*))                            { tlsapi:save-zh(ah:request-params()) };
declare function ah:show-obs($r as map(*))                           { tlsapi:show-obs(ah:request-params()) };
declare function ah:show-wr($r as map(*))                            { tlsapi:show-wr(ah:request-params()) };
declare function ah:showtab($r as map(*))                            { tlsapi:showtab(ah:request-params()) };
declare function ah:text-request($r as map(*))                       { tlsapi:text-request(ah:request-params()) };
declare function ah:update-gloss($r as map(*))                       { tlsapi:update-gloss(ah:request-params()) };
declare function ah:update-pinyin($r as map(*))                      { tlsapi:update-pinyin(ah:request-params()) };
declare function ah:zh-delete-line($r as map(*))                     { tlsapi:zh-delete-line(ah:request-params()) };
