xquery version "3.1";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:media-type "text/html";

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

let $textid := request:get-parameter("textid", "")
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
