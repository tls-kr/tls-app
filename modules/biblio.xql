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
<li>{bib:biblio-short($u/ancestor::mods:mods, "title")}</li>
}</ul> 
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
    {$topusage}
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
 bib:biblio-short($b/ancestor::mods:mods, $mode)
}</div>

else if ($mode eq "title") then 
<div>{
for $b in $tit
 where starts-with($b, $filterString)
 order by $b
 return
 bib:biblio-short($b/ancestor::mods:mods, $mode)
}</div>
else if ($mode eq "topic") then 
<div>{
for $b in $top
 where starts-with($b, $filterString)
 order by $b
 return
 bib:biblio-short($b/ancestor::mods:mods, $mode)
}</div>
else 
()
else ()}
</div>

</div>
};

(: <span>{count(collection($config:tls-data-root)//tei:ref[@target="#"||$m/@ID] )}</span> :) 

declare function bib:biblio-short($m as node(), $mode as xs:string) {
let $user := sm:id()//sm:real/sm:username/text()
, $usergroups := sm:get-user-groups($user)
return

<li><span class="font-weight-bold">{string-join(for $n in $m//mods:name return bib:display-author($n), '; ')}</span>　<a href="bibliography.html?uuid={$m/@ID}">{string-join($m//mods:title/text(), " ")}, {$m//mods:dateIssued/text()}　</a>   
<span class="badge badge-light">{$m//mods:note[@type='ref-usage']}</span>
  {if (contains($usergroups, "tls-editor" )) then 
    tlslib:format-button("delete_swl('bib', '" || data($m/@ID) || "')", "Immediately delete this reference", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()}{if ($mode eq "topic") then 
   <p class="text-muted">{string-join(for $t in $m//mods:topic return $t, "; ")}</p> else
   <p class="text-muted">{$m/mods:note[@type='general']/text()}</p>}</li>
};

declare function bib:display-mods($uuid as xs:string){
let $biblio := collection($config:tls-data-root || "/bibliography")
,$m:=$biblio//mods:mods[@ID=$uuid]
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
<div class="col-sm-5">(place){$m//mods:place/mods:placeTerm/text()}: (publisher){$m//mods:publisher/text()}, {$m//mods:dateIssued/text()}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Identifier</span></div>
<div class="col-sm-5">{$m/mods:note[@type="bibliographic-reference"]/text()}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Topics</span></div>
<div class="col-sm-5">{for $t in tokenize($m/mods:note[@type='topics'], ';') return <a  class="badge badge-pill badge-light" href="browse.html?type=biblio&amp;filter={$t}&amp;mode=topic">{$t}</a>}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Comments</span></div>
<div class="col-sm-5">{$m/mods:note[@type='general']/text()}</div>
</div>
<div class="row">
<div class="col-sm-2"/>
<div class="col-sm-2"><span class="font-weight-bold float-right">Electronic Version</span></div>
<div class="col-sm-5"><a class="btn badge badge-light" target="GXDS" style="background-color:paleturquoise" href="https://archive.org/search.php?query={string-join(for $n in $m/mods:name return ($n/mods:namePart[@type='given'])[1] || " " || ($n/mods:namePart[@type='family'])[1], ', ')}%20AND%20mediatype%3A%28texts%29 ">Find on Internet Archive</a> <button class="btn badge badge-warning" type="button" onclick="add_ref('')">Add direct link to this work</button></div>
</div>
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


declare function bib:display-author-role($n as node()*){
  <span>{if (exists($n/mods:role)) then "(" || $n/mods:role/mods:roleTerm ||"): " else ()} {bib:display-author($n)}</span>
};

declare function bib:display-author($n as node()*){
  <span>{for $s in ("Latn", "Hant")
   let $np :=  $n/mods:namePart[@type='family' and @script=$s]
  return
   ($np
   ,if ($np[@script=$s] and not($np/@lang = ("chi", "jpn"))) then ", " else " ",
   $np/preceding-sibling::mods:namePart[@type='given' and @script=$s] || " ") } </span>
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
<div><h3>Bibliography search results</h3>
<p class="font-weight-bold">Searched for <span class="mark">{$query}</span>, found {count($qr)} entries.</p>
<p>Please bear in mind that the search is case sensitive. It looks for entries, where the search term appears in <span class="font-weight-bold">names</span> (unfortunately, family name and first name can not be searched together), <span class="font-weight-bold">titles</span>, or <span class="font-weight-bold">notes</span>. Multiple search terms (separated by the space character) are interpreted as "OR" connected. You can also <a href="browse.html?type=biblio">browse</a> the bibliography, or <button class="btn badge badge-warning" type="button" onclick="add_ref('')">add</button> a new reference.</p>
<ul>{
for $q in $qr 
let $t := lower-case(normalize-space(($q//mods:title)[1]))
order by $t
return
bib:biblio-short($q, "title")
}</ul></div>
};


declare function bib:fix-mods($m as node()){
(:let $m := collection($config:tls-data-root||"/bibliography")//mods:mods[@ID=$uuid]:)
let $usage := count(collection($config:tls-data-root)//tei:ref[@target="#"||$m/@ID] )
let $fix := (
for $t in $m//mods:title
 let $val := if (tlslib:mostly-kanji($t)) then "Hant" else "Latn"
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
 let $val := if (tlslib:mostly-kanji($t)) then "Hant" else "Latn"
 , $ti := $t
 return
 if ($ti/@script) then
    update replace $ti/@script with $val
 else 
    update insert attribute script { $val }into  $ti

,for $t in $m//mods:namePart
 let $val := if ($bib:l2c($t/@lang)) then $bib:l2c($t/@lang) else ()
 , $ti := $t
 return
 if ($val) then
    update replace $ti/@lang with $val
 else ()
    
,for $n in $m//mods:note[@type='topics']
  let $s := for $t in tokenize($n, ";")
       let $se := <topic xmlns="http://www.loc.gov/mods/v3" xmlns:tls="http://hxwd.org/ns/1.0" tls:sort="{lower-case(normalize-space($t))}">{normalize-space($t)}</topic>
      return
      update insert <subject xmlns="http://www.loc.gov/mods/v3" xmlns:tls="http://hxwd.org/ns/1.0">{$se}</subject> into $m
  return
  update delete $n
, update insert <note  xmlns="http://www.loc.gov/mods/v3" type="ref-usage">{$usage}</note> into $m  
 )   
return "OK"
};