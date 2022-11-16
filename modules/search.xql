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
function src:query($node as node()*, $model as map(*), $query as xs:string?, $mode as xs:string?, $search-type as xs:string?, $textid as xs:string?)
{
    session:create(),
    let $hits := 
     switch($search-type)
     case $src:search-texts 
     case $src:search-one-text
     case $src:search-tr-lines
     case $src:search-tabulated return 
        src:ngram-query($query, $mode, $search-type, $textid) 
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
    map:merge((
       map:entry("hits", $hits), map:entry("query", $query)))
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
tlslib:get-sw($queryStr, "dic", "core")
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
declare function src:ngram-query($queryStr as xs:string?, $mode as xs:string?, $search-type as xs:string?, $stextid as xs:string?)
{
    let $dataroot := ($config:tls-data-root, $config:tls-texts-root, $config:tls-user-root)
    , $qs := tokenize($queryStr, "[\s;]")
    , $user := sm:id()//sm:real/sm:username/text()
    , $ratings := doc($config:tls-user-root || $user || "/ratings.xml")//text
    , $user-dates-doc := "/db/users/" || $user || "/textdates.xml"
    , $dates := 
        if (exists(doc($user-dates-doc)//date)) then 
         doc($user-dates-doc)//data 
        else 
         doc($config:tls-texts-root || "/tls/textdates.xml")//data
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
    return
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

(:~
 : This is also called from search.html, nested within app:query. 
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
function src:show-hits($node as node()*, $model as map(*), $start as xs:int, $type as xs:string, $mode as xs:string, $search-type as xs:string, $textid as xs:string?)
{
let $query := map:get($model, "query")
    ,$iskanji := tlslib:iskanji($query) 
    ,$title := if (string-length($textid) > 0) then collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:titleStmt/tei:title/text() else ()
    (: no of results to display :)
    ,$resno := 50
    ,$map := session:get-attribute($src:SESSION || ".types")
    ,$user := sm:id()//sm:real/sm:username/text()
    ,$qs := tokenize($query, "[\s;]")
    ,$q1 := substring($qs[1], 1, 1)
    ,$rat := "Go to the menu -> Browse -> Texts to rate your favorite texts."
    ,$qc := for $c in string-to-codepoints($query) 
       where $c > 255
       return  codepoints-to-string($c)
    ,$h1 := <h1>Searching in {map:get($config:search-map, $search-type)} for <mark>{$query}</mark>
    {if (string-length($type) > 0) then 
    <span>in {map:get($config:lmap, $type)}</span>
    else ()}</h1>
    return
    <div>{$h1}
    {
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
     let $h4 := <h4>Found {count($model?hits)} matches,  <span>showing {$start} to {min((count($model?hits), $start + $resno -1))}</span></h4>
     , $txtmatchcount := count(for $h in $model?hits let $x := $h/@xml:id where starts-with($x, $textid) return $h)
     , $trmatch := count(for $h in $model?hits let $x := "#" || $h/@xml:id
                   return collection($config:tls-translation-root)//tei:seg[@corresp=$x])
    , $p :=     <p>
     {if ($start = 1) then      
      tlslib:search-top-menu($search-type, $query, $txtmatchcount, $title, $trmatch, $textid, $qc, count($model?hits), $mode) else () }
     { if ($user = "guest") then () else
       if ($mode = "rating") then 
    ("&#160;Sorting by text rating. " , <a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type={$search-type}&amp;mode=date">Click here to sort by text date instead. </a> )
     else
    ("&#160;Sorting by text date. " , <a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type={$search-type}&amp;mode=rating" title="{$rat}">Click here to sort your favorite texts first. </a>)}</p>
    , $nav := <nav aria-label="Page navigation">
  <ul class="pagination">
    <li class="page-item"><a class="page-link {if ($start = 1) then "disabled" else ()}" href="search.html?query={$query}&amp;start={$start - $resno}&amp;textid={$textid}&amp;search-type={$search-type}{if (string-length($mode) > 0) then concat("&amp;mode=", $mode) else ()}">&#171;</a></li>
    <li class="page-item"><a class="page-link" href="search.html?query={$query}&amp;start={$start + $resno}&amp;textid={$textid}&amp;search-type={$search-type}{if (string-length($mode)>0) then concat("&amp;mode=", $mode) else ()}">&#187;</a></li>
  </ul>
</nav>
     return 
     src:show-text-results(map{"h4": $h4, "p" : $p, "nav": $nav, "hits": $model?hits, "start" : $start, "resno" : $resno, "q1" : $q1, "query": $query, "search-type" : $search-type })
    case $src:search-field return
     let $h4:=    <h4>Found {if (string-length($type) > 0) then (count(map:get($map, $type)),<span>; 
    displaying matches {$start} to {min((count(map:get($map, $type)), xs:int($start) + $resno))}</span>)
    else (count($model("hits")), <span> matches</span>)} </h4>
     return
     src:show-field-results(map{"h4" : $h4, "hits": $model?hits, "map":$map, "query" : $query, "search-type" : $search-type, "type" : $type, "start" : $start, "resno" : $resno})
    case $src:search-dic return
     src:show-dic-results(map:merge(($model, map:entry("start",$start), map:entry("qc", $qc))))
    default return "Unknown search type",
    <div class="col-sm-0">{wd:quick-search-form('title')}</div>
    }</div>
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
    (: this is search-type = "4", in fields :)
     $map?h4,    
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
    <div>{$map?h4, $map?p}
    <table class="table">
    {for $hx at $c in subsequence($map?hits, $map?start, $map?resno)
      for $h in if ($map?search-type=$src:search-trans) then $hx else util:expand($hx)//exist:match/ancestor::tei:seg
      let $loc := if ($map?search-type=$src:search-trans) then substring($h/@corresp,2) else $h/@xml:id,
      $m1 := substring(($h/exist:match)[1]/text(), 1, 1),
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
        <td>{$c + $map?start -1}</td>
        <td><a href="textview.html?location={$loc}&amp;query={$map?query}">{$title, " / ", $head}</a>
        </td>
        {if ($map?search-type = $src:search-trans) then  
        (<td>{$cseg}</td>,<td>{$h}</td>) else
        <td>{ 
        for $sh in $h/preceding-sibling::tei:seg[position()<4] return tlslib:proc-seg($sh),
        tlslib:proc-seg($h),
        (: this is a hack, it will probably show the most recent translation if there are more, but we want to make this predictable... :)
        for $sh in $h/following-sibling::tei:seg[position()<4] return tlslib:proc-seg($sh)}
        {if (exists($tr)) then (<br/>,"..." , $tr[last()] , "...") else ()
        }</td>
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
    <td class="previous">...{$node/preceding::text()[fn:position() < 10]}</td>
    <td class="hi"><mark>
    {
      if ($link) then
        <a href="{$config/@link}">{$node/text()}</a>
      else
        $node/text()
    }
    </mark></td>
    <td class="following">{$node/following::text()[fn:position() < 10]}...</td>
  </tr>
};




declare function src:advanced-search($query, $mode){
<div><h3>Advanced Search</h3>
</div>
};
