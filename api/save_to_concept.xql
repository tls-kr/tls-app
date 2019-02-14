xquery version "3.1";

(: module namespace test="http://hxwd.org/app"; :)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";


import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";
import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
declare variable $user := sm:id()//sm:real/sm:username/text();
(:declare variable $login := xmldb:login("/db/apps", $user, "tls55");
:)
(:  url : "api/save_to_concept.xql?line="+line_id+
"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"
&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"
&semfeat-val="+semfeat_val+"&guangyun="+guangyun_id+"&def="+def_val,
 :)


let $concept-id := request:get-parameter("concept", "xx"),
 $line-id := request:get-parameter("line", "xx"),
 $word := request:get-parameter("word", "xx"),
 $guangyun-id := request:get-parameter("guangyun", "xx"),
 $concept-val := request:get-parameter("concept-val", "xx"),
 $synfunc := request:get-parameter("synfunc", "xx"),
 $synfunc-val := request:get-parameter("synfunc-val", "xx"),
 $semfeat := request:get-parameter("semfeat", "xx"),
 $semfeat-val := request:get-parameter("semfeat-val", "xx"),
 $def := request:get-parameter("def", "xx")
 
 let $form :=
   let $e := collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$guangyun-id],
   $oc := $e//tx:old-chinese/tx:pan-wuyun/tx:oc,
   $mc := $e//tx:middle-chinese//tx:baxter,
   $p := for $s in $e//tx:mandarin/* 
       return 
       if (string-length(normalize-space($s)) > 0) then <pron xmlns="http://www.tei-c.org/ns/1.0" xml:lang="zh-Latn-x-pinyin" type="{local-name($s)}">{$s/text()}</pron> else ()
return
    <form xmlns="http://www.tei-c.org/ns/1.0" corresp="#{$guangyun-id}">
    <orth>{$e//tx:attested-graph/tx:graph/text()}</orth>
    {$p}
    <pron xml:lang="zh-x-mc" resp="rec:baxter">{$mc/text()}</pron>
    <pron xml:lang="zh-x-oc" resp="rec:pan-wuyun">{$oc/text()}</pron>
    </form>,

 
 $concept-doc := collection($config:tls-data-root)//tei:div[@xml:id=$concept-id]//tei:div[@type="words"],
 $wuid := concat("uuid-", util:uuid()),
 $suid := concat("uuid-", util:uuid()),
 $newnode :=
<entry xmlns="http://www.tei-c.org/ns/1.0" 
xmlns:tls="http://hxwd.org/ns/1.0"
type="word" xml:id="{$wuid}" resp="#{$user}" tls:created="{current-dateTime()}">
{$form}
<sense xml:id="{$suid}">
<gramGrp><pos>{upper-case(substring($synfunc-val, 1,1))}</pos>
  <tls:syn-func corresp="#{$synfunc}">{$synfunc-val}</tls:syn-func>
  {if ($semfeat) then 
  <tls:sem-feat corresp="#{$semfeat}">{$semfeat-val}</tls:sem-feat>
  else ()}
  </gramGrp>
  <def>{$def}</def></sense>
</entry>
return
<div>
<user>{$user}</user>
{update insert $newnode into $concept-doc}
</div>

