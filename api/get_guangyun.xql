xquery version "3.1";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

declare option output:method "html";
declare option output:media-type "text/html";

declare variable $char := request:get-parameter("char", "xx");

<div id="guangyun-input-dyn">{
for $g at $count in collection(concat($config:tls-data-root, "/guangyun"))//tx:attested-graph/tx:graph[.=$char]
let $e := $g/ancestor::tx:guangyun-entry,
$p := for $s in $e//tx:mandarin/* 
       return 
       if (string-length(normalize-space($s)) > 0) then $s else ()
return

<div class="form-check">
   <input class="form-check-input" type="radio" name="guangyun-input" id="guangyun-input-{$count}" 
   value="{$e/@xml:id}"/>
   <label class="form-check-label" for="guangyun-input-{$count}">
     {$e/tx:gloss/text()} -  {normalize-space(string-join($p, ';'))}
   </label>
  </div>
}
</div>