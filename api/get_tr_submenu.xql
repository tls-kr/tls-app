xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html";
declare option output:media-type "text/html";

import module namespace ltr="http://hxwd.org/lib/translation" at "../modules/lib/translation.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "../modules/lib/render-html.xqm";

let $textid := request:get-parameter("textid", "")
, $slot     := request:get-parameter("slot", "slot1")
return
try {
    let $tr         := ltr:get-translations($textid)
    , $content-id   := lrh:get-content-id($textid, $slot, $tr)
    return ltr:render-translation-submenu($textid, $slot, $content-id, $tr)
} catch * {
    <div id="translation-headerline-{$slot}" class="btn-group" role="group">
        <span class="text-muted small">Translation menu unavailable</span>
    </div>
}
