xquery version "3.1";

module namespace tlsapi="http://hxwd.org/tlsapi"; 

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";
import module namespace functx="http://www.functx.com" at "../modules/functx.xql";
import module namespace tlslib="http://hxwd.org/lib" at "../modules/tlslib.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";

(: Just for reference, might want to use this later...
"None" : "TJAN TJOE SOM 1949FF", (\: BHT 白虎通 :\)
"None" : "Stephen Owen", (\: CEN SHEN 岑參 :\)
"None" : "Stephen Owen", (\: CHEN ZIANG 陳子昂 :\)
"None" : "Legge", (\: CQ 春秋 :\)
"None" : "Christoph Anderl", (\: XINXINGLUN 大乘心行論 :\)
"None" : "Stephen Owen", (\: DU FU 杜甫 :\)
"None" : " ", (\: XIAOFUXU 馮夢龍笑府序 :\)
"None" : "C. Harbsmeier,  based on Dirk Meier", (\: GD.XZMC 郭店。性自命出 :\)
"None" : "C. Harbsmeier", (\: GD.YUCONG 郭店語叢 :\)
"None" : "Dirk Meier", (\: GD.ZHONGXIN 郭店.忠信之道 :\)
"None" : "PINE 2000", (\: HANSHAN 寒山詩 :\)
"None" : "HARPER 1998", (\: HEYINYANG 合陰陽 :\)
"None" : "C. Harbsmeier", (\: HUAZAN 畫贊 :\)
"None" : "Keightley, Takashima, Qiu", (\: HEJI 甲骨文字合集 :\)
"None" : "C. Harbsmeier", (\: KQ 孔雀東南飛 :\)
"None" : "Stephen Owen", (\: Li Bai 李白 :\)
"None" : "Stephen Owen", (\: LISHIMIN 李世民 :\)
"None" : "C. Harbsmeier, based on Pelliot 1920 and Keenan 1994", (\: MOUZI 牟子：理惑論 :\)
"None" : "C. Harbsmeier, based on SWANN 1960", (\: NJ 女戒 :\)
"None" : "C. Harbsmeier", (\: QYX 切韻序 :\)
"None" : "Martin Kern, modified by C. Harbsmeier", (\: STELAE 秦刻石 :\)
"None" : "C. Harbsmeier", (\: RENJING 吳亮：忍經 :\)
"None" : "Duyvendak", (\: SHANG 商君書 :\)
"None" : "P. Thompson", (\: SHENDAO 慎到 :\)
"None" : "Owen 1992", (\: SIKUNGTU.SHIPIN 司空圖:二十四詩品 :\)
"None" : "HULSEWE", (\: SHUIHUDI 睡虎地 :\)
"None" : "C. Harbsmeier", (\: SHUOWEN XU 説文解字序 :\)
"None" : "C. Harbsmeier", (\: SUMMA SUMMA.THEOL :\)
"None" : "LAU AND AMES 1996", (\: SB 孫臏 :\)
"None" : "Ralph D. Sawyer", (\: SUN 孫子 :\)
"None" : "Hightower", (\: TYM 陶淵明詩 :\)
"None" : "Stephen Owen", (\: Wang Ji 王績 :\)
"None" : "none", (\: WEN 文子 :\)
"None" : "Pang Pu et al.", (\: WXP 五行篇 :\)
"None" : "C. Harbsmeier", (\: XIAOLIN 笑林 :\)
"None" : "Pokora, Michigan University Press", (\: XINLUN 新論 :\)
"None" : "C. Harbsmeier", (\: ZHONGJING 忠經 :\)
:)

declare variable $tlsapi:translation-map := map{
"KR1a0001" : "[Lynn, Columbia Unversity Press]", (: XC 繫辭 :)
"KR1b0001" : "Karlgren", (: SHU 尚書 :)
"KR1c0001" : "Karlgren, BMFEA", (: SHI 詩經 :)
"KR1c0003" : "Stephen Owen 1992", (: DAXU 詩。大序 :)
"KR1c0066" : "Hightower", (: HSWZ 韓詩外傳 :)
"KR1d0052" : "Legge", (: LJ 禮記 :)
"KR1e0001" : "Legge", (: ZUO 左傳 :)
"KR1e0008" : "MALMQVIST 1972ff", (: CQGL 穀梁傳 :)
"KR1f0001" : "L. Zádrapa", (: XJ 孝經 :)
"KR1h0001" : "David Sehnal; D.C. Lau", (: MENG 孟子 :)
"KR1h0004" : "C. Harbsmeier", (: LY 論語 :)
"KR2a0001" : "Watson", (: SJ 史記 :)
"KR2e0001" : "none", (: GY 國語 :)
"KR2e0003" : "Crump, Oxford University Press", (: ZGC 戰國策 :)
"KR2g0003" : "none", (: YAN 晏子春秋 :)
"KR2g0017" : "O'HARA 1945", (: LNZ 列女傳 :)
"KR3a0001" : "KRAMER 1950", (: KJ 孔子家語 :)
"KR3a0002" : "Knoblock and Riegel", (: XUN 荀子 :)
"KR3a0006" : "GALE 1931", (: YTL 鹽鐵論 :)
"KR3a0047" : "C. Harbsmeier", (: YULEI 朱子語類 :)
"KR3c0001" : "Rickett, Princeton University Press", (: GUAN 管子 :)
"KR3c0005" : "C. Harbsmeier", (: HF 韓非子 :)
"KR3e0001" : "C. Harbsmeier", (: SUWEN 素問 :)
"KR3j0002" : "Mei Yi Pao", (: MOZI 墨子 :)
"KR3j0006" : "Wells", (: HEGUAN 鶡冠子 :)
"KR3j0009" : "Knoblock &amp; Riegel", (: LS 呂氏春秋 :)
"KR3j0010" : "Wallacker, Ames, LeBlanc, Kraft, Morgan", (: HNZ 淮南子 :)
"KR3j0080" : "Hu Chirui and Michael Nylan", (: LH 論衡 :)
"KR3l0002" : "Mather", (: SSXY 世說新語 :)
"KR3l0090" : "Anne Birrell", (: SHJ 山海經 :)
"KR4a0001" : "HAWKES 1985 ", (: CC 楚辭 :)
"KR5c0057" : "Karlgren 1975", (: LAO 道德經 :)
"KR5c0124" : "GRAHAM 1960", (: LIE 列子 :)
"KR5c0126" : "[Watson 1969]", (: ZHUANG 莊子 :)
"KR5f0010" : "Graham 1998", (: MOJ 墨經 :)
"KR6b0059" : "Sun Xixin and Victor Mair", (: XYJ 賢愚經 :)
"KR6b0066" : "C. Harbsmeier ", (: BAIYU 百喻經 :)
"KR6b0067" : "DHARMAJOTI 1990", (: FAJU 法句經 :)
"KR6b0070" : " ", (: SONGJING 法集要頌經 :)
"KR6d0001" : "WATSON 1993 ", (: FAHUA 法華經 :)
"KR6q0002" : "Christoph Anderl", (: ZTJ 祖堂集 :)
"KR6q0053" : "Christoph Anderl", (: LINJILU 臨濟錄 :)
"KR6q0082" : "YAMPOLSKY 1996" (: TANJING 六祖壇經 :),
"KR6s0019" : "?" (: FYMYJ 翻譯名義序 :)
};

declare function tlsapi:autocomplete($type as xs:string, $term as xs:string){
let $callback := request:get-parameter("callback", "xx")
let $payload := 
  for $t in collection($config:tls-data-root)//tei:div[@type=$type]/tei:head
  where contains($t/text(), $term)
  order by string-length($t/text()) ascending
  return
  concat('{"id": "', $t/ancestor::tei:div[1]/@xml:id, '", "label": "', $t/text(), '"}')
return 
concat($callback, "([", string-join($payload, ","), "]);")
};

declare function tlsapi:make-attribution($line-id as xs:string, $sense-id as xs:string, 
 $user as xs:string, $currentword as xs:string) as element(){
let $line := collection($config:tls-texts-root)//tei:seg[@xml:id=$line-id],
$tr := collection($config:tls-translation-root)//tei:*[@corresp=concat('#', $line-id)],
$textid := tokenize($line-id, "_")[1],
$title-en := $tr/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
$title := $line/ancestor::tei:TEI/tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title/text(),
$sense := collection($config:tls-data-root)//tei:sense[@xml:id=$sense-id],
$concept := $sense/ancestor::tei:div/tei:head/text(),
$concept-id := $sense/ancestor::tei:div/@xml:id, 
$wordtmp := $sense/parent::tei:entry/tei:form/tei:orth/text(),
(:$word := string-join(if (count($wordtmp) = 1) then $wordtmp else 
        for $w in $wordtmp
         return if (contains($line, $w)) then $w else "", ""),:)
$word := $wordtmp[1],
$uuid := concat("uuid-", util:uuid()),
$newswl :=
<tls:ann xmlns="http://www.tei-c.org/ns/1.0" concept="{$concept}" concept-id="{$concept-id}" xml:id="{$uuid}">
<link target="#{$line-id} #{$sense-id}"/>
<tls:text>
<tls:srcline title="{$title}" target="#{$line-id}" pos="{functx:index-of-string(string-join($line/text(), ""), $word)}">{$line/text()}</tls:srcline>
<tls:line title="{$title-en}" src="{map:get($tlsapi:translation-map, $textid)}">{$tr/text()}</tls:line>
</tls:text>
<form  corresp="{$sense/parent::tei:entry/tei:form/@corresp}" orig="{$currentword}">
{$sense/parent::tei:entry/tei:form/tei:orth,
$sense/parent::tei:entry/tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]}
</form>
<sense corresp="#{$sense-id}">
{$sense/*}
</sense>
<tls:metadata resp="#{$user}" created="{current-dateTime()}">
<respStmt>{if (("tls-editor") = sm:id()//sm:group/text()) then 
<resp>added and approved</resp> else
<resp>added</resp>}
<name>{$user}</name>
</respStmt>
</tls:metadata>
</tls:ann>
return
$newswl
};

(: instead of using a uuid-named file hierarchy, this version uses one file per text to store the annotations :)
declare function tlsapi:save-swl-to-docs($line-id as xs:string, $sense-id as xs:string, 
$user as xs:string, $currentword as xs:string) {
let $data-root := "/db/apps/tls-data"
let $targetcoll := if (xmldb:collection-available($data-root || "/notes/doc")) then $data-root || "/notes/doc" else 
    concat($data-root || "/notes", xmldb:create-collection($data-root || "/notes", "doc"))
,$textid := tokenize($line-id, "_")[1]
,$docname :=  $textid || "-ann.xml"
,$newswl:=tlsapi:make-attribution($line-id, $sense-id, $user, $currentword)
,$targetdoc :=   if (doc-available(concat($targetcoll,"/",$docname))) then
                    doc(concat($targetcoll,"/", $docname)) else 
   doc(xmldb:store($targetcoll, $docname, 
  <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$textid}-ann">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Annotations for {string($newswl//tls:srcline/@title)}</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Annotations</head><p xml:id="{$textid}-start"></p></div>
      </body>
  </text>
</TEI>))

let $targetnode := collection($targetcoll)//tei:seg[@xml:id=$line-id]

return (
if ($targetnode) then 
 update insert $newswl into $targetnode
else
 update insert <seg  xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$line-id}"><line>{$newswl//tls:srcline/text()}</line>{$newswl}</seg> into 
 $targetdoc//tei:p[@xml:id=concat($textid, "-start")]
 ,data($newswl/@xml:id))
};



declare function tlsapi:save-swl-with-path($line-id as xs:string, $sense-id as xs:string, 
$notes-path as xs:string, $user as xs:string, $currentword as xs:string){

if (($line-id != "xx") and ($sense-id != "xx")) then
let $newswl:=tlsapi:make-attribution($line-id, $sense-id, $user, $currentword)
,$uuid := $newswl/tls:ann/@xml:id
,$path := concat($notes-path, substring($uuid, 6, 2))
return (
if (xmldb:collection-available($path)) then () else
(xmldb:create-collection($notes-path, substring($uuid, 6, 2)),
sm:chmod(xs:anyURI($path), "rwxrwxr--"),
sm:chown(xs:anyURI($path), $user),
sm:chgrp(xs:anyURI($path), "tls-user")
),
let $res := (xmldb:store($path, concat($uuid, ".xml"), $newswl)) 
return
if ($res) then (
sm:chmod(xs:anyURI($res), "rwxrwxr--"),
sm:chown(xs:anyURI($res), $user),
sm:chgrp(xs:anyURI($res), "tls-editor"),
"OK")
else
"Some error occurred, could not save resource")
else
"Wrong parameters received"
};


declare function tlsapi:save-swl($line-id as xs:string, $sense-id as xs:string){
let $notes-path := concat($config:tls-data-root, "/notes/new/")
let $user := sm:id()//sm:real/sm:username/text()
let $currentword := ""
return
(:tlsapi:save-swl-with-path($line-id, $sense-id, $notes-path, $user, $currentword):)
tlsapi:save-swl-to-docs($line-id, $sense-id, $user, $currentword)

};



(: so this is now the xquery that displays the dialog for 
 - new concept for character:  type=concept
 - new word within concept for character: type=word
 - revision of existing swl:  type=swl
 the available information differs slightly, this will collected into a map and sent over to tlsapi
 
 the name is now slightly misleading, but I'll keep it for now:-)
 
:)
declare function tlsapi:get-swl($rpara as map(*)){

let $swl:= if ($rpara?uuid = "xx") then <empty/> else collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$rpara?uuid]
,$para := map{
"char" : if ($rpara?word = "xx") then $swl//tei:form/tei:orth/text() else $rpara?word,
"line-id" : if ($rpara?line-id = "xx") then tokenize(substring($swl//tei:link/@target, 2), " #")[1] else $rpara?line-id,
"line" : if ($rpara?line = "xx") then $swl//tls:srcline/text() else $rpara?line,
"concept" : if ($rpara?concept = "xx") then data($swl/@concept) else $rpara?concept,
"concept-id" : if ($rpara?concept-id = "xx") then data($swl/@xml:id) else $rpara?concept-id,
"synfunc-id" : data($swl//tls:syn-func/@corresp)=>substring(2),
"synfunc" : data($swl//tei:sense/tei:gramGrp/tls:syn-func/text()),
"semfeat-id" : data($swl//tls:sem-feat/@corresp)=>substring(2),
"semfeat" : data($swl//tei:sense/tei:gramGrp/tls:sem-feat/text()),
"pinyin" : $swl/tei:form/tei:pron[@xml:lang="zh-Latn-x-pinyin"]/text(),
"def" : data($swl//tei:sense/tei:def/text()),
"wid" : $rpara?wid,
"title" : if ($rpara?type = "concept") then "" else 
          if ($rpara?type = "swl") then "Editing Attribution for" else
          ""
}

return
tlsapi:swl-dialog($para, $rpara?type)
};

declare function tlsapi:swl-dialog($para as map(), $type as xs:string){

<div id="editSWLDialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                {if ($type = "concept") then
                <h5 class="modal-title">{$para?title} <strong class="ml-2"><span id="{$type}-query-span">{$para?char}</span></strong>
                    <button class="btn badge badge-primary ml-2" type="button" onclick="get_guangyun()">
                        廣韻
                    </button>
                </h5>
                else if ($type = "swl") then
                <h5 class="modal-title">{$para?title} <strong class="ml-2"><span id="{$type}-query-span">{$para?char}</span></strong>
                </h5>
                else
                <h5 class="modal-title">Adding SW for {$para?char} to concept <strong class="ml-2"><span id="newsw-concept-span">{$para?concept}</span></strong></h5>
                }
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    ×
                </button>
            </div>
            <div class="modal-body">
                {if ($type = ("concept", "swl", "word")) then
                (<h6 class="text-muted">At:  <span id="concept-line-id-span" class="ml-2">{$para?line-id}</span></h6>,
                <h6 class="text-muted">Line: <span id="concept-line-text-span" class="ml-2">{$para?line}</span></h6>
                ) else () }
                <div>
                    <span id="concept-id-span" style="display:none;">{$para?concept-id}</span>
                   {if ($type = ("word")) then
                    <span id="word-id-span" style="display:none;">{$para?wid}</span>
                    else ()
                    }
                    <span id="synfunc-id-span" style="display:none;">{$para?synfunc-id}</span>
                    <span id="semfeat-id-span" style="display:none;">{$para?semfeat-id}</span>
                    
                </div>
                   {if ($type = "concept") then 
                <div class="form-group" id="guangyun-group">                
                    <span class="text-muted" id="guangyun-group-pl"> Press the 廣韻 button above and select the pronounciation</span>
                </div> else if ($type = "swl") then
                <div class="form-group" id="guangyun-group">     
                   {tlsapi:get-guangyun($para?char, $para?pinyin)}
                </div>
                else (),
                if ($type = ("concept", "swl")) then
                <div id="select-concept-group" class="form-group ui-widget">
                    <label for="select-concept">Concept: </label>
                    <input id="select-concept" class="form-control" required="true" value="{$para?concept}"/>
                </div>
                    else ()}                
                <div class="form-row">
                <div id="select-synfunc-group" class="form-group ui-widget col-md-6">
                    <label for="select-synfunc">Syntactic function: </label>
                    <input id="select-synfunc" class="form-control" required="true" value="{$para?synfunc}"/>
                </div>
                <div id="select-semfeat-group" class="form-group ui-widget col-md-6">
                    <label for="select-semfeat">Semantic feature: </label>
                    <input id="select-semfeat" class="form-control" value="{$para?semfeat}"/>
                </div>
                </div>
                <div id="input-def-group">
                    <label for="input-def">Definition </label>
                    <textarea id="input-def" class="form-control">{$para?def}</textarea>                   
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                   {if ($type = "concept") then 
                <button type="button" class="btn btn-primary" onclick="save_to_concept()">Save changes</button>
                else if ($type = "swl") then
                <button type="button" class="btn btn-primary" onclick="save_swl()">Save SWL</button>
                else                
                <button type="button" class="btn btn-primary" onclick="save_newsw()">Save SW</button>
                }
            </div>
        </div>
    </div>    
    <!-- temp -->
    
</div>    
};

declare function tlsapi:get-guangyun($chars as xs:string, $pron as xs:string){

for $char at $cc in  analyze-string($chars, ".")//fn:match/text()
return
<div id="guangyun-input-dyn-{$cc}">
<h5><strong class="ml-2">{$char}</strong></h5>
{
for $g at $count in collection(concat($config:tls-data-root, "/guangyun"))//tx:attested-graph/tx:graph[contains(.,$char)]
let $e := $g/ancestor::tx:guangyun-entry,
$p := for $s in $e//tx:mandarin/* 
       return 
       if (string-length(normalize-space($s)) > 0) then $s else (),
$py := normalize-space(string-join($p, ';'))
return

<div class="form-check">
   { if (contains($py, $pron)) then (: todo: handle pron for binomes and more :)
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}" checked="checked"/>
   else
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}"/>
   }
   <label class="form-check-label" for="guangyun-input-{$cc}-{$count}">
     {$e/tx:gloss/text()} -  {$py}
   </label>
  </div>
}
</div>
};

declare function tlsapi:get-sw($word as xs:string) as item()* {
let $words := collection(concat($config:tls-data-root, '/concepts/'))//tei:orth[. = $word]
return
if (count($words) > 0) then
for $w in $words
let $concept := $w/ancestor::tei:div/tei:head/text(),
$id := $w/ancestor::tei:div/@xml:id,
$py := $w/parent::tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]/text(),
$zi := $w/parent::tei:form/tei:orth/text(),
$wid := $w/ancestor::tei:entry/@xml:id,
$form := $w/parent::tei:form/@corresp

(:group by $concept:)
order by $concept
return
<li class="mb-3"><strong>{$zi}</strong>&#160;({$py})&#160;<strong>{$concept}</strong> 
     { if (sm:is-authenticated()) then 
<button class="btn badge badge-secondary ml-2" type="button" 
onclick="show_newsw({{'wid':'{$wid}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">
           New SW
      </button>
      else ()}
<ul class="list-unstyled" style="swl-bullet">{for $s in $w/ancestor::tei:entry/tei:sense
let $sf := $s//tls:syn-func/text(),
$sm := $s//tls:sem-feat/text(),
$def := $s//tei:def/text()
return
<li><span id="pop-{$s/@xml:id}" class="small btn" data-toggle="popover" data-placement="left">●</span>{$sf}&#160;{$sm}: {$def}
     { if (sm:is-authenticated()) then 
     <button class="btn badge badge-primary ml-2" type="button" onclick="save_this_swl('{$s/@xml:id}')">
           Use
      </button>
      else () }
</li>
}
</ul></li>
else 
<li class="list-group-item">No word selected or no existing syntactic word found.</li>
};

declare function tlsapi:get-text-preview($loc as xs:string){

let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id = $loc],
$title := $seg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
$pseg := $seg/preceding::tei:seg[fn:position() < 5],
$fseg := $seg/following::tei:seg[fn:position() < 5],
$dseg := ($pseg, $seg, $fseg)
return
<div class="popover" role="tooltip">
<div class="arrow"></div>
<h3 class="popover-header">
<a href="textview.html?location={$loc}">{$title}</a></h3>
<div class="popover-body">
    {
for $d in $dseg 
return 
    tlslib:displayseg($d, map{"ann": "false", "log": $loc})
    }
</div>
</div>
};

declare function tlsapi:save-newsw($rpara as map(*)) {
 let $user := sm:id()//sm:real/sm:username/text()
 let $concept-doc := collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]//tei:entry[@xml:id=$rpara?wuid],
 $suid := concat("uuid-", util:uuid()),
 $newnode :=
<sense xml:id="{$suid}" resp="#{$user}" tls:created="{current-dateTime()}" xmlns="http://www.tei-c.org/ns/1.0" 
xmlns:tls="http://hxwd.org/ns/1.0">
<gramGrp><pos>{upper-case(substring($rpara?synfunc-val, 1,1))}</pos>
  <tls:syn-func corresp="#{$rpara?synfunc}">{$rpara?synfunc-val}</tls:syn-func>
  {if ($rpara?semfeat) then 
  <tls:sem-feat corresp="#{$rpara?semfeat}">{$rpara?semfeat-val}</tls:sem-feat>
  else ()}
  </gramGrp>
  <def>{$rpara?def}</def></sense>
return
<response>
<user>{$user}</user>
<result>{update insert $newnode into $concept-doc}</result>
<sense_id>{$suid}</sense_id>
</response>

};

declare function tlsapi:save-to-concept($rpara as map(*)) {

let $user := sm:id()//sm:real/sm:username/text()

let $gys :=    
   for $gid in tokenize(normalize-space($rpara?guangyun-id), "xxx") 
   return
    collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$gid]

 
 let $form :=
(:   let $e := collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$gid],:)
    let $oc := for $gy in $gys
        let $rec := $gy//tx:old-chinese/tx:pan-wuyun/tx:oc/text()
        return if ($rec) then $rec else "--"
    ,$mc := for $gy in $gys 
        let $rec := $gy//tx:middle-chinese//tx:baxter/text()
        return if ($rec) then $rec else "--"
    ,$p := for $gy in $gys for $s in $gy//tx:mandarin/*
       return 
       if (string-length(normalize-space($s)) > 0) then $s/text() else (),
    $gr := for $gy in $gys return 
      normalize-space($gy//tx:attested-graph/tx:graph/text())
    
return
    <form xmlns="http://www.tei-c.org/ns/1.0" corresp="#{replace($rpara?guangyun-id, "xxx", " #")}">
    <orth>{string-join($gr, "")}</orth>
    <pron xml:lang="zh-Latn-x-pinyin">{string-join($p, " ")}</pron>
    <pron xml:lang="zh-x-mc" resp="rec:baxter">{string-join($mc, " ")}</pron>
    <pron xml:lang="zh-x-oc" resp="rec:pan-wuyun">{string-join($oc, " ")}</pron>
    </form>,

 
 $concept-doc := collection($config:tls-data-root)//tei:div[@xml:id=$rpara?concept-id]//tei:div[@type="words"],
 $wuid := concat("uuid-", util:uuid()),
 $suid := concat("uuid-", util:uuid()),
 $newnode :=
<entry xmlns="http://www.tei-c.org/ns/1.0" 
xmlns:tls="http://hxwd.org/ns/1.0"
type="word" xml:id="{$wuid}" resp="#{$user}" tls:created="{current-dateTime()}">
{$form}
<sense xml:id="{$suid}" resp="#{$user}" tls:created="{current-dateTime()}">
<gramGrp><pos>{upper-case(substring($rpara?synfunc-val, 1,1))}</pos>
  <tls:syn-func corresp="#{$rpara?synfunc}">{$rpara?synfunc-val}</tls:syn-func>
  {if ($rpara?semfeat) then 
  <tls:sem-feat corresp="#{$rpara?semfeat}">{$rpara?semfeat-val}</tls:sem-feat>
  else ()}
  </gramGrp>
  <def>{$rpara?def}</def></sense>
</entry>
return
<response>
<user>{$user}</user>
<result>{update insert $newnode into $concept-doc}</result>
<sense_id>{$suid}</sense_id>
</response>

};


declare function tlsapi:show-att($uid as xs:string){

let $key := "#" || $uid
let $atts := collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = $key]
return
if (count($atts) > 0) then
for $a in $atts
let $src := data($a/tls:text/tls:srcline/@title),
$when := data($a/tls:text/@tls:when)
let $line := $a/tls:text/tls:srcline/text(),
$tr := $a/tls:text/tls:line,
$target := substring(data($a/tls:text/tls:srcline/@target), 2),
$loc := xs:int(substring-before(tokenize(substring-before($target, "."), "_")[last()], "-"))
order by $when descending
return
<div class="row bg-light table-striped">
<div class="col-sm-2"><a href="textview.html?location={$target}" class="font-weight-bold">{$src, $loc}</a></div>
<div class="col-sm-3"><span data-target="{$target}" data-toggle="popover">{$line}</span></div>
<div class="col-sm-7"><span>{$tr}</span></div>
</div>
else 
<p class="font-weight-bold">No attributions found</p>

};

declare function tlsapi:delete-swl($uid as xs:string) {
let $swl := collection($config:tls-data-root|| "/notes")//tls:ann[@xml:id=$uid]
return update delete $swl
};

declare function tlsapi:show-use-of($uid as xs:string){
let $key := "#" || $uid
let $res := for $r in collection($config:tls-data-root)//tls:*[@corresp = $key]
     where exists($r/ancestor::tei:sense)
     return $r

return

if (count($res) > 0) then
for $r in subsequence($res, 1, 10)
  let $sw := $r/ancestor::tei:sense
  return
  tlslib:display_sense($sw)
else 

concat("No usage examples found for key: ", $key)

};

declare function tlsapi:save-tr($trid as xs:string, $tr as xs:string, $lang as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
let $id := substring($trid, 1, string-length($trid) -3)
,$txtid := tokenize($id, "_")[1]
,$trcoll := concat($config:tls-translation-root, "/", $lang)
,$trcollavailable := xmldb:collection-available($trcoll) or 
  (xmldb:create-collection($config:tls-translation-root, $lang),
  sm:chmod(xs:anyURI($trcoll), "rwxrwxr--"),
  sm:chown(xs:anyURI($trcoll), "tls"),
  sm:chgrp(xs:anyURI($trcoll), "tls-user") )
,$docpath := concat($trcoll, "/", $txtid, "-", $lang, ".xml")
,$title := collection($config:tls-texts-root)//tei:TEI[@xml:id=$txtid]//tei:titleStmt/tei:title/text()
,$node := collection($trcoll)//tei:seg[@corresp=concat("#", $id)]
,$seg := <seg xmlns="http://www.tei-c.org/ns/1.0" corresp="#{$id}" xml:lang="{$lang}" resp="{$user}" modified="{current-dateTime()}">{$tr}</seg>
let $doc :=
  if (not (doc-available($docpath))) then
   doc(xmldb:store($trcoll, concat($txtid, "-", $lang, ".xml"), 
   <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$txtid}-{$lang}">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Translation of {$title} into ({$lang})</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Translated parts</head><p xml:id="{$txtid}-start"></p></div>
      </body>
  </text>
</TEI>)) 
 else doc($docpath)
 
return
if ($node) then 
if (update replace $node with $seg) then "Success. Updated translation." else "Could not update translation." 
else 
if (update insert $seg  into $doc//tei:p[@xml:id=concat($txtid, "-start")]) then "Success. Saved translation." else ("Could not save translation. ", $docpath)

};