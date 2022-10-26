xquery version "3.1";

module namespace krx="http://hxwd.org/krx-utils"; 


import module namespace json="http://www.json.org";
import module namespace http="http://expath.org/ns/http-client";
import module namespace config="http://hxwd.org/config" at "config.xqm";
(:
declare namespace nx= "http://kanripo.org/ns/KRX/Nexus/1.0";
declare namespace tk= "http://kanripo.org/ns/KRX/Token/1.0";
:)
declare namespace mf = "http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace kx = "http://kanripo.org/ns/KRX/1.0";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:media-type "text/javascript";
(: format of collate requests 
curl http://127.0.0.1:7369/collate -H "Content-Type: application/json" -X POST --data-binary @20200424144637889.txt

(:  http:send-request(<http:request http-version="1.1" href="http://127.0.0.1:7369/collate" method="post">
  <http:header name="Content-type" value="application/json"/>
  <http:body media-type="application/json" method="text">{$ret}</http:body></http:request>)  :)


TODO: - express lnk table as JSON for collate
 - request collation from collate via http-request
 - display results in html
 
                     let $xml-data := serialize($data,
                                        <output:serialization-parameters>
                                            <output:method>{$serialization}</output:method>
                                        </output:serialization-parameters>) 

 
:)

declare function krx:search($query){
()
};


declare function krx:show-manifest($mf as node()){
let $et := map{
"root" : "Editions of the root text",
"annotation" : "Commentaries to the root text",
"translation" : "Translations",
"other" : "Related texts"
}
, $textid := $mf/@xml:id

return
<div class="row" id="textid" data-id="{$textid}">
<div class="card col-sm-12" style="max-width: 1000px;">
<div class="card-body">
<h4 class="card-title">
<span id="{$textid}-la" class="sf" contenteditable="true">Manifest for {data($textid)}</span>  
</h4>
<h5 class="card-subtitle">{$mf/mf:description}</h5>
<div class="card">
<h4>Editions</h4>
{for $eg in $mf//mf:editions/mf:editionGroup
return
<div>
<h5>{map:get($et, $eg/@type)}</h5>
<ul>
{for $e in $eg/mf:edition return
<li title="{$e/@role}">{if (data($e/@role)="base") then 
let $id := tokenize($e/@id, "_")[1]
(:, $firstdiv := (collection($config:tls-texts-root)//tei:TEI[@xml:id=$id]//tei:body/tei:div)[1]
, $targetseg := if ($firstdiv//tei:seg) then ($firstdiv//tei:seg)[1] else  ($firstdiv/following::tei:seg)[1] :)
return
<a href="textview.html?location={$id}&amp;mode=visit">{$e/mf:description}</a>
else
($e/mf:description)
}
　<span class="text-muted">ID:</span>{data($e/@id)},　　<span class="text-muted">Type:</span>{data($e/@type)}</li>
}
</ul>
</div>
}
</div>
</div>
<div class="card-body">
<h4>Contents</h4>
<ul>
{for $d in $mf/mf:divisions/mf:div return
<li><a href="#">{data($d/@label)}   </a></li>
}
</ul>
</div>
</div>
</div>
};


declare function krx:get-variants($sid as xs:string){
let $edid := string-join(tokenize($sid, "_")[position()>=1 and position()<4], "_")
,$ltab := collection("/db/apps/tls-texts/aux/lnk")/kx:nexusList[@ed=$edid]
,$tok := collection("/db/apps/tls-texts/aux/tok")
,$s := $ltab/kx:nexus[@id=$sid]
let $ted := $s/@ed
, $tc := xs:int($s/@tcount)
, $tx := $tok/kx:tlist[@ed=$edid]/kx:t[@tp=$s/@tp] 
, $seg := $tx/following::kx:t[fn:position() < $tc + 1]
(:     (data($s/@tp), $tc, $seg) :)
return
count($ltab)
};

declare function krx:get-varseg-ed($sid as xs:string, $ed as xs:string){
let $edid := string-join(tokenize($sid, "_")[position()>=1 and position()<3], "_")
let $ltab := collection("/db/apps/tls-texts/aux/lnk")/kx:nexusList[@ed=$edid]
,$tok := collection("/db/apps/tls-texts/aux/tok")
,$r := $ltab/kx:nexus[@xml:id=$sid]/kx:locationRef[@ed=$ed]
, $tc := xs:int($r/@tcount)
, $tx := $tok//kx:tList[@ed=$ed]//kx:t[@tp=$r/@tp] 
, $tks := $tx/following::kx:t[fn:position() < $tc + 1]
return string-join(for $t in $tks return ($t || data($t/@f)), '')
};


declare function krx:collate-request($sid as xs:string){
let $edid := string-join(tokenize($sid, "_")[position()>=1 and position()<3], "_")
,$ltab := collection("/db/apps/tls-texts/aux/lnk")/kx:nexusList[@ed=$edid]
,$tok := collection("/db/apps/tls-texts/aux/tok")
,$s := $ltab/kx:nexus[@xml:id=$sid]
let $ted := $s/@ed
, $tc := xs:int($s/@tcount)
, $tx := $tok/kx:tList[@ed=$edid]//kx:t[@tp=$s/@tp] 
, $seg := $tx/following::kx:t[fn:position() < $tc + 1]
(:     (data($s/@tp), $tc, $seg) :)
return
<root>
{for $r in $s/kx:locationRef
  let $id := $r/@ed
  ,$rc := xs:int($r/@tcount)
  ,$rx := $tok/kx:tList[@ed=$id]//kx:t[@tp=$r/@tp]
  ,$rseg := $rx/following::kx:t[fn:position() < $rc + 1]
return
<witnesses>
<id>{data($id)}</id>
{for $t in $rseg
return
element tokens {
attribute t {$t/text()},
for $att in $t/@*
return
attribute {name($att)} { $att }
}
}

</witnesses>
}
</root>
};
(:
let $sid := "KR5c0057_tls_001-1a.4" 
return:)
(:http:send-request(<http:request http-version="1.1" href="http://127.0.0.1:7369/collate" method="post">
  <http:header name="Content-type" value="application/json"/>
  <http:body media-type="application/json" method="text">{local:collate-request($sid)}</http:body></http:request>)
local:collate-request($sid)
:)
(:
json:annotate-json-literals(
<root>
<witnesses>
<id>AB</id>
<tokens t="妙" tp="34" id="KR5c0057_tls_001-1a.9" el="seg" pos="8" f="。"/>
<tokens t="A" tp="35" id="KR5c0057_tls_001-1a.10" el="seg" pos="1"/>
<tokens t="B" tp="36" id="KR5c0057_tls_001-1a.10" el="seg" pos="2"/>
<tokens t="C" tp="37" id="KR5c0057_tls_001-1a.10" el="seg" pos="3" f="，"/>
<tokens t="D" tp="38" id="KR5c0057_tls_001-1a.10" el="seg" pos="4"/>
</witnesses>
<witnesses>
<id>DF</id>
<tokens t="妙" tp="34" id="KR5c0057_tls_001-1a.9" el="seg" pos="8" f="。"/>
<tokens t="A" tp="35" id="KR5c0057_tls_001-1a.10" el="seg" pos="1"/>
<tokens t="B" tp="36" id="KR5c0057_tls_001-1a.10" el="seg" pos="2"/>
<tokens t="C" tp="37" id="KR5c0057_tls_001-1a.10" el="seg" pos="3" f="，"/>
<tokens t="D" tp="38" id="KR5c0057_tls_001-1a.10" el="seg" pos="4"/>
</witnesses>
</root>
, (xs:QName('witnesses'), xs:QName('t'), xs:QName('tokens')))
:)
(:
json:annotate-json-literals(
<t t="恒" tp="35" id="KR5c0057_tls_001-1a.10" el="seg" pos="1"></t>
, xs:QName('t')
):)
(:let $t := <div>
<t tp="41" id="KR5c0057_tls_001-1a.10" el="seg" pos="7" f="。">徼</t>
<t tp="42" id="KR5c0057_tls_001-1a.11" el="seg" pos="1">此</t>
<t tp="43" id="KR5c0057_tls_001-1a.11" el="seg" pos="2">兩</t>
<t tp="44" id="KR5c0057_tls_001-1a.11" el="seg" pos="3">者</t>
<t tp="45" id="KR5c0057_tls_001-1a.11" el="seg" pos="4">同</t></div>
return
json:element-helper($t/@tp, $t/child::*
):)
(:let $ret := 
xs:string(serialize(local:collate-request($sid),
 <output:serialization-parameters>
 <output:method>json</output:method>
 <output:media-type>application/json</output:media-type>
</output:serialization-parameters>)) 

return
http:send-request(
<http:request http-version="1.1" href="http://127.0.0.1:7369/collate" method="post">
  <http:header name="Content-type" value="application/json"/>
  <http:body media-type="application/json"  method="text">{$ret}</http:body></http:request>
)

local:collate-request($sid)
:)