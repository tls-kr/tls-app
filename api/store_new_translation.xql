xquery version "3.1";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";

(:  url : "api/save_to_concept.xql?line="+line_id+
"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"
&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"
&semfeat-val="+semfeat_val+"&guangyun="+guangyun_id+"&def="+def_val,
 :)
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";

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
 if (string-length($trid) > 0) then 
 tlslib:update-tr-file($lang, $textid, $translator, $trtitle, $bibl, $vis, $copy, $type, $rel-id, $trid) else
 tlslib:store-new-translation($lang, $textid, $translator, $trtitle, $bibl, $vis, $copy, $type, $rel-id)

