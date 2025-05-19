xquery version "3.1";
(:~
: This module provides the functions for querying and displaying the bibliography
: of the TLS. 

: @author Christian Wittern  cwittern@gmail.com
: @version 1.0
:)
module namespace bib="http://hxwd.org/biblio";


declare namespace  mods="http://www.loc.gov/mods/v3";
declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

import module namespace config="http://hxwd.org/config" at "config.xqm";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace http="http://expath.org/ns/http-client";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "db-utility.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "lib/render-html.xqm";

import module namespace lu="http://hxwd.org/lib/utils" at "lib/utils.xqm";


declare variable $bib:l2c := map{
  "Chinese" : "chi",
  "English" : "eng",
  "Japanese": "jpn",
  "German"  : "ger",
  "Italian" : "ita",
  "Spanish" : "spn",
  "French"  : "fre",
  "Latin"   : "ltn",
  "Russian" : "rus",
  "Multiple": "mul"
};

declare variable $bib:c2l := map{
 "chi" : "Chinese" ,
 "eng" : "English" ,
 "jpn" : "Japanese",
 "ger" : "German"  ,
 "ita" : "Italian" ,
 "spn" : "Spanish" ,
 "fre" : "French"  ,
 "ltn" : "Latin"   ,
 "rus" : "Russian" ,
 "mul" : "Multiple" 
};

declare variable $bib:roleterms := map{
 "aut" : "Author" ,
 "trl" : "Translator" ,
 "edi" : "Editor",
 "cmp" : "Compiler"  ,
 "com" : "Commentator" 
};

declare variable $bib:script := map{
 "Latn" : "Latin" ,
 "Hant" : "Traditional Chinese" ,
 "Hans" : "Simplified Chinese"
};

declare variable $bib:genre := map{
 "book" : "Book" ,
 "chapter" : "Book chapter",
 "article" : "Article" ,
 "thesis" : "Thesis"
};

(:~ 
: import entries from zotero 
:)

declare variable $bib:zot-base-url := "https://api.zotero.org/users/";

declare function bib:get-zotero-item($item as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
, $user-doc := doc('/db/users/'||$user||'/access-config.xml')
, $zot-config := if($user-doc) then $user-doc else <response status="fail"><message>Load config.xml file please.</message></response>
, $zot-user-key := (: if($bib:zot-config//private-key-variable != '') then 
                                        if (environment-variable($git-config//private-key-variable/text()) != '') 
                                        then environment-variable($git-config//private-key-variable/text() ) else :)
                                      $zot-config//zotToken/text()

let $path := $zot-config//zotApiUser/text() || "/items/" || $item || "?v=3&amp;format=mods&amp;key=" || $zot-user-key 
let $res :=  
            http:send-request(<http:request http-version="1.1" href="{xs:anyURI($bib:zot-base-url||$path)}" method="get">
                                <http:header name="Connection" value="close"/>
                              </http:request>)                              
return  
$res[2]
(:bib:save-mods($res[2]):)
};
(:                                 <http:header name="Authentication" value="Bearer {$zot-user-key}"/> :)

(: this is the bookmarklet

javascript: (function() {var url = window.location.search;var uri = "https://hwxd.org/api/responder.xql?func=bib:add-zotero-entry&path="+path;xhr = new XMLHttpRequest();xhr.open("POST", encodeURI(uri));xhr.send();}());

javascript: (function() {var path = window.location.pathname;var uri = "https://hxwd.org/api/responder.xql?func=bib:add-zotero-entry&path="+path;xhr = new XMLHttpRequest();xhr.open("GET", encodeURI(uri));xhr.send();}());
javascript:location.href = 'https://krx.hwxd.org:8443/api/responder.xql?func=bib:add-zotero-entry&path='+ encodeURIComponent(location.pathname)
:)

(:add the item requested through the bookmarklet to the bibliography :)

declare function bib:add-zotero-entry($request as map(*)){
let $bib := bib:get-zotero-item(tokenize($request?path, "/")[position()=last()-1])
return
(bib:save-mods($bib),
response:redirect-to(xs:anyURI("https://www.zotero.org"||$request?path)))
};


declare function bib:get-mods($modsid){
 let $biblio := collection($config:tls-data-root || "/bibliography")
 return $biblio//mods:mods[@ID=$modsid]
};

declare function bib:save-mods($mods as node()){
let $id := "uuid-" || util:uuid() 
, $coll := dbu:ensure-collection($config:tls-data-root || "/bibliography/" || substring($id, 6, 1))
, $uri := xmldb:store($coll, $id || ".xml", <mods xmlns="http://www.loc.gov/mods/v3" ID="{$id}">{$mods//mods:mods/child::*}</mods>)
, $fix := bib:fix-mods(doc($uri))
return
 (
    sm:chmod(xs:anyURI($uri), "rwxrwxr--"),
(:    sm:chown(xs:anyURI($uri), "tls"),:)
    sm:chgrp(xs:anyURI($uri), "tls-user"),
    $uri
 )

};

(:~ 
: Browse the bibliography
:)
declare function bib:browse-biblio($type as xs:string, $filterString as xs:string, $mode as xs:string?){
let $biblio := collection($config:tls-data-root || "/bibliography")
, $auth := $biblio//mods:mods/mods:name/mods:namePart[@type='family']
, $count := 0
, $acap := for $d in distinct-values(for $a in $auth return substring(normalize-space($a), 1, 1))
    order by $d
    where string-length($d) > 0
    return $d
, $aheader := for $c in $acap
return 
if ($c eq $filterString and $mode eq "author") then 
<a class="badge badge-pill badge-light" name="{$c}"><span>{$c}</span></a>
else
<a class="badge badge-pill badge-light" href="browse.html?type=biblio&amp;filter={$c}&amp;mode=author"><span>{$c}</span></a>
, $tit := $biblio//mods:title
, $tcap := for $d in distinct-values(for $a in $tit return substring(normalize-space($a), 1, 1))
    order by $d
    where string-length($d) > 0
    return $d
, $theader := for $c in $tcap
return 
if ($c eq $filterString and $mode eq "title") then 
<a class="badge badge-pill badge-light" name="{$c}"><span>{$c}</span></a>
else
<a class="badge badge-pill badge-light" href="browse.html?type=biblio&amp;filter={$c}&amp;mode=title"><span>{$c}</span></a>

, $top := $biblio//mods:topic
, $topcap := for $d in distinct-values(for $y in $top return substring($y, 1, 1))
    order by data($d)
    where string-length($d) > 0
    return $d
, $topheader := for $c in $topcap
return 
if ($c eq $filterString and $mode eq "topic") then 
<a class="badge badge-pill badge-light" name="{$c}"><span>{$c}</span></a>
else
<a class="badge badge-pill badge-light" href="browse.html?type=biblio&amp;filter={$c}&amp;mode=topic"><span>{$c}</span></a>
, $topusage := <ul>{for $u in $biblio//mods:note[@type='ref-usage'] 
let $c := xs:int($u)
where $c > 0
order by $c descending
return
bib:biblio-short($u/ancestor::mods:mods, "title", '')
}</ul> 
, $recent := ""
return 
<div><h4>Browse the bibliography <button class="btn badge badge-warning ml-2" type="button" onclick="add_ref('')">Add new reference</button></h4>

    <ul class="nav nav-tabs" id="Tab" role="tablist">
    <li class="nav-item"> <a class="nav-link" id="aut-tab" role="tab" 
    href="#byauthor" data-toggle="tab">Authors</a></li>
    <li class="nav-item"> <a class="nav-link" id="tit-tab" role="tab" 
    href="#bytitle" data-toggle="tab">Titles</a></li>
    <li class="nav-item"> <a class="nav-link" id="top-tab" role="tab" 
    href="#bytopic" data-toggle="tab">Topics</a></li>
    <li class="nav-item"> <a class="nav-link" id="top-tab" role="tab" 
    href="#byusage" data-toggle="tab">Most referred</a></li>
    <li class="nav-item"> <a class="nav-link" id="top-tab" role="tab" 
    href="#byrecent" data-toggle="tab">Recently added</a></li>
    </ul>
    <div class="tab-content" id="TabContent">    
    <div class="tab-pane" id="byauthor" role="tabpanel">    
    {$aheader}
    </div>
    <div class="tab-pane" id="bytitle" role="tabpanel">    
    {$theader}
    </div>
    <div class="tab-pane" id="bytopic" role="tabpanel">    
    {$topheader}
    </div>
    <div class="tab-pane" id="byusage" role="tabpanel">    
    <h3>Works which have been most frequently referenced</h3>
    {$topusage}
    </div>
    <div class="tab-pane" id="byrecent" role="tabpanel">    
    <h3>Recently added works</h3>
    {$recent}
    </div>
    </div>
<div>
{if (string-length($filterString) > 0) then 
if ($mode eq "author") then
<div>{
for $b in $auth
 let $gn:= string-join($b/preceding-sibling::mods:namePart, '')
 where starts-with($b, $filterString)
 order by lower-case($b || $gn)
 return
 bib:biblio-short($b/ancestor::mods:mods, $mode, '')
}</div>

else if ($mode eq "title") then 
<div>{
for $b in $tit
 where starts-with($b, $filterString)
 order by $b
 return
 bib:biblio-short($b/ancestor::mods:mods, $mode, '')
}</div>
else if ($mode eq "topic") then 
<div>{
for $b in $top
 where starts-with($b, $filterString)
 order by $b
 return
 bib:biblio-short($b/ancestor::mods:mods, $mode, '')
}</div>
else 
()
else ()}
</div>

</div>
};

(: <span>{count(collection($config:tls-data-root)//tei:ref[@target="#"||$m/@ID] )}</span> :) 

declare function bib:biblio-short($m as node(), $mode as xs:string, $textid as xs:string) {
let $user := sm:id()//sm:real/sm:username/text()
, $usergroups := sm:get-user-groups($user)
return

<li><span class="font-weight-bold">{string-join(for $n in $m//mods:name return bib:display-author($n), '; ')}</span>　<a href="bibliography.html?uuid={$m/@ID}{if (string-length($textid)>0)then '&amp;textid='||$textid else ()}">{string-join($m//mods:title/text(), " ")}, {$m//mods:dateIssued/text()}　</a>   
<span class="badge badge-light">{$m//mods:note[@type='ref-usage']}</span>
  {if (contains($usergroups, "tls-editor" )) then 
    lrh:format-button("delete_swl('bib', '" || data($m/@ID) || "')", "Immediately delete this reference", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()}{if ($mode eq "topic") then 
   <p class="text-muted">{string-join(for $t in $m//mods:topic return $t, "; ")}</p> else
   <p class="text-muted">{$m/mods:note[@type='general']/text()}</p>}</li>
};

declare function bib:display-mods($uuid as xs:string){
let $biblio := collection($config:tls-data-root || "/bibliography")
,$m:=$biblio//mods:mods[@ID=$uuid]
,$r := collection($config:tls-texts)//tei:TEI//tei:witness//tei:ref[@target="#"||$uuid]
return
<div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Responsibility</span></div>
<div class="col-sm-5">{string-join(for $a in $m/mods:name return bib:display-author-role($a),"; ")}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Title</span></div>
<div class="col-sm-5">{for $t in $m/mods:titleInfo return bib:display-title($t)}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Details</span></div>
<div class="col-sm-5">(place){$m//mods:place/mods:placeTerm/text()}: (publisher){$m//mods:publisher/text()}, {$m//mods:dateIssued/text(),$m//mods:copyrightDate/text()}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Identifier</span></div>
<div class="col-sm-5">{$m/mods:note[@type="bibliographic-reference"]/text(), $m/mods:identifier[@type="isbn"]}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Topics</span></div>
<div class="col-sm-5">{for $t in $m//mods:topic return <a  class="badge badge-pill badge-light" href="browse.html?type=biblio&amp;filter={$t}&amp;mode=topic">{$t}</a>}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Comments</span></div>
<div class="col-sm-5">{$m/mods:note[@type='general']/text()}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Information basis</span></div>
<div class="col-sm-5">{$m/mods:note[@type='information-basis']/text()}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Electronic Version</span></div>
<div class="col-sm-5">{if (string-length($r)>0) then <a class="btn badge" href="textview.html?location={$r/ancestor::tei:TEI/@xml:id}&amp;mode=visit">TLS</a> else ()}<a class="btn badge badge-light" target="GXDS" style="background-color:paleturquoise" href="https://archive.org/search.php?query={string-join(for $n in $m/mods:name return ($n/mods:namePart[@type='given'])[1] || " " || ($n/mods:namePart[@type='family'])[1], ', ')}%20AND%20mediatype%3A%28texts%29 ">Find on Internet Archive</a> <button class="btn badge badge-warning" type="button" onclick="add_url('{$m/@ID}')">Add direct link to this work</button></div>
</div>
{ if ($m/mods:location) then
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Registered URLs</span></div>
<div class="col-sm-5"><ul>{for $l in $m/mods:location/mods:url return <li><a href="{$l/text()}">{data($l/@displayLabel)}</a><br/><span class="text-muted">{data($l/@note)}</span></li>}</ul></div>
</div>
else ()
}
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Referred from</span></div>
<div class="col-sm-5">{for $t in collection($config:tls-data-root)//tei:ref[@target="#"||$uuid] 
         let $cid := $t/ancestor::tei:div/@xml:id
         , $name := $t/ancestor::tei:div/tei:head/text()
         , $entry := $t/ancestor::tei:entry,
         $type := ($t/ancestor::tei:body/tei:div)[1]/@type
         order by $name
return 
if ($type eq "rhet-dev") then 
<a class="badge badge-pill badge-light" href="{$type}.html?uuid={$cid}">{$name}</a>
else
if ($type = ("syn-func", "sem-feat")) then
<a class="badge badge-pill badge-light" href="browse.html?type={$type}#{$cid}">{$name}</a>
else
<a class="badge badge-pill badge-light" href="concept.html?uuid={$cid}#{$entry/@xml:id}">{$name}{if ($entry) then ": " || string-join($entry//tei:orth, '/') else ()}</a>
}</div>
</div>
  
</div>
(: https://archive.org/search.php?query=Christoph%20Harbsmeier%20AND%20mediatype%3A%28texts%29 
<a class="btn badge badge-light" target="GXDS" title="Search {$c} in 國學大師字典 (External link)" style="background-color:paleturquoise" href="http://www.guoxuedashi.com/so.php?sokeytm={$c}&amp;ka=100">{$c}</a>
:)
};

declare function bib:url-save($para as map(*)){
let $mods := bib:get-mods($para?modsid)
let $urlnode := if (string-length($para?note)>0) then
              <location xmlns="http://www.loc.gov/mods/v3"><url note="{$para?note}" displayLabel="{$para?desc}">{$para?url}</url></location>
              else
              <location xmlns="http://www.loc.gov/mods/v3"><url displayLabel="{$para?desc}">{$para?url}</url></location>
return
update insert $urlnode into $mods
(:$para:)
};

declare function bib:display-author-role($n as node()*){
  <span>{if (exists($n/mods:role)) then "(" || $n/mods:role/mods:roleTerm ||"): " else ()} {bib:display-author($n)}</span>
};

declare function bib:display-author($n as node()*){
  <span>{for $s in ("Latn", "Hant")
   let $np :=  $n/mods:namePart[@type='family' and @script=$s]
  return
   ($np
   ,if ($np[@script=$s] and not($np/@lang = ("chi", "jpn"))) then ", " else " ",
   $np/preceding-sibling::mods:namePart[@type='given' and @script=$s]||$np/following-sibling::mods:namePart[@type='given' and @script=$s] || " ") } </span>
};


declare function bib:display-title($t as node()*){
 <span>{if (exists($t/@lang)) then "(" || data($t/@lang) ||"): " else ()} {$t/mods:title/text()} {$t/mods:subTitle/text()}</span>
};

declare function bib:biblio-search($query, $mode, $textid){
let $biblio := collection($config:tls-data-root || "/bibliography")
, $qr := for $q in tokenize($query) 
  return
  ($biblio//mods:name/mods:namePart[contains(.,$q)]/ancestor::mods:mods | $biblio//mods:title[contains(., $q)]/ancestor::mods:mods| $biblio//mods:subTitle[contains(., $q)]/ancestor::mods:mods |  $biblio//mods:note[contains(., $q)]/ancestor::mods:mods)
return
<div><h1>Bibliography search results</h1>
<p class="font-weight-bold">Searched for <span class="mark">{$query}</span>, found {count($qr)} entries.</p>
<p>Please bear in mind that the search is case sensitive. It looks for entries, where the search term appears in <span class="font-weight-bold">names</span> (unfortunately, family name and first name can not be searched together), <span class="font-weight-bold">titles</span>, or <span class="font-weight-bold">notes</span>. Multiple search terms (separated by the space character) are interpreted as "OR" connected. You can also <a href="browse.html?type=biblio">browse</a> the bibliography, or <button class="btn badge badge-warning" type="button" onclick="add_ref('{$textid}')">add</button> a new reference.</p>
<ul>{
for $q in $qr 
let $t := lower-case(normalize-space(($q//mods:title)[1]))
order by $t
return
bib:biblio-short($q, "title", $textid)
}</ul></div>
};

(: this is used to find and select references  :)
declare function bib:quick-search($map as map(*)){
let $biblio := collection($config:tls-data-root || "/bibliography")
, $qr := for $q in tokenize($map?query) 
  return
  ($biblio//mods:name/mods:namePart[contains(.,$q)]/ancestor::mods:mods | $biblio//mods:title[contains(., $q)]/ancestor::mods:mods| $biblio//mods:subTitle[contains(., $q)]/ancestor::mods:mods)
return
for $q in $qr 
let $t := lower-case(normalize-space(($q//mods:title)[1]))
order by $t
return
bib:qs-short($q, "title")
};

declare function bib:qs-short($m as node(), $mode as xs:string) {
<li>
<input class="form-check-input" type="radio" name="select-bib" id="{$m/@ID}"/>
<span id="content-{$m/@ID}">
<span class="font-weight-bold">{string-join(for $n in $m//mods:name return bib:display-author($n), '; ')}</span>　<span>{string-join($m//mods:title/text(), " ")}, {$m//mods:dateIssued/text()}　</span>
</span>
</li>
};



declare function bib:fix-mods($m as node()){
(:let $m := collection($config:tls-data-root||"/bibliography")//mods:mods[@ID=$uuid]:)
let $usage := count(collection($config:tls-data-root)//tei:ref[@target="#"||$m/@ID] )
let $fix := (
for $t in $m//mods:title
 let $val := if (lu:mostly-kanji($t)) then "Hant" else "Latn"
 , $ti := $t/parent::mods:titleInfo
 return
 if ($ti/@script) then
    update replace $ti/@script with $val
 else 
    update insert attribute script { $val }into  $ti
,for $t in $m//mods:titleInfo
 let $val := if (string-length($t/@lang) > 0) then $bib:l2c($t/@lang) else ()
 , $ti := $t
 return
 if ($val) then
    update replace $ti/@lang with $val
 else ()

,for $t in $m//mods:namePart
 let $val := if (lu:mostly-kanji($t)) then "Hant" else "Latn"
 , $ti := $t
 return
 if ($ti/@script) then
    update replace $ti/@script with $val
 else 
    update insert attribute script { $val }into  $ti

,for $t in $m//mods:namePart
 let $val := if ($t/@lang and $bib:l2c($t/@lang)) then $bib:l2c($t/@lang) else ()
 , $ti := $t
 return
 if ($val) then
    update replace $ti/@lang with $val
 else ()
, if (contains($m//mods:note, "mlzsync")) then
  let $t := $m//mods:note[contains(., "mlzsync")]
  , $r := bib:process-jurism-map($t)
  return ()
  ()
else ()

,if ($m//mods:subject/mods:topic) then
  for $t in $m//mods:topic
  let $se := <topic xmlns="http://www.loc.gov/mods/v3" xmlns:tls="http://hxwd.org/ns/1.0" tls:sort="{lower-case(normalize-space($t))}">{normalize-space($t)}</topic>
  return 
  update replace $t with $se
 
 else
 for $n in $m//mods:note[@type='topics']
  let $s := for $t in tokenize($n, ";")
       let $se := <topic xmlns="http://www.loc.gov/mods/v3" xmlns:tls="http://hxwd.org/ns/1.0" tls:sort="{lower-case(normalize-space($t))}">{normalize-space($t)}</topic>
      return
      update insert <subject xmlns="http://www.loc.gov/mods/v3" xmlns:tls="http://hxwd.org/ns/1.0">{$se}</subject> into $m
  return
  update delete $n
, update insert <note  xmlns="http://www.loc.gov/mods/v3" type="ref-usage">{$usage}</note> into $m/mods:mods  
 )   
return "OK"
};


  (: $map is a map of the multilingual fields, like 
  {
  "multicreators" : {
    "0" : {
      "_key" : {
        "ja-Latn-alalc97" : {
          "firstName" : "Atsushi",
          "lastName" : "Ibuki"
        }
      },
      "main" : "ja"
    }
  }
}
  we now need to go through the bib record and update the items.  // the above is for $item := "UMIR7FX8", 「戒律」から「清規」へ--北宗の禪律一致とその克服としての清規の誕生 (戒律と倫理)
  :)


declare function bib:process-jurism-map($t as node()){
let $map := parse-json(substring(substring-after(substring-before($t, tokenize($t, "\}")[last()]), "mlzsync"), 7))
, $mods := $t/ancestor::mods:mods
return 
for $k in map:keys($map)
 return
 switch($k)
 case "multicreators" return ()
 
 default return ()
};


declare function bib:mods2map($n as node()*){

};

(: form input elements need to have a 'name' attribute for the jquery serialize() function to work  CW 2023-04-20 :)

declare function bib:new-entry-dialog($map as map(*)){
 let $uuid :=  if (string-length($map?uuid) > 0) then $map?uuid else "uuid-" || util:uuid()
   , $mods := collection($config:tls-data-root||"/bibliography")//mods:mods[@ID=$uuid]
   , $lang := if ($mods//mods:languageTerm[@type="code"]) then $mods//mods:languageTerm[@type="code"]/text() else 
       if ($mods//mods:titleInfo/@lang) then $mods//mods:titleInfo/@lang else "chi"
   , $rt := if ($mods//mods:roleTerm) then $mods//mods:roleTerm else <roleTerm xmlns="http://www.loc.gov/mods/v3"></roleTerm>
   , $mt := if ($mods//mods:topic) then $mods//mods:topic else <topic xmlns="http://www.loc.gov/mods/v3"></topic>
   , $genre := if (string-length($mods//mods:genre/text()) > 0) then $mods//mods:genre/text() else "book" 
   , $name := ""
   , $def := ""
   , $textid := if (string-length($map?textid)>0) then $map?textid else $mods//mods:note[@type='source-reference-id']/text()
   return
   <div id="new-entry-dialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog modal-lg" role="document">
        <form id="new-entry-form">
        <div class="modal-content">
            <div class="modal-header"><h5><span>{if ($mods) then "Edit" else "Add new"}</span> bibliographic item {if (string-length($textid) > 0) then <span>for <span class="font-weight-bold">{lu:get-title($textid)}</span></span> else <span class="font-weight-bold">{$mods//mods:note[@type='bibliographic-reference']/text()}</span>}</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close" title="Close">x</button>
            </div>
            <div class="modal-body">
            <div class="form-row">
              <div id="select-lang-group" class="form-group col-md-4">
              <input type="hidden" name="ref-key" value="{$mods//mods:note[@type='bibliographic-reference']/text()}"/>
              <input type="hidden" name="ref-usage" value="{$mods//mods:note[@type='ref-usage']/text()}"/>
              <input type="hidden" name="inf-basis" value="{$mods//mods:note[@type='information-basis']/text()}"/>
              <input type="hidden" name="textid" value="{$textid}"/>
                <label for="select-lang" class="font-weight-bold">Language: </label>
                 <select class="form-control" name="select-lang">
                  {for $l in map:keys($bib:c2l)
                    order by $l
                    return
                    if ($l = $lang) then
                    <option value="{$l}" selected="true">{$bib:c2l($l)}</option>
                    else
                    <option value="{$l}">{$bib:c2l($l)}</option>
                   } 
                 </select>                 
              </div>
              <div id="select-lang-group" class="form-group col-md-4">
                <label for="select-lang" class="font-weight-bold">Item type: </label>
                 <select id="select-genre" class="form-control" name="select-genre" onchange="bib_genre_change()">
                  {for $l in map:keys($bib:genre)
                    order by $l
                    return
                    if ($genre = $l) then
                    <option value="{$l}" selected="true">{$bib:genre($l)}</option>
                    else
                    <option value="{$l}">{$bib:genre($l)}</option>
                   } 
                 </select>
              </div>
             <div class="col-md-4">
                <label for="select-lang" class="font-weight-bold">Publication date:</label>
                 <input name="pub-date" class="form-control" required="true" value="{$mods//mods:date|$mods//mods:dateIssued}"></input>
              </div>

            </div>
              <h6  class="font-weight-bold">Responsible persons</h6>
              {for $rg at $pos in $rt
               let $n:= $rg/ancestor::mods:name
              return
             <div class="form-row" id="role-group-{$pos}">
              <div class="form-group col-md-2">
               <small class="text-muted">Role<br/>　</small>                 
                 <select class="form-control" name="select-role-{$pos}">
                  {for $l in map:keys($bib:roleterms)
                    let $r := lower-case($bib:roleterms($l))
                    order by $l
                    return
                    if ($r = $rg) then
                    <option value="{$l}" selected="true">{$bib:roleterms($l)}</option>
                    else
                    <option value="{$l}">{$bib:roleterms($l)}</option>
                   } 
                 </select>
              </div>
              <div  class="col-md-2">
                 <small class="text-muted">Family Name (transcribed)</small>
                 <input name="fam-name-latn-{$pos}" class="form-control" value="{$n//mods:namePart[@type='family' and @script='Latn']}"></input>
              </div>
              <div class="col-md-2">
                 <small class="text-muted">Given Name (transcribed)</small>
                 <input name="giv-name-latn-{$pos}" class="form-control" value="{$n//mods:namePart[@type='given' and @script='Latn']}"></input>
              </div>
              <div  class="col-md-2">
                 <small class="text-muted">Family Name (characters)</small>
                 <input name="fam-name-hant-{$pos}" class="form-control"  value="{$n//mods:namePart[@type='family' and @script='Hant']}"></input>
              </div>
              <div  class="col-md-2">
                 <small class="text-muted">Given Name (characters)</small>
                 <input name="giv-name-hant-{$pos}" class="form-control"  value="{$n//mods:namePart[@type='given' and @script='Hant']}"></input>
              </div>
              <div  class="col-md-2">
              {if ($pos > 1) then (<span id="rem-line-{$pos}" onclick="bib_remove_line('role-group-{$pos}')">Remove this line</span>,<br/>) else ()}
              {if (count($rt) = $pos) then 
                (<br/>,<span id="add-line-{$pos}" onclick="bib_add_new_line({$pos + 1}, 'role-group-{$pos}')">Add new line</span>) else ()}
              </div>
              <hr/>
              </div>
               }
            <h6  class="font-weight-bold">Title</h6>   
           <div class="form-row">
              <div id="input-resp-group" class="col-md-6">
                 <small class="text-muted">Title (transcribed)</small>
                 <input name="title-latn" class="form-control"  value="{$mods/mods:titleInfo[@script='Latn'  and @lang='chi']/mods:title/text()}"></input>
              </div>
              <div id="input-resp-group" class="col-md-6">
                 <small class="text-muted">Title (characters)</small>
                 <input name="title-hant" class="form-control"  value="{$mods/mods:titleInfo[@script='Hant']/mods:title/text()}"></input>
              </div>
           </div>     
           <div class="form-row">
              <div id="input-resp-group" class="col-md-12">
                 <small class="text-muted">Title (translated or original)</small>
                 <input name="title-eng" class="form-control"  value="{$mods/mods:titleInfo[not(@lang='chi')]/mods:title/text()}{
                 if ($mods/mods:titleInfo[not(@lang='chi')]/mods:subTitle) then (' - ' || $mods/mods:titleInfo[not(@lang='chi')]/mods:subTitle/text()) else ()}"></input>
              </div>
            </div>
            <h6  class="font-weight-bold">Details</h6>
            <div class="form-row">
              <!-- not article -->
              <div class="col-md-3 book" style="{if ($genre='article') then 'display:none' else ''}">
               <small class="text-muted">Publisher (transcribed)</small>                 
                 <input name="book-pub-latn" class="form-control" value="{$mods/mods:originInfo/mods:publisher[not(@script='Hant')]}"></input>
              </div>
              <div class="col-md-2 book" style="{if ($genre='article') then 'display:none' else ''}">
               <small class="text-muted">Publ. (characters)</small>                 
                 <input name="book-pub-hant" class="form-control"  value="{$mods/mods:originInfo/mods:publisher[@script='Hant']}"></input>
              </div>
              <div class="col-md-3 book" style="{if ($genre='article') then 'display:none' else ''}">
               <small class="text-muted">Place (transcribed)</small>                 
                 <input name="book-place-latn" class="form-control"  value="{$mods/mods:originInfo//mods:placeTerm[not(@script='Hant')]}"></input>
              </div>
              <div class="col-md-2 book" style="{if ($genre='article') then 'display:none' else ''}">
               <small class="text-muted">Place (characters)</small>                 
                 <input name="book-place-hant" class="form-control" value="{$mods/mods:originInfo//mods:placeTerm[@script='Hant']}"></input>
              </div>
              
              <!-- article -->
              <div class="col-md-3 article" style="{if (not($genre='article')) then 'display:none' else ''}">
               <small class="text-muted">Publication (transcribed)</small>                 
                 <input name="art-latn" class="form-control"  value="{$mods//mods:relatedItem/mods:titleInfo[@script='Latn']/mods:title}"></input>
              </div>
              <div class="col-md-3 article" style="{if (not($genre='article')) then 'display:none' else ''}">
               <small class="text-muted">Publication (characters)</small>                 
                 <input name="art-hant" class="form-control"  value="{$mods//mods:relatedItem/mods:titleInfo[@script='Hant']/mods:title}"></input>
              </div>
              <div class="col-md-2 article" style="{if (not($genre='article')) then 'display:none' else ''}">
               <small class="text-muted">Volume</small>                 
                 <input name="art-vol" class="form-control"  value="{$mods//mods:relatedItem//mods:detail[@type='volume']}"></input>
              </div>
              <div class="col-md-2">
               <small class="text-muted">Pages</small>                 
                 <input name="art-page" class="form-control" value="{$mods//mods:relatedItem/mods:extent[@unit='pages']}"></input>
              </div>
            </div>
            {if (string-length($textid) > 0) then
             let $xmltext := collection($config:tls-texts)//tei:TEI[@xml:id=$textid]
            return 
            (<h6  class="font-weight-bold">Textual source and witnesses</h6>,
            <div id="wit-row" class="form-row">
             {if ($xmltext//tei:sourceDesc) then 
              <div class="col-md-4" id="src-field">
               <small class="text-muted" title="The source is defined in the associated text file">Source:</small>    
               <span >{string-join($xmltext//tei:sourceDesc//tei:title/text(), '　')}</span>
              </div>
             else ()}
             {for $t at $pos in $xmltext//tei:witness 
              let $r := $t//tei:ref[@target="#" || $uuid]
             return
              <div class="col-md-2" id="wit-field-{$pos}">
               <small class="{if ($r) then 'font-weight-bold' else 'text-muted'}">Witness{$pos}:</small>    
               <span class="{if ($r) then 'font-weight-bold' else ()}" title="{data($t/@xml:id)}">{$t/text()}</span>
              </div>
             }
              <!-- <div id="new-src-div" class="col-md-4">
               <small class="text-muted">Set this item as textual source</small>                 
                 <input name="new-src" class="form-control" value=""></input>
              </div> -->
              {if (not($xmltext//tei:witness//tei:ref[@target="#" || $uuid])) then
              <div id="new-wit-div" class="col-md-4">
               <small class="text-muted">Add sigle for this item as textual witness</small>                 
                 <input name="new-wit" class="form-control" value=""></input>
              </div>
              else ()
              }
            </div>
            ) else ()}
            <h6  class="font-weight-bold">Topics</h6>
            <div id="topic-row" class="form-row">
             {for $t at $pos in $mt 
             return
              <div class="col-md-3" id="topic-field-{$pos}">
               <small class="text-muted"></small>                 
                 <input name="topic-{$pos}" class="form-control" value="{$t/text()}"></input>
              </div>
             }
             <div id="new-topic" class="col-md-2"><span onclick="bib_add_topic({count($mt) + 1}, 'topic-field-{count($mt)}')">Add topic</span></div>
            </div>
            <h6  class="font-weight-bold">Notes</h6>
            <div class="form-row">
              <div id="input-notes-group" class="col-md-12">
                    <textarea name="input-notes" class="form-control">{$mods//mods:note[@type='general']/text()}</textarea>                   
              </div>
            </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" onclick="save_entry('{$uuid}')">Save</button>
           </div>
         </div>
         </form>
     </div>
     
</div>

};

declare function bib:save-entry($map as map(*)){
let $rt := for $l in map:keys($map) 
   where starts-with($l, "select-role")
   order by $l
   return $l
, $tt := for $l in map:keys($map)
    where starts-with($l, "topic-")
    order by $l
    return $l
, $lang := $map?select-lang   
, $user := sm:id()//sm:real/sm:username/text()
, $genre := if (string-length($map?select-genre) > 0) then $map?select-genre else "book"
, $date := $map?pub-date
, $ref := if (string-length($map?ref-key) > 0) then $map?ref-key else bib:make-bibref($map?fam-name-latn-1, $map?giv-name-latn-1, $date)
, $textid := $map?textid
, $wit := if (string-length($map?new-wit) > 0) then 
   let $ws := collection($config:tls-texts)//tei:TEI[@xml:id=$textid]//tei:witness
   return if ($ws//tei:ref[@target="#" || $map?uuid]) then () else
    let $w := <witness xmlns="http://www.tei-c.org/ns/1.0" xml:id="wit-{count($ws) + 1}">【{$map?new-wit}】<bibl><ref target="#{$map?uuid}">{$ref}</ref></bibl></witness>
   , $lw := tlslib:getlistwit($textid)
    return 
      update insert $w into $lw
   else ()
, $src := if(string-length($map?new-src) > 0) then
  (: TODO set the source 
   this would mean to replace / update the sourceDesc
  :)
  () else ()
let $mods := <mods xmlns="http://www.loc.gov/mods/v3" xmlns:tls="http://hxwd.org/ns/1.0" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ID="{$map?uuid}" version="3.6" xsi:schemaLocation="http://www.loc.gov/mods/v3 https://www.loc.gov/standards/mods/v3/mods.xsd" resp="{$user}" modified="{current-dateTime()}">
<language>
<languageTerm type="text">{$bib:c2l?($lang)}</languageTerm>
<languageTerm type="code" authority="iso639-2b">{$lang}</languageTerm>
</language>

{for $r in $rt return
let $pos := tokenize($r, "-")[last()]
, $fnl := $map?("fam-name-latn-"||$pos)
, $fnc := $map?("fam-name-hant-"||$pos)
where string-length($fnc || $fnl) > 0
return
<name type="personal">
{if ($map?("fam-name-latn-"||$pos)) then
<namePart type="family" lang="{$lang}" transliteration="chinese/ala-lc" script="Latn">{$fnl}</namePart> else ()}
{if ($map?("giv-name-latn-"||$pos)) then
<namePart type="given" lang="{$lang}" transliteration="chinese/ala-lc" script="Latn">{$map?("giv-name-latn-"||$pos)}</namePart> else ()}
{if ($map?("fam-name-hant-"||$pos)) then
<namePart type="family" lang="{$lang}" script="Hant">{$fnc}</namePart> else ()}
{if ($map?("giv-name-hant-"||$pos)) then
<namePart type="given" lang="{$lang}" script="Hant">{$map?("giv-name-hant-"||$pos)}</namePart> else ()}
<role>
<roleTerm type="text">{$bib:roleterms?($map?($r))}</roleTerm>
</role>
</name>
}
{if (string-length($map?title-hant) > 0) then
<titleInfo lang="{$lang}" script="Hant">
<title>{$map?title-hant}</title>
</titleInfo> else ()}
{if (string-length($map?title-latn) > 0) then
<titleInfo transliteration="chinese/ala-lc" lang="{$lang}" script="Latn">
<title>{$map?title-latn}</title>
</titleInfo> else ()}
{if (string-length($map?title-eng) > 0) then
<titleInfo lang="{$lang}" script="Latn">
<title>{$map?title-eng}</title>
</titleInfo> else ()}
{if ($genre = ("article", "chapter")) then 
<relatedItem type="host">
<titleInfo lang="{$lang}" script="Hant">
<title>{$map?art-hant}</title>
</titleInfo>
<titleInfo lang="{$lang}" script="Latn">
<title>{$map?art-latn}</title>
</titleInfo>
<originInfo>
<issuance>continuing</issuance>
</originInfo>
<part>
<detail type="volume">
<number>{$map?art-vol}</number>
</detail>
<extent unit="pages">
<list>{$map?art-page}</list>
</extent>
<date encoding="w3cdtf">{$date}</date>
        </part>
</relatedItem>
else 
(
<originInfo>
{if (string-length($map?book-place-hant) > 0) then
<place>
<placeTerm lang="{$lang}" script="Hant">{$map?book-place-hant}</placeTerm>
</place> else ()}
{if (string-length($map?book-place-latn) > 0) then
<place>
<placeTerm lang="{$lang}" script="Latn">{$map?book-place-latn}</placeTerm>
</place>else ()}
{if (string-length($map?book-pub-hant) > 0) then
<publisher lang="{$lang}" script="Latn">{$map?book-pub-hant}</publisher> else ()}
{if (string-length($map?book-pub-latn) > 0) then
<publisher lang="{$lang}" script="Latn">{$map?book-pub-latn}</publisher> else ()}
<dateIssued encoding="w3cdtf">{$date}</dateIssued>
<issuance>monographic</issuance>
</originInfo>,
<part>
<extent unit="pages">
<list>{$map?art-page}</list>
</extent>
</part>
)
}
{for $t in $tt
return
if (string-length($map?($t)) > 0) then 
<subject xmlns:tls="http://hxwd.org/ns/1.0"><topic tls:sort="{lower-case($map?($t))}">{$map?($t)}</topic></subject>
else ()
}
<genre authority="marcgt">{$genre}</genre>
<typeOfResource>text</typeOfResource>
<note type="bibliographic-reference">{$ref}</note>
{if (string-length($map?input-notes) > 0) then
<note type="general">{$map?input-notes}</note> else ()}
{if (string-length($map?ref-usage) > 0) then 
<note type="ref-usage">{$map?ref-usage}</note>
else ()}
<note type="information-basis">{string-join(distinct-values(($user, tokenize($map?inf-basis, ', '))), ', ')}</note>
</mods>
, $oldmods := collection($config:tls-data-root||"/bibliography")//mods:mods[@ID=$map?uuid]
, $saveold := if ($oldmods) then  
  let $cryptfile := bib:get-mods-crypt-file()
  , $md := (update insert attribute modified {current-dateTime()} into $oldmods,
    update insert attribute resp {$user} into $oldmods)
  return 
   update insert $oldmods following $cryptfile//mods:mods[1]
  else ()
, $save := xmldb:store(bib:uuid2path($map?uuid), $map?uuid || ".xml", $mods)  
return
$mods
};

declare function bib:uuid2path($uuid as xs:string) as xs:string{
let $f := substring(substring-after($uuid, "uuid-"), 1, 1)
return
  $config:tls-data-root || "/bibliography/" || $f || "/" 
};

declare function bib:get-ref-title($uuid){
let $biblio := collection($config:tls-data-root || "/bibliography")
,$t:=$biblio//mods:mods[@ID=$uuid]
return ($t//mods:title/text() )
};

declare function bib:get-bib-ref($uuid){
let $biblio := collection($config:tls-data-root || "/bibliography")
,$t:=$biblio//mods:mods[@ID=$uuid]
return ($t//mods:note[@type="bibliographic-reference"]/text() )
};


(: TODO: Avoid duplicated keys :)
declare function bib:make-bibref($fam as xs:string, $giv as xs:string, $date as xs:string) as xs:string{
let $refkey := $fam || " " || $giv || " " || $date
return $refkey
};


declare function bib:get-mods-crypt-file(){
  let $cm := substring(string(current-date()), 1, 7),
  $type := "mods",
  $doc-name := if (string-length($type) > 0 ) then $type || "-" || $cm || ".xml" else $cm || ".xml",
  $doc-path :=  $config:tls-data-root || "/vault/crypt/" || $doc-name,
  $doc := if (not(doc-available($doc-path))) then 
    let $res := 
    xmldb:store($config:tls-data-root || "/vault/crypt/" , $doc-name, 
    <modsCollection xmlns="http://www.loc.gov/mods/v3" xml:id="del-{$type}-{$cm}-crypt"></modsCollection>
)
    return
    (sm:chmod(xs:anyURI($res), "rw-rw-rw-"),
     sm:chgrp(xs:anyURI($res), "tls-user"),
(:     sm:chown(xs:anyURI($res), "tls"),:)
    doc($res)
    )
    else
    doc($doc-path)
  return $doc
};


declare function bib:display-bibl($bibl as node()){
<li><span class="font-weight-bold">{$bibl/tei:title/text()}</span>
(<span><a class="badge" href="bibliography.html?uuid={replace($bibl/tei:ref/@target, '#', '')}">{$bibl/tei:ref}</a></span>)
<span>p. {$bibl/tei:biblScope}</span>
{for $p in $bibl/tei:note/tei:p return
<p>{$p/text()}</p>}

</li>
};

