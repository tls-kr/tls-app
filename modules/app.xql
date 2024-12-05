xquery version "3.1";
(:~
: This module provides the functions that do more or less directly control
: the template driven Web presentation
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)
module namespace app="http://hxwd.org/app";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx="http://exist-db.org/tls";
declare namespace json = "http://www.json.org";
declare namespace ucd = "http://www.unicode.org/ns/2003/ucd/1.0";
declare namespace mf = "http://kanripo.org/ns/KRX/Manifest/1.0";

import module namespace templates="http://exist-db.org/xquery/templates" ;
(: 2022-11-16: update to new template library, also including lib, but not yet used :)
(:import module namespace templates="http://exist-db.org/xquery/html-templating";:)
(:import module namespace lib="http://exist-db.org/xquery/html-templating/lib";:)

import module namespace config="http://hxwd.org/config" at "config.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic"
    at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace krx="http://hxwd.org/krx-utils" at "krx-utils.xql";
import module namespace bib="http://hxwd.org/biblio" at "biblio.xql";
import module namespace wd="http://hxwd.org/wikidata" at "wikidata.xql"; 
import module namespace ly="http://hxwd.org/layout" at "layout.xql"; 
import module namespace log="http://hxwd.org/log" at "log.xql";
import module namespace src="http://hxwd.org/search" at "search.xql";
import module namespace sgn="http://hxwd.org/signup" at "signup.xql"; 
import module namespace tu="http://hxwd.org/utils" at "tlsutils.xql";

import module namespace lu="http://hxwd.org/lib/utils" at "lib/utils.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "lib/metadata.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "lib/render-html.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "lib/permissions.xqm";
import module namespace ltp="http://hxwd.org/lib/textpanel" at "lib/textpanel.xqm";
import module namespace lrv="http://hxwd.org/lib/review" at "lib/review.xqm";
import module namespace i18n="http://hxwd.org/lib/i18n" at "lib/i18n.xqm";
import module namespace ltx="http://hxwd.org/taxonomy" at "lib/taxonomy.xqm";
import module namespace lc="http://hxwd.org/concept" at "lib/concept.xqm";

import module namespace remote="http://hxwd.org/remote" at "lib/remote.xqm";

declare variable $app:log := $config:tls-log-collection || "/tlslib";

declare variable $app:SESSION := "tls:results";



(: start here :)
(:~
 : Get app logo. Value passed from repo-config.xml  
:)
declare
    %templates:wrap
function app:logo($node as node(), $model as map(*)) {
    if($config:get-config//repo:logo != '') then
        <img class="app-logo img-fluid" src="resources/images/{$config:get-config//repo:logo/text() }" title="{$config:app-title}"/>
    else ()
};

(:~
: This displays the title, both for regular pages (page.html) and textview pages (tv-page.html)
:)
declare
    %templates:wrap
function app:page-title($node as node()*, $model as map(*)) as xs:string
{ (: the html file accessed, without the extension :) 
 let $ts := 
 if ($model("textid")) then 
   $model("textid") || " : " || $model("title")
 else if ($model?concept = "unknown") then
   "漢學文典"
   else
   if (string-length($model?concept) > 0) then
   "Concept: " || $model("concept")
   else 
   upper-case($model?context)

(:,$context := substring-before(tokenize(request:get-uri(), "/")[last()], ".html"):)
return "TLS - " || $ts
};

declare function app:show-taxonomy($tax as xs:string) {
let $doc :=
  switch($tax)
  case "concept" return doc($config:tls-data-root || "/core/concept-taxonomy.xml")
  case "syn-func" return doc($config:tls-data-root || "/core/syntactic-functions-taxonomy.xml")
  default return ()
return
<div>
<h2>Taxonomy tree for {$config:lmap?($tax)}</h2>
{ltx:proc-taxonomy($doc//tei:taxonomy, $tax)}
</div>
 
};

(: display the taxonomy in HTML format :)

declare function app:doc-taxonomy(){
let $tax := doc($config:tls-texts||"/meta/taxonomy.xml")
return
<div class="row">
    <div class="col-md-2" ></div>
    <div class="col-md-6" >
    <h3>The genre categories</h3>
    <p>At different locations in the system, lists of results can be sliced into smaller result sets using certain pre-defined categories. For lack of better name, they will be called 'genre categories' here.  </p>
    <p>Currently, the following top-level genres are defined:
    <ul>{for $t in $tax//tei:taxonomy/tei:category return
    <li><a href="#{$t/@xml:id}--head"><span class="md2">{$t/tei:catDesc/text()}</span></a>　(<small class="md-2 text-muted">{data($t/@xml:id)}</small>)</li>
    }</ul>
    </p>
    <h3>Full view of the defined genre categories</h3>
    <div>
    <p>The internal codes are given in parentheses.</p>
    {for $t in $tax//tei:taxonomy/tei:category 
     let $cat := $t/@xml:id
     return
       src:facets-html($t, map{}, $cat, "", "open")}
    </div>
</div>
    <div class="col-md-2" ></div>
</div>
};

(:~
: Display the documentation. This is called from documentation.html
: @param $section gives the item of the submenu that has been selected
:)
declare
    %templates:wrap
function app:doc($node as node(), $model as map(*), $section as xs:string) {
switch($section)
 case "statistics" return app:stats()
 case "main-features" return doc(concat($config:app-root, "/documentation/main-features.html"))
 case "overview" return doc(concat($config:app-root, "/documentation/overview.html"))
 case "team" return doc(concat($config:app-root, "/documentation/team.html"))
 case "manual" return doc(concat($config:app-root, "/documentation/manual.html"))
 case "text-crit" return doc(concat($config:app-root, "/documentation/text-critical-editing.html"))
 case "taxonomy" return app:doc-taxonomy()
 default return (
 doc(concat($config:app-root, "/documentation/manual.html"))
 )
};

declare function app:jstree-script($node as node(), $model as map(*)){
if (tu:html-file() = ("char", "word")) then 
<script src="https://cdnjs.cloudflare.com/ajax/libs/jstree/3.2.1/jstree.min.js"/>
else 
if (tu:html-file() = ("search")) then
<script type="text/javascript" src="resources/scripts/krx.js"/>
else 
if (tu:html-file() = ("citations")) then
<script type="text/javascript" src="resources/scripts/tls-citations.js"/>
else ()
};
(:~
: 2020-02-26: this is not used anymore.  can go.
:)
declare function app:tls-summary($node as node(), $model as map(*)) {
(:let $tlsroot := $config:tls-data-root :)
<div>
{let $tlsroot := $config:tls-data-root
return
<p>
Dummy template {local-name($node), string($node), string($tlsroot), count(collection($tlsroot)//*:head)}
<table>
{for $a in collection($tlsroot)//tei:head
group by $key := $a/ancestor::tei:div/@type
order by $key
return
  <tr>
  <td>Key: {data($key)}</td>
  <td>Count: {count($a)}</td>
</tr>
}
</table>
</p>}
</div>
};

(: browse :)
(:~
 Called from browse.html 
 : @param $type "word" or "taxchar"
 : @param $filter  
:)
declare 
    %templates:wrap
function app:browse($node as node()*, $model as map(*), $type as xs:string?, $filter as xs:string?, $mode as xs:string?)
{
    session:create(),
    let $filterString := if (string-length($filter) > 0) then $filter else ""
    return
    if ($type = "word") then app:browse-word($type, $filterString)
    else if ($type = "tax") then app:show-taxonomy($mode)
    else if ($type = "welcome") then i18n:display(map{'id': 'browse'})
    else if ($type = "taxchar") then app:browse-char($type, $filterString)
    else if ($type = "taxword") then app:browse-word($type, $filterString)
    else if ($type = "biblio") then bib:browse-biblio($type, $filterString, $mode)
    else if ($type = "word-rel-type") then app:browse-word-rel($type, $filterString, $mode)
    else if (("concept", "syn-func", "sem-feat", "rhet-dev") = $type) then    
    let $hits :=  app:do-browse($type, $filterString)      
    let $store := session:set-attribute("tls-browse", $hits)
    return
   <div class="card">
    <div class="card-header" id="{$type}-card">
      <div class="row mb-0">
      <span class="col-3"><h4>{map:get($config:lmap, $type)}  {
      if ($type = ('concept', 'syn-func')) then (" / ", <a class="ml-2" href="browse.html?type=tax&amp;mode={$type}">Show tree</a>) else ()
      }</h4></span>&#160;
      <span class="col-3">
      <input class="form-control" id="myInput" type="text" placeholder="Type to filter..."/>
      </span>
      {if ($type = 'conceptxx') then 
      <button type="button" class="btn btn-primary" onclick="toggle_alt_labels()">Show alternate labels</button>
      else
      <button type="button" class="btn btn-primary" onclick="countrows()">Count</button>
      }
      <span class="col-2" id="rowCount"></span>
      {(: if ($type = 'concept') then
      <span class="col-3">
       <button type="button" class="btn btn-primary" onclick="new_concept_dialog()">New concept</button>
      </span> else () :)
      ()
      }
      </div>
    </div>
    <div class="card-body"><table id="filtertable" class="table">
    <thead><tr>
    <th scope="col">Formula</th>
    <th scope="col">Definition</th>
    <th scope="col">{if ($type='concept') then 'Alternate Labels' else 'Remarks'}</th>    
    </tr></thead><tbody class="table-striped">{
    for $h in $hits
     let $domain := tokenize(util:collection-name($h), '/')[last()]
    ,$n := if ($domain = ("concepts", "core")) then data($h/tei:head) else   $domain || "::" || data($h/tei:head)
    ,$id := $h/@xml:id
    (: editing for rhet dev postponed, because of the complicated structure. :)
    ,$edit := if (sm:id()//sm:groups/sm:group[. = "tls-editor"]  ) then 'true' else 'false'
    ,$d := $h/tei:div[@type="definition"]
    ,$def := if ($type = 'concept') then
       lc:display-defintion($h/@xml:id) 
(:       ($d/tei:p, <small>{$d/tei:note}</small>) :)
       else 
       if ($type = 'rhet-dev') then 
       $d/tei:p
       else
        ($h/tei:p, <small>{$h/tei:note}</small>)
    ,$al := $h/tei:list[@type='altnames']/tei:item/text()
    ,$b := $h/tei:div[@type="source-references"]
    ,$br := if ($type = ("syn-func", "sem-feat")) then 
      for $ref in $b//tei:bibl
      return <ul>{bib:display-bibl($ref)}</ul>
      else ()
    order by $n
    return
    (
    <tr id="{$id}" class="abbr">
    <td>{
    switch ($type) 
        case  "concept" return <a href="concept.html?uuid={$id}">{$n}</a>
        case  "syllables" return <a href="syllables.html?uuid={$id}">{$n}</a>
        case  "rhet-dev" return <a href="rhet-dev.html?uuid={$id}">{$n}</a>
        case  "syn-func" return <a href="syn-func.html?uuid={$id}">{$n}</a>
        default return (lrh:format-button("delete_sf('"||$id||"', '"||$type||"')", "Delete this " || lower-case($config:lmap($type||"1")) || ".", "open-iconic-master/svg/x.svg", "", "", "tls-editor"),
        <a id="{$id}-abbr" onclick="show_use_of('{$type}', '{$id}')">{$n}</a>)
    }</td>
    <td><p id="{$id}-{if ($type = 'sem-feat') then 'sm' else if ($type = 'syn-func') then 'sf' else 'rd'}" class="sf" contenteditable="{$edit}">
    {$def}&#160;</p>{$br}</td>
    <td><ul id="{$id}-resp"/><p class="altlabels" style="display:block">{string-join($al, ', ')}</p></td>
    </tr>)
    }</tbody></table></div>
  </div>
  (: unknown type :)
  else ()  
};

declare function app:browse-word-rel($type as xs:string?, $filter as xs:string?, $wrt as xs:string?){
let $reltypes := collection($config:tls-data-root)//tei:TEI[@xml:id="word-relations"]//tei:body/tei:div[@type='word-rel-type']
, $wt := if (string-length($wrt)) then $wrt else "Conv" 
, $rt := for $r in $reltypes 
        let $h := $r/tei:head/text()
        order by $h 
        return $r
return
<div><h4><span  class="font-weight-bold ml-2">Word relation type: </span>
                 <span><select id="rel-type" onChange="modify_rel_display()">
                 {for $l at $pos in $rt 
                  let $h := normalize-space($l/tei:head/text())
                  , $cnt := count($l//tei:div[@type="word-rel-ref"]/tei:list)
                return 
                 if ($h = $wt) then
                 <option value="{data($l/@xml:id)}" selected="true">{$h} ({$cnt})</option>
                 else
                 <option value="{data($l/@xml:id)}">{$h} ({$cnt})</option>}
                 </select></span>  
                 <span  class="font-weight-bold ml-2"> Sort by:　</span>
                 <span><select id="rel-type-sort" onChange="modify_rel_display()">
                 <option value="lw">Left word</option>
                 <option value="rw">Right word</option>
                 <option value="lc">Left concept</option>
                 <option value="rc">Right concept</option>
                 </select></span>    
   </h4>
   <p>　</p>
   <div id="rel-table">
   {tlslib:word-rel-table(map{"reltype":$rt[tei:head = $wt]/@xml:id, "mode":"lw"})}
   </div>
</div>    
};


(:~
 : currently (2020-02-26) this has been removed from the menu.  Needs rethinking
:)
declare function app:browse-word($type as xs:string?, $filter as xs:string?)
{<div><h4>Words by decreasing number of concepts</h4><small>1</small>
   { for $hit at $pos in collection($config:tls-data-root||"/core")//tei:div[@type=$type]
     let $head := $hit/tei:head
     ,$id := $hit/@xml:id
    return 
    (<a class="ml-2" href="word.html?char={$head[1]}" title="Found in {count($hit//tei:item)} CONCEPTS">{$head}</a>,
    if ($pos mod 30 = 0) then (<br/>,<small>{$pos}</small>) else () )
   }
</div>    
};

(:~
 : Displays the characters that had been analyzed taxonomically, culled from 
 : core/taxchar.xml
 : taxchar if available, otherwise look for words? :)
declare function app:browse-char($type as xs:string?, $filter as xs:string?)
{<div><h4>Analyzed characters by frequency</h4><small>1</small>
   { for $hit at $pos in collection($config:tls-data-root||"/core")//tei:div[@type=$type]
     let $head := $hit/tei:head
     ,$id := $hit/@xml:id
    return 
    (<a class="ml-2" href="char.html?char={$head[1]}">{$head}</a>,
    if ($pos mod 30 = 0) then (<br/>,<small>{$pos}</small>) else () )
   }
</div>    
};

(:~
: For "concept", "syn-func" and "sem-feat", this displays a list, which can be filtered by a search string
: called from app:browse
:)
declare function app:do-browse($type as xs:string?, $filter as xs:string?)
{
    if ($type = "concept") then 
     for $hit in collection($config:tls-data-root)//tei:div[@type=$type]
     let $domain := tokenize(util:collection-name($hit), '/')[last()],
     $head := if ($domain = "concept") then data($hit/tei:head) else () (:  $domain || "::" || data($hit/tei:head) :)
     , $w := $hit//tei:entry
     where starts-with($head, $filter) and count($w) > 0
     order by $head
     return $hit
    else 
     for $hit in collection($config:tls-data-root)//tei:div[@type=$type]
     let $head := data($hit/tei:head)
     where starts-with($head, $filter)
     order by $head
     return $hit
};


declare 
    %templates:wrap
    %templates:default("prec", 15)
    %templates:default("foll", 15)     
    %templates:default("first", "false")     
function app:getdata($node as node()*, $model as map(*), $location as xs:string?, $mode as xs:string?, $prec as xs:int?, $foll as xs:int?, $first as xs:string)
{
   session:create(),
   let $uid := request:get-parameter("uuid", "")
   , $clabel := request:get-parameter("concept", "")
   , $context := substring-before(tokenize(request:get-uri(), "/")[last()], ".html")
   return
    if (string-length($clabel) > 0) then
      map{"concept" : $clabel, "context" : $context}
    else if (string-length($uid) > 0) then
      let $clabel := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id = $uid]/tei:head/text()
      return
      map{"concept" : $clabel, "context" : $context}
    else
      map{"concept" : "unknown", "context" : $context}
};

(: textview related functions :)

(:~
: Get the first seg to display, translators, title etc. Store this in the model for later use
:)

declare 
    %templates:wrap
    %templates:default("prec", 15)
    %templates:default("foll", 15)     
    %templates:default("first", "false")     
function app:tv-data($node as node()*, $model as map(*), $location as xs:string?, $mode as xs:string?, $prec as xs:int?, $foll as xs:int?, $first as xs:string)
{
   session:create(),
    let $textid := tlslib:get-textid($location)
    return
    if ($mode = 'remote') then 
     let $skeleton := remote:get-segs(map{'location' : $location, 'prec': $prec, 'foll': $foll, 'first': $first}) 
     return
     map { "textid" : $textid, "title" : $skeleton//title/text(), "seg": $skeleton}
    else 
     let $seg := tlslib:get-first-seg($location, $mode, $first)
     , $title := lu:get-title($textid)
     return
     map { "textid" : $textid, "title" : $title, "seg": $seg}
};


(: function textview 
@param location  text location or text id for the text to display. If empty, display text list app:textlist
@param mode      when given as 'visit': bypass the manifest display and go directly to the text

: if we have a location, call tlslib:display-chunk(), which will display  n lines (tei:seg) elements
: for search results, prec and follow are the same to place the result in the middle of the page.

:) 

declare 
    %templates:wrap
    %templates:default("prec", 15)
    %templates:default("foll", 15)     
    %templates:default("first", "false")     
function app:textview($node as node()*, $model as map(*), $location as xs:string?, $mode as xs:string?, $prec as xs:int?, $foll as xs:int?, $first as xs:string)
{
(:     let $message := (for $k in map:keys($model) return $k) => string-join(","):)
  let $dispseg := $model("seg")
(:    , $l := log:info($app:log, "Loading; $model keys: " || $message):)
let $start-time := util:system-time()
let $query-needing-measurement := (: insert query or function call here :)

    (session:create(),
    if ($mode = 'remote') then
       ltp:prepare-chunk($dispseg, map:merge(($model, map{'prec': $prec, 'foll': $foll})))
    else
     if (string-length($location) > 0) then 
(:     tlslib:display-chunk($dispseg, $model, $prec, $foll):)
      try {
      
      tlslib:display-chunk($dispseg, $model, $prec, $foll)
      
      } catch * {"An error occurred, can't display text. Code:" || count($dispseg) || " (dispseg)" }      
    else 
    app:textlist()
    
    )
let $end-time := util:system-time()
let $duration := $end-time - $start-time
let $seconds := $duration div xs:dayTimeDuration("PT1S")
    
return
(
    $query-needing-measurement,
(:    "Query completed in " || $seconds || "s.",:)
    log:info($app:log, "Query completed in " || $seconds || "s.")    
)    
};

(: 2023-05-12 - now using search.html?query=&search-type=12 , this will be phased out.  :) 
declare function app:textlist(){
(: this is also quite expensive, need to cache... :)
    let $titles := map:merge(for $t in collection(concat($config:tls-texts-root, '/tls'))//tei:titleStmt/tei:title
            let $textid := data($t/ancestor::tei:TEI/@xml:id)
            return map:entry($textid, $t/text()))
    let $fv := function($k, $v){$v}
    let $bc := map:merge(for $c in map:keys($titles)
         let $bu := substring($c, 1, 3)
         group by $bu
         return map:entry($bu, count($c)))
    let $count :=  sum(map:for-each($bc, $fv)),
    $chantpath := concat($config:tls-texts-root, '/chant/'),
    $chantcount := if (xmldb:collection-available($chantpath)) then 
    sum(for $b in xmldb:get-child-collections($chantpath)
       let $coll := concat($chantpath, $b)
       return count(xmldb:get-child-resources($coll)))
    else 0,
    $user := sm:id()//sm:real/sm:username/text(),
    $ratings := doc( $config:tls-user-root || $user || "/ratings.xml")//text,
    $starredcount := count($ratings)
    , $krptexts := collection($config:tls-texts-root||"/KR")//tei:TEI/@xml:id
    return
    <div>
    <h1>Available texts: <span class="badge badge-pill badge-light">{$count + $chantcount + count($krptexts)}</span></h1>
    <ul class="nav nav-tabs" id="textTab" role="tablist">
    <li class="nav-item"> <a class="nav-link" id="coretext-tab" role="tab" 
    href="#coretexts" data-toggle="tab">Core Texts
    <span class="badge badge-pill badge-light">{$count}</span></a></li>
    <li class="nav-item"> <a class="nav-link" id="moretext-tab" role="tab" 
    href="#moretexts" data-toggle="tab">More Texts
    <span class="badge badge-pill badge-light">{$chantcount}</span></a></li>
    <li class="nav-item"> <a class="nav-link {if (sm:is-authenticated()) then () else "disabled"}" id="starredtext-tab" role="tab" 
    href="#starredtexts" data-toggle="tab">Starred Texts
    <span class="badge badge-pill badge-light">{$starredcount}</span></a></li>
    <li class="nav-item"> <a class="nav-link" id="krptext-tab" role="tab" 
    href="#krptexts" data-toggle="tab" title="Recently added texts">New Texts
    <span class="badge badge-pill badge-light">{count($krptexts)}</span></a></li>
    </ul>    
    <div class="tab-content" id="textsContent">    
    <div class="tab-pane" id="coretexts" role="tabpanel">    
    <ul class="nav nav-tabs" id="buTab" role="tablist">
    {for $b in map:keys($bc)
    order by $b
    return 
    <li class="nav-item">
    <a class="nav-link" id="{$b}-tab" role="tab" 
    href="#{$b}" data-toggle="tab">{map:get($config:lmap, $b)}
    <span class="badge badge-pill badge-light">{map:get($bc, $b)}</span></a></li>
    }
    </ul>
    <div class="tab-content" id="buTabContent">
    {
    for $tit in map:keys($titles)
     let $b := substring($tit, 1, 3)
     group by $b    
    return
    <div class="tab-pane" id="{$b}" role="tabpanel">
    <ul class="list">
    {for $t in $tit
    order by $t
    return
    <li class="list-group-itemx">
    <a href="textview.html?location={$t}">{map:get($titles, $t)}
    { if (sm:is-authenticated()) then
    <input id="input-{$t}" name="input-name" type="number" class="rating" 
    min="1" max="10" step="2" data-theme="krajee-svg" data-size="xs" value="{tlslib:get-rating($t)}"/>    
    else ()}
    </a></li>
    }
    </ul>
    
    </div>
    }
    </div>
    </div>
    <div class="tab-pane" id="moretexts" role="tabpanel">    
    
    { if (sm:is-authenticated()) then
    (: first create the tab links for sub catetories :)
    if (xmldb:collection-available($chantpath)) then (
    <ul class="nav nav-tabs" id="more-buTab" role="tablist">
    {for $b in xmldb:get-child-collections($chantpath)
    let $coll := concat($chantpath, $b)
    let $c := xmldb:get-child-resources($coll)
    order by $b
    return 
    <li class="nav-item">
    <a class="nav-link" id="{$b}-more-tab" role="tab" 
    href="#{$b}" data-toggle="tab">{map:get($config:lmap, $b)}
    <span class="badge badge-pill badge-light">{count($c)}</span></a></li>
    }
    </ul>
,    <div class="tab-content" id="more-buTabContent">
    {for $b in xmldb:get-child-collections($chantpath)
    let $coll := concat($chantpath, $b)
    return    
    <div class="tab-pane" id="{$b}" role="tabpanel">
    <ul>{
    for $title in collection($coll)//tei:titleStmt/tei:title
     let $textid := data($title/ancestor::tei:TEI/@xml:id)
     where string-length(string-join($title/text(), '')) > 0
    return
    <li class="list-group-item">
    <a href="textview.html?location={$textid}">{$title/text()}
    <input id="input-{$textid}" name="input-name" type="number" class="rating"
    min="1" max="10" step="2" data-theme="krajee-svg" data-size="xs" value="{if ($ratings[@id=$textid]) then $ratings[@id=$textid]/@rating else 0}"/>    
    </a></li>    
    }</ul>
    </div>
    }
    </div>
     ) else "Additional texts are not installed."   
    else 
    "More texts available.  Login to see a list."   
    }
    
    </div>
    <div class="tab-pane" id="starredtexts" role="tabpanel">    
    <ul>{for $text in $ratings
        let $r := xs:int($text/@rating),
        $textid := data($text/@id),
        $title := $text/text()
(:      $title := collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:titleStmt/tei:title/text():)
        order by $r descending
        return
    <li class="list-group-item">
    <a href="textview.html?location={$textid}">{$title}
    <input id="input-{$textid}" name="input-name" type="number" class="rating"
    min="1" max="10" step="2" data-theme="krajee-svg" data-size="xs" value="{$r}"/>    
    </a></li>
    }
    </ul>
    </div>

    <div class="tab-pane" id="krptexts" role="tabpanel">    
    <ul>{for $text in $krptexts
        let $bu := substring($text, 1, 4)
        group by $bu
        order by $bu
        return
    <li class="list-group-item">{doc($config:tls-add-titles)//work[@krid=$bu]/title/text()} <small class="text-muted ml-2">{$bu}</small>
    <ul>{for $t in $text 
        let $title := lu:get-title($t)
        order by $t 
    return
    <li><a href="textview.html?location={$t}">{$title}
     { if (sm:is-authenticated()) then
    <input id="input-{$t}" name="input-name" type="number" class="rating"
    min="1" max="10" step="2" data-theme="krajee-svg" data-size="xs" value="{if ($ratings[@id=$t]) then $ratings[@id=$t]/@rating else 0}"/>
     else () }    
    </a></li>}
    </ul></li>
    }
    </ul>
    </div>


    </div>
    </div>
};

(: additional info on the char under display, only shown if we are not in edit mode  :) 

declare 
    %templates:wrap
function app:char-info($node as node()*, $model as map(*), $char as xs:string?, $id as xs:string?, $edit as xs:string?)
{   if (string-length($edit) > 0) then () else
    let $usergroups := sm:id()//sm:group/text()
    let $key := replace($id, '#', '')
    let $e := string-length($edit) > 0
    let $n := if (string-length($id) > 0) then
      doc(concat($config:tls-data-root, "/core/taxchar.xml"))//tei:div[@xml:id = $id]
    else
      doc(concat($config:tls-data-root, "/core/taxchar.xml"))//tei:div[tei:head[. = $char]]
    let $char := if (string-length($char)> 0) then $char else ($n//tei:head)[1]/text()
    , $h := string-join(distinct-values($n/tei:head/text()), ' / ')
    , $char-id := tokenize($n/@xml:id)[1]  
    , $sw := doc($config:tls-texts-root || "/KR/KR1/KR1j/KR1j0018.xml")//tei:p[ngram:wildcard-contains(., "【" || $char || ".?】")][1]
    , $crit := for $p in collection($config:tls-data-root||"/concepts")//tei:div[@type="old-chinese-criteria" and contains(., ""|| $char)] return $p
    , $word-rel := doc($config:tls-data-root || "/core/word-relations.xml")//tei:div[@type='word-rel' and .//tei:item[contains(., $char)]]
    return
    <div class="card">
    <div class="card-header">
    <h4 class="card-title">Additional information about {$char}</h4>
    <p><a href="textview.html?location={($sw/tei:seg)[1]/@xml:id}">說文解字</a>: {$sw//text()}</p>
    {
    if ($crit) then <p class="ml-4"><ul><span class="font-weight-bold">Criteria</span>{for $c in $crit return 
    <li><span><a href="concept.html?uuid={$c/ancestor::tei:div[@type='concept']/@xml:id}">{$c/ancestor::tei:div[@type='concept']/tei:head/text()}</a><br/>{$c}</span></li>
    }</ul></p> else ()
    ,if ($word-rel) then 
    <p class="ml-4">{tlslib:display-word-rel($word-rel, $char, "")}</p> else ()
    }
    </div>
    </div>
    

};

(: taxchar display :)
declare 
    %templates:wrap
function app:char($node as node()*, $model as map(*), $char as xs:string?, $id as xs:string?, $edit as xs:string?)
{
    (session:create(),
    let $usergroups := sm:id()//sm:group/text()
    let $key := replace($id, '#', '')
    let $e := string-length($edit) > 0
    let $n := if (string-length($id) > 0) then
      doc(concat($config:tls-data-root, "/core/taxchar.xml"))//tei:div[@xml:id = $id]
    else
      doc(concat($config:tls-data-root, "/core/taxchar.xml"))//tei:div[tei:head[. = $char]]
    let $char := if (string-length($char)> 0) then $char else ($n//tei:head)[1]/text()
    , $h := string-join(distinct-values($n/tei:head/text()), ' / ')
    , $char-id := tokenize($n/@xml:id)[1]  
    return
    <div class="card">
    <div class="card-header">
    <h4 class="card-title">{if ($n) then <span>Taxonomy of meanings for {$h}:　　</span> else 
    <span>The character {$char} has not been analyzed yet.　　</span>,
    if ($e) then 
       <span><button id="save-taxchar-button" type="button" class="btn btn-primary" onclick="save_taxchar('taxchar')">Save taxonomy</button>　　<a class="btn btn-secondary" href="char.html?char={$char}">Leave edit mode</a></span> 
    else 
       if ("tls-editor" = $usergroups) then
       <a class="btn btn-secondary" href="char.html?char={$char}&amp;edit=true">Edit taxonomy</a>
       else ()
    }</h4>
    </div>
    
    {if ($e) then 
    <div class="card" id="help-content">
    <div class="card-header" id="help-head">
      <h5 class="mb-0">
        <button class="btn" data-toggle="collapse" data-target="#help" >
          Hints for editing the character taxonomy
        </button>
      </h5>
      </div>
      <div id="help" class="collapse" data-parent="#help-content">
      <ul>
      <li>Lines can be moved around with the mouse.</li>
      <li>Lines of the highest level indicate the reading for this part of the hierarchy.</li>
      <li><b>Save before leaving the page!</b></li>
      <li>Start editing the label by right-clicking on it. </li>
      <li>When editing the label, please leave the name of the concept unchanged at the very end of the label.</li>
      <li>Text <b>after</b> the name of the concept will <b>not</b> be saved.</li>
      <li>"Delete" will delete a subtree.  Move lines you want to keep to other subtrees before deleting the upper level item(s).</li>
      <li>There might be some lines at the bottom with new concepts that have been added since the last editing of this character.</li>
      </ul>
      </div>
    </div>
    else ()}
    
    
    <div class="card-text" id="{if ($e) then 'chartree' else 'notree'}" tei-id="{$char-id}" tei-head="{if (exists($n/tei:head)) then $h else $char}">
     {if ($n) then (for $l in $n/tei:list return tlslib:proc-char($l, $edit), 
        for $l in tlslib:char-tax-newconcepts($char, "taxchar")//tei:list return tlslib:proc-char($l, $edit) )
     else tlslib:char-tax-stub($char, "taxchar")}
    </div>
    <div class="card-footer">
    <ul class="pagination">
    {for $c in $n/preceding::tei:div[position()< 6]
    return
    <li class="page-item"><a class="page-link" href="char.html?id={$c/@xml:id}">{$c/tei:head/text()}</a></li>
    }    
    <li class="page-item disabled"><a class="page-link">&#171;</a></li>
    <li class="page-item disabled"><a class="page-link">{$h}</a></li>
    <li class="page-item disabled"><a class="page-link">&#187;</a></li>
    {for $c in $n/following::tei:div[position()< 6]
    return
    if ($e) then
    <li class="page-item"><a class="page-link" href="char.html?id={$c/@xml:id}&amp;edit=true">{$c/tei:head/text()}</a></li>
    else
    <li class="page-item"><a class="page-link" href="char.html?id={$c/@xml:id}">{$c/tei:head/text()}</a></li>
    }
    </ul>
    </div>
    </div>
)};   

(: taxword display :)
declare 
    %templates:wrap
function app:word($node as node()*, $model as map(*), $char as xs:string?, $id as xs:string?, $edit as xs:string?)
{
    (session:create(),
    let $usergroups := sm:id()//sm:group/text()
    let $key := replace($id, '#', '')
    let $e := string-length($edit) > 0
    let $n := if (string-length($id) > 0) then
      doc(concat($config:tls-data-root, "/core/taxword.xml"))//tei:div[@xml:id = $id]
    else
      doc(concat($config:tls-data-root, "/core/taxword.xml"))//tei:div[tei:head[. = $char]]
    let $char := if (string-length($char)> 0) then $char else ($n//tei:head)[1]/text()
    , $h := string-join(distinct-values($n/tei:head/text()), ' / ')
    , $char-id := tokenize($n/@xml:id)[1]  
    return
    <div class="card">
    <div class="card-header">
    <h4 class="card-title">{if ($n) then <span>Taxonomy of meanings for {$h}:　　</span> else 
    <span>The word {$char} has not been analyzed yet.　　</span>,
    if ($e) then 
       <span><button id="save-taxchar-button" type="button" class="btn btn-primary" onclick="save_taxchar('taxword')">Save taxonomy</button>　　<a class="btn btn-secondary" href="word.html?char={$char}">Leave edit mode</a></span> 
    else 
       if ("tls-editor" = $usergroups) then
       <a class="btn btn-secondary" href="word.html?char={$char}&amp;edit=true">Edit taxonomy</a>
       else ()
    }</h4>
    </div>
    
    {if ($e) then 
    <div class="card" id="help-content">
    <div class="card-header" id="help-head">
      <h5 class="mb-0">
        <button class="btn" data-toggle="collapse" data-target="#help" >
          Hints for editing the word taxonomy
        </button>
      </h5>
      </div>
      <div id="help" class="collapse" data-parent="#help-content">
      <ul>
      <li>Lines can be moved around with the mouse.</li>
      <li>Lines of the highest level indicate the reading for this part of the hierarchy.</li>
      <li><b>Save before leaving the page!</b></li>
      <li>Start editing the label by right-clicking on it. </li>
      <li>When editing the label, please leave the name of the concept unchanged at the very end of the label.</li>
      <li>Text <b>after</b> the name of the concept will <b>not</b> be saved.</li>
      <li>"Delete" will delete a subtree.  Move lines you want to keep to other subtrees before deleting the upper level item(s).</li>
      <li>There might be some lines at the bottom with new concepts that have been added since the last editing of this character.</li>
      </ul>
      </div>
    </div>
    else ()}
    
    
    <div class="card-text" id="{if ($e) then 'chartree' else 'notree'}" tei-id="{$char-id}" tei-head="{if (exists($n/tei:head)) then $h else $char}">
     {if ($n) then (for $l in $n/tei:list return tlslib:proc-char($l, $edit), 
        for $l in tlslib:char-tax-newconcepts($char, "taxword")//tei:list return tlslib:proc-char($l, $edit) )
     else tlslib:char-tax-stub($char, "taxword")}
    </div>
    <div class="card-footer">
    <ul class="pagination">
    {for $c in $n/preceding::tei:div[position()< 6]
    return
    <li class="page-item"><a class="page-link" href="word.html?id={$c/@xml:id}">{$c/tei:head/text()}</a></li>
    }    
    <li class="page-item disabled"><a class="page-link">&#171;</a></li>
    <li class="page-item disabled"><a class="page-link">{$h}</a></li>
    <li class="page-item disabled"><a class="page-link">&#187;</a></li>
    {for $c in $n/following::tei:div[position()< 6]
    return
    if ($e) then
    <li class="page-item"><a class="page-link" href="word.html?id={$c/@xml:id}&amp;edit=true">{$c/tei:head/text()}</a></li>
    else
    <li class="page-item"><a class="page-link" href="word.html?id={$c/@xml:id}">{$c/tei:head/text()}</a></li>
    }
    </ul>
    </div>
    </div>
)};   
   
(: rhetdev display :)
declare 
    %templates:wrap
function app:rhetdev($node as node()*, $model as map(*), $uuid as xs:string?, $ontshow as xs:string?)
{
    (session:create(),
    let $user := sm:id()//sm:real/sm:username/text()
    let $key := replace($uuid, '^#', '')
    let $rd :=  
       collection($config:tls-data-root || "/core")//tei:div[@xml:id=$key],        
    $show := if (string-length($ontshow) > 0) then " show" else "",
    $edit := if (sm:id()//sm:groups/sm:group[. = "tls-editor"]) then 'true' else 'false',
    $tr := $rd//tei:list[@type="translations"]//tei:item
    ,$rdlcnt := count(collection($config:tls-data-root || "/notes/rdl")//tls:span[@rhet-dev-id=$key])
    return 
    <div class="row" id="rhetdev-id" data-id="{$key}" >
    <div class="card col-sm-12" style="max-width: 1000px;background-color:honeydew;">
    <div class="card-body" >
    <h4 class="card-title">{$rd/tei:head/text()}&#160;&#160;{for $t in $tr return 
      <span class="badge badge-light" title="{map:get($config:lmap, $t/@xml:lang)}">{$t/text()}</span>} 
      </h4>
    <div class="card-text" id="rd-test" >{for $p in $rd/tei:div[@type="definition"]//tei:p/text() return <p>{$p}</p>}</div>
    <div id="rhetdev-content" class="accordion">
    
    <!-- pointers -->
    <div class="card">
    <div class="card-header" id="pointers-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#pointers" >
         {$config:lmap?pointers} of {$rd/tei:head/text()}
        </button>
      </h5>
      </div>
     <div id="pointers" class="collapse{$show}" data-parent="#rhetdev-content">
     {for $p in $rd//tei:div[@type="pointers"]//tei:list[not(@type = "taxonymy")]
     order by $p/@type
     return
     (<h5 class="ml-2">
     {map:get($config:lmap, data($p/@type))}
     {tlslib:capitalize-first(data($p/@type/text()))}</h5>,
     (: we assume that clicking here implies an interest in the ontology, so we load in open state:)
     <ul>
     {for $r in $p//tei:ref 
     let $lk := replace($r/@target, "#", "")
     let $def := collection($config:tls-data-root)//tei:div[@xml:id=substring($r/@target, 2)]/tei:div[@type='definition']/tei:p/text()
     return
     (<li >
     <a class="badge badge-light" href="rhet-dev.html?uuid={$lk}&amp;ontshow=true">{$r/text()}</a>
     <small style="display:block;">{$def}</small>
     </li>,
     <ul>{
     if ($p[@type = "hypernymy"]) then
     for $u in reverse(tlslib:ontology-up($lk, -5)) 
     return $u
     else ()
     }</ul>
     )} </ul>)}
     
     {for $p in $rd//tei:div[@type="pointers"]//tei:list[@type = "taxonymy"]
     return
     (<h5 class="ml-2">
     {map:get($config:lmap, data($p/@type))}
     {tlslib:capitalize-first(data($p/@type/text()))}</h5>,
     <ul>{
     for $r in $p//tei:ref 
     let $lk := replace($r/@target, "#", "")
     let $def := collection($config:tls-data-root)//tei:div[@xml:id=substring($r/@target, 2)]/tei:div[@type='definition']/tei:p/text()
     return
  
     <li>
     <a class="badge badge-light" href="rhet-dev.html?uuid={$lk}&amp;ontshow=true">{$r/text()}</a>
     <small style="display:block;">{$def}</small>
     <ul>{
     for $u in tlslib:ontology-links($lk, "taxonymy", 2 ) return
     $u
     }</ul></li>
     }</ul>
     )
     }
     
    
     </div>
    </div>
<!-- end pointers -->
    <!-- notes -->
    <div class="card">
    <div class="card-header" id="notes-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#notes" >Notes ({string-length($rd//tei:note)} characters)</button>
      </h5>
      </div>
     <div id="notes" class="collapse" data-parent="#rhetdev-content">
     {for $d in $rd//tei:note
     return
     <div lang="en-GB" contenteditable="{$edit}" style="white-space: pre-wrap;" class="nedit" id="note_{$key}-nt">{for $p in $d//tei:p return
     ($p/text(), <br/>,<br/>)}
     </div>}
     </div>
    </div>
    <!-- bibl -->
    <div class="card">
    <div class="card-header" id="bibl-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#bibl" >
          Source references ({count($rd//tei:div[@type="source-references"]//tei:bibl)} items) 
        </button>
      </h5>
      </div>
     <div id="bibl" class="collapse" data-parent="#rhetdev-content">
     <ul>
     {for $d in $rd//tei:div[@type="source-references"]//tei:bibl
     return
     bib:display-bibl($d)
     }</ul>  
     </div>
    </div>
    
      </div>
    <div><h5>Rhetorical device locations: {$rdlcnt}</h5>
    <ul>
    {for $rdl in collection($config:tls-data-root || "/notes/rdl")//tls:span[@rhet-dev-id=$key]
    let $tl := substring(($rdl//tls:srcline[1]/@target)[1], 2)
    , $ti := data(($rdl//tls:srcline[1]/@title)[1])
    return
    <li><a href="textview.html?location={$tl}">{$ti}</a><span>{($rdl//tls:srcline[1])[1]}</span>
    {if (count($rdl//tls:srcline) gt 1) then
    let $last := substring(($rdl//tls:srcline)[2]/@target, 2)
    , $targetseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$tl]
    , $rds := $targetseg/following::tei:seg[@xml:id=$last]
    (: $ns1[count(.|$ns2)=count($ns2)] :)
    for $s in ($targetseg/following::tei:seg intersect $rds/preceding::tei:seg) | $rds
    return
    <span>{$s}</span>
    else ()}
    {if ($rdl/tls:note) then <p>{$rdl/tls:note}</p> else ()}
    </li>
    }
    </ul>
    </div>  
      </div>
      </div>
      </div>    
    )
};   
   
(: concept display :)
declare 
%templates:wrap 
%templates:default("bychar", 0) 
function app:concept($node as node()*, $model as map(*), $concept as xs:string?, $uuid as xs:string?, $ontshow as xs:string?, $bychar as xs:boolean)
{
    (session:create(),
    let $user := sm:id()//sm:real/sm:username/text()
    let $key := replace($uuid, '^#', '')
    let $c :=  if (string-length($key) > 0) then
       (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[ends-with(@xml:id,$key)]    
     else
       (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[tei:head[. = $concept]],
    $key := $c/@xml:id,
    $concept := $c/tei:head/text(),
    $edit := if (sm:id()//sm:groups/sm:group[. = "tls-editor"]) then 'false' else 'false',
    $show := if (string-length($ontshow) > 0) then " show" else "",
    $tr := $c//tei:list[@type="translations"]//tei:item
    let $ann := for $c in collection($config:tls-data-root||"/notes")//tls:ann[@concept-id=$key]
     return $c
    return
    <div class="row" id="concept-id" data-id="{$key}">
    <div class="card col-sm-12" style="max-width: 1000px;">
    <div class="card-body">
    <h4 class="card-title"><span id="{$key}-la" class="sf" contenteditable="{$edit}">{$concept}</span>&#160;&#160;{for $t in $tr return 
      <span class="badge badge-light" title="{map:get($config:lmap, $t/@xml:lang)}">{$t/text()}</span>} 
      {if  ("tls-admin" = sm:get-user-groups($user)) then 
      <a target="_blank" class="float-right badge badge-pill badge-light" href="{
      concat($config:exide-url, "?open=", document-uri(root($c)))}">Edit concept</a>
      else ()}
      </h4>
    <h5 class="card-subtitle" id="concept-def">{$c/tei:div[@type="definition"]//tei:p/text()}</h5>
    <div id="concept-content" class="accordion">
    <div class="card">
    <div class="card-header" id="altnames-head">
      <h5 class="mb-0">
        <button class="btn" data-toggle="collapse" data-target="#altnames" >
          Alternate labels ({count($c//tei:list[@type="altnames"]/tei:item)})
        </button>
      </h5>
      </div>
      <div id="altnames" class="collapse" data-parent="#concept-content">{for $i in $c//tei:list[@type="altnames"]/tei:item/text()
      return
      <span class="badge badge-pill badge-light">{$i}</span>
      }</div>
    </div>
    <!-- pointers -->
    <div class="card">
    <div class="card-header" id="pointers-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#pointers" >
         {$config:lmap?pointers} of {$c/tei:head/text()}
        </button>
      </h5>
      </div>
     <div id="pointers" class="collapse{$show}" data-parent="#concept-content">
     {for $p in $c//tei:div[@type="pointers"]//tei:list[not(@type = "taxonymy")]
     order by $p/@type
     return
     (<h5 class="ml-2">
     {map:get($config:lmap, data($p/@type))}
     {tlslib:capitalize-first(data($p/@type/text()))}</h5>,
     (: we assume that clicking here implies an interest in the ontology, so we load in open state:)
     <ul>
     {for $r in $p//tei:ref 
     let $lk := replace($r/@target, "#", "")
     ,$def := collection($config:tls-data-root || "/concepts")//tei:div[@xml:id=$lk]/tei:div[@type='definition']/tei:p/text()
     return
     (<li>
     <a class="badge badge-light" href="concept.html?uuid={$lk}&amp;ontshow=true">{$r/text()}</a>
     <small style="display:block;">{$def}</small>
     <ul>{
     if ($p[@type = "hypernymy"]) then
     for $u in reverse(tlslib:ontology-up($lk, 1)) 
     return $u
     else ()
     }</ul></li>)} 
     </ul>)}
     
     {for $p in $c//tei:div[@type="pointers"]//tei:list[@type = "taxonymy"]
     return
     (<h5 class="ml-2">
     {map:get($config:lmap, data($p/@type))}
     {tlslib:capitalize-first(data($p/@type/text()))}</h5>,
     <ul>{
     for $r in $p//tei:ref 
     let $lk := replace($r/@target, "#", "")
      ,$def := collection($config:tls-data-root || "/concepts")//tei:div[@xml:id=$lk]/tei:div[@type='definition']/tei:p/text()
     return
  
     <li>
     <a  class="badge badge-light" href="concept.html?uuid={$lk}&amp;ontshow=true">{$r/text()}</a>
     <small style="display:inline;">　{$def}</small>
     <ul>{
     (: a higher cnt means less levels displayed. use 2 or 3 :)
     for $u in tlslib:ontology-links($lk, "taxonymy", 3 ) return $u
     }</ul></li>
     }</ul>
     )
     }
     
    
     </div>
    </div>
    <!-- notes -->
    <div class="card">
    <div class="card-header" id="notes-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#notes" >
          {$config:lmap?notes} ({string-length(string-join($c//tei:div[@type="notes"]//tei:div, ''))} characters)
        </button>
      </h5>
      </div>
     <div id="notes" class="collapse" data-parent="#concept-content">
     {for $d in $c//tei:div[@type="notes"]//tei:div
     return
     (<h5 class="ml-2 mt-2">{map:get($config:lmap, data($d/@type))}</h5>,
     <div lang="en-GB" contenteditable="{$edit}" style="white-space: pre-wrap;" class="nedit" id="{$d/@type}_{$key}-nt">{for $p in $d//tei:p return
     ($p/text(), <br/>,<br/>)
     }     
     </div>)}
     </div>
    </div>
    <!-- bibl -->
    <div class="card">
    <div class="card-header" id="bibl-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#bibl" >
          Source references ({count($c//tei:div[@type="source-references"]//tei:bibl)} items)
        </button>
      </h5>
      </div>
     <div id="bibl" class="collapse" data-parent="#concept-content">
     <ul>
     {for $d in $c//tei:div[@type="source-references"]//tei:bibl
     return
     bib:display-bibl($d)
     }</ul>  
     </div>
    </div>
    <!-- -->
    </div>
    <div class="card">
    <!-- Here we look for all places where this concept has been used -->
     <div>
     <div class="card-header" id="look-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#look" >
          <a href="citations.html?perspective=concept&amp;item={$concept}" title="This moves to a separate page">Citations</a> (<span class="btn badge badge-light">{count($ann)} attested)</span>
        </button>
      </h5>
      </div>
    </div>
    
    </div>
    
    </div>
    <div id="word-content" class="card">
    <div class="card-body">
    <h4 class="card-title">Words</h4>
    <p class="card-text">
    {for $e in $c/tei:div[@type="words"]//tei:entry
    let $zi := string-join($e/tei:form/tei:orth, " / ")
    ,$entry-id := $e/@xml:id
    ,$pr := $e/tei:form/tei:pron
    ,$def := $e/tei:def/text()
    , $resp := tu:get-member-initials($e/@resp)
    ,$word-rel := doc($config:tls-data-root || "/core/word-relations.xml")//tei:div[@type='word-rel' and .//tei:item[@corresp="#"||$entry-id]]
(:    ,$word-rel := doc($config:tls-data-root || "/core/word-relations.xml")//tei:item[@corresp="#"||$entry-id]/ancestor::tei:div[@type="word-rel"]:)
    ,$wc := sum(for $sw in $e//tei:sense 
             return count($ann//tei:sense[@corresp="#" || $sw/@xml:id]))
    order by if (xs:boolean($bychar)) then $zi else $wc descending    
(:    count $count :)
    return 
    (: tls-div will, together with the defs in style.css allow jumps to here land accurately :)
    <div class="tls-div" id="{$entry-id}"><h5>
    {let $seq := for $f at $pos in $e/tei:form 
    let $zi := $f/tei:orth/text()
    , $p := $f/tei:pron
    return
    (<span id="{$entry-id}-{$pos}">
    <span id="{$entry-id}-{$pos}-zi" class="zh">{$zi}</span>
    {for $l in $p return
    switch ($l/@xml:lang) 
    case "zh-x-oc" return <span>&#160;OC: {$l/text()}</span>
    case "zh-x-mc" return <span>&#160;MC: {$l/text()}</span>
    (: assign_guangyun_dialog( 
    '{$zi}','{$entry-id}', '{$l/text()}':)
    default 
    return  let $px := normalize-space($l/text()) return
    (: todo: check for permissions! :)
    <span id="{$entry-id}-{$pos}-py" title="Click here to change pinyin" onclick="assign_guangyun_dialog({{'zi':'{$zi}', 'wid':'{$entry-id}','py': '{normalize-space($l/text())}','concept' : '{$c/tei:head/text()}', 'concept_id' : '{$key}', 'pos':'{$pos}'}})">&#160;&#160;{
    if (string-length($px) = 0) then "Click here to add pinyin" else $px}</span>,
    if (count($e/tei:form) > 1) then 
    lrh:format-button("delete_zi_from_word('"|| $entry-id || "','" || $pos ||"','"|| $zi ||"')", "Delete " || $zi || " and pronounciation from this word.", "open-iconic-master/svg/x.svg", "", "", "tls-editor")
    else ()
    }
    </span>
    )
    , $len := count($seq)
    return 
    for $s at $pos in $seq
    return
    if ($pos < $len) then ($s, <br/>) else ($s)
    
    }    
        {if ($resp[1]) then 
    <small><span class="ml-2 btn badge-secondary" title="{$resp[1]} - {$e/@tls:created}">{$resp[2]}</span></small> else ()}

    <small>{"  " || $wc} {if ($wc = 1) then " Attribution" else " Attributions"}</small>
    {if ($wc = 0) then
    lrh:format-button("delete_word_from_concept('"|| $entry-id || "', 'word')", "Delete the word "|| $zi || ", including all syntactic words.", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else 
    (: move :)
    lrh:format-button("move_word('"|| $zi || "', '"|| $entry-id ||"', '"||$wc||"', 'word')", "Move the word "|| $zi || ", including all syntactic words to another concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor")
    }
    {if (lpm:show-setting('wd', 'concept')) then wd:display-qitems($entry-id, 'concept', $zi) else ()}
    </h5>
    {if ($def) then <p class="ml-4">{$def[1]}</p> else ()}
    {if ($word-rel) then <p class="ml-4">
    {let $char := $e/tei:form/tei:orth[1]/text()
    return tlslib:display-word-rel($word-rel, $char, $c/tei:head/text())}
    </p> else ()}
    {if ($e//tei:listBibl) then 
         <div><button class="btn" data-toggle="collapse" data-target="#bib-{$entry-id}">Show references</button><ul id="bib-{$entry-id}" class="collapse" data-toggle="collapse">
        {for $d in $e//tei:bibl
        return
        bib:display-bibl($d)
     }</ul></div>  
    else ()} 
    <ul><span class="font-weight-bold">Syntactic words</span>{for $sw in $e/tei:sense
    let $sf := lower-case(($sw//tls:syn-func/text())[1]),
    $sm := lower-case($sw//tls:sem-feat/text())
    order by $sf || $sm
    return
    tlslib:display-sense($sw, count($ann//tei:sense[@corresp="#" || $sw/@xml:id]), false())
    }</ul>
    </div>
    }
    </p>
    </div>
    </div>
    </div>
        <div class="col-sm-0">{tlslib:swl-form-dialog('concept', $model)}</div>
        <div class="col-sm-1">{if (lpm:show-setting('wd', 'concept')) then wd:quick-search-form('concept') else ()}</div>
    </div>
    )
    
};


(: get words for new ann :)
(: 2/28 disabled
declare 
    %templates:wrap
function app:get_sw($node as node()*, $model as map(*), $word as xs:string?)
{
for $w in tlslib:getwords($word, $model)
return $w
};

'{{\'user\' : \'{$me}\'}}'
:)

(: login :)
declare 
    %templates:wrap
function app:login($node as node()*, $model as map(*))
{ 
let $user := request:get-parameter("user", ())
return
if (sm:is-authenticated() and not($user)) then 
let $me := sm:id()//sm:real/sm:username/text()
return
<li class="nav-item dropdown">
<a class="nav-link dropdown-toggle" href="#" id="settingsDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
<img class="icon mr-2" 
src="resources/icons/open-iconic-master/svg/person.svg"/>{sm:id()//sm:real/sm:username/text()}</a>
<div class="dropdown-menu" aria-labelledby="settingsDropdown">
<a onclick="dologout()" class="dropdown-item bg-danger">Logout</a>
<!--
<a onclick="show_dialog('passwd-dialog', '{$me}')" class="dropdown-item bg-warning">Change Password</a>
-->
<a class="dropdown-item" href="settings.html">Settings</a>
<a class="dropdown-item" href="https://join.slack.com/t/tls-7al8577/shared_invite/zt-1h6hfirdt-8EdFCAxsQalvCIdIs3OK6w">Feedback channel</a>
</div>
</li>
else
<li class="nav-item">
<div class="btn-nav">
<a href="#" class="btn btn-default navbar-btn" data-toggle="modal" data-target="#loginDialog">
<img class="icon icon-account-login mr-2" 
src="resources/icons/open-iconic-master/svg/account-login.svg"/>Login</a>
</div>
</li>
};

(:~
 : The navbar shown on all pages except the textview page, which has app:tv-navbar instead
 : common elements between these navbars have been factored out to app:browse-navbar
:)
declare
    %templates:wrap
    %templates:default("query", "")
function app:navbar-main($node as node()*, $model as map(*), $query as xs:string?)
{
let $context := substring-before(tokenize(request:get-uri(), "/")[last()], ".html")
 ,$testuser := contains(sm:id()//sm:group, ('tls-test', 'guest'))
(: , $l := log:info($app:log, "Loading; app:navbar-main "):)
let $user := sm:id()//sm:real/sm:username/text()
return
if ($user = 'guest' and $context = ('index', 'signup')) then () else
<nav class="navbar navbar-expand-sm navbar-light bg-light fixed-top">
                <span class="banner-icon"><a href="index.html">
                {app:logo($node, $model)}</a>
                </span>
                <a class="navbar-brand ml-2" href="index.html">{$config:app-title}</a>
                <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
                    <span class="navbar-toggler-icon"/>
                </button>
                
                <div class="collapse navbar-collapse" id="navbarSupportedContent">
                    <ul class="navbar-nav mr-auto">
                        {if ($context = "concept") then
                        tlslib:navbar-concept($node, $model)
                        else ()}
                        <li class="nav-item dropdown">
                            <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                                Browse
                            </a>
                            <div class="dropdown-menu" aria-labelledby="navbarDropdown">
                                <a class="dropdown-item" href="search.html?search-type=12">Texts</a>
                                <a class="dropdown-item" href="browse.html?type=concept">Concepts</a>
                                <a class="dropdown-item" href="browse.html?type=taxchar">Characters</a>
                                <a class="dropdown-item" href="browse.html?type=taxword">Words</a>
                                <a class="dropdown-item" href="citations.html">Citations</a>
                                <a class="dropdown-item" href="browse.html?type=word-rel-type">Word relations</a>
                                <a class="dropdown-item" href="browse.html?type=syn-func">Syntactic functions</a>
                                <a class="dropdown-item" href="browse.html?type=sem-feat">Semantic features</a>
                                <a class="dropdown-item" href="browse.html?type=rhet-dev">Rhetorical devices</a>
                                <a class="dropdown-item" href="observations.html">Observations</a>
                                <!--<div class="dropdown-divider"/>-->
                                <!-- will need to make another menu level here for the bookmarks -->
                                <a class="dropdown-item" href="browse.html?type=biblio">Bibliography</a>
                            </div>                            
                        </li>
                        {if ($context = ("textview", "lineview")) then 
                        tlslib:tv-header($node, $model)
                        else 
                        (tlslib:navbar-doc(),
                        tlslib:navbar-link()
                        )}
                        {if (not($testuser)) then tlslib:navbar-bookmarks() else ()}
                        {if (lpm:should-display-navbar-review($context, $model)) then tlslib:navbar-review($context) else ()}
                        {tlslib:navbar-help($model)}
                        </ul>
                    <ul class="navbar-nav">
                    <li class="nav-item">
                    
                    <form action="search.html" class="form-inline my-2 my-lg-0" method="get">
                    <input type="hidden" name="textid" value="{request:get-parameter("textid", map:get($model, 'textid'))}"/>
<!--                    <input type="hidden" name="filter" value="{request:get-parameter("filter", tu:get-setting('search-default', 'tls-internal:annotation'))}"/> -->
                    <input id="query-inp" name="query" class="form-control w-50 mr-sm-2 chn-font" type="search" placeholder="Search" aria-label="Search" value="{if (string-length($query) > 0) then $query else ()}"/> <span class="mr-1">in</span> 
        <select class="form-control input-sm" name="search-type">
          {if (not($context = "bibliography")) then
          <option selected="true" value="{if ($context = "textview") then '5' else '1'}">{$config:search-map?1}</option>
          else
          <option value="{if ($context = "textview") then '5' else '1'}">{$config:search-map?1}</option>}
          <option value="7">{$config:search-map?7}</option>
          <option value="2">{$config:search-map?2}</option>
          <option value="3">{$config:search-map?3}</option>
        <!--<option value="11">{$config:search-map?11}</option> -->
          <option value="4">{$config:search-map?4}</option>
          {if ($context = "bibliography") then
          <option selected="true" value="10">{$config:search-map?10}</option>
          else
          <option value="10">{$config:search-map?10}</option>}
          <!--
          <option value="9">{$config:search-map?9}</option>
          -->
<!--          <option value="4">Three</option> -->
        </select>
                        <button id="search-submit" class="btn btn-outline-success my-2 my-sm-0" type="submit">
                            <img class="icon" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
                        </button>
                    <!--    
                    <li class="nav-item dropdown">    
                    <a class="nav-link dropdown-toggle" href="#" id="searchDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"></a>
                    <div class="dropdown-menu" aria-labelledby="searchDropdown">
                    {if (not($testuser)) then
                    <a onclick="show_dialog('search-settings', 'ok')" class="dropdown-item">Search Settings</a>
                    else ()}
                    <a class="dropdown-item" href="settings.html">Advanced Search</a>
                    </div>
                    </li>
                    -->
                    </form>
                    </li>
                        {app:login($node, $model)}
                    </ul>
                    <!--
                    <div class="btn-nav">
                        <a href="#" class="btn btn-default navbar-btn" data-toggle="modal" data-target="#searchDialog">Advanced Search</a>
                    </div>
                    -->
                </div>
            </nav>
};
(:~
 This is called from translations.html
:)
declare 
    %templates:wrap
function app:translations($node as node()*, $model as map(*)){
let $d := (for $d1 in collection($config:tls-data-root||"/statistics/")//div[@type="statistics"]
   let $m := xs:dateTime($d1/@modified)
   order by $m descending
   return $d1)[1]
, $tab := $d/table[@id="stat-translations"]   
return
$tab
};
(:~
 This is called from review.html
:)
declare 
    %templates:wrap
    %templates:default("issue", "")    
function app:review($node as node()*, $model as map(*), $type as xs:string, $issue as xs:string){
 switch($type) 
  case "swl" return lrv:review-swl()
  case "gloss" return lrv:review-gloss()
  case "special" return lrv:review-special($issue)
  case "request" return lrv:review-request()
  case "user" return sgn:review()
  default return ""
};


(:~
 This is called from changes.html
:)
declare 
    %templates:wrap
function app:recent($node as node()*, $model as map(*)){
(: attributions and translations, with API calls to actual activity :)

<div><h2>Recent activity as of {current-dateTime()}</h2>
{
let $notes := $config:tls-data-root || "/notes"
, $trans := $config:tls-data-root || "/translations"
let $atts := for $a in collection($notes)//tls:ann/tls:metadata
 let $date := xs:dateTime($a/@created)
 where $date > xs:dateTime("2019-08-29T19:51:15.425+09:00")
 order by $date descending
 return $a
,$pers := for $a in distinct-values($atts/@resp)
  return $a
  
return  

<div>
<h3>Attributions</h3>
<p>Total number of attributions made since Aug. 28, 2019: {count($atts)}</p>

<ul>
{for $p in $pers
let $px := substring-after($p,"#")
let $un := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px]//tei:persName/text()
(:,$un := $px
:), $cnt := count($atts[@resp=$p])
order by $cnt descending
return
<li>{if (not($un)) then $px else $un}, {$cnt}</li>
}
</ul>
{
for $a in subsequence($atts, 1, 1)
let $att := $a/ancestor::tls:ann
return 
<div><span>The most recent attribution was {lrh:display-duration(xs:dateTime(current-dateTime()) - xs:dateTime(data($a/@created)))} ago :</span>
{(
lrh:show-att-display($att),
lrh:format-swl($att, map{"type" : "row"})
)}
</div>}
</div>
},

{
let $trans := $config:tls-data-root || "/translations"
let $atts := for $a in collection($trans)//tei:seg
 let $date := xs:dateTime($a/@modified)
 where $date > xs:dateTime("2019-08-29T19:51:15.425+09:00")
 order by $date descending
 return $a
,$pers := distinct-values(for $a in distinct-values($atts/@resp)
  return replace($a, '#', ''))
  
return  

<div>
<h3>Lines of translations</h3>
<p>Total number of lines translated since Aug. 28, 2019: {count($atts)}</p>
<ul>
{for $px in $pers
let $un := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px]//tei:persName/text()
(:let $un := "xx":)
let $cnt := count($atts[@resp=$px]) + count($atts[@resp='#'|| $px])
order by $cnt descending
return
(:<li>{if (not($un)) then $px else $un}, {$cnt}</li>:)
<li>{if (not($un)) then $px else $un}, {$cnt}</li>

}
</ul>
</div>
}
</div>
};

declare
    %templates:wrap
function app:footer($node as node()*, $model as map(*)){
            <div class="container">
                <span id="copyright"/>
                    <p>Copyright TLS Project 2024, licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/" title="Creative Commons Attribution-ShareAlike 4.0 International License">CC BY SA</a> license (except some translations)</p>
                <p>Developed at the <strong>Center for Innovative Informatics of the Humanities, Institute for Research in Humanities, Kyoto University</strong>, with support from the 
                <strong>Dean for Research, Department of East Asian Studies</strong>, and
                <strong>Program in East Asian Studies, Princeton University</strong>.</p>    
                <p>Development supported by the <strong>sin-aps</strong> research group at <strong>Friedrich-Alexander-Universität Erlangen Nürnberg</strong>, with financial support from the <strong>Alexander von Humboldt Foundation</strong>.  </p>
                <p>Hosted by <strong>Princeton University, Department of East Asian Studies</strong>, in cooperation with <strong>Ruhr University Bochum, Center for the Study of Traditional Chinese Cultures </strong>.  </p>
                <p>Support from 
                    <strong>Heidelberg University - Cluster of Excellence - Asia and Europe in a Global Context</strong>
                    and <strong>IKOS - University of Oslo</strong>
                    gratefully acknowledged.
                </p>
                <p class="small text-right">This site uses cookies to maintain login state. The cookies are not used for any other purposes. By using this site you agree to this.</p>
            </div>
};


declare function app:theme($node as node()*, $model as map(*)){
let $user := sm:id()//sm:real/sm:username/text()
return
if ($user = "chrisx") then 
<link rel="stylesheet" type="text/css" data-template="app:theme" href="resources/bootstrap-4.2.1/css/bootstrap.solar.min.css"/>
else
<link rel="stylesheet" type="text/css" data-template="app:theme" href="resources/bootstrap-4.2.1/css/bootstrap.min.css"/>
};

declare function app:recent-activity(){
  let $userref := concat('#', sm:id()//sm:username/text())
  for $r in collection($config:tls-data-root)//*/@tls:resp=$userref
  return $r
};

declare
    %templates:wrap
function app:welcome($node as node()*, $model as map(*)){
i18n:welcome-message()
};

declare function app:stats(){
let $d := for $d1 in collection($config:tls-data-root||"/statistics/")//div[@type="statistics"]
   let $m := xs:dateTime($d1/@modified)
   order by $m descending
   return $d1
return
<div>
<h3>Overview of the content of the database (last updated: {format-dateTime(xs:dateTime(data($d[1]/@modified)), "[MNn] [D], [Y]", "en", (), ())})</h3>
{$d[1]//table[@id='stat-overview']}
</div>        

};

declare
    %templates:wrap
function app:dialogs($node as node()*, $model as map(*))
{<div>
        <div id="loginDialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
            <p>Login</p>
            <div class="modal-dialog" style="z-index: 1080;" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h4 class="modal-title">Login</h4>
                        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
                    </div>
                        <div class="modal-body">
                            <div class="form-group">
                                <label class="control-label col-sm-2">User:</label>
                                <div class="col-sm-10">
                                    <input type="text" name="user" class="form-control"/>
                                </div>
                            </div>
                            <div class="form-group">
                                <label class="control-label col-sm-2">Password:</label>
                                <div class="col-sm-10">
                                    <input type="password" name="password" class="form-control"/>
                                </div>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button name="login-button" class="btn btn-primary" onclick="dologin()">Login</button>
                        </div>
                        <input type="hidden" name="duration" value="P7D"/>
                </div>
            </div>
        </div>
        <div id="remoteDialog"/>
        <div id="facslot1"/>
        <div id="facslot2"/>
        <div id="remDialog2"/>
        <div id="remBibRef"/>
   </div>
};


declare
    %templates:wrap
    %templates:default("char", "")  
    %templates:default("uuid", "")    
function app:syllables($node as node()*, $model as map(*), $uuid as xs:string?, $char as xs:string?){
    (session:create(),
    let $user := sm:id()//sm:real/sm:username/text()
    , $grc := collection($config:tls-data-root||"/guangyun")
    , $gys := if (string-length($uuid) > 0) then 
      $grc//tx:guangyun-entry[@xml:id=$uuid]
      else 
      $grc//tx:graphs//tx:graph[. = $char]/ancestor::tx:guangyun-entry
    for $gy at $pos in $gys
    let $mand-jin := ($gy//tx:pronunciation/tx:mandarin/tx:jin|$gy//tx:pronunciation/tx:mandarin/tx:jiu)
    , $key := $gy/@xml:id
    , $gloss := $gy//tx:gloss
    , $zis := for $a in $gys/tx:graphs//tx:graph
                return
                if (string-length($a/text()) > 0) then $a else ()
    , $zi := if (string-length(translate(normalize-space($gy/tx:graphs/tx:standardised-graph/tx:graph), ' ', ''))> 0) then
                $gy/tx:graphs/tx:standardised-graph/tx:graph else
                $gy/tx:graphs/tx:attested-graph/tx:graph
    , $fq := ($gy//tx:fanqie/tx:fanqie-shangzi//tx:graph/text(),
     $gy//tx:fanqie/tx:fanqie-xiazi//tx:graph/text())
    return 
  <div class="row" id="syllables-id" data-id="{$key}" >
   <div class="card col-sm-12" style="max-width: 1000px;background-color:palegreen  ;">
    <div class="card-body" >
    <h3>Phonetic profile</h3>
     <h4 class="card-title">{$zis}&#160;&#160; {string-join($mand-jin, ',')}&#160;&#160; <small>
     <span class="text-muted">廣韻韻目：</span>{$gy//tx:headword}&#160;&#160; 
     <span class="text-muted">反切：</span><strong>{$fq}</strong>　　
     <span class="text-muted">聲調：</span><strong>{$gy//tx:調/text()}</strong>　
     <span class="text-muted">等：</span> <strong>{$gy//tx:等/text()}</strong>&#160;&#160; 
     <span class="text-muted">聲母：</span><strong>{$gy//tx:聲/text()}</strong></small></h4>
    <h5 class="card-subtitle" id="mand-jin" >Gloss: {$gloss}</h5>
    <!--
    <div class="row">
     <div class="col-sm-4">
     <div class="row"></div>
     </div>
     <div class="col-sm-4">B</div>
    </div>
    <div class="row">
     <div class="col-sm-4">Source: {$gy//tx:sources}</div>
     <div class="col-sm-4">{$gy//tx:note}</div>
    </div>
    -->
    <div id="syllables-content" class="accordion">
    
    <!-- Reconstructions -->
    <div class="card">
     <div class="card-header" id="pointers-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#pointers" >
         Reconstructions
        </button>
      </h5>
      </div>
     <div id="pointers" class="collapse" data-parent="#syllables-content">
    <div class="row">
     <div class="col-sm-4"><strong>Middle Chinese</strong>
     {for $s in ($gy//tx:middle-chinese/tx:yundianwang-reconstructions/tx:*|$gy//tx:middle-chinese/tx:authorial-reconstructions/tx:*) return
     <div class="row">
      <div class="col-sm-6"><span class="text-muted">{local-name($s)}</span></div>
      <div class="col-sm-6">{$s}</div>
     </div>
     }
    </div>
    <div class="col-sm-4"><strong>Old Chinese</strong>
    <div><span>潘悟云</span>
      {for $s in $gy//tx:old-chinese/tx:pan-wuyun/tx:* 
      return
     <div class="row">
     <div class="col-sm-6"><span class="text-muted">{local-name($s)}</span></div>
     <div class="col-sm-6">{$s}    </div>
    </div>
    }</div>
    <div><span>鄭張尚芳</span>
    {for $s in $gy//tx:old-chinese/tx:zhengzhang-shangfang/tx:* 
     return
     <div class="row">
     <div class="col-sm-6"><span class="text-muted">{local-name($s)}</span></div>
     <div class="col-sm-6">{$s}    </div>
    </div>
    }</div>
    </div>    
    </div>
    <div class="row">
     <div class="col-sm-4">Source: {$gy//tx:sources}</div>
     <div class="col-sm-4">{$gy//tx:note}</div>
    </div>
    </div>
     </div>
    <!-- Refs -->
    <div class="card">
     <div class="card-header" id="ref-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#ref" >
         References
        </button>
      </h5>
      </div>
      {let $ucd := doc($config:tls-data-root||"/guangyun/ucd.unihan.flat.xml")
      (: there is a bug that affects astral characers - length is reported as 2  :)
      , $cp := tlslib:num2hex(string-to-codepoints(if(string-length($zi)=2) then () else if ($char) then $char else $zi))
      , $cpr := $ucd//ucd:char[@cp=$cp]
      , $cinfo := ("kDefinition", "kRSUnicode", "kFrequency", "kGradeLevel", "kHanyuPinlu", "kFourCornerCode", "kTotalStrokes", "kIICore", "kUnihanCore2020")
      , $read := ("kVietnamese", "kMandarin", "kHanyuPinyin", "kTang", "kJapaneseKun", "kJapaneseOn", "kCantonese", "")
      , $dics := ("kHanYu", "kCihaiT", "kSBGY", "kNelson", "kCowles", "kMatthews", "kPhonetic", "kGSR", "kFenn", "kFennIndex", "kKarlgren", "kMeyerWempe", "kLau", "kKangXi", "kDaeJaweon", "kMorohashi", "kTGHZ2013", "kXHC1983", "kPhonetic")
      , $vars := ("kTraditionalVariant", "kSimplifiedVariant", "kSemanticVariant", "kSpecializedSemanticVariant")
      , $csets := ("cp", "kBigFive", "kCCCII", "kEACC", "kIRG_JSource")
      return
     <div id="ref" class="collapse" data-parent="#syllables-content">
    <div class="row">
     <div class="col-sm-12"><h5>References for {$zi} based on {$ucd//ucd:description/text()}</h5></div>
    </div> 
    <div class="row">
     <div class="col-sm-4">
     <strong>Dictionary references</strong>
     {for $v in $cpr/@* 
      let $n := local-name($v)      
      where $n = $dics
     return
     <div class="row">
      <div class="col-sm-6"><span class="text-muted">{$n}</span></div>
      <div class="col-sm-6">{data($v)}</div>
     </div>
     }
    </div>
    <div class="col-sm-4"><strong>Readings</strong>
    {for $v in $cpr/@* 
      let $n := local-name($v)      
      where $n = $read
     return
     <div class="row">
      <div class="col-sm-6"><span class="text-muted">{$n}</span></div>
      <div class="col-sm-6">{data($v)}</div>
     </div>
     }
   </div>    
    </div>
    <div class="row">
     <div class="col-sm-4"><strong>Character Info</strong>
    {for $v in $cpr/@* 
      let $n := local-name($v)      
      where $n = $cinfo
     return
     <div class="row">
      <div class="col-sm-6"><span class="text-muted">{$n}</span></div>
      <div class="col-sm-6">{data($v)}</div>
     </div>
     }
     </div>
     <div class="col-sm-4"><strong>Codepoints</strong>
    {for $v in $cpr/@* 
      let $n := local-name($v)      
      where $n = $csets
     return
     <div class="row">
      <div class="col-sm-6"><span class="text-muted">{$n}</span></div>
      <div class="col-sm-6">{data($v)}</div>
     </div>
     }
     </div>
    </div>
    </div>
    (: end of ref card :)
    }
    </div>
    </div>
     <div><h4>Phonetically related characters</h4>
     <div><h5>Same 反切</h5>
     <div class="row"> 
       <div class="col-sm-1">字</div>
       <div class="col-sm-1">反切</div>
       <div class="col-sm-1">聲母</div>
       <div class="col-sm-1">等</div>
       <div class="col-sm-1">呼</div>
       <div class="col-sm-1">韻部</div>
       <div class="col-sm-1">聲調</div>
       <div class="col-sm-1">重紐</div>
       <div class="col-sm-1">攝</div>
       <div class="col-sm-1">OC</div>
     </div>
     {for $c in $grc//tx:guangyun-entry[.//tx:fanqie/tx:fanqie-shangzi//tx:graph=$fq[1] and .//tx:fanqie/tx:fanqie-xiazi//tx:graph=$fq[2]]
     return tlslib:format-phonetic($c)}
     </div>
     <div><h5>Same 潘悟云 OC reconstruction</h5>
     {for $c in $grc//tx:guangyun-entry[.//tx:old-chinese/tx:pan-wuyun/tx:oc=$gy//tx:old-chinese/tx:pan-wuyun/tx:oc/text()]
     return tlslib:format-phonetic($c)}
     </div>
     <div><h5>Same 聲母 and 韻部 </h5></div>
     {for $c in $grc//tx:guangyun-entry[.//tx:聲=$gy//tx:聲/text() and .//tx:韻部=$gy//tx:韻部/text()]
     return tlslib:format-phonetic($c)}
     <!--
     <div><h5>Same phonetic</h5></div>
     -->
     </div>
     <div><h4>TLS Usage: Words using {$zi}</h4>
     <ul>
     {for $z in (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:entry[.//tei:orth[. = $zi//text()]]
     let $c:= $z/ancestor::tei:div[@type="concept"]
     , $w:= $z/ancestor::tei:entry
     return
     <li>{$zi}　<a href="concept.html?uuid={$c/@xml:id}#{$z/@xml:id}">{$c/tei:head/text()}</a></li>}
     </ul>
     </div>
     <!-- end of card content -->
     </div>
  <!-- end of card body -->   
  </div>
 </div>
    )
};


declare 
    %templates:wrap
    %templates:default("uuid", "")    
    %templates:default("textid", "")  
function app:bibliography($node as node()*, $model as map(*), $uuid as xs:string, $textid as xs:string){
    <div class="card">
    <div class="card-header">
    <h4 class="card-title"><a class="btn" href="browse.html?type=biblio">Bibliography</a> <button class="btn badge badge-primary ml-2" type="button" onclick="edit_bib('{$uuid}', '{$textid}')">Edit this reference</button></h4>
    </div>
    <div class="card-text">{
    bib:display-mods($uuid)
}</div>
</div>
};


declare function app:obs($node as node(), $model as map(*)){
     let $n := $model?n
     , $facts-def := collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:body/tei:div
     return
     (session:create(),
    <div class="card">
    <div class="card-header">
    <h4 class="card-title">Observations in the TLS　　&#160;<button type="button" class="btn btn-primary" onclick="add_obs()">Add new template</button></h4>
    </div>
    <p></p>
    <div class="card-text">{    
     for $f in $facts-def
     let $t := $f/@type
     group by $t 
     return 
     <div><h4><span class="text-muted">{data($t)}</span></h4>{
     for $ff in $f return
     (
     <p>{$ff/tei:head}　　
     <button class="btn badge badge-primary ml-2" type="button" onclick="show_obs('{$ff/@xml:id}')">Edit template</button>     
     <button class="btn badge badge-secondary ml-2" type="button" onclick="show_obs('{$ff/@xml:id}')">Show observations</button></p>,
     <div id="{$ff/@xml:id}-obs"></div>
     )
     }</div>
    }</div>
    <div class="card-footer">
    <ul class="pagination">
    {for $c in $n/preceding::tei:div[position()< 6]
    return
    <li class="page-item"><a class="page-link" href="char.html?id={$c/@xml:id}">{$c/tei:head/text()}</a></li>
    }    
    <li class="page-item disabled"><a class="page-link">&#171;</a></li>
    <li class="page-item disabled"><a class="page-link">{$n/tei:head/text()}</a></li>
    <li class="page-item disabled"><a class="page-link">&#187;</a></li>
    {for $c in $n/following::tei:div[position()< 6]
    return
    <li class="page-item"><a class="page-link" href="char.html?id={$c/@xml:id}">{$c/tei:head/text()}</a></li>
    }
    </ul>
    </div>
    </div>
)
};

(: lineview, replacement for textview :)
declare 
    %templates:wrap
    %templates:default("prec", 15)
    %templates:default("foll", 15)     
    %templates:default("first", "false")     
function app:lineview($node as node()*, $model as map(*), $location as xs:string?, $mode as xs:string?, $prec as xs:int?, $foll as xs:int?, $first as xs:string)
{
    let $dataroot := $config:tls-data-root
    , $message := (for $k in map:keys($model) return $k) => string-join(",")
    , $l := log:info($app:log, "Loading; $model keys: " || $message)
    return
    (session:create(),
    if (string-length($location) > 0) then
     if (contains($location, '_')) then
      let $textid := tokenize($location, '_')[1]
      let $firstseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$location]
      return
        try {ly:setup-grid(map:merge(($model, map{"targetseg" : $firstseg, "prec" : 0, "foll" : $prec + $foll })))} catch * {
        let $m := "An error occurred, can't display text. Code:" || count($firstseg) || " (firstseg); location:  " || $location 
        return (log:error($app:log, $m), $m)}
     else
      if (not($mode = 'visit') and collection($config:tls-manifests)//mf:manifest[@xml:id=$location]) then 
      krx:show-manifest(collection($config:tls-manifests)//mf:manifest[@xml:id=$location]) 
      else
      let $firstdiv := if ($first = 'true') then 
      (collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]//tei:body/tei:div)[1]
            else
        let $user := sm:id()//sm:real/sm:username/text(),
         $visit := (for $v in collection($config:tls-user-root || "/" || $user)//tei:list[@type="visits"]/tei:item
            let $date := xs:dateTime($v/@modified),
            $target := substring($v/tei:ref/@target, 2)
            order by $date descending
            where starts-with($target, $location)
            return $target)[1]
         return
         if ($visit) then 
         collection($config:tls-texts-root)//tei:seg[@xml:id=$visit]  else 
         (collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]//tei:body)[1]

      let $targetseg := if (local-name($firstdiv) = "seg") then $firstdiv else 
      if ($firstdiv//tei:seg) then ($firstdiv//tei:seg)[1] else  ($firstdiv/following::tei:seg)[1] 
      return
         try {ly:setup-grid(map:merge(($model, map{"targetseg" : $targetseg, "prec" : 0, "foll" : $prec + $foll })))} catch * {
         let $m := "An error occurred, can't display text. Code:" || count($targetseg) || " (targetseg); location:  " || $location 
         return (log:error($app:log, $m), $m)}
    else 
    app:textlist()
    )
};

declare function app:signup($node as node()*, $model as map(*)) {

map {"current-time" : current-dateTime(), "shared-secret" : util:uuid(), "captcha" : "12x13"}
};

declare function app:render($node as node()*, $model as map(*)){
let $question := map{"12x13" : "What is twelve times thirteen? (write the answer in numbers)" }
return
<p>
     <input type="hidden" name="ss" value="{$model?shared-secret}"/>
     <input type="hidden" name="vk" value="{$model?captcha}"/>
     <label>To make sure, only humans sign up, here is a random question:</label>
     <br/>
     <strong>{map:get($question, $model?captcha)}</strong>
     <br/>
     <input name="answer" required="required" ></input>
</p>
};

(:: xx :)
