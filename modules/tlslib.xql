xquery version "3.1";
(:~
: This module provides the internal functions that do not directly control the 
: template driven Web presentation
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace tlslib="http://hxwd.org/lib";

import module namespace config="http://hxwd.org/config" at "config.xqm";
(: import module namespace app="http://hxwd.org/app" at "app.xql"; :)
(:
import module namespace templates="http://exist-db.org/xquery/templates" ;
:)

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(:~ 
: Helper functions
:)

declare function tlslib:expath-descriptor() as element() {
    <rl/>
};

(:~
: check if a string consists completely of kanji
: @param $string  a string to be tested
:)

declare function tlslib:iskanji($string as xs:string) as xs:boolean {
let $kanji := '&#x3400;-&#x4DFF;&#x4e00;-&#x9FFF;&#xF900;-&#xFAFF;&#xFE30;-&#xFE4F;&#x00020000;-&#x0002A6DF;&#x0002A700;-&#x0002B73F;&#x0002B740;-&#x0002B81F;&#x0002B820;-&#x0002F7FF;',
$pua := '&#xE000;-&#xF8FF;&#x000F0000;-&#x000FFFFD;&#x00100000;-&#x0010FFFD;'
return 
matches(replace($string, '\s', ''), concat("^[", $kanji, $pua, "]+$" ))
};

(:~ 
: check if the tei:seg node passed in is the first in the paragraph
: @param  $seg a tei:seg element
:)

declare function tlslib:is-first-in-p($seg as node()){
    $seg/@xml:id = $seg/parent::tei:p/tei:seg[1]/@xml:id    
};

(:~ 
: check if the tei:seg node passed in is the first in the division
: @param  $seg a tei:seg element
:)

declare function tlslib:is-first-in-div($seg as node()){
    $seg/@xml:id = $seg/ancestor::tei:div/tei:p[1]/tei:seg[1]/@xml:id    
};

declare function tlslib:capitalize-first ( $arg as xs:string? )  as xs:string? {
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
 } ;
declare function tlslib:get-juan($link as xs:string){
xs:int((tokenize($link, "_")[3] => tokenize("-"))[1])
};
(:~
: get the definition for semantic features or syntactic functions
: @param $type either "sem-feat" or "syn-func"
: @param $string  : this string will be used to look up the feature
: 2020-02-26 not sure if this is actually used somewhere
:)
declare function tlslib:getsynsem($type as xs:string, $string as xs:string, $map as map(*))
{
map:merge(
let $file := if ($type = "sem-feat") then "semantic-features.xml" else 
             if ($type = "syn-func") then "syntactic-functions.xml" else ""
   for $s in doc(concat($config:tls-data-root, '/core/', $file))//tei:head[contains(., $string)]
   return 
   map:entry(string($s/parent::tei:div/@xml:id), string($s))
 )
};

declare function tlslib:getdate($node as node()) as xs:int{
 let $nb := xs:int($node/@notbefore)
 , $na := xs:int($node/@notafter)
 return
 xs:int(($na + $nb) div 2)
};
  
(:~
 : Get the content source for the given slot, either 1 or 2
 : @param $seg the line for which we need content
 : @param $options is a map with possible options
 : we return a map of labels and doc nodes that fulfil the requirements
:)
declare function tlslib:get-content-slots($seg as node(), $options as map(*)) {
let $user := sm:id()//sm:real/sm:username/text()
,$id := $seg/@xml:id
,$tr := for $s in collection($config:tls-translation-root, "/db/users/" || $user || "/translations")//tei:seg[@corresp="#"||$id]
        return root($s)
,$retmap := map:merge(
          for $t in $tr
          let $lang := tokenize($tr/tei:TEI/@xml:id, '-')[last()]
          ,$ed := $tr//tei:editor[@role='translator']/text()
          return map:entry(document-uri($tr), ($lang, $ed))
)
return $retmap
};

  
declare function tlslib:proc-char($node as node())
{ 
typeswitch ($node)
  case element(tei:div) return
      <div>{for $n in $node/node() return tlslib:proc-char($n)}</div>
  case element(tei:head) return
  <h4 class="card-title">{$node/text()}</h4>
  case element(tei:list) return
  <ul >{for $n in $node/node()
       return
       tlslib:proc-char($n)
  }</ul>
  case element(tei:item) return
    <li>{for $n in $node/node()
        return
            tlslib:proc-char($n)
    }</li>
  case element(tei:ref) return
     let $id := substring($node/@target, 2),
     $char := tokenize($node/ancestor::tei:div[1]/tei:head/text(), "\s")[1],
     $swl := collection($config:tls-data-root)//tei:div[@xml:id=$id]//tei:entry[tei:form/tei:orth[. = $char]]//tei:sense
      (: this is the concept originally defined in the taxononomy file! :)
     ,$alt := $node/@altname
     ,$swl-count := count($swl)
     ,$concept := normalize-space($node/text())
     return
      <span>
      {if ($swl-count = 0) then 
      if ($alt) then 
      <a href="concept.html?uuid={$id}" class="text-muted mr-2 ml-2" title="Concept pending: not yet attributed. Alternate name: {string($alt)}">{$concept}</a>
      else 
      <a href="concept.html?uuid={$id}" class="text-muted mr-2 ml-2" title="Concept pending: not yet attributed">{$concept}</a>
      else 
      (
      <a href="concept.html?uuid={$id}" class="mr-2 ml-2">{$concept}</a>
      ,
      <button title="click to reveal {count($swl)} syntactic words" class="btn badge badge-light" type="button" 
      data-toggle="collapse" data-target="#{$id}-swl">{$swl-count}</button>)}
      <ul class="list-unstyled collapse" id="{$id}-swl"> 
      {for $sw in $swl
      (: we dont check for attribution count, so pass -1  :)
      return tlslib:display-sense($sw, -1)}
      </ul>
      </span>
  case text() return
      $node
  default
  return 
  <not-handled>{$node}</not-handled>
};
   
(: button, mostly at the right side, in which case class will be "close" :)
declare function tlslib:format-button($onclick as xs:string, $title as xs:string, $icon as xs:string, $style as xs:string, $class as xs:string, $group as xs:string){
 let $usergroups := sm:id()//sm:group/text()
 return
 if (contains($usergroups, $group)) then
 if (string-length($style) > 0) then
 <button type="button" class="btn {$class}" onclick="{$onclick}"
 title="{$title}">
 <img class="icon" style="width:10px;height:13px;top:0;align:top" src="resources/icons/{$icon}"/>
 </button>
 else 
 <button type="button" class="btn {$class}" onclick="{$onclick}"
 title="{$title}">
 <img class="icon"  src="resources/icons/{$icon}"/>
 </button>
 else ()
};

declare function tlslib:format-button-common($onclick as xs:string, $title as xs:string, $icon as xs:string){
  tlslib:format-button($onclick, $title, $icon, "", "close", "tls-user")
};

(:~
: looks for a word in the tei:orth element of concepts
: @param $word the word
: @map  ??
: returns a map of entry elements and their concept-id and concept name
: used by app:get_sw($node, $model, $word)
:)
declare function tlslib:getwords($word as xs:string, $map as map(*))
{
map:merge(
   for $s in collection(concat($config:tls-data-root, '/concepts/'))//tei:orth[. = $word]
   return 
   map:entry(string($s/ancestor::tei:entry/@xml:id), (string($s/ancestor::tei:div/@xml:id), string($s/ancestor::tei:div/tei:head)))
 )
};

declare function tlslib:get-sf-def($sfid as xs:string){
let $sfdef := doc($config:tls-data-root || "/core/syntactic-functions.xml")//tei:div[@xml:id=$sfid]/tei:p/text()
return $sfdef
};

(:~
: format the duration in a human readable way
: @param  $pt a xs:duration instance
:)
declare function tlslib:display-duration($pt as xs:duration) {
let $y := years-from-duration($pt)
,$m := months-from-duration($pt)
,$d := days-from-duration($pt)
,$h := hours-from-duration($pt)
,$mi := minutes-from-duration($pt)
,$s := seconds-from-duration($pt)
return
<span>{(
if ($y > 0) then if ($y > 1) then <span> {$y} years </span> else <span>{$y} year </span> else (),
if ($m > 0) then if ($m > 1) then <span> {$m} months </span> else <span> {$m} month </span> else (),
if ($d > 0) then if ($d > 1) then <span> {$d} days </span> else <span> {$d} day </span> else (),
if ($h > 0) then if ($h > 1) then <span> {$h} hours </span> else <span> {$h} hour </span> else (),
if ($mi > 0) then if ($mi > 1) then <span> {$mi} minutes </span> else <span> {$mi} minute </span> else (),
if ($s > 0) then if ($s > 1) then <span> {$s} seconds </span> else <span> {$s} second </span> else ()
)
}
</span>
};

(:~
: recurse through the supplied node (a te:seg) and return only the top level text()
: 2020-02-20: created this element because KR2m0054 has <note> elements in translation. 
: @param $node a tei:seg node, typically
:)
declare function tlslib:procseg($node as node()){
 typeswitch ($node)
 case element(tei:note) return ()
(:     <small>{$node/text()}</small>:)
  case element (tei:l) return ()
  case element (tei:lb)  return ()
  case element(tei:seg) return for $n in $node/node() return tlslib:procseg($n)
 default return $node    
};

(:~ 
: get the rating (an integer between 0 and 10) of the text, identified by the passed in text id
: this is i.e. used for the ranking of search results
: @param $txtid  the id of the text
:)
declare function tlslib:get-rating($txtid){
    let $user := sm:id()//sm:real/sm:username/text(),
    $ratings := doc("/db/users/" || $user || "/ratings.xml")//text
    return 
    if ($ratings[@id=$txtid]) then $ratings[@id=$txtid]/@rating else 0
};
(:~
: Lookup the title for a given textid
: @param $txtid
:)
declare function tlslib:get-title($txtid as xs:string){
let $title := collection("/db/apps/tls-texts") //tei:TEI[@xml:id=$txtid]//tei:titleStmt/tei:title/text()
return $title
};

(: -- Search / retrieval related functions -- :)


(: -- Display related functions -- :)

declare function tlslib:navbar-doc(){
                        <li class="nav-item dropdown">
                            <a class="nav-link dropdown-toggle" href="#" id="navbarDropdownDoc" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                                Documentation
                            </a>
                            <div class="dropdown-menu" aria-labelledby="navbarDropdownDoc">
                                <a class="dropdown-item" href="documentation.html?section=overview">Overview</a>
                                <a class="dropdown-item" href="documentation.html?section=team">Advisory Board</a>
                                <div class="dropdown-divider"/>
                                <a class="dropdown-item" href="documentation.html?section=manual">About this website</a>
                            </div>
                        </li>

};

declare function tlslib:navbar-link(){
                        <li class="nav-item dropdown">
                            <a class="nav-link dropdown-toggle" href="#"  id="navbarDropdownLinks" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">Links</a>
                            <div class="dropdown-menu" aria-labelledby="navbarDropdownLinks">
                            <a class="dropdown-item" href="https://www.kanripo.org">Kanseki Repository</a>
                                <!--
                                <a class="dropdown-item" href="documentation.html?section=team">Advisory Board</a>
                                <div class="dropdown-divider"/>
                                <a class="dropdown-item" href="documentation.html?section=manual">About this website</a>
                                -->
                            </div>
                        </li>
};


(:~ 
: this is the header line used for the text display, called from app:textview
: @param  $node  this is the tei:seg element that contains a line that will be on this page, 
: note: currently the translators are drawn from the $config:textsource map, this will have to come from the 
: translation file itself:  eg //tei:TEI[@xml:id=$textid || "-en"]//tei:editor[@role='translator']
: TODO: add textid and title to the <title> element of HTML
: @param $node  tei:seg on the page
: @param $model a map containing arbitrary data 
:)
declare function tlslib:tv-headerz($node as node()*, $model as map(*)){
<span>{for $k in distinct-values(map:keys($model)) 
let $r := if (not($k="configuration")) then map:get($model, $k) else ()
return
<li>{$k, string($r)}</li>
}
</span>
};
declare function tlslib:session-att($name, $default){
   if (contains(session:get-attribute-names(),$name)) then 
    session:get-attribute($name) else 
    (session:set-attribute($name, $default), $default)
};

declare function tlslib:tv-header($node as node()*, $model as map(*)){
   let $textid := $model('textid'),
   $toc := if (contains(session:get-attribute-names(), $textid || "-toc")) then 
    session:get-attribute($textid || "-toc")
    else 
    tlslib:generate-toc($model("seg")/ancestor::tei:body)
   
   let $store := 
     if (not(contains(session:get-attribute-names(),$textid || "-toc"))) 
     then session:set-attribute($textid || "-toc", $toc) else ()

   return
      (
      <span class="navbar-text ml-2 font-weight-bold">{$model('title')/text()} <small class="ml-2">{$model('seg')/ancestor::tei:div[1]/tei:head[1]/text()}</small></span> 
      ,<li class="nav-item dropdown">
       <a id="navbar-mulu" role="button" data-toggle="dropdown" href="#" class="nav-link dropdown-toggle">目錄</a> 
       <div class="dropdown-menu">
       {$toc}
       </div>
      </li>
      ,<button title="Show SWL" class="btn btn-primary ml-2" type="button" data-toggle="collapse" data-target=".swl">
            
     <img class="icon" src="resources/icons/open-iconic-master/svg/eye.svg"/>

      </button>,
      <li class="nav-item">
      <small class="nav-brand ml-2" title="Text provided by">Source: 
      {if (map:contains($config:txtsource-map, $textid)) then 
          map:get($config:txtsource-map, $textid) 
      else 
         if (substring($model('textid'), 1, 3) = "KR6") then "CBETA" 
         else <a href="http://www.chant.org/">CHANT</a>}
      </small>
      {if ($model("transl")) then 
      (<br/>,<small class="nav-brand ml-2">Translation by {$model("transl")}</small>) else () }
      </li>

      )
};

(:~
: generate the table of contents for the textview header.  Called from
: @param $node  a node from the text to process
: @see tlslib:tv-header()
: TODO: Store a generated TOC in the text file and use if available
:)

declare function tlslib:generate-toc($node){
 if ($node/tei:head) then
  let $locseg := if ($node//tei:seg/@xml:id) then ($node//tei:seg/@xml:id)[1] else $node/following::tei:seg[1]/@xml:id
  return 
    <a class="dropdown-item" title="{$locseg}" href="textview.html?location={$locseg}&amp;prec=0&amp;foll=30">{$node/tei:head/text()}</a>
  else (),
 for $d in $node/child::tei:div
 return tlslib:generate-toc($d)
};
(:~
 Display a selection menu for translations and commentaries, given the current slot and type
:)
declare function local:trsubmenu($model as map(*), $slottype as xs:string, $slot as xs:int){
        <div class="dropdown">
            <button class="btn btn-secondary dropdown-toggle" type="button" id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
    Translation {$model($slottype)[$slot]/text()}
            </button>
    <div class="dropdown-menu" aria-labelledby="dropdownMenuButton">
        {for $n in ('transl', 'comm')
         for $m at $i in $model($n) 
           where not($i = $slot and $slottype = $n) 
            return 
        <a class="dropdown-item" title="This is not working yet." href="#">{$n ||" : " || $m}</a>
        }
  </div>
</div>

};

(:~
: display a chunk of text, surrounding the $targetsec
: @param $targetseg  a tei:seg element
: @param $prec an xs:int giving the number of tei:seg elements to display before the $targetsec
: @param $foll an xs:int giving the number of tei:seg elements following the $targetsec 
display $prec and $foll preceding and following segments of a given seg :)

declare function tlslib:display-chunk($targetseg as node(), $model as map(*), $prec as xs:int?, $foll as xs:int?){

      let $fseg := if ($foll > 0) then $targetseg/following::tei:seg[fn:position() < $foll] 
        else (),
      $pseg := if ($prec > 0) then $targetseg/preceding::tei:seg[fn:position() < $prec] 
        else (),
      $head := $targetseg/ancestor::tei:div[1]/tei:head[1],
(:      $title := $model('title')/text(),:)
      $dseg := ($pseg, $targetseg, $fseg),
      $slot1 := tlslib:session-att("slot1", 1), 
      $slot2 := tlslib:session-att("slot2", 2), 
      $slottype1 :=  tlslib:session-att("slottype1", 'transl'),
      $slottype2 :=  tlslib:session-att("slottype2", 'transl')
    return
      (
      <div id="chunkrow" class="row">
      <div id="toprow" class="col-sm-12">
      {(:  this is the same structure as the one display-seg will fill it 
      with selection for translation etc, we use this as a header line :)()}
       <div class="row">
        <div class="col-sm-2" id="toprow-1"><!-- zh --></div>
        <div class="col-sm-5" id="toprow-2"><!-- tr -->
        {local:trsubmenu($model, $slottype1, $slot1)}
        </div>
        <div class="col-sm-4" id="toprow-3">
        {local:trsubmenu($model, $slottype1, $slot2)}
        </div>
        </div>
      </div>
      <div id="chunkcol-left" class="col-sm-12">{for $d at $pos in $dseg return tlslib:display-seg($d, map:merge(($model, map{'loc' : data($targetseg/@xml:id), 'pos' : $pos})))}</div>
      <div id="chunkcol-right" class="col-sm-0">
      {tlslib:swl-form-dialog('textview')}
    </div>
    </div>,
      <div class="row">
      <div class="col-sm-2">
      {if ($dseg) then  
      (: currently the 0 is hardcoded -- do we need to make this customizable? :)
       <a href="?location={tokenize($dseg/@xml:id, "_")[1]}">First</a>
       else ()}
       </div>
      <div class="col-sm-2">
      {if ($dseg[1]/preceding::tei:seg[1]/@xml:id) then  
      (: currently the 0 is hardcoded -- do we need to make this customizable? :)
       <a href="?location={$dseg[1]/preceding::tei:seg[1]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=2">Previous</a>
       else ()}
       </div>
       <div class="col-sm-2">
       {
       if ($dseg[last()]/following::tei:seg[1]/@xml:id) then
      <a href="?location={$dseg[last()]/following::tei:seg[1]/@xml:id}&amp;prec=2&amp;foll={$foll+$prec -2}">Next</a>
       else ()}
       </div> 
       <div class="col-sm-2">
       {
       if ($dseg/following::tei:seg[last()]/@xml:id) then
      <a href="?location={$dseg/following::tei:seg[last()]/@xml:id}&amp;prec={$foll+$prec - 2}&amp;foll=0">Last</a>
       else ()}
       </div> 
      </div>
      )

};

(: dialog functions :) 

(: This is the stub for the dynamic display in the right section.  Called from textview, it is used for attributions, from other contexts, just for display :)

declare function tlslib:swl-form-dialog($context as xs:string){
<div id="swl-form" class="card ann-dialog overflow-auto">
{if ($context = 'textview') then
 <div class="card-body">
    <h5 class="card-title">{if (sm:is-authenticated()) then "New Attribution:" else "Existing SW for " }<strong class="ml-2"><span id="swl-query-span">Word or char to annotate</span>:</strong>
     <button type="button" class="close" onclick="hide_new_att()" aria-label="Close" title="Close">
     <img class="icon" src="resources/icons/open-iconic-master/svg/circle-x.svg"/>  
     </button></h5>
    <h6 class="text-muted">At:  <span id="swl-line-id-span" class="ml-2">Id of line</span>&#160;
    {tlslib:format-button-common("bookmark_this_line()","Bookmark this location", "open-iconic-master/svg/bookmark.svg")}</h6>
    <h6 class="text-muted">Line: <span id="swl-line-text-span" class="ml-2">Text of line</span>
    {tlslib:format-button-common("comment_this_line()","Comment on this line", "octicons/svg/comment.svg")}</h6>
    <div class="card-text">
       
        <p> { if (sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then <span>
        <span class="badge badge-primary">Use</span> one of the following syntactic words (SW), 
        create a <span class="mb-2 badge badge-secondary">New SW</span> 
         or add a new concept to the word here: 
         <span class="btn badge badge-light ml-2" data-toggle="modal" onclick="show_new_concept()">Concept</span> 
         </span>
         else <span>You do not have permission to make attributions.</span>
         }
        <ul id="swl-select" class="list-unstyled"></ul>
        </p>
      </div>
    </div>    
else 
 <div class="card-body">
    <h5 class="card-title">Existing SW for <strong class="ml-2"><span id="swl-query-span"></span></strong>
     <button type="button" class="close" onclick="hide_new_att()" aria-label="Close" title="Close">
     <img class="icon" src="resources/icons/open-iconic-master/svg/circle-x.svg"/>  
     </button></h5>
    <div class="card-text">
    <p>Here are <b>S</b>yntactic <b>W</b>ords already defined in the database:</p>
        <ul id="swl-select" class="list-unstyled"></ul>
      </div>
    </div>    

}
</div>
};


declare function tlslib:get-sense-def($uuid as xs:string){
let $cnode := collection("/db/apps/tls-data")//tei:sense[@xml:id=$uuid]
,$def := $cnode/tei:def[1]/text()
return $def
};
(: 2020-02-23 : because of defered update in tlsapi:save-def, we use the master definition instead of the local definition of the swl 
 : 2020-02-26 : this now works indeed.
:) 
(:~
: formats a single syntactic word location for display either in a row (as in the textview, made visible by the blue eye) or as a list item, this is used in the left hand display for the annotations
: @param $node  the tls:ann element to display
: @param $type  type of the display, currently 'row' for selecting the row style, anything else will be list style
: called from api/show_swl_for_line.xql
:)

declare function tlslib:format-swl($node as node(), $type as xs:string?){
let $user := sm:id()//sm:real/sm:username/text()
let $concept := data($node/@concept),
$zi := $node/tei:form[1]/tei:orth[1]/text(),
$py := $node/tei:form[1]/tei:pron[starts-with(@xml:lang, 'zh-Latn')][1]/text(),
$sf := $node//tls:syn-func,
$sm := $node//tls:sem-feat
,$link := substring(tokenize($node/tei:link/@target)[2], 2)
(: damnit, why does this not work?  3 days later... seems to work now :)
,$cdef := collection("/db/apps/tls-data")//tei:sense[@xml:id=$link]/ancestor::tei:div/tei:div[@type="definition"]/tei:p/text()
,$def := tlslib:get-sense-def($link)
(:$pos := concat($sf, if ($sm) then (" ", $sm) else "")
:)
return
if ($type = "row") then
<div class="row bg-light ">
<div class="col-sm-1">&#160;</div>
<div class="col-sm-2"><span class="zh">{$zi}</span> ({$py})
 {if  ("tls-admin" = sm:get-user-groups($user)) then (data(($node//tls:srcline/@pos)[1]),
 <a href="{
      concat($config:exide-url, "?open=", document-uri(root($node)))}">eXide</a>)
      else ()
  }    
</div>
<div class="col-sm-3"><a href="concept.html?concept={$concept}" title="{$cdef}">{$concept}</a></div>
<div class="col-sm-6">
<span><a href="browse.html?type=syn-func&amp;id={data($sf/@corresp)}">{$sf/text()}</a>&#160;</span>
{if ($sm) then 
<span><a href="browse.html?type=sem-feat&amp;id={$sm/@corresp}">{$sm/text()}</a>&#160;</span> else ()}
{$def}
{if (sm:has-access(document-uri(fn:root($node)), "w") and $node/@xml:id) then 
(: for the time being removing the button, don't really now what I want to edit here:-)
 <button type="button" class="btn" onclick="edit_swl('{$node/@xml:id}')" style="width:10px;height:20px;" 
 title="Edit Attribution">
 <img class="icon" onclick="edit_swl('{$node/@xml:id}')" style="width:10px;height:13px;top:0;align:top" src="resources/icons/open-iconic-master/svg/pencil.svg"/>
 </button> 
 :)
tlslib:format-button("delete_swl('" || data($node/@xml:id) || "')", "Delete Attribution for "||$zi, "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")

else ()
}
</div>
</div>
else 
<li class="list-group-item" id="{$concept}">{$py} {$concept} {$sf} {$sm} {
if (string-length($def) > 10) then concat(substring($def, 10), "...") else $def}</li>
};


(:~
: displays a tei:seg element, that is, a line of text, including associated items like translation and swl
: @param $seg the tei:seg to display
: @param $options  a map of additional options, for example 
:         {"ann" : true } for the display of annotations,
:        {"loc" : "<@xml:id of a tei:seg>"} the id of a line to be highlighted in the display
: @see tlslib:format-swl(), which is used for displaying the swl
: called from tlsapi:get-text-preview($loc as xs:string)
: 
:)

declare function tlslib:display-seg($seg as node()*, $options as map(*) ) {
 let $user := sm:id()//sm:real/sm:username/text(),
 $testuser := contains(sm:id()//sm:group, ('tls-test', 'guest'))
 let $link := concat('#', $seg/@xml:id),
  $ann := lower-case(map:get($options, "ann")),
  $loc := map:get($options, "loc"),
  $mark := if (data($seg/@xml:id) = $loc) then "mark" else ()
  ,$lang := 'zho'
  ,$alpheios-class := 'alpheios-enabled'
  (: $model($model('slottype1'))[$model('slot1')] :)
(:  ,$slot1 := root($options($options('slottype1'))[$options('slot1')])
  ,$slot2 := root($options($options('slottype2'))[$options('slot2')]):)
  ,$slot1 := root($options('transl')[1])
  ,$slot2 := root($options('transl')[2])
return
(
<div class="row {$mark}">
<div class="{if ($ann='false') then 'col-sm-4' else 'col-sm-2'} zh {$alpheios-class}" lang="{$lang}" id="{$seg/@xml:id}">{$seg/text()}</div>　
<div class="col-sm-5 tr" tabindex="{2*$options('pos')+500}" id="{$seg/@xml:id}-tr" contenteditable="{if (not($testuser)) then 'true' else 'false'}">{$slot1//tei:seg[@corresp="#"||$seg/@xml:id]/text()}</div>
<div tabindex="{2*$options('pos')+500+1}"></div>
 {if ($ann = 'false') then () else 
  <div class="col-sm-4 tr" tabindex="{2*$options('pos')+1000}" id="{$seg/@xml:id}-ex" contenteditable="{if (not($testuser)) then 'true' else 'false'}">
  {$slot2//tei:seg[@corresp="#"||$seg/@xml:id]/text()}
  </div>}
  <div tabindex="{2*$options('pos')+1000+1}"> </div>
</div>,
<div class="row swl collapse" data-toggle="collapse">
<div class="col-sm-10" id="{$seg/@xml:id}-swl">
{if ($ann = "false") then () else 
for $swl in collection($config:tls-data-root|| "/notes")//tls:srcline[@target=$link]
let $pos := if (string-length($swl/@pos) > 0) then xs:int(tokenize($swl/@pos)[1]) else 0
order by $pos
return
tlslib:format-swl($swl/ancestor::tls:ann, "row")}
</div>
<div class="col-sm-2"></div>
</div>
)
};

declare function tlslib:display-segx($seg as node()*, $options as map(*) ) {
 let $user := sm:id()//sm:real/sm:username/text()
 let $link := concat('#', $seg/@xml:id),

$ann := (:lower-case(map:get($options, "ann")):) 'false',
$loc := map:get($options, "loc"),
$mark := if (data($seg/@xml:id) = $loc) then "mark" else ()
return
( (: headers or paragraphs :)
if (tlslib:is-first-in-p($seg)) then
 if (tlslib:is-first-in-div($seg)) then 
  let $hx := $seg/ancestor::tei:div[1]/tei:head/text()
  return
 <div class="row"><!-- head! -->
 <div class="col-sm-12"><h5>{$hx}　　　</h5></div>
 </div>
 else
 (: create an empty line between paragraphs :)
 <div class="row">
 <!-- p --> 
 <div class="col-sm-12 my-6">　　　</div>
 </div> 
 else
 (),
 (: avoid extra empty lines :)
if (string-length(string-join($seg/text(), "")) > 0) then
(<div class="row {$mark}">
<div class="{if ($ann='false') then 'col-sm-4' else 'col-sm-2'} zh" id="{$seg/@xml:id}">{$seg/text()}</div>　
<div class="col-sm-5 tr" id="{$seg/@xml:id}-tr" 
  contenteditable="{if (sm:has-access(xs:anyURI($config:tls-translation-root), "r") and not(contains(sm:id()//sm:group, 'tls-test'))) then 'true' else 'false'}">
 {  (: if there is more than one translation, we take the one with the shorter path (outrageous hack) :)
(:   let $tr:= if ($config:tls-translation-root) then 
             for $t in collection($config:tls-translation-root)//tei:seg[@corresp=$link]
             let $p := string-length(document-uri(root($t)))
             order by $p ascending
             return $t
             else ():)
             let $tr := ('')
   return if ($tr[1]) then tlslib:procseg($tr[1]) else ()
 }</div>
 {if ($ann = 'false') then () else 
  <div class="col-sm-4 ex" id="{$seg/@xml:id}-ex">Dummy</div>}
</div>,
<div class="row swl collapse" data-toggle="collapse">
<div class="col-sm-10" id="{$seg/@xml:id}-swl">
{if ($ann = "false") then () else 
for $swl in collection($config:tls-data-root|| "/notes")//tls:srcline[@target=$link]
let $pos := if (string-length($swl/@pos) > 0) then xs:int(tokenize($swl/@pos)[1]) else 0
order by $pos
return
tlslib:format-swl($swl/ancestor::tls:ann, "row")}
</div>
<div class="col-sm-2"></div>
</div>
) else ()
)
};

 (:~ 
 : called from function tlsapi:show-use-of($uid as xs:string, $type as xs:string), which is called via XHR from concept.html and char.html through 
 : tls-app.js -> show_use_of(type, uid) 
 : @param $sw the tei:sense to display 
 : 2020-02-26 it seems this belongs to tlsapi
 :)
 
declare function tlslib:display-sense($sw as node(), $count as xs:int){
    let $id := data($sw/@xml:id),
    $sf := $sw//tls:syn-func/text(),
    $sm := $sw//tls:sem-feat/text(),
    $user := sm:id()//sm:real/sm:username/text(),
    $def := $sw//tei:def/text()
    return
    <li id="{$id}"><span id="sw-{$id}" class="font-weight-bold">{$sf}</span>
    <em class="ml-2">{$sm}</em> 
    <span class="ml-2">{$def}</span>
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp" onclick="show_att('{$id}')">
          {if ($count > -1) then $count else ()}
          {if ($count = 1) then " Attribution" else  " Attributions" }
      </button>
     {if ($user = "guest") then () else 
     <button title="Search for this word" class="btn badge btn-outline-success ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp1" onclick="search_and_att('{$id}')">
      <img class="icon-small" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
      </button>,
      if ($count = 0) then
      tlslib:format-button("delete_word_from_concept('"|| $id || "')", "Delete the syntactic word "|| $sf || ".", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else ()
      }
      <div id="{$id}-resp" class="collapse container"></div>
      <div id="{$id}-resp1" class="collapse container"></div>
    </li>
 
 };

(:~
: called from tlsapi:save-sf($sense-id as xs:string, $synfunc-id as xs:string, $synfunc-val as xs:string, $def as xs:string)
 : 2020-02-26 it seems this belongs to tlsapi

:)
 
declare function tlslib:new-syn-func ($sf as xs:string, $def as xs:string){
 let $uuid := concat("uuid-", util:uuid()),
 $user := sm:id()//sm:real/sm:username/text(),
$el := <div xmlns:tls="http://hxwd.org/ns/1.0" xmlns="http://www.tei-c.org/ns/1.0" type="syn-func" xml:id="{$uuid}" resp="#{$user}" tls:created="{current-dateTime()}">
<head>{$sf}</head>
<p>{$def}</p>
</div>,
$last := doc($config:tls-data-root || "/core/syntactic-functions.xml")//tei:div[@type="syn-func"][last()]
,$ret := update insert $el following $last 
return $uuid
 };
 
 (:~
 : called from function tlsapi:show-att($uid as xs:string)
  : 2020-02-26 it seems this belongs to tlsapi

 :)
 
 declare function tlslib:show-att-display($a as node()){

let $user := sm:id()//sm:real/sm:username/text()
let $src := data($a/tls:text/tls:srcline/@title)
let $line := $a/tls:text/tls:srcline/text(),
$tr := $a/tls:text/tls:line,
$target := substring(data($a/tls:text/tls:srcline/@target), 2),
$loc := xs:int((tokenize($target, "_")[3] => tokenize("-"))[1])

return
<div class="row bg-light table-striped">
<div class="col-sm-2"><a href="textview.html?location={$target}" class="font-weight-bold">{$src, $loc}</a></div>
<div class="col-sm-3"><span data-target="{$target}" data-toggle="popover">{$line}</span></div>
<div class="col-sm-7"><span>{$tr}</span>
{if ((sm:has-access(document-uri(fn:root($a)), "w") and $a/@xml:id) and not(contains(sm:id()//sm:group, 'tls-test'))) then 
tlslib:format-button("delete_swl('" || data($a/@xml:id) || "')", "Delete this attribution", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
else ()}
</div>
</div>
};

 