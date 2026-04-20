xquery version "3.1";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

import module namespace lrh="http://hxwd.org/lib/render-html" at "../modules/lib/render-html.xqm";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

let $line-ids := tokenize(request:get-parameter("lines", ""), ",")
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
