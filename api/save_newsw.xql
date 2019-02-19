xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "json";
declare option output:media-type "application/json";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
declare variable $user := sm:id()//sm:real/sm:username/text();

(:  url : "api/save_newsw.xql?line="+line_id+
"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"
&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"
&semfeat-val="+semfeat_val+"&guangyun="+guangyun_id+"&def="+def_val,
 :)


let $concept-id := request:get-parameter("concept", "xx"),
 $line-id := request:get-parameter("line", "xx"),
 $word := request:get-parameter("word", "xx"),
 $wuid := request:get-parameter("wid", "xx"),
 $concept-val := request:get-parameter("concept-val", "xx"),
 $synfunc := request:get-parameter("synfunc", "xx"),
 $synfunc-val := request:get-parameter("synfunc-val", "xx"),
 $semfeat := request:get-parameter("semfeat", "xx"),
 $semfeat-val := request:get-parameter("semfeat-val", "xx"),
 $def := request:get-parameter("def", "xx"),

 
 $concept-doc := collection($config:tls-data-root)//tei:div[@xml:id=$concept-id]//tei:entry[@xml:id=$wuid],
 $suid := concat("uuid-", util:uuid()),
 $newnode :=
<sense xml:id="{$suid}" resp="#{$user}" tls:created="{current-dateTime()}" xmlns="http://www.tei-c.org/ns/1.0" 
xmlns:tls="http://hxwd.org/ns/1.0">
<gramGrp><pos>{upper-case(substring($synfunc-val, 1,1))}</pos>
  <tls:syn-func corresp="#{$synfunc}">{$synfunc-val}</tls:syn-func>
  {if ($semfeat) then 
  <tls:sem-feat corresp="#{$semfeat}">{$semfeat-val}</tls:sem-feat>
  else ()}
  </gramGrp>
  <def>{$def}</def></sense>
return
<response>
<user>{$user}</user>
<result>{update insert $newnode into $concept-doc}</result>
<sense_id>{$suid}</sense_id>
</response>

