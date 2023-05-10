xquery version "3.1";
(:~
: This module provides the search functions used by the web version
: of the TLS. 
: 2022-11-16
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace src="http://hxwd.org/search";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://hxwd.org/config" at "config.xqm";
import module namespace krx="http://hxwd.org/krx-utils" at "krx-utils.xql";
import module namespace wd="http://hxwd.org/wikidata" at "wikidata.xql"; 
import module namespace bib="http://hxwd.org/biblio" at "biblio.xql";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace log="http://hxwd.org/log" at "log.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tx="http://exist-db.org/tls";

declare variable $src:log := $config:tls-log-collection || "/app";

declare variable $src:SESSION := "tls:results";

declare variable $src:search-texts := "1";
declare variable $src:search-dic   := "2";
declare variable $src:search-trans := "3";
declare variable $src:search-field := "4";
declare variable $src:search-one-text := "5";
declare variable $src:search-tr-lines := "6";
declare variable $src:search-titles := "7";
declare variable $src:search-tabulated := "8";
declare variable $src:search-advanced := "9";
declare variable $src:search-bib := "10";

(: search related functions :)
(:~
: This is called from search.html
: @param  $query  This is the querystring from the search dialog
: @param  $search-type The type of search: 1=text, 2=dictionary 3=translation
:)
declare 
    %templates:wrap
function src:query($node as node()*, $model as map(*), $query as xs:string?, $mode as xs:string?, $search-type as xs:string?, $textid as xs:string?, $genre as xs:string?, $cat as xs:string?)
{
    session:create(),
    let $hits := 
     switch($search-type)
     case $src:search-texts 
     case $src:search-one-text
     case $src:search-tr-lines
     case $src:search-tabulated return 
        src:ngram-query($query, $mode, $search-type, $textid, $genre, $cat) 
     case $src:search-dic return
      (: searching for kanji in dictionary, eg. the words in concepts :)
       src:dic-query($query, $mode)
     case $src:search-trans return
      (: searching for word in translations :)
       src:tr-query($query, $mode)
     case $src:search-titles return
      (: searching for word in titles :)
       src:title-query($query, $mode)
     case $src:search-field return
       src:do-query($query, $mode)
     case $src:search-advanced return
       src:advanced-search($query, $mode)
     case $src:search-bib return
       bib:biblio-search($query, $mode, $textid)
     default return "Unknown search type"
    let $store := session:set-attribute($src:SESSION, $hits)
    return
    map{"hits" : $hits, "query" : $query, "mode" : $mode, "search-type" : $search-type, "textid" : $textid, "resno" : 50}
};

declare function src:do-query($queryStr as xs:string?, $mode as xs:string?)
{
    let $dataroot := ($config:tls-data-root, $config:tls-texts-root, $config:tls-user-root, $config:tls-translation-root),
    $query := src:create-query(lower-case($queryStr), $mode),
    $hits := for $h in collection($dataroot)//tei:div[ft:query(., $query)]
            where $h/@type != "swl" return $h,
    $types := map:merge(for $hit in $hits
        let $type := if ($hit/@type) then data($hit/@type) else "none"
        group by $type
        return map:entry($type, $hit)),
    $store := session:set-attribute($src:SESSION || ".types", $types)
    for $hit in $hits
    order by ft:score($hit) descending
    return $hit
};



declare
    %templates:wrap
function src:from-session($node as node()*, $model as map(*)) {
    map:entry("hits", session:get-attribute($src:SESSION))
};

declare %templates:default("start", 1)
function src:show-hits-short($node as node()*, $model as map(*),$start as xs:int)
{   <div>
    {for $hit at $p in subsequence($model("hits"), $start, 10)
(:    let $kwic := kwic:summarize($hit, <config width="40"/>, app:filter#2):)
    let $kwic := src:get-kwic($hit, <config width="40"/>, <a></a>)
    return
    <div class="tls-concept" xmlns="http://www.w3.org/1999/xhtml">
      <h3>{$hit/ancestor::tei:head/text()}</h3>
      <span class="number">{$start + $p - 1}</span>
      <span>{data($hit/@type)}</span>
      { $kwic }
    </div>
    }</div>
};    



declare %private function src:filter($node as node(), $mode as xs:string?) as text()?
{
    if ($mode eq 'before') then 
    text {concat($node, ' ') }
    else 
    text {concat(' ', $node) }
};

(: temporarily added the search code here to see if the search is working at all
 this should just be count($model("hits"))
:)
declare
    %templates:wrap
function src:hit-count($node as node()*, $model as map(*), $query as xs:string?) {
   count($model("hits"))
};



(: query in dictionary :)
declare function src:dic-query($queryStr as xs:string?, $mode as xs:string?)
{
tlslib:get-sw($queryStr, "dic", "core", "")
};

(: query in translation :)
declare function src:tr-query($queryStr as xs:string?, $mode as xs:string?)
{
  let $user := sm:id()//sm:real/sm:username/text()
  let $dataroot := ($config:tls-translation-root, $config:tls-user-root || $user || "/translations")
  let $w := collection($dataroot)//tei:seg[contains(. , $queryStr)]
  for $a in $w
  return $a
};

(: paragraph based query :)
declare function src:ngram-query($queryStr as xs:string?, $mode as xs:string?, $search-type as xs:string?, $stextid as xs:string?, $genre as xs:string?, $cat as xs:string?)
{
    let $dataroot := ($config:tls-data-root, $config:tls-texts-root, $config:tls-user-root)
    , $qs := tokenize($queryStr, "[\s;]")
    , $user := sm:id()//sm:real/sm:username/text()
    , $ratings := doc($config:tls-user-root || $user || "/ratings.xml")//text
    , $user-dates-doc := "/db/users/" || $user || "/textdates.xml"
    , $dates := 
        if (exists(doc($user-dates-doc)//data)) then 
         doc($user-dates-doc)//data 
        else 
        doc($config:tls-texts-meta  || "/textdates.xml")//data
     (: HACK: if no login, use date mode for sorting :)
    , $mode := if ($user = "guest") then "date" else $mode
    , $pmatches := 
      if  (count($qs) > 1) then 
         (collection($dataroot)//tei:p[ngram:wildcard-contains(., $qs[1]) and ngram:wildcard-contains(., $qs[2])] |
         collection($dataroot)//tei:lg[ngram:wildcard-contains(., $qs[1]) and ngram:wildcard-contains(., $qs[2])])
      else
       (: 2022-02-24 for one char searches, go only in tls texts; this needs more discussion... :)
       if ($search-type = $src:search-one-text) then 
        (collection($dataroot)//tei:TEI[@xml:id=$stextid]//tei:p[ngram:wildcard-contains(., $qs[1])] |
        collection($dataroot)//tei:TEI[@xml:id=$stextid]//tei:lg[ngram:wildcard-contains(., $qs[1])])
       else
        if (string-length($qs[1]) < 2) then
         (collection($config:tls-texts-root || "/tls")//tei:p[ngram:wildcard-contains(., $qs[1])],
         collection($config:tls-texts-root || "/tls")//tei:lg[ngram:wildcard-contains(., $qs[1])])
        else
         (collection($dataroot)//tei:p[ngram:wildcard-contains(., $qs[1])] | 
         collection($dataroot)//tei:lg[ngram:wildcard-contains(., $qs[1])])
    , $matches := 
       (: this messes up the search display, disabling for now :)
       if (contains($queryStr, ";xx")) then 
          for $s in $pmatches//tei:seg
          return
           if (matches($s, $qs[1]) or matches($s, $qs[2])) then
              $s else ()
       else $pmatches
    , $hit-res := 
    for $hit in $matches
     let $textid := substring-before(tokenize(document-uri(root($hit)), "/")[last()], ".xml"),
      (: for the CHANT text no text date data exist, so we use this flag to cheat a bit :)
      $flag := substring($textid, 1, 3),
      $filter := 
       if ($search-type = $src:search-one-text) then $stextid = $textid 
       else 
       if ($search-type = $src:search-tr-lines) then 
         let $x := "#" || $hit/@xml:id
         return collection($config:tls-translation-root)//tei:seg[@corresp=$x]
       else true(),
      $r := 
       if ($mode = "rating") then 
         (: the order by is ascending because of the dates, so here we inverse the rating :)
         if ($ratings[@id=$textid]) then - xs:int($ratings[@id=$textid]/@rating) else 0
       else
        switch ($flag)
         case "CH1" return 0
         case "CH2" return 300
         case "CH7" return 700
         case "CH8" return -200
         default return
          if (string-length($dates[@corresp="#" || $textid]/@notafter) > 0) then tlslib:getdate($dates[@corresp="#" || $textid]) else 0
(:    let $id := $hit/ancestor::tei:TEI/@xml:id :)     
    order by $r ascending
    where $filter
    return $hit 
   return
   if (string-length($cat) > 0) then src:facets-filter-hits($hit-res, $genre, $cat) else $hit-res 
};




declare function src:title-query($query, $mode){
let $dataroot := ($config:tls-texts-root, $config:tls-user-root)
for $t in collection($dataroot)//tei:titleStmt/tei:title[contains(., $query)]
return $t
};

declare function src:create-query($queryStr as xs:string?, $mode as xs:string?)
{
<query>
    {
    if ($mode eq 'any') then 
        for $term in tokenize($queryStr, '\s')
        return
        <term occur="should">{$term}</term>
    else if ($mode eq 'all') then
        for $term in tokenize($queryStr, '\s')
        return
        <term occur="must">{$term}</term>
    else if ($mode eq 'phrase') then
        <phrase>{$queryStr}</phrase>
    else 
        <near>{$queryStr}</near>
    }
</query>
};

declare
%templates:default("type", "")  (: type is only relevant for advanced search starting from the search landing page for non-Kanji generell search :)
function src:show-hits-h1($node as node()*, $map as map(*),  $type as xs:string){
let $st :=  if (string-length($type) > 0) then map:get($config:search-map, $map?search-type) || "/" || map:get($config:lmap, $type) else map:get($config:search-map, $map?search-type)
return
if ($map?search-type = "10") then () else
<h1>Searching in <strong>{$st}</strong> for <mark class="chn-font">{$map?query}</mark></h1>
};

declare
%templates:default("start", 1)
%templates:default("type", "")  (: type is only relevant for advanced search starting from the search landing page for non-Kanji generell search :)
function src:show-hits-h4($node as node()*, $model as map(*), $start as xs:int, $type as xs:string){
let $query := $model?query
  , $map := session:get-attribute($src:SESSION || ".types")
  , $cnt := if (string-length($type) > 0) then count(map:get($map, $type)) else count($model?hits)
return
(: if type = 10 do not display here :)
if ($model?search-type = "10") then () else
<h4>Found {$cnt} {if ($cnt = 1) then " match" else " matches"},  <span>showing {$start} to {min(($cnt, $start + $model?resno -1))}</span></h4>

};

(: for a $hit, we find the value associated with the requested genre :)
 
declare function src:facets-get-metadata($hit, $field){
    let $header := $hit/ancestor::tei:TEI/tei:teiHeader
    return
        switch ($field)
            case "title" return 
                string-join((
                    $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                    $header//tei:titleStmt/tei:title
                ), " - ")
            case "tls-dates"
            case "kr-categories"
            case "tls-regions" return 
                let $res := for $t in $header//tei:textClass/tei:catRef[@scheme="#"||$field]/@target return substring($t, 2)
                return
                if (string-length(string-join($res)) > 0) then $res else "notav"
            case "extent" return
                $header//tei:extent/tei:measure[@unit="char"]/@quantity
            case "genre" return ()
            default return ()
};


(: We receive the result-set and calculate the count on the nodes 
@hits is the result set
@genre is the desired genre 
:)

declare function src:facets-map($hits, $genre){
    map:merge(
    for $h in $hits
    let $md := src:facets-get-metadata($h, $genre)
    , $grp := string-join($md[1])
    group by $grp
    where string-length($grp) > 0
    return
    map:entry($grp, count($md))
    )
};

declare function src:facets-add-n($n, $map){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@n,
    if ($map?($id)) then attribute n {$map?($id)} else (),
    for $nn in $n/node() return src:facets-add-n($nn, $map)}
  case element(*)
   return $n
  default return $n
};

declare function src:facets-sum-n($n, $map){
  typeswitch ($n)
  case element(tei:category) return
   let $id := $n/@xml:id
   , $nv := if ($n/@n) then xs:int($n/@n) else 0
   , $sum := sum(($nv, for $s in $n//tei:category/@n return xs:int($s)))
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@sum,
    if ($n/tei:category) then if ($sum > $nv) then attribute sum {$sum} else () else (),
    for $nn in $n/node() return src:facets-sum-n($nn, $map)}
  case element(*)
   return $n
  default return $n
};

(: sum of characters on the same level :)
declare function src:lev-sum($node){
let $p := $node/parent::tei:category
, $cn := $p/tei:category
, $s := sum(for $t in $cn return 
    if ($t/@sum) then xs:int($t/@sum)
    else if ($t/@n) then xs:int($t/@n) 
    else 0)
   return $s
};

declare function src:facets-ratio($n){
  typeswitch ($n)
  case element(tei:category) return
   let $sum := src:lev-sum($n)
   , $this := if ($n/@sum) then xs:int($n/@sum)
    else if ($n/@n) then xs:int($n/@n) 
    else 0
   , $cur-ratio := if ($this > 0 and $sum > 0) then $this div $sum else ()
   return
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* except $n/@res-ratio,
    if ($cur-ratio and $n/@ratio) then attribute res-ratio {$cur-ratio div xs:float($n/@ratio)} else () ,
    for $nn in $n/node() return src:facets-ratio($nn)}
  case element(*)
   return $n
  default return $n
};

declare function src:facets-prune($n){
  typeswitch ($n)
  case element(tei:category) return
   if ($n/@n or xs:int($n/@sum) > 0 ) then 
    element {QName(namespace-uri($n),local-name($n))} {
    $n/@* ,
    for $nn in $n/node() return src:facets-prune($nn)}
    else ()
  case element(*)
   return $n
  default return $n
};
(: convert the pruned category tree to HTML for jstree :)
declare function src:facets-html($node, $map, $baseid, $url){
  <div  id="chartree">
  <ul>{
  for $n in $node/node()
  return
  typeswitch ($n)
  case element(tei:category) return 
    src:facets-html-node($n, $baseid, $url)
  case element(tei:catDesc) return 
    (<span class="anchor" id="{$baseid}--head"></span>,
    <h3 >{$n/text()}</h3>)
  default return $n
  }
  {if ($map?notav) then 
   if (string-length($url) > 0) then 
  <li id="{$baseid}---notav"><a href="{$url}&amp;genre={$baseid}&amp;cat=notav" onclick="#">Not assigned <span>{$map?notav}</span></a></li>
  else
  <li id="{$baseid}---notav">Not assigned</li>
  else ()}
  </ul></div>
};


declare function src:facets-html-node($n, $baseid, $url){
   <li id="{$baseid}---{$n/@xml:id}">
   {if (string-length($url) > 0) then 
   <span>
   <a title="Click here to filter on this category" class="mr-2 ml-2" href="{$url}&amp;genre={$baseid}&amp;cat={$n/@xml:id}">{$n/tei:catDesc/text()}</a>
   {if ($n/@sum) then <span title="Aggregate over this and lower levels" class="badge badge-primary">{data($n/@sum)}</span> else ()}
   {if ($n/@n) then <span title="Count on this level only" class="badge badge-secondary">{data($n/@n)}</span> else ()}
   {if ($n/@res-ratio) then <span title="Ratio of this result towards the expected result" class="badge badge-secondary">{data($n/@res-ratio)}</span> else ()}
   </span>
   else 
   <span><span class="md2">{$n/tei:catDesc/text()}</span>　(<small class="md-2 text-muted">{data($n/@xml:id)}</small>)</span> }
   {if ($n/tei:category) then 
    <ul>{for $c in $n/tei:category
    return src:facets-html-node($c, $baseid, $url)}</ul>
    else ()
   }</li>
};

declare function src:facets($node as node()*, $model as map(*), $query as xs:string?, $mode as xs:string?, $search-type as xs:string?, $textid as xs:string?){
 let $genres := ("tls-dates", "kr-categories")
 (: query=國語&start=1&search-type=1&textid=KR2o0001&mode=# :)
  , $umode := if (string-length($mode) > 0) then "&amp;mode="||$mode else ""
  , $utextid := if (string-length($textid) > 0) then "&amp;textid="||$textid else ""
 , $url := "search.html?query="||$query||"&amp;search-type="||$search-type || $umode || $utextid 
 return
<div>
<h1>Facets</h1>
<p></p>
<div>{
for $g in $genres
let $map := src:facets-map($model?hits, $g)
, $tax := doc($config:tls-texts||"/meta/taxonomy.xml")//tei:category[@xml:id=$g]
, $tree :=  src:facets-add-n($tax, $map) => src:facets-sum-n($map)   => src:facets-prune()
, $tree2 := src:facets-ratio($tree)
return
<p>
{src:facets-html($tree2, $map, $g, $url )}
</p>
}
</div>
</div>
};

(: apply the filter to the result set 
TODO: add the metadata to result set in src:ngram-query
:)
declare function src:facets-filter-hits($hits, $genre, $cat){
 let $cats := if ($cat = 'notav') then $cat else src:facets-expand-cat($genre, $cat)
 return 
 for $h in $hits
   let $md := src:facets-get-metadata($h, $genre)
   where $md = $cats
   return $h
};

(: get the full set of relevant category ids :)

declare function src:facets-expand-cat($genre, $cat){
let $tax := doc($config:tls-texts||"/meta/taxonomy.xml")//tei:category[@xml:id=$genre]//tei:category[@xml:id=$cat]
return
(data($tax/@xml:id), for $t in $tax//tei:category return data($t/@xml:id))
};

(: only add to query if set :)

declare function src:maybe-query($type, $item){
if (string-length($item)>0) then "&amp;"||$type||"="||$item else ()
};

(:~
 : This is also called from search.html, nested within src:query. 
 : Paged result display is achieved here.
 : Search type 5 is "limit search to text id"
 : Search type 6 is "Search only in text lines with translation"
 : 7 is title search
 : 8 is search results tabulated by text id
:)


declare 
%templates:default("start", 1)
%templates:default("type", "")  (: type is only relevant for advanced search starting from the search landing page for non-Kanji generell search :)
%templates:default("mode", "")   (: for text display sort by date or rating :)
%templates:default("search-type", "1")
%templates:default("textid", "")
%templates:default("genre", "")
%templates:default("cat", "")
function src:show-hits($node as node()*, $model as map(*), $start as xs:int, $type as xs:string, $mode as xs:string, $search-type as xs:string, $textid as xs:string?, $genre as xs:string?, $cat as xs:string?)
{
let $query := $model?query
    ,$iskanji := tlslib:iskanji($query) 
    ,$title := if (string-length($textid) > 0) then collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:titleStmt/tei:title/text() else ()
    (: no of results to display :)
    ,$resno := $model?resno
    ,$map := session:get-attribute($src:SESSION || ".types")
    ,$user := sm:id()//sm:real/sm:username/text()
    ,$qs := tokenize($query, "[\s;]")
    ,$q1 := substring($qs[1], 1, 1)
    ,$rat := "Go to the menu -> Browse -> Texts to rate your favorite texts."
    ,$burl := "search.html?query="||$query||"&amp;search-type="||$search-type || src:maybe-query("textid",$textid) || src:maybe-query("genre",$genre) || src:maybe-query("cat",$cat)
    ,$qc := for $c in string-to-codepoints($query) 
       where $c > 255
       return  codepoints-to-string($c)
    return
    switch ($search-type)
    case $src:search-advanced return
       src:advanced-search($query, $mode)
    case $src:search-bib return 
       bib:biblio-search($query, $mode, $textid)
    case $src:search-titles return
      src:show-title-results(map{"hits": $model?hits, "query" : $query})
    case $src:search-tabulated return 
      let $p := tlslib:search-top-menu($search-type, $query, 0, "", 0, $textid, $qc, count($model?hits), $map?mode)
      return
      src:show-tab-results(map{"p": $p, "hits" : $model?hits, "mode" : $map?mode, "query":$query}) 
    case $src:search-texts 
    case $src:search-one-text
    case $src:search-trans
    case $src:search-tr-lines return
     let $hits := if (string-length($cat) > 0) then src:facets-filter-hits($model?hits, $genre, $cat) else $model?hits
     let $txtmatchcount := count(for $h in $model?hits let $x := $h/@xml:id where starts-with($x, $textid) return $h)
     , $trmatch := count(for $h in $model?hits let $x := "#" || $h/@xml:id
                   return collection($config:tls-translation-root)//tei:seg[@corresp=$x])
    , $p :=     <p>
     {if ($start = 1) then      
      tlslib:search-top-menu($search-type, $query, $txtmatchcount, $title, $trmatch, $textid, $qc, count($hits), $mode) else () }
     { if ($user = "guest") then () else
       if ($mode = "rating") then 
    ("&#160;Sorting by text rating. " , <a class="btn badge badge-light" href="{$burl}&amp;start=1&amp;mode=date">Click here to sort by text date instead. </a> )
     else
    ("&#160;Sorting by text date. " , <a class="btn badge badge-light" href="{$burl}&amp;start=1&amp;mode=rating" title="{$rat}">Click here to sort your favorite texts first. </a>)}</p>
    , $nav := <nav aria-label="Page navigation">
  <ul class="pagination">
    <li class="page-item"><a class="page-link {if ($start = 1) then "disabled" else ()}" href="{$burl}&amp;start={$start - $resno}{src:maybe-query("mode", $mode)}">&#171;</a></li>
    <li class="page-item"><a class="page-link" href="{$burl}&amp;start={$start + $resno}{src:maybe-query("mode", $mode)}">&#187;</a></li>
  </ul>
</nav>
     return 
     try {
     src:show-text-results(map{"p" : $p, "nav": $nav, "hits": $hits, "start" : $start, "resno" : $resno, "q1" : $q1, "query": $query, "search-type" : $search-type }) } catch * {()}
    case $src:search-field return
     src:show-field-results(map{"hits": $model?hits, "map":$map, "query" : $query, "search-type" : $search-type, "type" : $type, "start" : $start, "resno" : $resno})
    case $src:search-dic return
     src:show-dic-results(map:merge(($model, map:entry("start",$start), map:entry("qc", $qc))))
    default return "Unknown search type",
    <div class="col-sm-0">{wd:quick-search-form('title')}</div>
};

(:      
 :)

declare function src:show-dic-results($map as map(*)){
    <div>
    <p>{if ($map?start = 1) then tlslib:linkheader($map?qc) else ()}</p>
    <ul>
    {for $h at $c in map:get($map, "hits")
    return $h
    }
    </ul>
    </div>    
};

declare function src:show-field-results($map as map(*)){
    if (string-length($map?type) > 0) then 
<div>{
      src:get-more($map?type, xs:int($map?start), $map?resno)}
    <nav aria-label="Page navigation">
      <ul class="pagination">
        <li class="page-item"><a class="page-link {if (xs:int($map?start) = 1) then "disabled" else ()}" href="search.html?query={$map?query}&amp;search-type={$map?search-type}&amp;type={$map?type}&amp;start={$map?start - $map?resno}">&#171;</a></li>
        <li class="page-item"><a class="page-link" href="search.html?query={$map?query}&amp;search-type={$map?search-type}&amp;type={$map?type}&amp;start={$map?start + $map?resno}">&#187;</a></li>
      </ul>
     </nav>
     </div>
    else  
    <div>
    <ul>{
      for $t in map:keys($map?map)
     order by $t
      return <li><a href="#{data($t)}-link" title="{data($t)}">{map:get($config:lmap, $t)}</a>, {count(map:get($map?map, $t))}</li>}</ul>
    {for $t in map:keys($map?map)
      let $hitcount := count(map:get($map?map, $t))
     order by $t
     return
     <div id="{data($t)}-link"><h4>{map:get($config:lmap, $t)} <span class="badge badge-light">{$hitcount}</span></h4>
     <ul>{      src:get-more($t, 1, 3) }
     </ul>
     { if ($hitcount > 3) then 
     <a href="search.html?query={$map?query}&amp;search-type={$map?search-type}&amp;type={$t}&amp;start=1">Show more...</a>
     else ()}
     </div>
     }
    </div>

};


declare function src:show-text-results($map as map(*)){
    <div>{$map?p}
    <table class="table">
    {for $hx at $c in subsequence($map?hits, $map?start, $map?resno)
      for $h in if ($map?search-type=$src:search-trans) then $hx else try { util:expand($hx)//exist:match/ancestor::tei:seg } catch * {"x"}
      let $loc := if ($map?search-type=$src:search-trans) then substring($h/@corresp,2) else $h/@xml:id,
      $m1 := try { substring(($h/exist:match)[1]/text(), 1, 1) } catch * {"x"},
      $cseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$loc],
      $head :=  $cseg/ancestor::tei:div[1]/tei:head[1]//text() ,
      $title := $cseg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
(:     at some point use this to select the translation the user prefers
      $tr := tlslib:get-translations($model?textid),
      $slot1-id := tlslib:get-content-id($model?textid, 'slot1', $tr),:)
      $tr := collection($config:tls-translation-root)//tei:seg[@corresp="#"||$h/@xml:id]
      where if ($map?search-type=$src:search-trans) then $m1 = $m1 else $m1 = $map?q1
    return
      <tr>
        <td class="chn-font">{$c + $map?start -1}</td>
        <td><a href="textview.html?location={$loc}&amp;query={$map?query}">{$title, " / ", $head}</a>
        </td>
        {if ($map?search-type = $src:search-trans) then  
        (<td>{$cseg}</td>,<td>{$h}</td>) else
        <td class="chn-font">{ try { 
        for $sh in $h/preceding-sibling::tei:seg[position()<4] return tlslib:proc-seg($sh,map{"punc" : true()}),
        tlslib:proc-seg($h, map{"punc" : true()}),
        (: this is a hack, it will probably show the most recent translation if there are more, but we want to make this predictable... :)
        for $sh in $h/following-sibling::tei:seg[position()<4] return tlslib:proc-seg($sh, map{"punc" : true()})} catch * {()}}
        {if (exists($tr)) then (<br/>,"..." , $tr[last()] , "...") else ()
        } </td>
        }
        </tr>
    }
    </table>
    {$map?nav}
    </div>

};


declare function src:show-tab-results($map as map(*)){
    <div><p>Found {count($map?hits)} matches, shown by text.<br/>
    {$map?p}
    </p><ul>{
    for $h in $map?hits
    let $loc := $h/ancestor::tei:TEI/@xml:id
    , $tit := $h/ancestor::tei:TEI//tei:titleStmt/tei:title/text()
    , $hcnt := count($h)
    group by $loc
    order by sum($hcnt) descending
    return
    <li><a href="search.html?query={$map?query}&amp;start=1&amp;search-type=5&amp;textid={$loc}&amp;mode={$map?mode}">{data($loc[1])}　{$tit[1]} </a>　{sum($hcnt)} match(es)</li>
    }
    </ul></div>
};

declare function src:show-title-results ($map as map(*)){
    <div><h2>Existing texts in TLS:</h2>
    <ul>{
    for $h in $map?hits
    let $loc := $h/ancestor::tei:TEI/@xml:id
    return
    <li><a href="textview.html?location={$loc}">{data($loc) || " " || data($h)}</a> 
    {wd:display-qitems(data($loc),'title',data($h))}</li>}
    </ul>
    <h2>Texts in the Kanseki Repository:</h2>
    <ul>{
       for $w in 
       if (matches($map?query, "^[A-Z]"))  then  
          if (starts-with($map?query, "KR")) then 
            doc($config:tls-add-titles)//work[contains(@krid, $map?query)]
          else 
            doc($config:tls-add-titles)//work[altid[contains(., $map?query)]]
        else 
          doc($config:tls-add-titles)//work[title[contains(., $map?query)]]
      let $h :=  $w/title
      , $kid := data($w/@krid)
      , $tls := $w/@tls-added
      , $req := if ($w/@request) then <span id="{$kid}-req">　Requests: {count(tokenize($w/@request, ','))}</span> else ()
      , $but := <button type="button" class="btn btn-primary btn-sm" onclick="text_request('{$kid}')">Request for TLS</button>
      , $av := not($w/note) 
      order by $kid
      where string-length($kid) > 5
      return if ($tls) then 
           <li><a href="textview.html?location={$kid}">{data($kid) || " " || data($h)}</a> 
           {wd:display-qitems(data($kid),'title',data($h))}
           </li>
            else
          <li>{if ($av) then $but else ()}　{$kid || " " || $h/text() || " "} <span class="text-muted"><small>{ string-join($w/altid, " / ")}</small></span>  {$req} 
           {wd:display-qitems(data($kid),'title',data($h))}
           {if ($av) then 
             <span class="ml-2">{
              <a class="btn badge badge-light" target="kanripo" title="View {data($h)} in Kanseki Repository (External link)" style="background-color:paleturquoise" href="https://www.kanripo.org/text/{data($kid)}/">KR</a>}</span> 
            else ()}
           </li>
    }
    </ul>
 </div>
};


(:~ 
:)
declare %private function src:get-more($t as xs:string, $start as xs:int, $count as xs:int){
    let $map := session:get-attribute($src:SESSION || ".types")
     for $h in subsequence(map:get($map, $t), $start, $count)
(:      let $kwic := kwic:summarize($h, <config width="40"/>, app:filter#2),:)
    let $expanded := util:expand($h, "add-exist-id=all")
    return
    (: if there is more than one match, they could be expanded here. Maybe make this optional? 
    for the time being, disabled, thus expanding only one match:)
    for $match in subsequence($expanded//exist:match, 1, 1)
(:    let $kwic := kwic:summarize($hit, <config width="40"/>, app:filter#2):)
     let $kwic := src:get-kwic($match, <config width="40"/>, <a></a>),
      $root := $h/ancestor-or-self::tei:div[@type="concept" or @type="taxchar" or @type="syn-func" or @type="sem-feat"],
      $uplink := if ($root) then $root/@xml:id else (),
      $head := $root/tei:head/text()
      (: $h is a div element, so this does not seem to work... :)
     return
         <li>{if ($root) 
         then <strong>
         {
         if ($t = "syn-func" or $t = "sem-feat") then
         <a href="browse.html?type={$t}&amp;id=#{$uplink}" title="{substring-after(document-uri(root($h)), $config:tls-data-root)}"
         >{$head}</a>
         else if ($t = "taxchar") then
         <a href="char.html?id={$uplink}" title="{substring-after(document-uri(root($h)), $config:tls-data-root)}"
         >{$head}</a>
         else 
         <a href="concept.html?uuid={$uplink}#{$t}" title="{substring-after(document-uri(root($h)), $config:tls-data-root)}"
         >{$head}</a>
         }</strong> 
         else <strong>{substring-after(document-uri(root($h)), $config:tls-data-root)}#{$t}</strong>}
         {$kwic}</li>
};


declare function src:get-kwic($node as element(), $config as element(config), $link) {
  <tr>
    <td class="previous chn-font">...{$node/preceding::text()[fn:position() < 10]}</td>
    <td class="hi chn-font"><mark>
    {
      if ($link) then
        <a href="{$config/@link}">{$node/text()}</a>
      else
        $node/text()
    }
    </mark></td>
    <td class="following chn-font">{$node/following::text()[fn:position() < 10]}...</td>
  </tr>
};




declare function src:advanced-search($query, $mode){
<div><h3>Advanced Search</h3>
</div>
};
