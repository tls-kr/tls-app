xquery version "3.1";

module namespace wd="http://hxwd.org/wikidata"; 

import module namespace http="http://expath.org/ns/http-client";
import module namespace config="http://hxwd.org/config" at "config.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare variable $wd:wikidata-api := "https://www.wikidata.org/w/api.php?format=xml&amp;action=query&amp;list=search&amp;srlimit=100&amp;srprop=titlesnippet%7Csnippet&amp;uselang=zh&amp;srsearch=";

(: get data for entities with https://www.wikidata.org/w/api.php?action=help&modules=wbgetentities :)

declare variable $wd:qtypes := map{
  "Q7725634" : "Literary Work",
  "Q5" : "Human",
  "P497" : "CBDB",
  "P6772" : "Buddhist Author Authority Database ID",
  "P4517" : "ctext work ID"
};
declare variable $wd:ptypes := map{
  "P497" : "Q5",
  "P6772" : "Q5",
  "P4517" : "Q7725634"
};


declare function wd:search($map){
let $q := encode-for-uri($map?query)
, $type := if ($map?type = ('no-selection', 'undefined')) then "" else "%20" || $map?type
let $res :=  try {
            http:send-request(<http:request http-version="1.1" href="{xs:anyURI($wd:wikidata-api||$q||$type)}" method="get">
                                <http:header name="Connection" value="close"/>
                              </http:request>)} 
             catch * {"Illegal search term.  Please try again"}
, $s := <api batchcomplete="">
    <query>
        <searchinfo totalhits="2"/>
        <search>
            <p ns="0" title="Q704075" pageid="662383" snippet="Chinese scholar and philologist (1623-1716)" titlesnippet="&lt;span class=&#34;searchmatch&#34;&gt;毛&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;奇&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;龄&lt;/span&gt;"/>
            <p ns="0" title="Q59205807" pageid="59112037" snippet="" titlesnippet="行香子·即事 (&lt;span class=&#34;searchmatch&#34;&gt;毛&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;奇&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;齡&lt;/span&gt;)"/>
        </search>
    </query>
</api>
return
(: , $r := parse-xml("<r>"||data($c/@titlesnippet)||"</r>")  :)
if (starts-with($res, "Ill")) then $res 
else
<div>
{if (string-length($map?qitem) = 0 or $map?target='wikidata' or $map?context='concept') then () else 
<div id="wd-recent"><h3>Recent Qitems:</h3>
<ul>{for $i in wd:recent-qitems(map{"n" : 3}) 
let $title := substring-after($i/ancestor::tei:TEI//tei:titleStmt/tei:title/text(), '::')
return 
(: <item ana="{$map?qitem}" modified="{current-dateTime()}" resp="#{$user}" xmlns="http://www.tei-c.org/ns/1.0" type="{$type}" subtype="{$context}"><ref target="#{$map?id}">{$map?locallabel}</ref></item> :)
<li><a target="dict" title="Open page in WikiData (External link)" style="background-color:paleturquoise" href="https://www.wikidata.org/wiki/{$i/@ana}">{data($i/@ana)}</a> / <span class="text-muted">{string-join(for $r in $i/tei:ref return substring($r/@target, 2) || " :" || $r/text(), ';')}</span>
    <span class="ml-2"><button class="btn badge badge-primary ml-2" title="Link this item with this title" type="button" onclick="save_qitem('{data($i/@ana)}', '{$map?context}', '{$map?id}', '{$title}')">
           Use
      </button></span> </li>
}
</ul>
</div>
}
<div>
<h3>Results from Wikidata for {util:unescape-uri($q, 'UTF-8')}, {data($res[2]//searchinfo/@totalhits)} hits</h3>
<p class="text-muted">Showing up to 100 results here. <a style="background-color:paleturquoise" target="dict" title="Search for {util:unescape-uri($q, 'UTF-8')} on WikiData (External link)" href="https://www.wikidata.org/w/index.php?search={$q}&amp;title=Special%3ASearch&amp;ns0=1&amp;ns120=1">See all</a></p>
<ul>{
for $c in $res[2]//p
   let $ts := parse-xml("<span>" || $c/@titlesnippet || "</span>")
   , $t := data($c/@snippet)
   return <li><a target="dict" title="Open page in WikiData (External link)" style="background-color:paleturquoise" href="https://www.wikidata.org/wiki/{$c/@title}">{data($c/@title)}</a> / <span class="text-muted">{$t}</span> {$ts}
   {if ($map?context and ("tls-user" = sm:id()//sm:group) ) then 
    <span class="ml-2"><button class="btn badge badge-primary ml-2" title="Link this item with this title" type="button" onclick="save_qitem('{$c/@title}', '{$map?context}', '{$map?id}', '{$t}$${$ts}')">
           Use
      </button></span> 
     else ()}
   </li>
}</ul>
</div>
</div>
};



(: this function needs to construct the whole dialog for the search results :)
(: TODO add search box to refine query if necessary :)
declare function wd:quick-search-form($context as xs:string){
<div id="wd-form" class="card ann-dialog overflow-auto">
 <div class="card-body">
    <h5 class="card-title"><span id="wd-title">Searching Wikidata</span>
    <button type="button" class="close" onclick="hide_form('wd-form')" aria-label="Close" title="Close"><img class="icon" src="resources/icons/open-iconic-master/svg/circle-x.svg"/></button>
    </h5>
     <div class="form-row">
       <div class="col-md-3"><strong class="ml-2"><span id="wd-query-span"></span></strong><br/><span id="wd-qitem" class="text-muted ml-2"></span>
       </div>
       <div  class="col-md-4">
           <input id="wd-search" class="form-control" value=""></input>
       </div>    
       <div  class="col-md-1">
           <button id="wd-search-again" class="btn badge btn-outline-success" onclick="wikidata_search_again()">
                <img class="icon" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
           </button>
       </div>
       <div  class="col-md-1">
         <span class="text-muted"><small><strong>Type:</strong></small></span>
       </div>
       <div class="col-md-3">
             <select class="form-control input-sm" id="wd-stype">
             <option value="no-selection" selected="true">No selection</option>
             {for $m in map:keys($wd:qtypes) return
             <option value="{$m}">{map:get($wd:qtypes, $m)}</option>}
             </select>
        </div>
     </div>
    <p><span id="wd-detail"></span></p>
    <p>
     </p>
    <ul id="wd-search-results" class="list-unstyled"></ul>
</div>
</div>
};

(: this is a stub.  We want to add more info from wikidata here later :)

declare function wd:save-qitem($map as map(*)){
let $qfile := wd:get-qitem-file($map)
, $user := sm:id()//sm:real/sm:username/text()
, $context := if (contains($map?context, ":change")) then
            (wd:remove-qitem($map?oldqitem, $map?id), substring-before($map?context, ":change")) else
            $map?context
, $type := if ($map?type) then 
             if (starts-with($map?type, "Q")) then 
                $map?type 
             else map:get($wd:ptypes, $map?type) 
           else "untyped"
, $qnode := <item ana="{$map?qitem}" modified="{current-dateTime()}" resp="#{$user}" xmlns="http://www.tei-c.org/ns/1.0" type="{$type}" subtype="{$context}"><ref target="#{$map?id}">{$map?locallabel}</ref></item>
return update insert $qnode into $qfile//tei:list[@xml:id=$map?qitem||"-related"]
};

declare function wd:get-qitem-file($map as map(*)){
  let $cm := substring(string(current-date()), 1, 7),
  $doc-name := $map?qitem || ".xml",
  $doc-path :=  $config:tls-data-root || "/qitems/" || $doc-name,
  $doc := if (not(doc-available($doc-path))) then 
    let $res := 
    xmldb:store($config:tls-data-root || "/qitems/" , $doc-name, 
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$map?qitem}">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>{$map?qitem}::{$map?label}</title>
         </titleStmt>
         <publicationStmt>
            <ab>published electronically as part of the TLS project at https://hxwd.org</ab>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date>.</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div type="related-items"><head>Associated Items</head>
         <list xml:id="{$map?qitem}-related">
         </list>
      </div>
      </body>
  </text>
</TEI>)
    return
    (sm:chmod(xs:anyURI($res), "rw-rw-r--"),
     sm:chgrp(xs:anyURI($res), "tls-user"),
(:     sm:chown(xs:anyURI($res), "tls"),:)
    doc($res)
    )
    else
    doc($doc-path)
  return $doc
};

(: if this is the only reference, we remove the qitem :)
declare function wd:remove-qitem($qitem as xs:string, $ref as xs:string){
  let $qcoll := $config:tls-data-root||"/qitems"
  , $qdoc := $qitem || ".xml"
  , $qitem := doc($qcoll || "/" || $qdoc)
  return
  if ($qitem) then 
    let $refs := $qitem//tei:ref
    return
    if (count($refs) = 1) then xmldb:remove($qcoll, $qdoc)
      else
        update delete $qitem//tei:ref[@target="#"||$ref]
  else
    "Qitem not found."
};

(: display links etc for the qitem referenced in qitem-ref :)
declare function wd:display-qitems($idref as xs:string, $context as xs:string, $label as xs:string){
  let  $qitems := collection($config:tls-data-root||"/qitems")//tei:ref[@target="#"||$idref]
  return
  if ($qitems) then
   for $q in $qitems
    let $qr := $q/ancestor::tei:TEI
      , $qlabel := tokenize($qr//tei:titleStmt/tei:title/text(), '\$\$')[last()]
    return
    (<span class="ml-2"><a  class="btn badge badge-light" target="dict" title="View {$qlabel} in Wikidata (External link)" style="background-color:paleturquoise" href="https://www.wikidata.org/wiki/{$qr/@xml:id}">{$qlabel}</a></span>,
       <span class="badge badge-secondary ml-2" onclick="do_wikidata_search('{$label}','{$context}:change', '{$idref}', '{$qr/@xml:id}')" title="Click here to change association of {$label} with {data($qr/@xmlid)}">WD</span>)             
  else 
       <span class="badge badge-info ml-2" onclick="do_wikidata_search('{$label}','{$context}', '{$idref}', '')" title="Click here to search for {$label} in WikiData">WD</span>             
           
};

declare function wd:recent-qitems($map as map(*)){
let $n := if ($map?n) then $map?n else 5
, $items := if ($map?context) then 
             collection($config:tls-data-root||"/qitems")//tei:item[@type=$map?context] 
            else
             collection($config:tls-data-root||"/qitems")//tei:item               
, $items-sorted := for $i in $items
  let $time := xs:dateTime($i/@modified)
  order by $time descending
  return $i
return subsequence($items-sorted, 1, $n)
};

declare function wd:stub($map as map(*)){
() 
};
