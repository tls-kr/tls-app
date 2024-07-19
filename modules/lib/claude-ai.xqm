xquery version "3.1";
(:~
: This module provides the functions for querying and displaying the bibliography
: of the TLS. 

: @author Christian Wittern  cwittern@gmail.com
: @version 1.0
:)
module namespace ai="http://hxwd.org/lib/claude-ai";

import module namespace config="http://hxwd.org/config" at "../config.xqm"; 
import module namespace json="http://www.json.org";
import module namespace http="http://expath.org/ns/http-client";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace ltr="http://hxwd.org/lib/translation" at "translation.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare option output:method "json";
declare option output:media-type "text/javascript";

declare variable $ai:config := if(doc('../../access-config.xml')) then doc('../../access-config.xml') else <response status="fail"><message>Load config.xml file please.</message></response>;

declare variable $ai:key := if($ai:config//claude-config/api-var != '') then 
                                    environment-variable($ai:config//api-var/text())
                              else $ai:config//claude-config/api-token/text();
declare variable $ai:model := "claude-3-opus-20240229";

(: format of claude requests 

curl https://api.anthropic.com/v1/messages \
     --header "x-api-key: $ANTHROPIC_API_KEY" \
     --header "anthropic-version: 2023-06-01" \
     --header "content-type: application/json" \
     --data \
'{
    "model": "claude-3-opus-20240229",
    "max_tokens": 1024,
    "messages": [
        {"role": "user", "content": "Hello, world"}
    ]
}'

:)

declare function ai:query-claude($map){
    let $url := 'https://api.anthropic.com/v1/messages'
    , $api :=   <http:header name="x-api-key" value="{$ai:key}"/>
    , $version :=   <http:header name="anthropic-version" value="2023-06-01"/>
    , $content-type := <http:header name="Content-type" value="application/json"/>
    , $lang := if ($map?lang) then $map?lang else "English"
    , $body := '{
    "model": "'|| $ai:model ||'",
    "max_tokens": 1024,
    "system" : "Translate from classical Chinese to '|| $lang || '.  Dates in the source text should be supplemented with equivalents in the western calendar. Named entities should be underlined. The translation should be returned in a table with two rows, one row for each phrase. Please keep the number of phrases from the input the same as in the output. The left row should contain the source text and the right row the corresponding English text.",
    "messages": [{"role": "user", "content": [{"type" : "text", "text" : "' || $map?user-prompt || '" }]  }] }'
return
    
http:send-request(    
<http:request http-version="1.1" href="{xs:anyURI($url)}" method="post">
{$api,$version,$content-type}
<http:body media-type="application/json" method="text">{
$body
}</http:body>
    
</http:request>    
)
};

declare function ai:parse-response($resp-file){
    let $resp := json-doc($resp-file)
    let $content := array:head($resp?content)
    , $table := tokenize($content?text, '\n')
    return
    if ($resp?type = 'message') then 
    map:merge(
    for $row in $table
      let $cells := tokenize($row, "\|")
      return map:entry(normalize-space($cells[2]), normalize-space($cells[3]))
    )  
    else
    map{"type" : $resp?type, "content" : "Error"}
};

declare function ai:save-response($dseg, $res, $slot, $lang){
 for $seg at $pos in $dseg
  let $trid := $seg/@xml:id || "-" || $slot
  , $pseg := normalize-space(string-join( lrh:proc-seg($seg, map{"punc" : true(), "lpb" : false()}), ''))
  return
  if (map:keys($res) = $pseg) then
    ltr:save-tr($trid, $res?($pseg), $lang, $ai:model)
    else ()
};

declare function ai:make-tr-for-page($loc_in as xs:string, $prec as xs:int, $foll as xs:int, $slot as xs:string, $content-id as xs:string, $lang as xs:string){
let $loc := replace($loc_in, "-swl", "")
, $textid := tokenize($loc, "_")[1]
, $edtp := if (contains($content-id, "_")) then xs:boolean(1) else xs:boolean(0)
, $dseg := lu:get-targetsegs($loc, $prec, $foll)
, $user-prompt := lrh:multiple-segs-plain($loc,  $prec + 3 , $foll + 3)
, $query := ai:query-claude(map{'user-prompt' : $user-prompt, 'lang' : $lang})
, $user := sm:id()//sm:real/sm:username/text()
, $temp := xmldb:store('/db', $user || '-temp.json', $query[2])
, $res := if ($query[1]/@status = '200') then ai:parse-response('/db/' || $user || '-temp.json') else map{"type": "error", "content" : "400"}
, $save-tr := if ($res?type = 'error') then () else ai:save-response($dseg, $res, $slot, $lang) 
, $ret :=  let $transl := ltr:get-translations($textid),
   $troot := $transl($content-id)[1] 
   return
   map:merge(for $seg in $dseg 
     let $tr := $troot//tei:seg[@corresp="#"||$seg/@xml:id]/text()
      return 
      map:entry("#"||data($seg/@xml:id)||"-"||$slot, $tr))
 return $ret
};
  


declare function ai:dummy(){
let $prompt := "序例上韓保升云：\n　\n　\n按藥有玉石、\n　\n　\n草木、\n　\n　\n蟲獸，\n　\n　\n直云本草者，\n　\n　\n為諸藥中草類最多也。\n　\n　\n嘉祐補註總敘\n　\n　\n舊說《本草經》神農所作，\n　\n　\n而不經見，\n　\n　\n《漢書·藝文志》亦無錄焉。\n　\n　\n《平帝紀》云：\n　\n　\n元始五年，\n　\n　\n舉天下通知方術、\n　\n　\n本草者，\n　\n　\n在所為駕一封，\n　\n　\n軺傳遣諸京師。\n　\n　\n《樓護傳》稱護，\n　\n　\n少誦醫經、\n　\n　\n本草、\n　\n　\n方術數十萬言。\n　\n　\n本草之名，\n　\n　\n蓋見於此。\n　\n　\n而英公李世績等注引班固敘《黃帝內外經》云：\n　\n　\n本草石之寒溫，\n　\n　\n原疾病之深淺，\n　\n　\n此乃論經方之語，\n　\n　\n而無本草之名。 "

(:let $ret := local:query-claude($prompt)

return
($ret[1]
,xmldb:store('/db', 'temp.txt', $ret[2])
)

:)

return count(ai:parse-response(""))

};