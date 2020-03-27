xquery version "3.1";


declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

import module namespace tlsapi="http://hxwd.org/tlsapi" at "tlsapi.xql";

let $uid := request:get-parameter("uid", "xx"),
$comment := request:get-parameter("com", ""),
$action := request:get-parameter("action", "approve"),
(: if the dialog has not been loaded, the pars are undefined :)
$com := if ($comment = "undefined") then "" else $comment,
$act := if ($action = "undefined") then "approve" else $action

return

tlsapi:save-swl-review($uid, $com, $act)
