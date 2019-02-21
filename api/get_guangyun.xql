xquery version "3.1";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

declare option output:method "html";
declare option output:media-type "text/html";

declare variable $chars := request:get-parameter("char", "xx");

for $char at $cc in  analyze-string($chars, ".")//fn:match/text()
return
<div id="guangyun-input-dyn-{$cc}">
<h5><strong class="ml-2">{$char}</strong></h5>
{
for $g at $count in collection(concat($config:tls-data-root, "/guangyun"))//tx:attested-graph/tx:graph[contains(.,$char)]
let $e := $g/ancestor::tx:guangyun-entry,
$p := for $s in $e//tx:mandarin/* 
       return 
       if (string-length(normalize-space($s)) > 0) then $s else ()
return

<div class="form-check">
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}" />
   <label class="form-check-label" for="guangyun-input-{$cc}-{$count}">
     {$e/tx:gloss/text()} -  {normalize-space(string-join($p, ';'))}
   </label>
  </div>
}
</div>