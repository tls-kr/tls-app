xquery version "3.1";
(:~
 : Records a page visit asynchronously.
 : Called via fire-and-forget AJAX from tls-webapp.js after the page renders,
 : so the DB write does not block the initial page load.
 : Accepts: ?location=<seg-xml-id>
:)

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "text";
declare option output:media-type "text/plain";

import module namespace config = "http://hxwd.org/config"    at "../modules/config.xqm";
import module namespace lu    = "http://hxwd.org/lib/utils"  at "../modules/lib/utils.xqm";
import module namespace lvs   = "http://hxwd.org/lib/visits" at "../modules/lib/visits.xqm";

let $sid := request:get-parameter("location", "")
let $seg := if ($sid) then lu:get-seg($sid) else ()
return
  if (exists($seg)) then (lvs:record-visit($seg), "ok") else "skip"
