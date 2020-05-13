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
declare namespace json = "http://www.json.org";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://hxwd.org/config" at "config.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic"
    at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";


declare variable $app:SESSION := "tls:results";
declare variable $app:tmap := map{
"1" : "texts",
"2" : "dictionary",
"3" : "translations"
};
declare variable $app:lmap := map{
"zh" : "Modern Chinese",
"och" : "Old Chinese",
"syn-func" : "Syntactic Functions",
"sem-feat" : "Semantic Features",
"word" : "Words",
"char" : "Chars",
"taxchar" : "Taxonomy of meanings for character",
"concept" : "Concepts",
"definition" : "Definition",
"notes" : "Criteria and general notes",
"old-chinese-criteria" : "Old Chinese Criteria",
"modern-chinese-criteria" : "Modern Chinese Criteria",
"taxonymy" : "Taxonoymy",
"antonymy" : "Antonymy",
"hypernymy" : "Kind Of",
"see" : "See also",
"source-references" : "Bibliography",
"warring-states-currency" : "Warring States Currency",
"register" : "Register",
"words" : "Words",
"none" : "Texts or Translation",
"old-chinese-contrasts" : "Old Chinese Contrasts",
"pointers" : "Pointers",
"huang-jingui" : "黄金貴：古漢語同義詞辨釋詞典",
"KR1" : "經部",
"KR2" : "史部",
"KR3" : "子部",
"KR4" : "集部",
"KR5" : "道部",
"KR6" : "佛部",
"CH1" : "先秦兩漢",
"CH2" : "魏晉南北朝",
"CH7" : "類書",
"CH8" : "竹簡帛書"
};

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
: Display the documentation. This is called from documentation.html
: @param $section gives the item of the submenu that has been selected
:)
declare
    %templates:wrap
function app:doc($node as node(), $model as map(*), $section as xs:string) {
switch($section)
 case "overview" return doc(concat($config:app-root, "/documentation/overview.html"))
 case "team" return doc(concat($config:app-root, "/documentation/team.html"))
 default return (<h1>About the TLS project</h1>,
        <p>Under construction</p>)
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
function app:browse($node as node()*, $model as map(*), $type as xs:string?, $filter as xs:string?)
{
    session:create(),
    let $filterString := if (string-length($filter) > 0) then $filter else ""
    return
    if ($type = "word") then app:browse-word($type, $filterString)
    else if ($type = "taxchar") then app:browse-char($type, $filterString)
    else if (("concept", "syn-func", "sem-feat") = $type) then    
    let $hits :=  app:do-browse($type, $filterString)      
    let $store := session:set-attribute("tls-browse", $hits)
    return
   <div class="card">
    <div class="card-header" id="{$type}-card">
      <div class="row mb-0">
      <span class="col-3"><h4>{map:get($app:lmap, $type)}</h4></span>&#160;
      <span class="col-3">
      <input class="form-control" id="myInput" type="text" placeholder="Type to filter..."/>
      </span>
      <span class="col-2"></span>
      {(: if ($type = 'concept') then
      <span class="col-3">
       <button type="button" class="btn btn-primary" onclick="new_concept_dialog()">New concept</button>
      </span> else () :)
      ()
      }
      </div>
    </div>
    <div class="card-body"><table class="table">
    <thead><tr>
    <th scope="col">Formula</th>
    <th scope="col">Definition</th>
    <th scope="col">Remarks</th>    
    </tr></thead><tbody class="table-striped">{
    for $h in $hits
    let $n := $h/tei:head/text()
    ,$id := $h/@xml:id
    ,$edit := sm:id()//sm:groups/sm:group[. = "tls-editor"]
    ,$d := $h/tei:div[@type="definition"]
    ,$def := if ($type = 'concept') then ($d/tei:p, <small>{$d/tei:note}</small>) else ($h/tei:p, <small>{$h/tei:note}</small>)
    order by $n
    return
    (
    <tr id="{$id}" class="abbr">
    <td>{
    switch ($type) 
        case  "concept" return <a href="concept.html?uuid={$id}">{$n}</a>
        default return (tlslib:format-button("delete_sf('"||$id||"', '"||$type||"')", "Delete this syntactic definition.", "open-iconic-master/svg/x.svg", "", "", "tls-editor"),
        <a id="{$id}-abbr" onclick="show_use_of('{$type}', '{$id}')">{$n}</a>)
    }</td>
    <td><p id="{$id}-sf" class="sf" contenteditable="{if ($edit) then 'true' else 'false'}">
        {string-join(for $p in $def return
         $p/text(), " ")}&#160;</p></td>
    <td><ul id="{$id}-resp"/></td>
    </tr>)
    }</tbody></table></div>
  </div>
  (: unknown type :)
  else ()  
};

(:~
 : currently (2020-02-26) this has been removed from the menu.  Needs rethinking
:)
declare function app:browse-word($type as xs:string?, $filter as xs:string?)
{
    let $typeString := if (string-length($type) > 0) then $type else "word"    
    for $hit at $c in collection($config:tls-data-root)//tei:entry[@type=$type]
     let $head := $hit/tei:orth/text()
     order by $head
     where $c < 100
     return $hit
};

(:~
 : Displays the characters that had been analyzed taxonomically, culled from 
 : core/taxchar.xml
 : taxchar if available, otherwise look for words? :)
declare function app:browse-char($type as xs:string?, $filter as xs:string?)
{<div><h4>Analyzed characters by frequency</h4><small>1</small>
   { for $hit at $pos in collection($config:tls-data-root)//tei:div[@type=$type]
     let $head := $hit/tei:head
     ,$id := $hit/@xml:id
    return 
    (<a class="ml-2" href="char.html?id={$id}">{$head}</a>,
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
     let $head := data($hit/tei:head),
     $w := $hit//tei:entry
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



(: search related functions :)
(:~
: This is called from search.html
: @param  $query  This is the querystring from the search dialog
: @param  $search-type The type of search: 1=text, 2=dictionary 3=translation
:)
declare 
    %templates:wrap
function app:query($node as node()*, $model as map(*), $query as xs:string?, $mode as xs:string?, $search-type as xs:string?)
{
    session:create(),
    let $hits := 
     if ($search-type = "1") then
      if (tlslib:iskanji($query)) 
      then tlslib:ngram-query($query, $mode) else 
      app:do-query($query, $mode)
      else if ($search-type = "2") then 
      (: searching for kanji in dictionary, eg. the words in concepts :)
      tlslib:dic-query($query, $mode)
      else if ($search-type = "3") then 
      (: searching for word in translations :)
      tlslib:tr-query($query, $mode)
      else "Unknown search type"
    let $store := session:set-attribute($app:SESSION, $hits)
    return
    map:merge((
       map:entry("hits", $hits), map:entry("query", $query)))
};

declare function app:do-query($queryStr as xs:string?, $mode as xs:string?)
{
    let $dataroot := ($config:tls-data-root, $config:tls-texts-root, $config:tls-user-root, $config:tls-translation-root),
    $query := app:create-query(lower-case($queryStr), $mode),
    $hits := for $h in collection($dataroot)//tei:div[ft:query(., $query)]
            where $h/@type != "swl" return $h,
    $types := map:merge(for $hit in $hits
        let $type := if ($hit/@type) then data($hit/@type) else "none"
        group by $type
        return map:entry($type, $hit)),
    $store := session:set-attribute($app:SESSION || ".types", $types)
    for $hit in $hits
    order by ft:score($hit) descending
    return $hit
};



declare
    %templates:wrap
function app:from-session($node as node()*, $model as map(*)) {
    map:entry("hits", session:get-attribute($app:SESSION))
};



declare function app:create-query($queryStr as xs:string?, $mode as xs:string?)
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
:)

declare 
%templates:default("start", 1)
%templates:default("type", "")  (: type is only relevant for advanced search starting from the search landing page for non-Kanji generell search :)
%templates:default("mode", "")   (: for text display sort by date or rating :)
%templates:default("search-type", "1")
function app:show-hits($node as node()*, $model as map(*), $start as xs:int, $type as xs:string, $mode as xs:string, $search-type as xs:string)
{   let $query := map:get($model, "query")
    ,$iskanji := tlslib:iskanji($query) 
    ,$map := session:get-attribute($app:SESSION || ".types")
    ,$user := sm:id()//sm:real/sm:username/text()
    ,$qs := tokenize($query, "\s")
    ,$rat := "Go to the menu -> Browse -> Texts to rate your favorite texts."
    ,$qc := for $c in string-to-codepoints($query) return  codepoints-to-string($c)
    return
    <div><h1>Searching in {map:get($app:tmap, $search-type)} for <mark>{$query}</mark>
    {if (string-length($type) > 0) then 
    <span>in {map:get($app:lmap, $type)}</span>
    else ()}</h1>
    {if ($iskanji) then
    (
    <h4>Found {count($model("hits"))} matches {if (not($search-type="2")) then <span>, showing {$start} to {$start + 10 -1}</span> else ()}</h4>,
    if ($search-type = "1") then 
    <p>
    {if ($start = 1) then ("Taxonomy of meanings: ", for $c in $qc return  <a class="btn badge badge-light" title="Show taxonomy of meanings for {$c}" href="char.html?char={$c}">{$c}</a>) else ()}
    { if ($user = "guest") then () else
    if ($mode = "rating") then 
    (
    "&#160;Sorting by text rating. ", <a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type={$search-type}&amp;mode=date">Click here to sort by text date instead. </a> 
    )
     else
    (
    "&#160;Sorting by text date. ", <a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type={$search-type}&amp;mode=rating" title="{$rat}">Click here to sort your favorite texts first. </a> 
    )
    }
    </p> else ()
    )
    else
    <h4>Found {if (string-length($type) > 0) then (count(map:get($map, $type)),<span>; displaying matches {$start} to {min((count(map:get($map, $type)), xs:int($start) + 10))}</span>)
    else (count($model("hits")), <span> matches</span>)}</h4>}    
    {if ($search-type = "2") then 
    <div>
    <p>{if ($start = 1) then ("Taxonomy of meanings: ", for $c in $qc return  <a class="btn badge badge-light" title="Show taxonomy of meanings for {$c}" href="char.html?char={$c}">{$c}</a>) else ()}</p>
    <table class="table">
    {for $h at $c in map:get($model, "hits")
    return $h
    }
    </table>
    </div>    
    else if ($search-type = "3" or $iskanji) then
    <div>
    <table class="table">
    {for $h at $c in subsequence(map:get($model, "hits"), $start, 10)
      let $loc := if ($search-type="3") then substring($h/@corresp,2) else $h/@xml:id,
      $cseg := if ($search-type="3") then collection($config:tls-texts-root)//tei:seg[@xml:id=$loc] else (),
      $head := if ($search-type="3") then $cseg/ancestor::tei:div[1]/tei:head[1] else $h/ancestor::tei:div[1]/tei:head[1],
      $title := if ($search-type="3") then $cseg/ancestor::tei:TEI//tei:titleStmt/tei:title/text() else $h/ancestor::tei:TEI//tei:titleStmt/tei:title/text()
    return
      <tr>
        <td>{$c + $start -1}</td>
        <td><a href="textview.html?location={$loc}&amp;query={$query}">{$title, " / ", $head}</a>
        </td>
        {if ($search-type = "3") then  
        (<td>{$cseg}</td>,<td>{$h}</td>) else
        <td>{ $h/preceding-sibling::tei:seg[1,3],
        if (count($qs) > 1) then $h else
        (substring-before($h, $query), 
        <mark>{$query}</mark> 
        ,substring-after($h, $query)), 
        $h/following-sibling::tei:seg[1,3]}</td>
        }
        </tr>
    }
    </table>
    <nav aria-label="Page navigation">
  <ul class="pagination">
    <li class="page-item"><a class="page-link {if ($start = 1) then "disabled" else ()}" href="search.html?query={$query}&amp;start={$start - 10}&amp;search-type={$search-type}{if ($mode) then concat("&amp;mode=", $mode) else ()}">&#171;</a></li>
    <li class="page-item"><a class="page-link" href="search.html?query={$query}&amp;start={$start + 10}&amp;search-type={$search-type}{if ($mode) then concat("&amp;mode=", $mode) else ()}">&#187;</a></li>
  </ul>
</nav>
    </div>
    else if (string-length($type) > 0) then 
     <div>{
      app:get-more($type, xs:int($start), 10)}
    <nav aria-label="Page navigation">
      <ul class="pagination">
        <li class="page-item"><a class="page-link {if (xs:int($start) = 1) then "disabled" else ()}" href="search.html?query={$query}&amp;search-type={$search-type}&amp;type={$type}&amp;start={$start - 10}">&#171;</a></li>
        <li class="page-item"><a class="page-link" href="search.html?query={$query}&amp;search-type={$search-type}&amp;type={$type}&amp;start={$start + 10}">&#187;</a></li>
      </ul>
     </nav>
     </div>
    else
    <div>
    <ul>{
      for $t in map:keys($map)
     order by $t
      return <li><a href="#{data($t)}-link" title="{data($t)}">{map:get($app:lmap, $t)}</a>, {count(map:get($map, $t))}</li>}</ul>
    {for $t in map:keys($map)
      let $hitcount := count(map:get($map, $t))
     order by $t
     return
     <div id="{data($t)}-link"><h4>{map:get($app:lmap, $t)} <span class="badge badge-light">{$hitcount}</span></h4>
     <ul>{      app:get-more($t, 1, 3) }
     </ul>
     { if ($hitcount > 3) then 
     <a href="search.html?query={$query}&amp;search-type={$search-type}&amp;type={$t}&amp;start=1">Show more...</a>
     else ()}
     </div>
     }
    </div>
    }
    </div>
};    

(:~ 
:)
declare %private function app:get-more($t as xs:string, $start as xs:int, $count as xs:int){
    let $map := session:get-attribute($app:SESSION || ".types")
     for $h in subsequence(map:get($map, $t), $start, $count)
(:      let $kwic := kwic:summarize($h, <config width="40"/>, app:filter#2),:)
    let $expanded := util:expand($h, "add-exist-id=all")
    return
    (: if there is more than one match, they could be expanded here. Maybe make this optional? 
    for the time being, disabled, thus expanding only one match:)
    for $match in subsequence($expanded//exist:match, 1, 1)
(:    let $kwic := kwic:summarize($hit, <config width="40"/>, app:filter#2):)
     let $kwic := app:get-kwic($match, <config width="40"/>, <a></a>),
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


declare %private function app:get-kwic($node as element(), $config as element(config), $link) {
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


declare 
%templates:default("start", 1)
function app:show-hits-short($node as node()*, $model as map(*),$start as xs:int)
{   <div>
    {for $hit at $p in subsequence($model("hits"), $start, 10)
(:    let $kwic := kwic:summarize($hit, <config width="40"/>, app:filter#2):)
    let $kwic := app:get-kwic($hit, <config width="40"/>, <a></a>)
    return
    <div class="tls-concept" xmlns="http://www.w3.org/1999/xhtml">
      <h3>{$hit/ancestor::tei:head/text()}</h3>
      <span class="number">{$start + $p - 1}</span>
      <span>{data($hit/@type)}</span>
      { $kwic }
    </div>
    }</div>
};    



declare %private function app:filter($node as node(), $mode as xs:string?) as text()?
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
function app:hit-count($node as node()*, $model as map(*), $query as xs:string?) {
   count($model("hits"))
};

(: textview related functions :)

(:~
: Get the first seg to display, translators, title etc. Store this in the model for later use
:)

declare 
    %templates:wrap
function app:tv-data($node as node()*, $model as map(*))
{
   session:create(),
   let $location := request:get-parameter("location", "")
   let $seg := 
    if (string-length($location) > 0) then
     if (contains($location, '_')) then
      let $textid := tokenize($location, '_')[1]
      return
       collection($config:tls-texts-root)//tei:seg[@xml:id=$location]
     else
      let $firstdiv := (collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]//tei:body/tei:div)[1]
      let $targetseg := if ($firstdiv//tei:seg) then ($firstdiv//tei:seg)[1] else  ($firstdiv/following::tei:seg)[1] 
      return
       $targetseg
    else (), 
    $textid := tokenize($seg/@xml:id, "_")[1],
    $title := collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid]//tei:titleStmt/tei:title
    return
    map {"seg" : $seg, "textid" : $textid, "title" : $title}
};


(: function textview 
@param location  text location or text id for the text to display. If empty, display text list app:textlist
@param mode      for textlist: 'tls' texts or 'chant' texts or 'all' texts

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
    let $dataroot := $config:tls-data-root
    return
    (session:create(),
    if (string-length($location) > 0) then
     if (contains($location, '_')) then
      let $textid := tokenize($location, '_')[1]
      let $firstseg := collection($config:tls-texts-root)//tei:*[@xml:id=$location]
      return
        tlslib:display-chunk($firstseg, $model, $prec, $foll)
     else
      let $firstdiv := if ($first = 'true') then 
      (collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]//tei:body/tei:div)[1]
            else
        let $user := sm:id()//sm:real/sm:username/text(),
         $visit := (for $v in collection($config:tls-user-root|| $user)//tei:list[@type="visits"]/tei:item
            let $date := xs:dateTime($v/@modified),
            $target := substring($v/@target, 2)
            order by $date descending
            where starts-with($target, $location)
            return $v)[1]
         return
         if ($visit) then $visit else (collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]//tei:body/tei:div)[1]

      let $targetseg := if ($firstdiv//tei:seg) then ($firstdiv//tei:seg)[1] else  ($firstdiv/following::tei:seg)[1] 
      return
       tlslib:display-chunk($targetseg, $model, 0, $prec + $foll)
    else 
    app:textlist()
    )
};

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
    $chantcount := if (xmldb:collection-available($chantpath)) then 1184 else 0,
    $user := sm:id()//sm:real/sm:username/text(),
    $ratings := doc( $config:tls-user-root || $user || "/ratings.xml")//text,
    $starredcount := count($ratings)
    return
    <div>
    <h1>Available texts: <span class="badge badge-pill badge-light">{$count + $chantcount}</span></h1>
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
    </ul>    
    <div class="tab-content" id="textsContent">    
    <div class="tab-pane" id="coretexts" role="tabpanel">    
    <ul class="nav nav-tabs" id="buTab" role="tablist">
    {for $b in map:keys($bc)
    return 
    <li class="nav-item">
    <a class="nav-link" id="{$b}-tab" role="tab" 
    href="#{$b}" data-toggle="tab">{map:get($app:lmap, $b)}
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
    href="#{$b}" data-toggle="tab">{map:get($app:lmap, $b)}
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
     where string-length($title/text()) > 0
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
    
    </div>
    </div>
};

(: taxchar display :)
declare 
    %templates:wrap
function app:char($node as node()*, $model as map(*), $char as xs:string?, $id as xs:string?)
{
    (session:create(),
    let $key := replace($id, '#', '')
    let $n := if (string-length($id) > 0) then
      doc(concat($config:tls-data-root, "/core/taxchar.xml"))//tei:div[@xml:id = $id]
    else
      doc(concat($config:tls-data-root, "/core/taxchar.xml"))//tei:div[tei:head[. = $char]]
    return
    <div class="card">
    <div class="card-header">
    <h4 class="card-title">{if ($n) then <span>Taxonomy of meanings for {$n/tei:head/text()}:</span> else 
    <span>The character {$char} has not been analyzed yet.</span>
    }</h4>
    </div>
    <div class="card-text">
     {for $l in $n/tei:list return tlslib:proc-char($l)}
    </div>
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
)};   

   
   
(: concept display :)
declare 
    %templates:wrap
function app:concept($node as node()*, $model as map(*), $concept as xs:string?, $uuid as xs:string?)
{
    (session:create(),
    let $user := sm:id()//sm:real/sm:username/text()
    let $key := replace($uuid, '^#', '')
    let $c :=  if (string-length($key) > 0) then
       collection($config:tls-data-root || "/concepts")//tei:div[ends-with(@xml:id,$key)]    
     else
       collection($config:tls-data-root || "/concepts")//tei:div[tei:head[. = $concept]],
    $key := $c/@xml:id,
    $tr := $c//tei:list[@type="translations"]//tei:item
    let $ann := for $c in collection($config:tls-data-root||"/notes")//tls:ann[@concept-id=$key]
     return $c
    return
    <div class="row" id="concept-id" data-id="{$key}">
    <div class="card col-sm-12" style="max-width: 1000px;">
    <div class="card-body">
    <h4 class="card-title">{$c/tei:head/text()}&#160;&#160;{for $t in $tr return 
      <span class="badge badge-light" title="{map:get($app:lmap, $t/@xml:lang)}">{$t/text()}</span>} 
      {if  ("tls-admin" = sm:get-user-groups($user)) then 
      <a target="_blank" class="float-right badge badge-pill badge-light" href="{
      concat($config:exide-url, "?open=", document-uri(root($c)))}">Edit concept</a>
      else ()}
      </h4>
    <h5 class="card-subtitle" id="popover-test" data-toggle="popover">{$c/tei:div[@type="definition"]//tei:p/text()}</h5>
    <div id="concept-content" class="accordion">
    <div class="card">
    <div class="card-header" id="altnames-head">
      <h5 class="mb-0">
        <button class="btn" data-toggle="collapse" data-target="#altnames" >
          Alternate labels
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
          Pointers
        </button>
      </h5>
      </div>
     <div id="pointers" class="collapse" data-parent="#concept-content">
     {for $p in $c//tei:div[@type="pointers"]//tei:list
     return
     (<h5 class="ml-2">{map:get($app:lmap, data($p/@type))}{tlslib:capitalize-first(data($p/@type/text()))}</h5>,
     <p>{for $r in $p//tei:ref return
     <span class="badge badge-light"><a href="concept.html?uuid={replace($r/@target, "#", "")}">{$r/text()}</a></span>
     }
     
     </p>)}
     </div>
    </div>
    <!-- notes -->
    <div class="card">
    <div class="card-header" id="notes-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#notes" >
          {$app:lmap?notes}
        </button>
      </h5>
      </div>
     <div id="notes" class="collapse" data-parent="#concept-content">
     {for $d in $c//tei:div[@type="notes"]//tei:div
     return
     (<h5 class="ml-2 mt-2">{map:get($app:lmap, data($d/@type))}</h5>,
     <div>{for $p in $d//tei:p return
     <p>{$p}</p>
     }     
     </div>)}
     </div>
    </div>
    <!-- bibl -->
    <div class="card">
    <div class="card-header" id="bibl-head">
      <h5 class="mb-0 mt-2">
        <button class="btn" data-toggle="collapse" data-target="#bibl" >
          Source references
        </button>
      </h5>
      </div>
     <div id="bibl" class="collapse" data-parent="#concept-content">
     {for $d in $c//tei:div[@type="source-references"]//tei:bibl
     return
     $d
     }     
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
          Attributions overview <span class="btn badge badge-light">{count($ann)} attested</span>
        </button>
      </h5>
      </div>
     <div id="look" class="collapse" data-parent="#concept-content">
     <p><b>Attributions by syntactic funtion</b>
     <ul>
     {for $sf in distinct-values($ann//tls:syn-func/@corresp)
       let $csf :=  count($ann//tls:syn-func[@corresp=$sf])
       order by $csf descending
       return
       <li>{($ann//tls:syn-func[@corresp=$sf])[1], " : ", $csf}</li>
     }</ul></p>
     <p><b>Attributions by text</b>
     <ul>{for $ti in distinct-values($ann//tls:srcline/@title)
       let $csf :=  count($ann//tls:srcline[@title=$ti])
       order by $csf descending
       return
       <li>{data(($ann//tls:srcline[@title=$ti])[1]/@title), " : ", $csf}</li>
     }
     </ul>
     </p>
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
    ,$wc := sum(for $sw in $e//tei:sense 
             return count($ann//tei:sense[@corresp="#" || $sw/@xml:id]))
    order by $wc descending    
(:    count $count :)
    return 
    <div id="{$entry-id}"><h5><span class="zh">{$zi}</span>&#160;&#160; {for $p in $pr return <span>{
    if (ends-with($p/@xml:lang, "oc")) then "OC: " else 
    if (ends-with($p/@xml:lang, "mc")) then "MC: " else (),
    $p/text()}&#160;</span>}  <small>{$wc} {if ($wc = 1) then " Attribution" else " Attributions"}</small>
    {if ($wc = 0) then
    tlslib:format-button("delete_word_from_concept('"|| $entry-id || "', 'word')", "Delete the word "|| $zi || ", including all syntactic words.", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else 
    (: move :)
    tlslib:format-button("move_word('"|| $zi || "', '"|| $entry-id ||"', '"||$wc||"', 'word')", "Move the word "|| $zi || ", including all syntactic words to another concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor")
    }
    </h5>
    {if ($def) then <p class="ml-4">{$def}</p> else ()}
    <ul>{for $sw in $e//tei:sense
    return
    tlslib:display-sense($sw, count($ann//tei:sense[@corresp="#" || $sw/@xml:id]), false())
    }</ul>
    </div>
    }
    </p>
    </div>
    </div>
    </div>
        <div class="col-sm-0">{tlslib:swl-form-dialog('concept')}</div>
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
:)

(: login :)
declare 
    %templates:wrap
function app:login($node as node()*, $model as map(*))
{ 
let $user := request:get-parameter("user", ())
return
if (sm:is-authenticated() and not($user)) then 
<li class="nav-item dropdown">
<a class="nav-link dropdown-toggle" href="#" id="settingsDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
<img class="icon mr-2" 
src="resources/icons/open-iconic-master/svg/person.svg"/>{sm:id()//sm:real/sm:username/text()}</a>
<div class="dropdown-menu" aria-labelledby="settingsDropdown">
<a onclick="dologout()" class="dropdown-item bg-danger">Logout</a>
<a class="dropdown-item" href="settings.html">Settings</a>
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
function app:main-navbar($node as node()*, $model as map(*), $query as xs:string?)
{
let $context := substring-before(tokenize(request:get-uri(), "/")[last()], ".html")
 ,$testuser := contains(sm:id()//sm:group, ('tls-test', 'guest'))

return
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
                        <li class="nav-item dropdown">
                            <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                                Browse
                            </a>
                            <div class="dropdown-menu" aria-labelledby="navbarDropdown">
                                <a class="dropdown-item" href="browse.html?type=concept">Concepts</a>
                                <a class="dropdown-item" href="browse.html?type=taxchar">Characters</a>
                                <!--
                                <a class="dropdown-item" href="browse.html?type=word">Words</a>
                                -->
                                <a class="dropdown-item" href="browse.html?type=syn-func">Syntactical functions</a>
                                <a class="dropdown-item" href="browse.html?type=sem-feat">Semantic features</a>
                                <div class="dropdown-divider"/>
                                <!-- will need to make another menu level here for the bookmarks -->
                                <a class="dropdown-item" href="textlist.html">Texts</a>
                            </div>                            
                        </li>
                        {if ($context = "textview") then
                        tlslib:tv-header($node, $model)
                        else
                        (tlslib:navbar-doc(),
                        tlslib:navbar-link())}
                        {if (not($testuser)) then tlslib:navbar-bookmarks() else ()}
                        {if (contains(sm:id()//sm:group, "tls-editor")) then tlslib:navbar-review() else ()}
                        </ul>
                    <ul class="navbar-nav">
                    <li class="nav-item">
                    
                    <form action="search.html" class="form-inline my-2 my-lg-0" method="get">
                        <input id="query-inp" name="query" class="form-control mr-sm-2" type="search" placeholder="Search" aria-label="Search" value="{if (string-length($query) > 0) then $query else ()}"/> in 
        <select class="form-control" name="search-type">
          <option selected="true" value="1">{$app:tmap?1}</option>
          <option value="2">{$app:tmap?2}</option>
          <option value="3">{$app:tmap?3}</option>
<!--          <option value="4">Three</option> -->
        </select>
                        <button class="btn btn-outline-success my-2 my-sm-0" type="submit">
                            <img class="icon" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
                        </button>
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
 This is called from review.html
:)
declare 
    %templates:wrap
function app:review($node as node()*, $model as map(*), $type as xs:string){
let $user := "#" || sm:id()//sm:username
  ,$review-items := for $r in collection($config:tls-data-root || "/notes")//tls:metadata[not(@resp= $user)]
       let $score := if ($r/@score) then data($r/@score) else 0
       , $date := xs:dateTime($r/@created)
       where $score < 1 and $date > xs:dateTime("2019-08-29T19:51:15.425+09:00")
       order by $date descending
       return $r/parent::tls:ann
return
<div>
<h3>Reviews due: {count($review-items)}</h3>
 <div class="container">
 {for $att in subsequence($review-items, 1, 20)
  let  $px := substring($att/tls:metadata/@resp, 2)
  let $un := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px]//tei:persName/text()
  , $created := $att/tls:metadata/@created
  return 
  (
  <div class="row border-top pt-4">
  <div class="col-sm-4"><img class="icon" src="resources/icons/octicons/svg/pencil.svg"/>
By <span class="font-weight-bold">{$un}</span>(@{$px})</div>
  <div class="col-sm-5" title="{$created}">created {tlslib:display-duration(current-dateTime()- xs:dateTime($created))} ago</div>
  </div>,
tlslib:show-att-display($att),
tlslib:format-swl($att, map{"type" : "row", "context" : "review"})
  )
 }
 </div>
 <p>Refresh page to see more items.</p>
</div>
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
<div><span>The most recent attribution was {tlslib:display-duration(xs:dateTime(current-dateTime()) - xs:dateTime(data($a/@created)))} ago :</span>
{(
tlslib:show-att-display($att),
tlslib:format-swl($att, map{"type" : "row"})
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
                    <p>Copyright TLS Project 2020</p>
                <p>Developed at the <strong>Center for Informatics in East-Asian Studies, Institute for Research in Humanities, Kyoto University</strong>, with support from the 
                <strong>Dean for Research, Department of East Asian Studies</strong>, and
                <strong>Program in East Asian Studies, Princeton University</strong>.</p>    
                <p>Hosted by <strong>Princeton University, Department of East Asian Studies</strong>, in cooperation with <strong>Ruhr University Bochum, Center for the Study of Traditional Chinese Cultures </strong>.  </p>
                <p>Support from 
                    <strong>Heidelberg University - Cluster of Excellence - Asia and Europe in a Global Context</strong>
                    and <strong>IKOS - University of Oslo</strong>
                    gratefully acknowledged.
                </p>
                <p class="small text-right">This site uses cookies to maintain login state. The cookies are not used for any other purposes. By using this site you agree to this.</p>
            </div>
};

(:~
: This displays the title, both for regular pages (page.html) and textview pages (tv-page.html)

:)
declare
    %templates:wrap
function app:page-title($node as node()*, $model as map(*))
{ (: the html file accessed, without the extension :) 
 let $ts := 
 if ($model("textid")) then 
   $model("textid") || " : " || $model("title")
 else if ($model("concept")) then
   "Concept: " || $model("concept")
 else "漢學文典"

(:,$context := substring-before(tokenize(request:get-uri(), "/")[last()], ".html"):)
return concat ("TLS - ", $ts)
};

declare function app:theme($node as node()*, $model as map(*)){
let $user := sm:id()//sm:real/sm:username/text()
return
if ($user = "chris") then 
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
function app:settings($node as node()*, $model as map(*))
{
let $user := sm:id()//sm:real/sm:username/text()
, $settings := tlslib:get-settings()
, $px := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$user]//tei:persName/text()
return
<div><h2>Settings for {$px}</h2>
<h3>Most recently visited</h3>
<ul></ul>
<h3>Display</h3>
<div>
<input type="checkbox" name="theme" data-toggle="toggle" checked="true" aria-label="Dark theme"/>
Dark theme
</div>
<h3>Bookmarks</h3>
<ul>
{for $b in doc($config:tls-user-root || $user || "/bookmarks.xml")//tei:item
  let $segid := $b/tei:ref/@target,
  $id := $b/@xml:id,
  $date := xs:dateTime($b/@modified)
  order by $date descending

return
<li>{tlslib:format-button("delete_bm('"||$id||"')", "Delete this bookmark.", "open-iconic-master/svg/x.svg", "", "", "tls-user")}
<a href="textview.html?location={substring($segid, 2)}">{$b/tei:ref/tei:title/text()}: {$b/tei:seg}</a></li>
}
</ul>
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
                            <button class="btn btn-primary" onclick="dologin()">Login</button>
                        </div>
                        <input type="hidden" name="duration" value="P7D"/>
                </div>
            </div>
        </div>
        <div id="remoteDialog"/>
        <div id="remDialog2"/>
   </div>
};
(:: xx :)