xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

(:  url : "api/save_to_concept.xql?line="+line_id+
"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"
&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"
&semfeat-val="+semfeat_val+"&guangyun="+guangyun_id+"&def="+def_val,
 :)
import module namespace ltr="http://hxwd.org/lib/translation" at "../modules/lib/translation.xqm";

let $bibl := request:get-parameter("bibl", "")
, $trtitle := request:get-parameter("trtitle", "")
, $lang := request:get-parameter("lang", "en")
, $translator := request:get-parameter("transl", "yy")
, $textid := request:get-parameter("textid", "")
, $vis := request:get-parameter("vis", "")
, $copy := request:get-parameter("copy", "")
, $type := request:get-parameter("type", "")
, $rel-id := request:get-parameter("rel", "")
, $trid := request:get-parameter("trid", "")


return
 if ($trid = 'ai') then
 ltr:new-ai-translation($lang, $textid, $translator, $rel-id, $bibl)
 else
 if (string-length($trid) > 0 and $trid != "xx") then 
 ltr:update-translation-file($lang, $textid, $translator, $trtitle, $bibl, $vis, $copy, $type, $rel-id, $trid) else
 ltr:store-new-translation($lang, $textid, $translator, $trtitle, $bibl, $vis, $copy, $type, $rel-id)

