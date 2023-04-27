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
, $bid := $seg/@xml:id || "-" || $map?pos
, $fid := "beg-" || $bid 
, $tid := "end-" || $bid
, $ns1 := xed:insert-node-at($seg, xs:integer($map?pos), <anchor type="app" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$fid}"/>)
, $ns2 := xed:insert-node-at($ns1, xs:integer($map?pos)+string-length($map?sel), <anchor type="app" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$tid}"/>)
, $app := <app xmlns="http://www.tei-c.org/ns/1.0" from="#{$fid}" to="#{$tid}"><lem>{$map?sel}</lem><rdg wit="#{$map?wit}">{$map?rdg}</rdg>{
if (string-length($map?note)>0) then <note>{$map?note}</note> else () 
}</app>
, $res := (txc:check-txc-elements($seg), update replace $seg with $ns2, update insert $app into $tei//tei:listApp)
return $res
};
