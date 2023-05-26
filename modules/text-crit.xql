xquery version "3.1";
(:~
: This module provides function for generic changes to xml files in the database
: 2022-10-10
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace txc="http://hxwd.org/text-crit";

import module namespace config="http://hxwd.org/config" at "config.xqm";
import module namespace krx="http://hxwd.org/krx-utils" at "krx-utils.xql";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "db-utility.xqm";
import module namespace xed="http://hxwd.org/xml-edit" at "xml-edit.xql";
import module namespace bib="http://hxwd.org/biblio" at "biblio.xql";
declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tx="http://exist-db.org/tls";

declare variable $txc:encodingDesc :=       
<encodingDesc xmlns="http://www.tei-c.org/ns/1.0">
       <variantEncoding location="external" method="double-end-point"/>
</encodingDesc>;

declare variable $txc:listWit := <p xmlns="http://www.tei-c.org/ns/1.0"><listWit></listWit></p>;

declare variable $txc:back := <back xmlns="http://www.tei-c.org/ns/1.0"><listApp><app/></listApp></back>;

(: check if the elements necessary to register variants are available :
  variantEncoding
  listWit
  listApp
:)

declare function txc:check-txc-elements ($node){
let $tei:= $node/ancestor::tei:TEI
let $res:=
 (if ($tei//tei:variantEncoding) then () else
  if ($tei//tei:encodingDesc) then 
    update insert <variantEncoding xmlns="http://www.tei-c.org/ns/1.0" location="external" method="double-end-point"/> into $tei//tei:encodingDesc
  else 
    update insert $txc:encodingDesc following $tei//tei:fileDesc
  ,if ($tei//tei:listWit) then () else
    if ($tei//tei:sourceDesc/tei:bibl) then 
      update insert <listWit xmlns="http://www.tei-c.org/ns/1.0"></listWit> following $tei//tei:sourceDesc/tei:bibl
    else
      update insert $txc:listWit into $tei//tei:sourceDesc
  , if ($tei//tei:listApp) then () else 
    if ($tei//tei:back) then 
      update insert <listApp xmlns="http://www.tei-c.org/ns/1.0"><app/></listApp> into $tei//tei:back
    else
     update insert $txc:back following $tei//tei:body
  ) 
return $res
};

declare function txc:save-txc($map as map(*)){
let $seg := collection($config:tls-texts)//tei:seg[@xml:id=$map?uid]
, $tei := $seg/ancestor::tei:TEI
, $user := sm:id()//sm:real/sm:username/text()
, $rd-keys := for $l in map:keys($map) 
   where starts-with($l, "rdg---")
   order by $l
   return $l
, $ck := (for $r in $rd-keys return $map?($r), $map?sel)
, $bid := $seg/@xml:id || "-" || $map?pos
, $fid := "beg-" || $bid 
, $appid := "app-" || $bid
, $ns1 := xed:insert-node-at($seg, xs:integer($map?pos), <anchor type="app" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$fid}"/>)
, $tid := "end-" || $bid
, $bibref := if (string-length($map?bibref) > 0 and not ($map?bibref="undefined")) then 
    let $ref := bib:get-bib-ref($map?bibref)
    , $tit := bib:get-ref-title($map?bibref)
    return
   <bibl xmlns="http://www.tei-c.org/ns/1.0"><title>{$tit}</title>, <ref target="#{$map?bibref}">{$ref}</ref>, p.<biblScope unit="page">{$map?bibpage}</biblScope></bibl> else ()
, $ns2 := xed:insert-node-at($ns1, xs:integer($map?pos)+string-length($map?sel), <anchor type="app" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$tid}"/>)
, $app := <app resp="#{$user}" modified="{current-dateTime()}" xml:id="{$appid}" xmlns="http://www.tei-c.org/ns/1.0" from="#{$fid}" to="#{$tid}"><lem>{$map?sel}</lem>
  {for $r in $rd-keys  
   let $rdg := $map?($r)
   , $wit := substring-after($r, "rdg---")
   where not ($rdg = $map?sel)
   return
  <rdg wit="#{$wit}">{$rdg}</rdg>}
  {if (string-length($map?note)>0) then <note>{$map?note}{$bibref}</note> else () }
  </app>
, $res := 
   if (count(distinct-values($ck)) = 1) then "Error: No variant given!" 
   else 
   (txc:check-txc-elements($seg), 
    if ($tei//tei:app[@xml:id=$appid]) then 
     update replace $tei//tei:app[@xml:id=$appid] with $app
     else 
    ( 
    update replace $seg with $ns2, update insert $app into $tei//tei:listApp, 
  "Success.")
  )
return $res
};
