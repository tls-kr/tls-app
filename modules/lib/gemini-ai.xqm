xquery version "3.1";
(:~
: This module provides the functions for querying and displaying the bibliography
: of the TLS. 

: @author Christian Wittern  cwittern@gmail.com
: @version 1.0
:)
module namespace ai="http://hxwd.org/lib/gemini-ai";

import module namespace config="http://hxwd.org/config" at "../config.xqm"; 
import module namespace json="http://www.json.org";
import module namespace http="http://expath.org/ns/http-client";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace ltr="http://hxwd.org/lib/translation" at "translation.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace lrm="http://hxwd.org/remote" at "remote.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare variable $ai:config := if(doc('../../ai-config.xml')) then doc('../../ai-config.xml') else <response status="fail"><message>Load ai-config.xml file please.</message></response>;

declare variable $ai:model := "gemini-2.0-flash";
declare variable $ai:key := $ai:config//gemini-config/api-token/text();
declare variable $ai:temp-path := "/db/groups/tls-user/";

declare function ai:query($map){
    let $url := 'https://generativelanguage.googleapis.com/v1beta/models/'||$ai:model||':generateContent?key='||$ai:key
    , $content-type := <http:header name="Content-type" value="application/json"/>
    , $lang := if ($map?lang) then $map?lang else "English"
    , $body := '{
    "system_instruction" : {"parts" : [ {"text" : "Translate from classical Chinese to '|| $lang || '.  The text contains page numbers like [001], these should be passed through unchanged. Names etc. should be returned using Hànyǔ Pīnyīn with tone marks. \nDo *not* return the whole Chinese text as Pinyin."}]},
    "contents": [{"parts": [{ "text" : "' || $map?user-prompt || '" }]  }] }'
return
    
http:send-request(    
<http:request http-version="1.1" href="{xs:anyURI($url)}" method="post">
{$content-type}
<http:body media-type="application/json" method="text">{
$body
}</http:body>
    
</http:request>    
)
};


declare function ai:parse-response($resp-file){
let $inp := json-doc($resp-file)
, $cand := try { array:head($inp?candidates[1]) } catch * {map{'type': 'error' } }
, $text :=  if ( $cand?type = 'error') then '' else array:head($cand?content?parts)?text

return
    if ($text = '') then map{'type': 'error' } else
    map:merge(
    for $a in analyze-string($text, '\[\d+\]')/fn:match
    let $n := $a/following-sibling::*[1]
    return 
        map:entry($a/text(), if (local-name($n) = 'non-match') then $n/text() else '')
    )
(: return error also :)
};

declare function ai:save-response($dseg, $res, $slot, $lang){
 for $seg at $pos in $dseg
  let $trid := $seg/@xml:id || "-" || $slot
  , $p := format-number($pos, '[00]')
  return
  if (map:keys($res) = $p) then
    ltr:save-tr($trid, $res?($p), $lang, $ai:model)
    else ()
};

declare function ai:make-tr-for-page($loc_in as xs:string, $prec as xs:int, $foll as xs:int, $slot as xs:string, $content-id as xs:string, $lang as xs:string){
let $loc := replace($loc_in, "-swl", "")
, $user := sm:id()//sm:real/sm:username/text()
, $resp-file := $user || '-temp.json'
, $textid := tokenize($loc, "_")[1]
, $transl := ltr:get-translations($textid)
, $troot := $transl($content-id)[1] 
, $lg := $troot//tei:bibl[@corresp="#"||$textid]/following-sibling::tei:lang 
, $edtp := if (contains($content-id, "_")) then xs:boolean(1) else xs:boolean(0)
, $dseg := if ($troot//tei:sourceDesc//tei:ref[@type='remote']) then (lrm:get-segs(map{'location' : $loc, 'prec': $prec + 3, 'foll': $foll +3, 'type': 'raw'})//tei:seg) else lu:get-targetsegs($loc, $prec + 3, $foll + 3)
, $user-prompt := lrh:multiple-segs-plain-dseg($dseg)
, $query := ai:query(map{'user-prompt' : $user-prompt, 'lang' : $lg/text()})
, $temp := xmldb:store($ai:temp-path, $resp-file, $query[2])
, $res := if ($query[1]/@status = '200') then ai:parse-response($ai:temp-path || $resp-file) else map{"type": "error", "content" : "400"}
, $save-tr := if ($res?type = 'error') then () else ai:save-response($dseg, $res, $slot, $lg/@xml:lang) 
, $ret :=  
   map:merge(for $seg in $dseg 
     let $tr := $troot//tei:seg[@corresp="#"||$seg/@xml:id]/text()
      return 
      map:entry("#"||data($seg/@xml:id)||"-"||$slot, $tr))
 return $ret
};
  

