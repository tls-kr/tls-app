xquery version "3.1";
(:~
 : OpenAPI route handlers for the TLS application.
 :
 : Handlers take the roaster request map and delegate to the business-logic
 : modules (`tlsapi`, `ltr`, `lsf`, `ltp`, `lvs`, `tlslib`, ...). Endpoints
 : declared in `../api.json` resolve to the `ah:*` functions below.
 :)
module namespace ah="http://hxwd.org/api-handlers";

import module namespace config="http://hxwd.org/config"   at "config.xqm";
import module namespace tlsapi="http://hxwd.org/tlsapi"   at "../api/tlsapi.xql";
import module namespace ltr   ="http://hxwd.org/lib/translation" at "lib/translation.xqm";
import module namespace ai    ="http://hxwd.org/lib/gemini-ai"   at "lib/gemini-ai.xqm";
import module namespace lsf   ="http://hxwd.org/lib/syn-func"    at "lib/syn-func.xqm";
import module namespace ltp   ="http://hxwd.org/lib/textpanel"   at "lib/textpanel.xqm";
import module namespace lrh   ="http://hxwd.org/lib/render-html" at "lib/render-html.xqm";
import module namespace lu    ="http://hxwd.org/lib/utils"       at "lib/utils.xqm";
import module namespace lvs   ="http://hxwd.org/lib/visits"      at "lib/visits.xqm";
import module namespace tlslib="http://hxwd.org/lib"     at "tlslib.xql";
import module namespace tu    ="http://hxwd.org/utils"   at "tlsutils.xql";

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
 :)
declare function ah:get-toc($request as map(*)) {
    let $textid := ($request?parameters?textid, "")[1]
    return
    if (session:exists() and contains(session:get-attribute-names(), $textid || "-toc")) then
        session:get-attribute($textid || "-toc")
    else
        let $body := (collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:body)[1]
        let $toc := subsequence(
            for $h in ($body/tei:div/tei:head | $body/tei:div/tei:div/tei:head)
            let $locseg := ($h//tei:seg/@xml:id)[1]
            let $tid := tokenize($locseg[1], "_")[1]
            where matches($tid, "^[A-Za-z]")
            return
            <a class="dropdown-item" title="{$locseg}"
               href="textview.html?location={$locseg}&amp;prec=0&amp;foll=30">{$h//text()}</a>
            , 1, 100)
        return (
            if (session:exists()) then session:set-attribute($textid || "-toc", $toc) else (),
            $toc
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
