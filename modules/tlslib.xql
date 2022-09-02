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

import module namespace krx="http://hxwd.org/krx-utils" at "krx-utils.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tx="http://exist-db.org/tls";

declare function local:string-to-ncr($s as xs:string) as xs:string{
 string-join(for $a in string-to-codepoints($s)
 return "&#x26;#x" || number($a) || ";" 
 , "")
};

(:~ 
: Helper functions
:)
(: quick fix, this needs to be made user-extensible :)
declare function tlslib:annotation-types($type as xs:string){
  let $map := 
 map{'nswl' : ('Grammar', 'Syntactic Word Location'), 
     'rdl' : ('Rhetoric', 'Rhetoric Device Location'),
     'drug' : ('本草', 'Drug Location')}
 return
 if (count($map($type))> 0) then $map($type) else ( collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@xml:id=$type]/tei:head/text(), '')
};

declare function tlslib:remove-punc($s as xs:string) as xs:string{
translate(normalize-space($s), ' ，。、&#xA;：；', '')
};


declare function tlslib:num2hex($num as xs:int) as xs:string {
let $h := "0123456789ABCDEF"
, $s := if ($num > 65535) then
  (tlslib:num2hex($num idiv 65536),
  tlslib:num2hex($num mod 65536))
  else if ($num < 65536 and $num > 255) then
  (tlslib:num2hex($num idiv 256),
  tlslib:num2hex($num mod 256))
  else if ($num < 256 and $num > 15) then
  (tlslib:num2hex($num idiv 16),
  tlslib:num2hex($num mod 16))
  else if ($num < 16) then
   substring($h, $num + 1, 1)
  else ()
  return
  string-join($s, "")
};

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

(: check if most characters are kanji :)
declare function tlslib:mostly-kanji($string as xs:string) as xs:boolean {
if (string-length($string) > 0) then
let $q := sum(for $s in string-to-codepoints($string)
    return
    if ($s > 500) then 1 else 0 )
return
if ($q div string-length($string) > 0.5) then xs:boolean("1") else xs:boolean(0)
else xs:boolean(0)
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
  
(: Helper for ontology  I guess I need to return a map? :)  
(: this covers now also the rhet-dev ontology :)

declare function tlslib:ontology-up($uid as xs:string, $cnt as xs:int){
  let $concept := collection($config:tls-data-root)//tei:div[@xml:id=$uid],
  $dtype := $concept/@type,
  $type := "hypernymy",
  $hyp := $concept//tei:list[@type=$type]//tei:ref
  return
  for $r in $hyp
  let $def := collection($config:tls-data-root)//tei:div[@xml:id=substring($r/@target, 2)]/tei:div[@type='definition']/tei:p/text()
  return
  <li>{<a class="badge badge-light" href="{$dtype}.html?uuid={substring($r/@target, 2)}&amp;ontshow=true">{$r/text()}</a>, 
  <small style="display:block;">{$def}</small>, 
  if ($cnt < 3) then 
  <ul>{tlslib:ontology-up(substring($r/@target, 2), $cnt+1)}</ul>
  else "..."}
  </li>
};

(: this covers now also the rhet-dev ontology :)

declare function tlslib:ontology-links($uid as xs:string, $type as xs:string, $cnt as xs:int){
  let $concept := collection($config:tls-data-root)//tei:div[@xml:id=$uid],
  $dtype := $concept/@type,
  $hyp := $concept//tei:list[@type=$type]//tei:ref
  return
    for $r in $hyp
    let $def := collection($config:tls-data-root)//tei:div[@xml:id=substring($r/@target, 2)]/tei:div[@type='definition']/tei:p/text()
     return
     <li>
      <a  class="badge badge-light" href="{$dtype}.html?uuid={substring($r/@target, 2)}&amp;ontshow=true">{$r/text()}</a>
      <small style="display:inline;">　{$def}</small>
      {
      if ($cnt < 3) then 
      <ul>
      {tlslib:ontology-links(substring($r/@target, 2), $type, $cnt + 1)}
      </ul>
      else 
      if (count( 
      collection($config:tls-data-root || "/concepts")//tei:div[@xml:id=substring($r/@target, 2)]//tei:list[@type=$type]//tei:ref
      ) > 1) then
        <span>...</span>
      else ()  
      }
      </li>
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

declare function tlslib:get-translations($textid as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
  (: this is trying to work around a bug in fn:collection 
  TODO: This fails if the user is guest.  Make a guest collection /db/users/guest? No, guest can't access the translation
  :)
  , $t1 := collection($config:tls-user-root || $user || "/translations")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator'] 
  , $t2 := collection($config:tls-translation-root)//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator']
  , $rn := collection($config:tls-data-root||"/notes/research")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator']
  , $t3 := if (exists($rn)) then $rn else 
  (: create research notes file if necessary :)
  let $tmp := tlslib:store-new-translation("en", $textid, "TLS Project", "Research Notes", "", "option4", "option2", "notes", "") 
  return 
    collection($config:tls-data-root||"/notes/research")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator' or @role='creator']   
 let $tr := map:merge((
  for $ed in  ($t1, $t2, $t3)
   let $t := $ed/ancestor::tei:TEI
   , $tid := data($t/@xml:id)
   , $type := if ($t/@type) then if ($t/@type = "transl") then "Translation" else 
   if ($t/@type = "notes") then "Research Notes" else
   "Comments" else "Translation"
   , $lg := if ($type = "Translation") then
       $t//tei:bibl[@corresp="#"||$textid]/following-sibling::tei:lang/text() 
       else  
       if ($t//tei:bibl[@corresp="#"||$textid]/following-sibling::tei:ref) then 
        let $rel-tr:= substring($t//tei:bibl[@corresp="#"||$textid]/following-sibling::tei:ref/@target, 2) 
        , $this-tr := ($t1, $t2)[ancestor::tei:TEI[@xml:id=$rel-tr]] 
       return
        "to transl. by " || $this-tr/text()
       else "" 
   , $lic := $t//tei:availability/@status
   , $resp := if ($ed/text()) then $ed/text() else "anon"
   return
   map:entry($tid, ($t, $resp, if ($lg) then $lg else "en", if ($lic) then xs:int($lic) else 3, $type)),
   (: now we look for variants :)
   for $v in collection($config:tls-texts-root || "/manifests/")//mf:edition[starts-with(@id, $textid)]
   for $ed in $v/ancestor::mf:editions//mf:edition
    let $lang := data($ed/@language)
    , $edid := data($ed/@id)
    , $desc := $ed/mf:description/text()
    , $etp := data($ed/@type)
    where $lang = "lzh"
   return
   map:entry($edid, ($edid ||"::" || $desc, "x", $lang, 3, $etp))
   ))
   return $tr
};
  
  
declare function tlslib:proc-char($node as node(), $edit as xs:string?)
{ 
typeswitch ($node)
  case element(tei:list) return
  <ul >{for $n in $node/node()
       return
       tlslib:proc-char($n, $edit)
  }</ul>
  case element(tei:item) return
    if (exists($node/tei:ref)) then
    <li class="jstree-open" tei-target="{$node/tei:ref/@target}" tei-ref="{$node/tei:ref/text()}">{for $n in $node/node()
        return tlslib:proc-char($n, $edit)
    }</li>
    else
    <li class="jstree-open" tei-type="{$node/@type}" tei-corresp="{$node/@corresp}">{for $n in $node/node()
        return
            tlslib:proc-char($n, $edit)
    }</li>
  case element(tei:refx) return
     let $id := substring($node/@target, 2)
     ,$concept := normalize-space($node/text())
     return
      <a href="concept.html?uuid={$id}" class="mr-2 ml-2">{$concept}</a>
  
  case element(tei:ref) return
     let $id := substring($node/@target, 2),
     $char := tokenize($node/ancestor::tei:div[1]/tei:head/text(), "\s")[1],
     $swl := collection($config:tls-data-root)//tei:div[@xml:id=$id]//tei:entry[tei:form/tei:orth[. = $char]]//tei:sense
      (: this is the concept originally defined in the taxononomy file! :)
     ,$swl-count := count($swl)
     ,$concept := if (exists($node/@altname)) then data($node/@altname) else normalize-space($node/text())
     , $e := string-length($edit) > 0
     return
      if ($e) then 
      (: only show the plain concept when editing :)
      $concept
       else
      <span>
      {if ($swl-count = 0) then 
      <a href="concept.html?uuid={$id}" class="text-muted mr-2 ml-2" title="Concept pending: not yet attributed for this character">{$concept}</a>
      else 
      (
      <a href="concept.html?uuid={$id}" class="mr-2 ml-2">{$concept}</a>
       ,
      <button title="click to reveal {count($swl)} syntactic words" class="btn badge badge-light" type="button" 
      data-toggle="collapse" data-target="#{$id}-swl">{$swl-count}</button>)}
      <ul class="list-unstyled collapse" id="{$id}-swl"> 
      {for $sw in $swl
      (: we dont check for attribution count, so pass -1  :)
      return tlslib:display-sense($sw, -1, false())}
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
 <img class="icon" style="width:12px;height:15px;top:0;align:top" src="resources/icons/{$icon}"/>
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

declare function tlslib:get-sf-def($sfid as xs:string, $type as xs:string){
let $sfdef := if ($type= 'syn-func') then 
  doc($config:tls-data-root || "/core/syntactic-functions.xml")//tei:div[@xml:id=$sfid]/tei:p/text()
  else 
  doc($config:tls-data-root || "/core/semantic-features.xml")//tei:div[@xml:id=$sfid]/tei:p/text()
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
declare function tlslib:proc-seg($node as node()){
 typeswitch ($node)
 case element(tei:note) return ()
(:     <small>{$node/text()}</small>:)
  case element (tei:l) return ()
  case element (tei:c) return data($node/@n)
  case element (tei:lb)  return ()
  case element (exist:match) return <mark>{$node/text()}</mark>
  case element(tei:seg) return (if (string-length($node/@n) > 0) then data($node/@n)||"　" else (), for $n in $node/node() return tlslib:proc-seg($n))
  case attribute(*) return () 
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
let $title := collection($config:tls-texts-root) //tei:TEI[@xml:id=$txtid]//tei:titleStmt/tei:title/text()
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
                                {if ("tls-user" = sm:id()//sm:group) then 
                                <a class="dropdown-item" href="changes.html">Recent changes</a>
                                else ()}
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
(:=
TODO: move to XHR
:)
declare function tlslib:navbar-bookmarks(){
let $user := sm:id()//sm:real/sm:username/text()
,$bm := doc($config:tls-user-root || $user|| "/bookmarks.xml")
,$ratings := doc("/db/users/" || $user || "/ratings.xml")//text


return
(
 <li class="nav-item dropdown">
  <a class="nav-link dropdown-toggle" href="#"  id="navbarDropdownBookmarks" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">Bookmarks</a>
   <div class="dropdown-menu" aria-labelledby="navbarDropdownBookmarks">
   {if ($bm) then 
    for $b in $bm//tei:item
      let $segid := $b/tei:ref/@target,
      $date := xs:dateTime($b/@modified)
      order by $date descending
     return
    <a class="dropdown-item" href="textview.html?location={substring($segid,2)}" title="Created: {$date}"><span class="bold">{$b/tei:ref/tei:title/text()}</span>: {$b/tei:seg}</a>
    else 
    <span class="text-muted px-1">You can add bookmarks by clicking on <img class="icon"  src="resources/icons/open-iconic-master/svg/bookmark.svg"/> after selecting a character.</span>,
  if (count($ratings) > 0) then 
    for $t in $bm//text
      let $r := xs:int($t/@rating),
      $id := data($t/@id)
      order by $r descending
     return
    <a class="dropdown-item" href="textview.html?location={$id}"><span class="bold">{$t/text()}</span></a>
    else 
    <span class="text-muted px-1">You can star texts in the lists available under the menu item "Browse->Text" or in the text detail display available by clicking on "Source:" to the right of the Blue Eye, visible when a text is displayed.</span>    
    }
   </div>
 </li>,
 <li class="nav-item dropdown">
  <a class="nav-link dropdown-toggle" href="#"  id="navbarDropdownStars" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"><span class="bold" style="color:red;">★</span></a>
   <div class="dropdown-menu" aria-labelledby="navbarDropdownStars">
   {if (count($ratings) > 0) then 
    for $t in $ratings
      let $r := xs:int($t/@rating),
      $id := data($t/@id)
      order by $r descending
     return
    <a class="dropdown-item" href="textview.html?location={$id}&amp;mode=visit"><span class="bold">{$t/text()}</span><span class="text-muted px-1">({$r})</span></a>
    else 
    <span class="text-muted px-1">You can star texts in the lists available under the menu item "Browse->Text" or in the text detail display available by clicking on "Source:" to the right of the Blue Eye, visible when a text is displayed.</span>    
    }
   </div>
 </li>
) 
};

(:     
     :)

declare function tlslib:navbar-review($context as xs:string){
 <li class="nav-item dropdown">
  <a class="nav-link dropdown-toggle" href="#"  id="navbarDropdownEditors" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">內部</a>
   <div class="dropdown-menu" aria-labelledby="navbarDropdownEditors">
     <a class="dropdown-item" href="review.html?type=swl">Review SWLs</a>
     <a class="dropdown-item" href="review.html?type=gloss">Add pronounciation glosses</a>
     <a class="dropdown-item" href="review.html?type=special">Special pages</a>
     {if ($context = 'textview') then 
     <a class="dropdown-item" href="#" onClick="zh_start_edit()">Edit Chinese text</a>
     else ()}
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
declare function tlslib:tv-headerx($node as node()*, $model as map(*)){
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
   session:create(),
   let $textid := $model('textid'),
   $tsrc := if ($textid and map:contains($config:txtsource-map, $textid)) then 
          map:get($config:txtsource-map, $textid) 
      else 
         if (substring($model('textid'), 1, 3) = "KR6") then "CBETA" 
         else "CHANT", 
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
      </li>,
     <li class="nav-item">
      <button id="blue-eye" title="Please wait, SWL are still loading." class="btn btn-primary ml-2" type="button" data-toggle="collapse" data-target=".swl">
       <img class="icon" src="resources/icons/open-iconic-master/svg/eye.svg"/>
      </button>
   </li>
   ,
      <li class="nav-item">
      <span class="navbar-text ml-2" title="Click here for more information" data-toggle="collapse" data-target="#srcref">Source: 
      {$tsrc}
      </span>
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
    <a class="dropdown-item" title="{$locseg}" href="textview.html?location={$locseg}&amp;prec=0&amp;foll=30">{$node/tei:head//text()}</a>
  else (),
 for $d in $node/child::tei:div
 return tlslib:generate-toc($d)
};

declare function tlslib:get-content-id($textid as xs:string, $slot as xs:string, $tr as map(*)){
   let $show-transl := not(contains(sm:id()//sm:group/text(), "guest")),
   $slot-no := xs:int(substring-after($slot, 'slot')) - 1,
   $usergroups := sm:id()//sm:group/text(),   
   $select := for $t in map:keys($tr)
        let $lic := $tr($t)[4]
        where if ($show-transl) then $lic < 5 else $lic < 3
        (: TODO in the future, maybe also consider the language :)
        order by $lic ascending
        return $t,
   $content-id := if (("tls-test", "guest") = $usergroups) then 
     tlslib:session-att($textid || "-" || $slot, $select[1 + $slot-no]) else
        let $t1 := tlslib:get-settings()//tls:section[@type='slot-config']/tls:item[@textid=$textid and @slot=$slot]/@content
        return
        if ($t1) then data($t1)
        else if (count($select) > $slot-no) then $select[1 + $slot-no] else "new-content"
  return if (string-length($content-id) > 0) then $content-id else "new-content"
};

(:~
 Display a selection menu for translations and commentaries, given the current slot and type
:)
declare function tlslib:trsubmenu($textid as xs:string, $slot as xs:string, $trid as xs:string, $tr as map(*)){
 let $edtps := ("documentary", "interpretative")
 let $keys := for $k in map:keys($tr)
           let $tm := $tr($k)[5]
           order by $tm
           where not($k = ($trid, "content-id")) return $k
    ,$type := if ($trid and map:contains($tr, $trid)) then $tr($trid)[5] else "Translation"       
 return
  <div class="dropdown" id="{$slot}" data-trid="{$trid}">
            <button class="btn btn-secondary dropdown-toggle" type="button" id="ddm-{$slot}" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
            {if ($trid and map:contains($tr, $trid)) 
            then ( if ($tr($trid)[5] = $edtps) then 
             ("Edition " ||  substring-after($tr($trid)[1], "::") || " (" || $trid, substring($tr($trid)[5], 1, 3) || ")")
            else
            ($tr($trid)[5], 
            if ($tr($trid)[5] = "Comments") then () else  " by " ||  $tr($trid)[2])) 
            else "Translation"} 
            </button>
    <div class="dropdown-menu" aria-labelledby="dropdownMenuButton">
        {  for $k at $i in $keys
            return 
         if ($tr($k)[5] = "Comments") then 
        <a class="dropdown-item" id="sel{$slot}-{$i}" onclick="get_tr_for_page('{$slot}', '{$k}')" href="#">{$tr($k)[5] || " " }  {$tr($k)[3]}</a>
        else
        if ($tr($k)[5] = $edtps) then 
        <a class="dropdown-item" id="sel{$slot}-{$i}" onclick="get_tr_for_page('{$slot}', '{$k}')" href="#">Edition {substring-after($tr($k)[1], "::")} ({$k}, {substring($tr($k)[5], 1, 3)} )</a>
        else
        <a class="dropdown-item" id="sel{$slot}-{$i}" onclick="get_tr_for_page('{$slot}', '{$k}')" href="#">{$tr($k)[5]} by {$tr($k)[2]}({$tr($k)[3]})</a>
        }
        {if ("tls-user" = sm:id()//sm:group) then
        <a class="dropdown-item" onclick="new_translation('{$slot}')" href="#"> <button class="btn btn-warning" type="button">New translation / comments</button></a> else ()
        }
        {if (count($keys) = 0) then 
         if (count(map:keys($tr)) > 0) then  
        <a class="dropdown-item disabled" id="sel-no-trans" href="#">No other translation available</a>
        else 
        <a class="dropdown-item disabled" id="sel-no-trans" href="#">No translation available</a>
        else ()
        }
  </div>
</div>

};

declare function tlslib:display-bibl($bibl as node()){
<li><span class="font-weight-bold">{$bibl/tei:title/text()}</span>
(<span><a class="badge" href="bibliography.html?uuid={replace($bibl/tei:ref/@target, '#', '')}">{$bibl/tei:ref}</a></span>)
<span>p. {$bibl/tei:biblScope}</span>
{for $p in $bibl/tei:note/tei:p return
<p>{$p/text()}</p>}

</li>
};

(:~
: get the following n segs starting at the seg with the xml:id startseg 
: @param $startseg xml:id of a tei:seg element
: @param $n number of elements
: this returns a sequence of nodes
:)

declare function tlslib:next-n-segs($startseg as xs:string, $n as xs:int){
let $targetseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$startseg]
return
$targetseg/following::tei:seg[fn:position() < $n]
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
      $d := $targetseg/ancestor::tei:div[1],
      $head := $d/tei:head[1],
      $sc := count($d//tei:seg),
      $xpos := index-of($d//tei:seg/@xml:id, $targetseg/@xml:id),
(:      $title := $model('title')/text(),:)
      $dseg := ($pseg, $targetseg, $fseg),
(:      $model := if (string-length($model?textid) > 0) then $model else map:put($model, "textid", tokenize($targetseg, "_")[1]), :)
      $show-transl := not(contains(sm:id()//sm:group/text(), "guest")),
      $show-variants := xs:boolean(1),
      $visit := tlslib:record-visit($targetseg),
      $tr := if ($show-transl) then tlslib:get-translations($model?textid) else map{},
      $slot1-id := tlslib:get-content-id($model?textid, 'slot1', $tr),
      $slot2-id := tlslib:get-content-id($model?textid, 'slot2', $tr),
      $atypes := distinct-values(for $s in $dseg/@xml:id
        let $link := "#" || $s
        return
        for $node in (collection($config:tls-data-root|| "/notes")//tls:ann[.//tls:srcline[@target=$link]] | collection($config:tls-data-root|| "/notes")//tls:span[.//tls:srcline[@target=$link]] ) return 
        (: need to special case the legacy type ann=swl :)
        if (local-name($node)='ann') then "nswl" else data($node/@type))
    return
      (
      <div id="chunkrow" class="row">
      <!-- here is where we select what to display -->
      <div id="srcref" class="col-sm-12 collapse" data-toggle="collapse">
      {tlslib:textinfo($model?textid)}
      </div>
      <!-- here is where we select what to display -->
      {if (count($atypes) > 1) then 
      <div id="swlrow" class="col-sm-12 swl collapse" data-toggle="collapse">
       <div class="row">
         <div class="col-sm-2" id="swlrow-1"><span class="font-weight-bold">Select type of annotation:</span></div>
         <div class="col-sm-5" id="swlrow-2">{for $a in $atypes return <button id="{$a}-select" onclick="showhide('{$a}')" title="{tlslib:annotation-types($a)[2]}" class="btn btn-primary ml-2" type="button">{tlslib:annotation-types($a)[1]}</button>}</div>
      </div>
      </div>
      else ()
      }
      <div id="toprow" class="col-sm-12">
      
      {(:  this is the same structure as the one display-seg will fill it 
      with selection for translation etc, we use this as a header line :)()}
       <div class="row">
        <div class="col-sm-2" id="toprow-1"><span class="font-weight-bold">{$head}</span><span class="btn badge badge-light">line {$xpos} / {($xpos * 100) idiv $sc}%</span><!-- zh --></div>
        <div class="col-sm-5" id="toprow-2"><!-- tr -->
        {if ($show-transl) then tlslib:trsubmenu($model?textid, "slot1", $slot1-id, $tr) else ()}
        </div>
        <div class="col-sm-4" id="toprow-3">
        {if ($show-transl) then tlslib:trsubmenu($model?textid, "slot2", $slot2-id, $tr) else ()}
        </div>
        </div>
      </div>
      <div id="chunkcol-left" class="col-sm-12">{for $d at $pos in $dseg 
      return tlslib:display-seg($d, map:merge(($model, $tr, 
      map{'slot1': $slot1-id, 'slot2': $slot2-id, 
          'loc' : data($targetseg/@xml:id), 
          'pos' : $pos, "ann" : "xfalse.x"})))}</div>
      <div id="chunkcol-right" class="col-sm-0">
      {tlslib:swl-form-dialog('textview')}
    </div>
    </div>,
      <div class="row">
      <div class="col-sm-2">
      {if ($dseg) then  
      (: currently the 0 is hardcoded -- do we need to make this customizable? :)
       <button type="button" class="btn" onclick="page_move('{tokenize($dseg/@xml:id, "_")[1]}&amp;first=true')" title="Go to the first page"><span style="color: blue">First</span></button>
       else ()}
       </div>
      <div class="col-sm-2">
      {if ($dseg[1]/preceding::tei:seg[1]/@xml:id) then  
       <button type="button" class="btn" onclick="page_move('{$dseg[1]/preceding::tei:seg[1]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=2')" title="Go to the previous page"><span style="color: blue">Previous</span></button>
       else ()}
       </div>
       <div class="col-sm-2">
       {
       if ($dseg[last()]/following::tei:seg[1]/@xml:id) then
       <button type="button" class="btn" onclick="page_move('{$dseg[last()]/following::tei:seg[1]/@xml:id}&amp;prec=2&amp;foll={$foll+$prec -2}')" title="Go to the next page"><span style="color: blue">Next</span></button>
       else ()}
       </div> 
       <div class="col-sm-2">
       {
       if ($dseg/following::tei:seg[last()]/@xml:id) then
       <button type="button" class="btn" onclick="page_move('{$dseg/following::tei:seg[last()]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=0')" title="Go to the last page"><span style="color: blue">Last</span></button>
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
    <h5 class="card-title"><span id="new-att-title">{if (sm:is-authenticated()) then "New Attribution:" else "Existing SW for " }<strong class="ml-2"><span id="swl-query-span">Word or char to annotate</span>:</strong></span>
<span id="domain-lookup-mark">
    <span>　　Lookup domain:<select id="domain-select" onChange="update_swlist()"><option value="core">Core</option>{for $d in xmldb:get-child-collections($config:tls-data-root||'/domain') return <option value="{$d}">{tlslib:capitalize-first($d)}</option>}</select></span>
    {if (1 = 2) then
    (: do not display for the time being  :) 
    <span>　　<span class="btn badge badge-light" type="button" data-toggle="collapse" data-target="#mark-buttons" >Mark</span>

    <span id="mark-buttons" class="collapse"><p>{for $d in collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@type='inline'] return 
    <button onClick="save_mark('{data($d/@xml:id)}','{$d//tei:head/text()}')" style="{data($d/@rend)}">{$d//tei:head/text()}</button>}</p></span>
    </span>
    else ()
    }
    </span>
    <button type="button" class="close" onclick="hide_new_att()" aria-label="Close" title="Close"><img class="icon" src="resources/icons/open-iconic-master/svg/circle-x.svg"/></button>
    </h5>
    <h6 class="text-muted">At:  <span id="swl-line-id-span" class="ml-2">Id of line</span>&#160;
    {tlslib:format-button-common("bookmark_this_line()","Bookmark this location", "open-iconic-master/svg/bookmark.svg")}</h6>
    <h6 class="text-muted">Line: <span id="swl-line-text-span" class="ml-2">Text of line</span>
    {tlslib:format-button-common("add_rd_here()","Add observation (regarding a text segment) starting on this line", "octicons/svg/comment.svg")}</h6>
    <div class="card-text">
       
        <p> { if (sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then <span id="new-att-detail">
        <span class="badge badge-primary">Use</span> one of the following syntactic words (SW), 
        create a <span class="mb-2 badge badge-secondary">New SW</span> 
         ,add an <span class="font-weight-bold">existing</span> <span class="btn badge badge-primary ml-2" onclick="show_new_concept('existing', '')">Concept</span> to the word
         or create a <span class="btn badge badge-primary ml-2" onclick="show_new_concept('new', '')">New Concept</span>.
         </span>
         else <span id="new-att-detail">You do not have permission to make attributions.</span>
         }
         <span id="swl-jisho"></span>
        <ul id="swl-select" class="list-unstyled"></ul>
        </p>
      </div>
    </div>    
else 
 <div class="card-body">
    <h5 class="card-title"><span id="new-att-title">Existing SW for <strong class="ml-2"><span id="swl-query-span"></span></strong></span>
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
 : 2020-11-09 : zi also uses master definition
:) 
(:~
: formats a single syntactic word location for display either in a row (as in the textview, made visible by the blue eye) or as a list item, this is used in the left hand display for the annotations
: @param $node  the tls:ann element to display
: @param $type  type of the display, currently 'row' for selecting the row style, anything else will be list style
: called from api/show_swl_for_line.xql
: 2021-10-15: also display other annotation types (e.g. rhetorical devices etc.)
:)
declare function tlslib:format-swl($node as node(), $options as map(*)){
let $user := sm:id()//sm:real/sm:username/text(),
$usergroups := sm:get-user-groups($user),
(: already used swl as a class, so need a different one here; for others we want the type given in the source :)
$anntype := if (local-name($node)='ann') then "nswl" else if (local-name($node)='drug') then "drug" else data($node/@type),
$type := $options?type,
$context := $options?context
let $concept := data($node/@concept),
$creator-id := substring($node/tls:metadata/@resp, 2),
$zi := string-join($node/tei:form/tei:orth/text(), "/")
(: 2021-03-17 we ignore the pinyin from SWL, retrieve the one from concept below as $cpy :)
(:$py := $node/tei:form[1]/tei:pron[starts-with(@xml:lang, 'zh-Latn')][1]/text(),:)
,$link := substring(tokenize($node/tei:link/@target)[2], 2)
(: 2021-03-17 below we get the data from the CONCEPT entry, rather than the SWL, all we need in the SWL now is the link :)
, $s := collection($config:tls-data-root)//tei:sense[@xml:id=$link]
, $w := $s/ancestor::tei:entry
, $czi := string-join($w/tei:form/tei:orth/text(), " / ")
, $cpy := string-join($w/tei:form/tei:pron[@xml:lang='zh-Latn-x-pinyin']/text(), " / ")
,$cdef := $w/ancestor::tei:div/tei:div[@type="definition"]/tei:p/text()
,$sf := $s//tls:syn-func
,$sm := $s//tls:sem-feat
,$def := tlslib:get-sense-def($link)
,$rid := $options?line-id || "-" || $node/@xml:id 
(:$pos := concat($sf, if ($sm) then (" ", $sm) else "")
:)
return
if ($type = "row") then
if ($anntype eq "nswl") then
<div class="row bg-light {$anntype}">
{if (not($context = 'review')) then 
<div class="col-sm-1"><span class="{$anntype}-col">●</span>
<!--
      <span id="input-{$rid}" class="starRating">
        <input id="{$rid}-rating3" type="radio" name="rating" value="3" checked="true"/>
        <label for="{$rid}-rating3">3</label>
        <input id="{$rid}-rating2" type="radio" name="rating" value="2"/>
        <label for="{$rid}-rating2" >2</label>
        <input class="starRatingOn" id="{$rid}-rating1" type="radio" name="rating" value="1"/>
        <label for="{$rid}-rating1" class="starRatingOn">1</label>
      </span>
-->      
</div>
else ()}
<div class="col-sm-2"><span class="zh">{$czi}</span> ({$cpy})
{if  ("tls-admin.x" = sm:get-user-groups($user)) then (data(($node//tls:srcline/@pos)[1]),
 <a href="{
      concat($config:exide-url, "?open=", document-uri(root($node)))}">eXide</a>)
      else ()
  }    
</div>
<div class="col-sm-3"><a href="concept.html?concept={$concept}#{$w/@xml:id}" title="{$cdef}">{$concept}</a></div>
<div class="col-sm-6">
<span><a href="browse.html?type=syn-func&amp;id={data($sf/@corresp)}">{$sf/text()}</a>&#160;</span>
{if ($sm) then 
<span><a href="browse.html?type=sem-feat&amp;id={$sm/@corresp}">{$sm/text()}</a>&#160;</span> else ()}
{$def}
{
if ("tls-editor"=sm:get-user-groups($user) and $node/@xml:id) then 
(: for the time being removing the button, don't really know what I would want to edit here:-)
 <button type="button" class="btn" onclick="edit_swl('{$node/@xml:id}')" style="width:10px;height:20px;" 
 title="Edit Attribution">
 <img class="icon" onclick="edit_swl('{$node/@xml:id}')" style="width:10px;height:13px;top:0;align:top" src="resources/icons/open-iconic-master/svg/pencil.svg"/>
 </button> 
 :)
(
 (:   tlslib:format-button("delete_swl('swl', '" || data($node/@xml:id) || "')", "Request deletion of SWL for "||$zi, "open-iconic-master/svg/x.svg", "small", "close", "tls-editor"),:)
 (: for reviews, we display the buttons in tlslib:show-att-display, so we do not need them here :)
  if (not($context='review')) then
   (
(:   <input id="input-{$node/@xml:id}" style="display:inline;" name="input-name" type="number" class="rating" 
    min="0" max="3" step="1" data-theme="krajee-svg" data-size="xs" value="3"/>,  :)

(:      <span id="input-{$rid}" class="starRating">
        <input id="{$rid}-rating3" type="radio" name="rating" value="3" checked="true"/>
        <label for="{$rid}-rating3">3</label>
        <input id="{$rid}-rating2" type="radio" name="rating" value="2"/>
        <label for="{$rid}-rating2">2</label>
        <input id="{$rid}-rating1" type="radio" name="rating" value="1"/>
        <label for="{$rid}-rating1">1</label>
      </span>,
      
      <span id="input-{$rid}" class="starRating pull-right">
        <label for="{$rid}-rating3" class="icon" style="width:12px;height:15px;top:0;align:bottom"></label>
        <label for="{$rid}-rating2" class="icon"  style="width:12px;height:15px;top:0;align:bottom"></label>
        <label for="{$rid}-rating1" class="icon"  style="width:12px;height:15px;top:0;align:bottom"></label>
      </span>    
      
      :)



   (: for my own swls: delete, otherwise approve :)
   if (($user = $creator-id) or contains($usergroups, "tls-editor" )) then 
    tlslib:format-button("delete_swl('swl', '" || data($node/@xml:id) || "')", "Immediately delete this SWL for "||$zi[1], "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else (),
   if (not ($user = $creator-id)) then
   (
<span class="rp-5">
{tlslib:format-button("review_swl_dialog('" || data($node/@xml:id) || "')", "Review the SWL for " || $zi[1], "octicons/svg/unverified.svg", "small", "close", "tls-editor")}&#160;&#160;</span>,   
    tlslib:format-button("save_swl_review('" || data($node/@xml:id) || "')", "Approve the SWL for " || $zi, "octicons/svg/thumbsup.svg", "small", "close", "tls-editor")
    ) else ()
  ) else ()
)
else ()
}
</div>
</div>
else if ($anntype eq "drug") then
<div class="row bg-light {$anntype}">
 <div class="col-sm-2"><span class="{$anntype}-col">drug</span></div>
 <div class="col-sm-6">{$node/text()}, Q:{data($node/@quantity)}, FL:{data($node/@flavor)}
 {
   if (($user = $creator-id) or contains($usergroups, "tls-editor" )) then 
    tlslib:format-button("delete_swl('drug', '" || data($node/@xml:id) || "')", "Immediately delete the observation "||data($node/text()), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()
}
</div>
</div>
else
(: not swl, eg: rhet-dev etc :)
<div class="row bg-light {$anntype}" style="{if ($anntype ne 'nswl') then 'display:None;' else ()}">
{
let $role := if (ends-with(data($node/tls:text[tls:srcline[@target="#"||$options?line-id]]/@role), 'start')) then "(●" else "●)"
return
(
 <div class="col-sm-2"><span class="{$anntype}-col">{$role}</span></div>,
 <div class="col-sm-6">{if ($anntype='rdl') then <a href="rhet-dev.html?uuid={$node/@rhet-dev-id}">{data($node/@rhet-dev)}</a> else
 if ($anntype = 'comment') then
 (<span class="text-muted">{collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@xml:id=$anntype]/tei:head/text() || ":　"}</span>, 
  if ($role eq "(●") then
   (: for the comment, we display the note, not the @name, which does not make sense here.. :)
   <span class="{$anntype}-name" data-uuid="{data($node/@xml:id)}" data-lineid="{$options?line-id}">{data($node/tls:note)}</span>
  else ()
  ) 
 else
 (collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@xml:id=$anntype]/tei:head/text() || "　", 
  if ($role eq "(●") then
   <span class="{$anntype}-name" data-uuid="{data($node/@xml:id)}" data-lineid="{$options?line-id}">{data($node/@name)}</span>
  else ()
 )}
{
   if (($user = $creator-id) or contains($usergroups, "tls-editor" )) then 
    tlslib:format-button("delete_swl('rdl', '" || data($node/@xml:id) || "')", "Immediately delete the observation "||data($node/@rhet-dev), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()
}
 </div>
) 
}
</div>
(: not in the row :)
else 
<li class="list-group-item" id="{$concept}">{$cpy} {$concept} {$sf} {$sm} {
if (string-length($def) > 10) then concat(substring($def, 10), "...") else $def}</li>
};

(:~
: displays a tei:seg element, that is, a line of text, including associated items like translation and swl
: @param $seg the tei:seg to display
: @param $options  a map of additional options, for example 
:         {"ann" : true } for the display of annotations,
:        {"loc" : "<@xml:id of a tei:seg>"} the id of a line to be highlighted in the display
: @see tlslib:format-swl(), which is used for displaying the swl
: called from tlsapi:get-text-preview($loc as xs:string, map)
: 
:)

declare function tlslib:display-seg($seg as node()*, $options as map(*) ) {
 let $user := sm:id()//sm:real/sm:username/text(),
 $usergroups := sm:get-user-groups($user),
 $show-transl := not(contains(sm:id()//sm:group/text(), "guest")),
 $testuser := contains(sm:id()//sm:group, ('tls-test', 'guest'))
 let $link := concat('#', $seg/@xml:id),
  (: we are displaying in a reduced context, only 2 rows  :)
  $ann := lower-case(map:get($options, "ann")),
  $loc := map:get($options, "loc"),
  $mark := if (data($seg/@xml:id) = $loc) then "mark" else ()
  ,$lang := 'zho'
  ,$alpheios-class := if ($user = 'test2') then 'alpheios-enabled' else ''
  ,$slot1 := if ($show-transl) then 
     if (map:contains($options, "transl")) then $options?transl
     else map:get($options, $options?slot1)[1] else ()
  ,$slot2 := if ($show-transl and not($ann = 'false')) then map:get($options, $options?slot2)[1] else ()
  (: check if transl + comment are related, if yes than do not manipulate tab-index :)
  (: if tei:TEI, then we have a translation, otherwise a variant :)
  , $px1 := typeswitch ($slot1) case element(tei:TEI) return  replace(($slot1//tei:seg[@corresp="#"||$seg/@xml:id]/@resp)[1], '#', '') default return () 
  ,$resp1 := if ($px1) then "Resp: "||doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px1]//tei:persName/text() else ()
  , $px2 :=  typeswitch ($slot2) case element(tei:TEI) return replace(($slot2//tei:seg[@corresp="#"||$seg/@xml:id]/@resp)[1], '#', '') default return () 
  ,$resp2 :=  if ($px2) then "Resp: "||doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$px2]//tei:persName/text() else () 
(: normalize-space(string-join($seg/text(),'')) :)
return
(
<div class="row {$mark}">
<div class="{if ($seg/parent::tei:head) then 'tls-head ' else () }{if ($ann='false') then 'col-sm-4' else 'col-sm-2'} zh {$alpheios-class}" lang="{$lang}" id="{$seg/@xml:id}" data-tei="{ util:node-id($seg) }">{tlslib:proc-seg($seg)}{(:if (exists($seg/tei:anchor/@xml:id)) then <span title="{normalize-space(string-join($seg/ancestor::tei:div//tei:note[tei:ptr/@target='#'||$seg/tei:anchor/@xml:id]/text()))}" >●</span> else ():) ()}</div>　
<div class="col-sm-5 tr" title="{$resp1}" lang="en-GB" tabindex="{$options('pos')+500}" id="{$seg/@xml:id}-tr" contenteditable="{if (not($testuser)) then 'true' else 'false'}">{typeswitch ($slot1) 
case element(tei:TEI) return  $slot1//tei:seg[@corresp="#"||$seg/@xml:id]/text()
default return (krx:get-varseg-ed($seg/@xml:id, substring-before($slot1, "::")))
}</div>
 {if ($ann = 'false') then () else 
 (: using en-GB for now, need to get that from translation in the future...  :)
  <div class="col-sm-4 tr" title="{$resp2}" lang="en-GB" tabindex="{$options('pos')+1000}" id="{$seg/@xml:id}-ex" contenteditable="{if (not($testuser)) then 'true' else 'false'}">
  {typeswitch ($slot2) 
case element(tei:TEI) return $slot2//tei:seg[@corresp="#"||$seg/@xml:id]/text()  
default return

(krx:get-varseg-ed($seg/@xml:id, substring-before($slot2, "::")))

}
  </div>}
</div>,
<div class="row swl collapse" data-toggle="collapse">
<div class="col-sm-10 swlid" id="{$seg/@xml:id}-swl">
{if (starts-with($ann, "false")) then () else 
for $swl in collection($config:tls-data-root|| "/notes")//tls:srcline[@target=$link]
let $pos := if (string-length($swl/@pos) > 0) then xs:int(tokenize($swl/@pos)[1]) else 0
order by $pos
return
if ($swl/ancestor::tls:ann) then ()
(:tlslib:format-swl($swl/ancestor::tls:ann, map{'type' : 'row'}):)
else 
<div class="row bg-light ">
<div class="col-sm-1">Rhet:</div>
<div class="col-sm-4"><a href="rhet-dev.html?uuid={$swl/ancestor::tls:span/@rhet-dev-id}">{data($swl/ancestor::tls:span/@rhet-dev)}</a>
{
let $creator-id := substring($swl/ancestor::tls:span/@resp, 2)
return
   if (($user = $creator-id) or contains($usergroups, "tls-editor" )) then 
    tlslib:format-button("delete_swl('rdl', '" || data($swl/ancestor::tls:span/@xml:id) || "')", "Immediately delete the attribution of rhetorical device "||data($swl/ancestor::tls:span/@rhet-dev), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()
}
</div>
</div>
}
</div>
<div class="col-sm-2"></div>
</div>
)
};

 (:~ 
 : called from function tlsapi:show-use-of($uid as xs:string, $type as xs:string), which is called via XHR from concept.html and char.html through 
 : tls-app.js -> show_use_of(type, uid) 
 : @param $sw the tei:sense to display 
 : 2020-02-26 it seems this belongs to tlsapi
 :)
 
declare function tlslib:display-sense($sw as node(), $count as xs:int, $display-word as xs:boolean){
    let $id := if ($sw/@xml:id) then data($sw/@xml:id) else substring($sw/@corresp, 2),
    $sf := ($sw//tls:syn-func/text())[1],
    $sm := $sw//tls:sem-feat/text(),
    $user := sm:id()//sm:real/sm:username/text(),
    $def := $sw//tei:def/text(),
    $char := $sw/preceding-sibling::tei:form[1]/tei:orth/text()
    return
    <li id="{$id}">
    {if ($display-word) then <span class="ml-2">{$char}</span> else ()}
    <span id="sw-{$id}" class="font-weight-bold">{$sf}</span>
    <em class="ml-2">{$sm}</em> 
    <span class="ml-2">{$def}</span>
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp" onclick="show_att('{$id}')">
          {if ($count > -1) then $count else ()}
          {if ($count = 1) then " Attribution" else  " Attributions" }
      </button>
     {if ($user = "guest") then () else 
      if ($count != -1 and not($display-word)) then
     <button title="Search for this word" class="btn badge btn-outline-success ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp1" onclick="search_and_att('{$id}')">
      <img class="icon-small" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
      </button> else (),
      if ($count = 0) then
      tlslib:format-button("delete_word_from_concept('"|| $id || "')", "Delete the syntactic word "|| $sf || ".", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else 
      if ($count > 0) then (
      tlslib:format-button("move_word('"|| $char || "', '"|| $id ||"', '"||$count||"')", "Move the SW  '"|| $sf || "' including "|| $count ||"attribution(s) to a different concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor") ,      
      tlslib:format-button("merge_word('"|| $sf || "', '"|| $id ||"', '"||$count||"')", "Delete the SW '"|| $sf || "' and merge "|| $count ||"attribution(s) to a different SW.", "open-iconic-master/svg/wrench.svg", "", "", "tls-editor")       
      )
      else ()
      }
      <div id="{$id}-resp" class="collapse container"></div>
      <div id="{$id}-resp1" class="collapse container"></div>
    </li>
 
 };

(:~
: called from tlsapi:save-sf($sense-id as xs:string, $synfunc-id as xs:string, $synfunc-val as xs:string, $def as xs:string)
 : 2020-02-26 it seems this belongs to tlsapi
 : 2021-03-16 extended to cover sem-feat as well
:)
 
declare function tlslib:new-syn-func ($sf as xs:string, $def as xs:string, $type as xs:string){
 let $uuid := concat("uuid-", util:uuid()),
 $sfdoc := if ($type = "syn-func") then  doc($config:tls-data-root || "/core/syntactic-functions.xml")
  else doc($config:tls-data-root || "/core/semantic-features.xml") ,
 $sf := normalize-space($sf),
 $sfexist := $sfdoc//tei:head[. = $sf],
 $user := sm:id()//sm:real/sm:username/text(),
$el := <div xmlns="http://www.tei-c.org/ns/1.0" type="{$type}" xml:id="{$uuid}" resp="#{$user}" tls:created="{current-dateTime()}">
<head>{$sf}</head>
<p>{$def}</p>
</div>,
$last := $sfdoc//tei:div[@type=$type][last()]
,$ret := if (not($sfexist)) then update insert $el following $last else ()
return if ($sfexist) then $sfexist/parent::tei:div/@xml:id else $uuid
 };
 
 (:~
 : called from function tlsapi:show-att($uid as xs:string)
  : 2020-02-26 it seems this belongs to tlsapi
  : 2020-03-13 this is called from app:recent 
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
<div class="col-sm-7"><span>{$tr/text()}</span>
{if ((sm:has-access(document-uri(fn:root($a)), "w") and $a/@xml:id) and not(contains(sm:id()//sm:group, 'tls-test'))) then 
(
(:tlslib:format-button("review_swl_dialog('" || data($a/@xml:id) || "')", "Review this attribution", "octicons/svg/unverified.svg", "small", "close", "tls-editor"),:)
tlslib:format-button("delete_swl('swl', '" || data($a/@xml:id) || "')", "Delete this attribution", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor"),
 if (not ($user = substring($a/tls:metadata/@resp, 2))) then
    tlslib:format-button("save_swl_review('" || data($a/@xml:id) || "')", "Approve the SWL", "octicons/svg/thumbsup.svg", "small", "close", "tls-editor") else ()
)
else ()}
</div>
</div>
};



(: ~
 : on visiting a page, record the visit in the history.xml file
:)
 
declare function tlslib:record-visit($targetseg as node()){
let $user := sm:id()//sm:real/sm:username/text(),
$groups := sm:get-user-groups($user),
$cm := substring(string(current-date()), 1, 7),
$doc := if ("guest" = $groups) then () else tlslib:get-visit-file($cm),
$date := current-dateTime(),
$item := <item xmlns="http://www.tei-c.org/ns/1.0" modified="{current-dateTime()}"><ref target="#{$targetseg/@xml:id}">{$targetseg/text()}</ref></item>
return 
if ($doc) then
update insert $item  into $doc//tei:list[@xml:id="vis-" || $cm || "-start"]
else ()
};

declare function tlslib:get-visit-file($cm as xs:string){
  let $user := sm:id()//sm:real/sm:username/text(),
  $doc-path := $config:tls-user-root|| $user || "/visits-" || $cm || ".xml",
  $doc := if (not(doc-available($doc-path))) then 
    doc(xmldb:store($config:tls-user-root|| $user,  "visits-" || $cm || ".xml",
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="vis-{$user}-{$cm}">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Visited pages for month {$cm}</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
         </publicationStmt>
         <sourceDesc>
            <p>Created by members of the TLS project</p>
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation>Initially created: <date>{current-dateTime()}</date> for {$user}.</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      <div><head>Visited pages</head>
      <list type="visits" xml:id="vis-{$cm}-start"></list>
      </div>
      </body>
  </text>
</TEI>))
    else doc($doc-path)
  return $doc
};




declare function tlslib:get-crypt-file($type as xs:string){
  let $cm := substring(string(current-date()), 1, 7),
  $doc-name := if (string-length($type) > 0 ) then $type || "-" || $cm || ".xml" else $cm || ".xml",
  $doc-path :=  $config:tls-data-root || "/vault/crypt/" || $doc-name,
  $doc := if (not(doc-available($doc-path))) then 
    let $res := 
    xmldb:store($config:tls-data-root || "/vault/crypt/" , $doc-name, 
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="del-{$type}-{$cm}-crypt">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Recorded items for month {$cm}</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
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
      <div><head>Items</head>
      <p xml:id="del-{$cm}-start"></p>
      </div>
      </body>
  </text>
</TEI>)
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

(:~
 : saves the content-id of a content selected for a s slot for a text
:)
declare function tlslib:settings-save-slot($slot as xs:string, $textid as xs:string, $content-id as xs:string) {
let $settings := tlslib:get-settings(),
  $current-setting := $settings//tls:section[@type='slot-config']/tls:item[@textid=$textid and @slot=$slot] 
let $proc := 
if ($current-setting) then 
 (update value $current-setting/@content with $content-id,
 update value $current-setting/@modified with current-dateTime())
else 
 let $newitem := <item xmlns="http://hxwd.org/ns/1.0" created="{current-dateTime()}" modified="{current-dateTime()}" slot="{$slot}" textid="{$textid}" content="{$content-id}"/>
 return
 update insert $newitem into $settings//tls:section[@type='slot-config']
 return
 (:  we return the content-id for the case where this is used in a then clause of if statement:)
 $content-id
};
(:~
 : this creates a new empty stub for various user settings (if necessary) and returns the doc
:)
declare function tlslib:get-settings() {
let $user := sm:id()//sm:real/sm:username/text()
, $filename := "settings.xml"
,$docpath := $config:tls-user-root || $user || "/" || $filename
let $doc :=
  if (not (doc-available($docpath))) then
   doc(xmldb:store($config:tls-user-root || $user, $filename, 
<settings xmlns="http://hxwd.org/ns/1.0" xml:id="{$user}-settings">
<section type="bookmarks"></section>
<section type="slot-config"></section>
</settings>)) 
 else doc($docpath)
return $doc
};

declare function tlslib:merge-sw-word($map as map(*)){
let $sw := collection($config:tls-data-root||"/concepts")//tei:*[@xml:id=$map?wid]
, $target := collection($config:tls-data-root||"/concepts")//tei:*[@xml:id=$map?target]
,$user := sm:id()//sm:real/sm:username/text()
, $r :=
for $s in collection($config:tls-data-root||"/notes")//tei:sense[@corresp="#" || $map?wid] 
 let $newsense := 
 <sense xmlns="http://www.tei-c.org/ns/1.0" corresp="#{$target/@xml:id}">
 {$target//tei:gramGrp, $target//tei:def}
 </sense>
 , $md := <respStmt xmlns="http://www.tei-c.org/ns/1.0" created="{current-dateTime()}" resp="#{$user}">
 <resp>changed SW</resp>
 <name>{$user}</name>
 </respStmt>
 , $ann := $s/ancestor::tls:ann
 return 
 if ($target) then
   (
   update replace $ann//tei:sense with $newsense,
   update insert $md into $ann//tls:metadata
   )
 else ()
return "OK"
};

(:~
 : move W with all SW to a new concept
 @param $word : the word to move.  must exist in src-concept
 @param $src-concept: uuid of concept where the word is currently defined
 @param $trg-concept: uuid of concept where the words should be moved to, must exist and the word must not exist there already
:)
declare function tlslib:move-word-to-concept($map as map(*)){
 util:declare-option("exist:serialize", "method=json media-type=application/json"),
if ($map?type = "word") then 
tlslib:move-entry-to-concept($map)
else 
tlslib:move-sw-to-concept($map)
};

declare function tlslib:move-entry-to-concept($map as map(*)){
 let $sc := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id=$map?src-concept]
 ,$tc := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id=$map?trg-concept]
 ,$tc-name := $tc/tei:head/text()
 ,$sc-name := $sc/tei:head/text()
 ,$sw := $sc//tei:orth[. = $map?word]/ancestor::tei:entry
 ,$swl := for $a in collection($config:tls-data-root||"/notes")//tls:ann[@concept-id=$map?src-concept] 
        let $wx := $a//tei:orth[. = $map?word]
        where ($wx)
        return $a
 ,$resp-uuid := "uuid-" || util:uuid()       
 ,$user := sm:id()//sm:real/sm:username/text()
 ,$cm := substring(string(current-date()), 1, 7)
 ,$rdoc := tlslib:get-crypt-file("changes")
 ,$rec := <respStmt xml:id="{$resp-uuid}" xmlns="http://www.tei-c.org/ns/1.0" resp="#{$user}"><name>{$user}</name><resp notBefore="{current-dateTime()}">started moving {$map?word} and {count($swl)} attribution(s) from 
 <ref corresp="#{$map?src-concept}">{$sc-name}</ref>to <ref corresp="#{$map?trg-concept}">{$tc-name}</ref>. </resp></respStmt>
 return
 if ($sc and count($tc//tei:orth[. = $map?word]) = 0) then 
   let $tw := $tc//tei:div[@type="words"]
   return
     if ($tw) then (
       update insert $rec into $rdoc//tei:p[@xml:id="del-" || $cm || "-start"],
       update insert $sw into $tw,
       update delete $sw,
     for $a in $swl 
       return
     (
     if ($a/tls:metadata/@concept) then 
     update replace $a/tls:metadata/@concept with $tc-name else
     update insert attribute concept {$tc-name}  into $a ,
     if ($a/tls:metadata/@concept-id) then 
     update replace $a/tls:metadata/@concept-id with $map?trg-concept else
     update insert attribute concept-id {$map?trg-concept}  into $a ,
     map {'uuid': $resp-uuid,  'mes' : "OK! Moved " || $map?word || " and "|| count($swl) ||" attribution(s) to concept " || $tc-name || ".'"} 
     )
 
 ) else "NO!! no words div in concept file"
 else map{'uuid': (), 'mes' : "ERROR: Word already exists in concept " || $tc-name || "."}
};

(: actually, move  SW , depending on $map?type  :)
declare function tlslib:move-sw-to-concept($map as map(*)){
 let $sc := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id=$map?src-concept]
 ,$tc := (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@xml:id=$map?trg-concept]
 ,$tc-name := $tc/tei:head/text()
 ,$sc-name := $sc/tei:head/text()
 ,$tw := $tc//tei:div[@type="words"]
 ,$sw := $sc//tei:orth[. = $map?word]/ancestor::tei:entry
 ,$wid :=  "uuid-" || util:uuid()
 (: for swl the map?wid actuallt holds the sense id :)
 ,$scsw := $sc//tei:sense[@xml:id=$map?wid]
 ,$swl := for $a in collection($config:tls-data-root||"/notes")//tls:ann[@concept-id=$map?src-concept] 
         let $wx :=  $map?wid = substring($a/tei:sense/@corresp, 2)
         where ($wx)
        return $a
  (: rec :)      
 ,$resp-uuid := "uuid-" || util:uuid()       
 ,$user := sm:id()//sm:real/sm:username/text()
 ,$cm := substring(string(current-date()), 1, 7)
 ,$rdoc := tlslib:get-crypt-file("changes")
 ,$rec :=  <respStmt xml:id="{$resp-uuid}" xmlns="http://www.tei-c.org/ns/1.0" resp="#{$user}"><name>{$user}</name><resp notBefore="{current-dateTime()}">started moving SW {$scsw} of {$map?word} and {count($swl)} attribution(s) from 
 <ref corresp="#{$map?src-concept}">{$sc-name}</ref>to <ref corresp="#{$map?trg-concept}">{$tc-name}</ref>. </resp></respStmt>
 , $tce := <entry  xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$wid}">
       {$sw//tei:form}
       {$scsw}
     </entry>
 return     
 (
 if (not($tw)) then "NO!! no words div in concept file" else 
  (: if ($scsw) then $scsw else :)
   if ($sc and count($tc//tei:orth[. = $map?word]) = 0) then
      (update insert $tce into $tw,
       update delete $scsw)
     else 
   (: word exists already in tc, we just move the sense over 
    need to make sure to use only one tei:entry.  How do we know this is the right one?
   :)
    let $te := ($tw//tei:orth[. = $map?word]/ancestor::tei:entry[not(.//tei:sense[@xml:id=$map?wid])])[1]
    return 
    (update insert $scsw into $te
     ,update delete $scsw )
    (: and now, finally, we update the swls :) 
    ,
     for $a in $swl 
       return
     (
     if ($a/tls:metadata/@concept) then 
     update replace $a/tls:metadata/@concept with $tc-name else
     update insert attribute concept {$tc-name}  into $a ,
     if ($a/tls:metadata/@concept-id) then 
     update replace $a/tls:metadata/@concept-id with $map?trg-concept else
     update insert attribute concept-id {$map?trg-concept}  into $a) 
     ,
     map {'uuid': $resp-uuid,  'mes' : "OK! Moved " || $map?word || " and "|| count($swl) ||" attribution(s) to concept " || $tc-name || ".'"} 
  )   
};

declare function tlslib:move-done($map as map(*)){
let $resp:=  tlslib:get-crypt-file("changes")//tei:respStmt[@xml:id=$map?uuid]/tei:resp
return
     update insert attribute notAfter {current-dateTime()} into $resp
};


declare function tlslib:get-text-preview($loc as xs:string, $options as map(*)){

let $seg := collection($config:tls-texts-root)//tei:seg[@xml:id = $loc],
$context := if($options?context) then $options?context else 5,
$format := if($options?format) then $options?format else 'tooltip',
$title := $seg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
$pseg := $seg/preceding::tei:seg[fn:position() < $context],
$fseg := $seg/following::tei:seg[fn:position() < $context],
$dseg := ($pseg, $seg, $fseg),
$textid := tokenize($loc, "_")[1],
$tr := tlslib:get-translations($textid),
$slot1 := if ($options?transl-id) then $options?transl-id else tlslib:get-settings()//tls:section[@type='slot-config']/tls:item[@textid=$textid and @slot='slot1']/@content,
$transl := if ($slot1) then $tr($slot1) else ()
(:$transl := collection("/db/apps/tls-data")//tei:bibl[@corresp="#"||$textid]/ancestor::tei:fileDesc//tei:editor[@role='translator']:)
return
if ($format = 'tooltip') then
<div class="popover" role="tooltip">
<div class="arrow"></div>
<h3 class="popover-header">
<a href="textview.html?location={$loc}">{$title}</a></h3>
<div class="popover-body">
    {
for $d in $dseg 
return 
    (: we hardcode the translation slot to 1; need to make sure that 1 always has the one we want :)
    tlslib:display-seg($d, map{"transl" : $transl[1], "ann": "false", "loc": $loc})
    }
</div>
</div>
else 
<div class="col">
    {
for $d in $dseg 
return 
    (: we hardcode the translation slot to 1; need to make sure that 1 always has the one we want :)
    tlslib:display-seg($d, map{"transl" : $transl[1], "ann": "false", "loc": $loc})
    }
</div>
};

(: This displays the list of words by concept in the right hand popup pane  :)
declare function tlslib:get-sw($word as xs:string, $context as xs:string, $domain as xs:string) as item()* {
let $w-context := ($context = "dic") or contains($context, "concept")
, $coll := if ($domain = "core") then "/concepts/" else "/domain/"||$domain
let $words-tmp := if ($w-context) then 
  collection($config:tls-data-root||$coll)//tei:orth[contains(. , $word)]
  else
  collection($config:tls-data-root||$coll)//tei:entry/tei:form/tei:orth[. = $word]
  (: this is to filter out characters that occur multiple times in a entry definition (usually with different pronounciations, however we actually might want to get rid of them :)
, $words := for $w in $words-tmp
   let $e := $w/ancestor::tei:entry
   group by $e
   return $w[1]
let $user := sm:id()//sm:real/sm:username/text()
, $doann := contains($context, 'textview')  (: the page we were called from can annotate :)
, $edit := sm:id()//sm:groups/sm:group[. = "tls-editor"] and $doann
, $taxdoc := doc($config:tls-data-root ||"/core/taxchar.xml")
(: creating a map as a combination of the concepts in taxchar and the existing concepts :)
, $wm := map:merge((
    for $c in $taxdoc//tei:div[tei:head[. = $word]]//tei:ref
        let $s := $c/ancestor::tei:list/preceding::tei:item[@type='pron'][1]/text()
        let $pys := tokenize(normalize-space($s), '\s+')        
        , $py := if (tlslib:iskanji($pys[1])) then $pys[2] else $pys[1]
        return map:entry(substring($c/@target, 2), map {"concept": $c/text(), "py" : $py, "zi" : $word})
    ,
    for $w in $words
    let $concept := $w/ancestor::tei:div/tei:head/text(),
    $wid := $w/ancestor::tei:entry/@xml:id,
    $concept-id := $w/ancestor::tei:div/@xml:id,
    $py := $w/parent::tei:form/tei:pron[starts-with(@xml:lang, 'zh-Latn')]/text(),
    $zi := $w/parent::tei:form/tei:orth/text(),
    $cwid := concat(data($concept-id), "::", data($wid))
    group by $concept-id
    return map:entry($concept-id, map {"concept": $concept, "py" : $py, "zi" : $zi, "w" : $w})
    ))          
return
if (map:size($wm) > 0) then
for $id in map:keys($wm)
let $concept := map:get($wm($id), "concept"),
(:$w := map:get($wm($id), "w"):)
(:$w := collection(concat($config:tls-data-root, '/concepts/'))//tei:entry[@xml:id = $cid[2]]//tei:orth:)
$w := collection($config:tls-data-root||$coll)//tei:div[@xml:id = $id]//tei:orth[. = $word]
,$cdef := $w/ancestor::tei:div/tei:div[@type="definition"]/tei:p/text(),
$form := $w/parent::tei:form/@corresp,
$z := map:get($wm($id), "zi")
(:$py := for $p in map:get($wm($id), "py")
        return normalize-space($p):)
(:group by $concept:)
order by $concept[1]
return
(: since I used "order by" for populating the map, some values are sequences now, need to disentangle that here  :)
for $zi at $pos in distinct-values($z) 
(: there might be more than one entry that has the char $zi, so $wx is a sequence of one or more
 we need to loop through these entries:)
for $wx at $pw in (collection($config:tls-data-root||$coll)//tei:div[@xml:id = $id]//tei:orth[. = $zi])[1]
(: we take only the first, because for multiple readings of the same char, we have two entries here :)


let $scnt := for $w1 in $wx return
           count($w1/ancestor::tei:entry/tei:sense),
$wid := $wx/ancestor::tei:entry/@xml:id,
$syn := $wx/ancestor::tei:div[@xml:id = $id]//tei:div[@type="old-chinese-criteria"]//tei:p,
$py := for $pp in $wx/ancestor::tei:entry/tei:form[tei:orth[.=$zi]]/tei:pron[@xml:lang="zh-Latn-x-pinyin"] return normalize-space($pp),
$esc := replace($concept[1], "'", "\\'")
return
<li class="mb-3">
{if ($zi) then
(: todo : check for permissions :)
(<strong>
{ if (not ($w-context)) then <a href="char.html?char={$zi}" title="Click here to go to the taxonomy for {$zi}"><span id="{$wid}-{$pos}-zi">{$zi}</span></a> else <span id="{$wid}-{$pos}-zi">{$zi}</span>}
</strong>,<span id="{$wid}-{$pos}-py" title="Click here to change pinyin" onclick="assign_guangyun_dialog({{'zi':'{$zi}', 'wid':'{$wid}','py': '{$py[$pos]}','concept' : '{$esc}', 'concept_id' : '{$id}', 'pos' : '{$pos}'}})">&#160;({string-join($py, "/")})&#160;</span>)
else ""}
<strong><a href="concept.html?uuid={$id}#{$wid}" title="{$cdef}" class="{if ($scnt[$pw] = 0) then 'text-muted' else ()}">{$concept[1]}</a></strong> 

{if ($doann and sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then 
 if ($wid) then     
 <button class="btn badge badge-secondary ml-2" type="button" 
 onclick="show_newsw({{'wid':'{$wid}','py': '{string-join($py, "/")}','concept' : '{$esc}', 'concept_id' : '{$id}'}})">
           New SW
      </button>
else 
<button class="btn badge badge-secondary ml-2" type="button" 
onclick="show_newsw({{'wid':'xx', 'py': '{string-join($py, "/")}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">
           New Word
      </button>
   else ()}

{if ($scnt > 0) then      
<span>      
{if (count($syn) > 0) then
<button title="Click to view {count($syn)} synonyms" class="btn badge badge-info" data-toggle="collapse" data-target="#{$wid}-syn">SYN</button> else 
if ($edit) then 
<button title="Click to add synonyms" class="btn" onclick="new_syn_dialog({{'char' : '{$zi}','concept' : '{$concept}', 'concept_id' : '{$id}'}})">＋</button>
else ()
}
<button title="click to reveal {count($wx/ancestor::tei:entry/tei:sense)} syntactic words" class="btn badge badge-light" type="button" data-toggle="collapse" data-target="#{$wid}-concept">{$scnt}</button>
<ul class="list-unstyled collapse" id="{$wid}-syn" style="swl-bullet">{
for $l in $syn
return
<li>{$l}</li>
}
</ul>
<ul class="list-unstyled collapse" id="{$wid}-concept" style="swl-bullet">{for $s in $wx/ancestor::tei:entry/tei:sense
let $sf := ($s//tls:syn-func)[1],
$sfid := substring(($sf/@corresp), 2),
$sm := $s//tls:sem-feat/text(),
$smid := substring($sm/@corresp, 2),
$def := $s//tei:def/text(),
$sid := $s/@xml:id,
$clicksf := if ($edit) then concat("get_sf('" , $sid , "', 'syn-func')") else "",
$clicksm := if ($edit) then concat("get_sf('" , $sid , "', 'sem-feat')") else "",
$atts := count(collection(concat($config:tls-data-root, '/notes/'))//tls:ann[tei:sense/@corresp = "#" || $sid])
order by $sf
(:  :)
return
<li>
<span id="pop-{$s/@xml:id}" class="small btn">●</span>

<a href="#" onclick="{$clicksf}" title="{tlslib:get-sf-def($sfid, 'syn-func')}">{$sf/text()}</a>&#160;{
if (string-length($sm) > 0) then
<a href="#" onclick="{$clicksm}" title="{tlslib:get-sf-def($smid, 'sem-feat')}">{$sm}</a>
else 
 if ($edit) then
(: allow for newly defining sem-feat :) 
 <a href="#" onclick="{$clicksm}" title="Click here to add a semantic feature to the SWL">＋</a>
 else ()

}: 
<span class="swedit" id="def-{$sid}" contenteditable="{if ($edit) then 'true' else 'false'}">{ $def}</span>
    {if ($edit) then 
     <button class="btn badge badge-warning ml-2" type="button" onclick="save_def('def-{$sid}')">
           Save
     </button>
    else ()}
     { if (sm:is-authenticated()) then 
     (
     if ($user != 'test' and $doann) then
     <button class="btn badge badge-primary ml-2" type="button" onclick="save_this_swl('{$s/@xml:id}')">
           Use
      </button> else ()) else ()}
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$sid}-resp" onclick="show_att('{$sid}')">
      <span class="ml-2">SWL: {$atts}</span>
      </button> 
      
      <div id="{$sid}-resp" class="collapse container"></div>
</li>
}
</ul>
</span> 
else ()
}
</li>
else 
<li class="list-group-item">No word selected or no existing syntactic word found.</li>
};



(: query in dictionary :)
declare function tlslib:dic-query($queryStr as xs:string?, $mode as xs:string?)
{
tlslib:get-sw($queryStr, "dic", "core")
};

(: query in translation :)
declare function tlslib:tr-query($queryStr as xs:string?, $mode as xs:string?)
{
  let $user := sm:id()//sm:real/sm:username/text()
  let $dataroot := ($config:tls-translation-root, $config:tls-user-root || $user || "/translations")
  let $w := collection($dataroot)//tei:seg[contains(. , $queryStr)]
  for $a in $w
  return $a
};

(: paragraph based query :)
(:declare function tlslib:ngram-p-query($queryStr as xs:string?, $mode as xs:string?, $search-type as xs:string?, $stextid as xs:string?)
{tlslib:do-ngram-query($queryStr, $mode, $search-type, $stextid, "tei:p")};:)

(: query in texts :)
(:declare function tlslib:ngram-query($queryStr as xs:string?, $mode as xs:string?, $search-type as xs:string?, $stextid as xs:string?)
{tlslib:do-ngram-query($queryStr, $mode, $search-type, $stextid, "tei:seg")};:)

declare function tlslib:ngram-query($queryStr as xs:string?, $mode as xs:string?, $search-type as xs:string?, $stextid as xs:string?)
{
    let $dataroot := ($config:tls-data-root, $config:tls-texts-root, $config:tls-user-root)
    let $qs := tokenize($queryStr, "\s"),
    $user := sm:id()//sm:real/sm:username/text(),
    $ratings := doc($config:tls-user-root || $user || "/ratings.xml")//text,
    $dates := if (exists(doc("/db/users/" || $user || "/textdates.xml")//date)) then 
      doc("/db/users/" || $user || "/textdates.xml")//data else 
      doc($config:tls-texts-root || "/tls/textdates.xml")//data,
    (: HACK: if no login, use date mode for sorting :)
    $mode := if ($user = "guest") then "date" else $mode,
    $matches := if  (count($qs) > 1) then 
      collection($dataroot)//tei:p[ngram:wildcard-contains(., $qs[1]) and ngram:wildcard-contains(., $qs[2])]
      else
      (: 2022-02-24 for one char searches, go only in tls texts; this needs more discussion... :)
      if ($search-type = "5") then 
      collection($dataroot)//tei:TEI[@xml:id=$stextid]//tei:p[ngram:wildcard-contains(., $qs[1])]
      else
      if (string-length($qs[1]) < 2) then
      collection($config:tls-texts-root || "/tls")//tei:p[ngram:wildcard-contains(., $qs[1])]
      else
      collection($dataroot)//tei:p[ngram:wildcard-contains(., $qs[1])]
    for $hit in $matches
      let $textid := substring-before(tokenize(document-uri(root($hit)), "/")[last()], ".xml"),
      (: for the CHANT text no text date data exist, so we use this flag to cheat a bit :)
      $flag := substring($textid, 1, 3),
      $filter := if ($search-type = "5") then $stextid = $textid else 
       if ($search-type = "6") then 
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
(: query for multiple terms :)
declare function tlslib:multi-query1($queryStr as xs:string?, $mode as xs:string?, $search-type as xs:string?, $stextid as xs:string?)
{
tlslib:ngram-query($queryStr, $mode, $search-type, $stextid)
};

(: 
:)

declare function tlslib:multi-query($queryStr as xs:string?, $mode as xs:string?, $search-type as xs:string?, $stextid as xs:string?)
{
    let $dataroot := ($config:tls-data-root, $config:tls-texts-root, $config:tls-user-root)
    let $qs := tokenize($queryStr, ";"),
    $user := sm:id()//sm:real/sm:username/text(),
    $ratings := doc($config:tls-user-root || $user || "/ratings.xml")//text,
    $dates := if (exists(doc("/db/users/" || $user || "/textdates.xml")//date)) then 
      doc("/db/users/" || $user || "/textdates.xml")//data else 
      doc($config:tls-texts-root || "/tls/textdates.xml")//data,
    (: HACK: if no login, use date mode for sorting :)
    $mode := if ($user = "guest") then "date" else $mode,
    $matches := if  (count($qs) > 1) then 
      collection($dataroot)//tei:p[ngram:wildcard-contains(., $qs[1]) and ngram:wildcard-contains(., $qs[2])]
      else
      collection($dataroot)//tei:p[ngram:wildcard-contains(., $qs[1])]
    for $hit in $matches
      let $textid := substring-before(tokenize(document-uri(root($hit)), "/")[last()], ".xml"),
      (: for the CHANT text no text date data exist, so we use this flag to cheat a bit :)
      $flag := substring($textid, 1, 3),
      $filter := if ($search-type = "5") then $stextid = $textid else 
       if ($search-type = "6") then 
        let $x := "#" || $hit/@xml:id
        return collection($config:tls-translation-root)//tei:seg[@corresp=$x]
      else true(),
      $sx := for $s in $hit//tei:seg
            return
            if (matches($s, $qs[1]) or matches($s, $qs[2])) then
                $s else (),

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
    return $sx
};

(: get related texts: look at Manifest.xml :)

declare function tlslib:get-related($map as map(*)){
let $line := $map?line
,$sid := $map?seg
, $res := krx:collate-request($sid)
, $edid := string-join(subsequence(tokenize($sid, "_"), 1,2), "_")
, $mf := collection($config:tls-texts-root || "/manifests/")//mf:edition[@id=$edid]/ancestor::mf:editions
return
<li class="mb-3">
{for $w in $res//witnesses 
return
<ul><li>{collection($config:tls-texts-root || "/manifests/")//mf:edition[@id=$w/id]/mf:description} ({$w/id})<p>
{string-join(for $t in $w/tokens return
(data($t/@t), data($t/@f)), '') 
}</p>
</li>
</ul>
}
</li>
};

declare function tlslib:translation-firstseg($transid as xs:string){
let $dataroot := ($config:tls-translation-root, $config:tls-user-root)
, $doc := collection($dataroot)//tei:TEI[@xml:id=$transid]
, $firstseg := substring((for $s in $doc//tei:seg
                let $id := $s/@corresp
                order by $id
                return $id)[1], 2)
  return $firstseg
};

declare function tlslib:title-query($query, $mode){
let $dataroot := ($config:tls-texts-root, $config:tls-user-root)
for $t in collection($dataroot)//tei:titleStmt/tei:title[contains(., $query)]
return $t
};

(: $gyonly controls wether we offer to override GY.  Most probably false.. :)

declare function tlslib:get-guangyun($chars as xs:string, $pron as xs:string, $gyonly as xs:boolean){
(: loop through the characters of the string $chars :)
for $char at $cc in  analyze-string($chars, ".")//fn:match/text()
return
<div id="guangyun-input-dyn-{$cc}">
<h5><strong class="ml-2">{$char}</strong>　{tlslib:guguolin($char)}</h5>
{let $r:= collection(concat($config:tls-data-root, "/guangyun"))//tx:graphs//tx:graph[contains(.,$char)]
return 
(
if ($r) then
for $g at $count in $r
let $e := $g/ancestor::tx:guangyun-entry,
$p := for $s in ($e//tx:mandarin/tx:jin|$e//tx:mandarin/tx:jiu) 
       return 
       if (string-length(normalize-space($s)) > 0) then $s else (),
$py := normalize-space(string-join($p, ';'))
, $oc := normalize-space($e//tx:old-chinese/tx:pan-wuyun/tx:oc/text())
, $mc := normalize-space($e//tx:middle-chinese//tx:baxter/text())
return
(
<div class="form-check">
   { if (contains($py, $pron) and $gyonly) then (: todo: handle pron for binomes and more :)
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}" checked="checked"/>
   else
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}"/>
   }
   <label class="form-check-label" for="guangyun-input-{$cc}-{$count}">
     {$e/tx:gloss} - {$p[1]}
     {if ($oc[1] or $mc[1]) then
     <span class="text-muted"> ({
     if ($oc[1]) then "OC:" || $oc else (),
     if ($mc[1]) then "MC:" || $mc else ()
     })</span>
     else ()}
   </label>
  </div>,
  if ($p[2]) then 
  <div class="form-check">
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}-2" 
   value="{$e/@xml:id}$jiu"/>
   <label class="form-check-label" for="guangyun-input-{$cc}-{$count}-2">
     <span class="text-muted">同上</span>, 舊音 -  {$p[2]}
   </label>  
  </div>
  else ()
  )
  else (),
  if (not ($gyonly) or not ($r)) then
  <div class="form-check">
   { if (not ($r)) then
   <label class="form-check-label" for="guangyun-input-{$cc}-9">
     Character not in 廣韻, please enter pinyin directly after ‘{$char}:’ 
   </label> 
   else
   <label class="form-check-label" for="guangyun-input-{$cc}-9">
     For a different reading, please enter pinyin directly after ‘{$char}:’ 
   </label>
   }
  <input class="guangyun-input-checked" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-9" type="text" value="{$char}:"/>
  </div> else ()
)}
</div>
};


declare function tlslib:save-new-syllable($map as map(*)){
let $uid := "uuid-"||util:uuid()
,$timestamp := current-dateTime()
,$user := sm:id()//sm:real/sm:username/text()
,$path := $config:tls-data-root || "/guangyun/" || substring($uid, 6, 1)
let $res:=xmldb:store($path, $uid || ".xml",
<guangyun-entry xmlns="http://exist-db.org/tls" xml:id="{$uid}">
    <graphs>
        <attested-graph>
            <unemended-graph>
                <graph/>
            </unemended-graph>
            <emended-graph>
                <graph/>
            </emended-graph>
            <graph/>
        </attested-graph>
        <standardised-graph>
            <graph>{$map?char}</graph>
        </standardised-graph>
    </graphs>
    <gloss>{$map?gloss}</gloss>
    <xiaoyun>
        <headword/>
        <graph-count/>
    </xiaoyun>
    <fanqie>
        <fanqie-shangzi>
            <fanqie-shangzi-attested>
                <graph/>
            </fanqie-shangzi-attested>
            <fanqie-shangzi-standard>
                <graph/>
            </fanqie-shangzi-standard>
        </fanqie-shangzi>
        <fanqie-xiazi>
            <fanqie-xiazi-attested>
                <graph/>
            </fanqie-xiazi-attested>
            <fanqie-xiazi-standard>
                <graph/>
            </fanqie-xiazi-standard>
        </fanqie-xiazi>
    </fanqie>
    <ids>
        <guangyun-jiaoshi-id/>
        <pan-wuyun-id/>
    </ids>
    <locations>
        <guangyun-location/>
        <baxter-location/>
        <pan-wuyun-location/>
    </locations>
    <pan-wuyun-note-on-guangyun/>
    <pan-wuyun-note/>
    <pronunciation>
        <mandarin>
            <jin>{$map?jin}</jin>
            <wen/>
            <yi/>
            <bai/>
            <jiu/>
        </mandarin>
        <middle-chinese>
            <categories>
                <聲/>
                <等/>
                <呼/>
                <韻部/>
                <調/>
                <重紐/>
                <攝/>
            </categories>
            <yundianwang-reconstructions>
                <li-rong/>
                <pan-wuyun/>
                <wang-li/>
                <pulleyblank/>
                <shao-rongfen/>
                <zhengzhang-shangfang/>
                <karlgren/>
            </yundianwang-reconstructions>
            <authorial-reconstructions>
                <baxter/>
            </authorial-reconstructions>
        </middle-chinese>
        <old-chinese>
            <pan-wuyun>
                <yunbu/>
                <phonetic/>
                <oc/>
            </pan-wuyun>
            <zhengzhang-shangfang>
                <oc/>
                <yunbu/>
                <phonetic/>
                <notes/>
            </zhengzhang-shangfang>
        </old-chinese>
    </pronunciation>
    <note>{$map?note}</note>
    <sources>{$map?sources}</sources>
    <tls:metadata xmlns:tls="http://hxwd.org/ns/1.0" resp="#{$user}" created="{$timestamp}">
        <respStmt>
            <resp>added and approved</resp>
            <name>{$user}</name>
        </respStmt>
    </tls:metadata>
</guangyun-entry>)
return 
(sm:chmod(xs:anyURI($res), "rw-rw-rw-"),
 sm:chgrp(xs:anyURI($res), "tls-user"),
(: sm:chown(xs:anyURI($res), "tls"),:)
 $uid)
};

declare function tlslib:make-form($guangyun-id as xs:string, $chars as xs:string){
(:  if no gy record is found, we return a string like this for guangyun-id "黃:huangxxx蘗:bo" :)
let $jmap := map:merge(
       for $gid in tokenize(normalize-space($guangyun-id), "xxx") 
       let $id := tokenize($gid, "\$")
       return map:entry($id[1], if ($id[2]) then "jiu" else "jin")
           )
let $gys :=    
   for $gid in tokenize(normalize-space($guangyun-id), "xxx") 
   let $r :=  if (contains($gid, "$jiu")) then 
      let $id := substring-before($gid, "$jiu")
      return
      collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$id]
      else 
      collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$gid]

   return
   if ($r) then $r else $gid

 
 let $form :=
(:   let $e := collection(concat($config:tls-data-root, "/guangyun"))//tx:guangyun-entry[@xml:id=$gid],:)
    let $oc := for $gy in $gys
        let $rec := if ($gy instance of element()) then 
        normalize-space($gy//tx:old-chinese/tx:pan-wuyun/tx:oc/text()) else ()
        return if ($rec) then $rec else "--"
    ,$mc := for $gy in $gys 
        let $rec := if ($gy instance of element()) then
        normalize-space($gy//tx:middle-chinese//tx:baxter/text()) else ()
        return if ($rec) then $rec else "--"
    ,$p := for $gy in $gys 
         let $rec := 
         if ($gy instance of element()) then
            let $id := $gy/@xml:id 
              return
            if (map:get($jmap, $id) = "jiu") then
             for $s in $gy//tx:mandarin/tx:jiu
              return
              if (string-length(normalize-space($s)) > 0) then normalize-space($s/text()) else ()
            else
              for $s in $gy//tx:mandarin/tx:jin
              return
              if (string-length(normalize-space($s)) > 0) then normalize-space($s/text()) else ()
           else () 
          return 
           (: we are now creating new syllable records for this case, so this should not happen anymore :)
           if (count($rec) > 0) then $rec 
           else  tokenize($gy, ":")[2] ,
    $gr := for $gy in $gys
      let $r := if ($gy instance of element()) then 
         (: we prefer the standard forms here :)
         if ($gy[1]//tx:standardised-graph/tx:graph) then 
           normalize-space($gy[1]//tx:standardised-graph/tx:graph/text())
         else
           normalize-space($gy[1]//tx:attested-graph/tx:graph/text()) 
       else ()
      return
       (: if we got characters, we use them! :)
      if ($r) then 
      (: let's see what we can do about astral characters (5min later) seems to work -- yeah!! :)
      let $cp := string-to-codepoints($r)
      for $cl in $cp
        return
        if ($cl > 65536) then "&amp;#"||$cl||";" else codepoints-to-string($cl) 
      else tokenize($gy, ":")[1] 
return
    <form xmlns="http://www.tei-c.org/ns/1.0" corresp="#{replace(replace($guangyun-id, 'xxx', ' #'), 
    '\$jiu', '')}">
    <orth>{if (string-length($chars) > 0) then $chars else string-join($gr, "")}</orth>
    <pron xml:lang="zh-Latn-x-pinyin">{string-join($p, " ")}</pron>
    <pron xml:lang="zh-x-mc" resp="rec:baxter">{string-join($mc, " ")}</pron>
    <pron xml:lang="zh-x-oc" resp="rec:pan-wuyun">{string-join($oc, " ")}</pron>
    </form>
return
$form
};



declare function tlslib:review-special($issue as xs:string){
let $user := "#" || sm:id()//sm:username
, $issues := map{
"missing-pinyin" : "Concepts with missing pinyin reading",
"duplicate" : "Concepts with duplicate word entries"
}
return
<div>
<h3>Special pages : {map:get($issues, $issue)}</h3>
 <div class="container">
 <ul>
 {switch ($issue)
 case "missing-pinyin" return 
  let $missing := for $p in (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:pron[@xml:lang="zh-Latn-x-pinyin" and (string-length(.) = 0)] 
  let $z := $p/ancestor::tei:form/tei:orth/text()
  where string-length($z) > 0
  return $p

  for $p in $missing
  let $w := $p/ancestor::tei:entry
  , $c := $p/ancestor::tei:div[@type="concept"]
  let $z := $p/ancestor::tei:form/tei:orth/text()

  return
  <li>{$z}　<a href="concept.html?uuid={$c/@xml:id}#{$w/@xml:id}">{$c/tei:head/text()}</a></li>
(:  tlslib:get-sw($z, "concept"):)
 case "duplicate" return 
 let $dup := 
  for $c in (collection($config:tls-data-root || "/concepts") | collection($config:tls-data-root || "/domain"))//tei:div[@type="concept"]
    for $e in $c//tei:entry
      let $cx := for $o in $e//tei:orth
        let $x := count($c//tei:entry[.//tei:orth[. = $o]])
        let $w := $o/ancestor::tei:entry/@xml:id
              return ($x, $o, $o/ancestor::tei:entry/@xml:id, $w)
    where $cx[1] > 1
   return 
   <li>{$cx[2]/text()}　<a href="concept.html?uuid={$c/@xml:id}&amp;bychar=1#{$cx[4]}">{$c/tei:head/text()}</a> {$cx[1]}</li>
  return (count($dup), $dup)
 default return 
  for $i in map:keys($issues)
  order by $i
  return
  <li><a href="review.html?type=special&amp;issue={$i}">{map:get($issues, $i)}</a></li>
 }
 </ul>
 </div>
</div> 
};

declare function tlslib:review-gloss(){
let $user := "#" || sm:id()//sm:username
  ,$review-items := for $r in 
     (collection($config:tls-data-root || "/guangyun")//tx:guangyun-entry[tx:gloss[starts-with(., "Added by")]] 
    (: | collection($config:tls-data-root || "/guangyun")//tx:guangyun-entry[string-length(tx:gloss) = 0] :)
     )
     let $g := $r/tx:graphs[1]/tx:standardised-graph[1]/tx:graph[1]
       , $date := xs:dateTime($r/tls:metadata/@created)
     order by $date descending
     return $r
return

<div class="container">
<div>
<h3>New pronounciations without gloss: {count($review-items)} items</h3>
<small class="text-muted">Glosses can be added by clicking on "No gloss"<br/>Current pinyin assignments can be confirmed by clicking the pinyin</small>
{for $r at $pos in $review-items
     let $g := $r/tx:graphs[1]/tx:standardised-graph[1]/tx:graph[1]
     ,$py := $r/tx:pronunciation[1]/tx:mandarin[1]/tx:jin[1]
     ,$un := $r/tls:metadata//tx:name
     ,$created := $r/tls:metadata/@created
return
  <div class="row border-top pt-4" id="{data($r/@xml:id)}">
  <div class="col-sm-2">{$g}</div>
  <div class="col-sm-2"><span title="Click here to confirm the current pinyin assignments" onclick="assign_guangyun_dialog({{'zi':'{$g}', 'wid':'','py': '{$py}', 'type' : 'read-only', 'pos' : '{$pos}'}})">{$py}</span></div>  
  <div class="col-sm-3"><span id="gloss-{$pos}" title="Click here to add/change gloss" onclick="update_gloss_dialog({{'zi':'{$g}', 'py': '{$py}', 'uuid': '{$r/@xml:id}',  'pos' : '{$pos}'}})">No gloss</span></div>
  <div class="col-sm-3" title="{$created}">created by {$un}&#160;</div>
  <div class="col-sm-2">{tlslib:format-button("delete_pron('" || data($r/@xml:id) || "')", "Immediately delete pronounciation "||$py||" for "||$g, "open-iconic-master/svg/x.svg", "", "close", "tls-editor")}</div>
  </div>,
()
}
</div>
</div>
};


declare function tlslib:review-swl(){
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

declare function tlslib:format-phonetic($gy as node()){
    let $mand-jin := $gy//tx:pronunciation/tx:mandarin/tx:jin
    , $key := $gy/@xml:id
    , $gloss := $gy//tx:gloss/text()
    , $zi := $gy//tx:graphs
    , $fq := ($gy//tx:fanqie/tx:fanqie-shangzi//tx:graph/text(),
     $gy//tx:fanqie/tx:fanqie-xiazi//tx:graph/text())
  return 
  <div class="row">
  <div class="col-sm-1"><a href="syllables.html?uuid={$key}" class="btn badge badge-light">{$zi}</a></div>
  <div class="col-sm-1">{$fq}</div>
  {for $c in $gy//tx:categories/tx:* return 
  <div class="col-sm-1">{$c//text()}</div>
  }
  <div class="col-sm-1">{$gy//tx:old-chinese/tx:pan-wuyun/tx:oc/text()}</div>
  </div>
};

declare function tlslib:linkheader($qc) {
("Taxonomy of meanings: ", for $c in $qc return  <a class="btn badge badge-light" title="Show taxonomy of meanings for {$c}" href="char.html?char={$c}">{$c}</a>,
         " Phonetic profile: ",
     for $c in $qc return  
     <a class="btn badge badge-light" style="background-color:palegreen" title="Show phonetic profile for {$c}" href="syllables.html?char={$c}">{$c}</a>,
(:     <span>{" 國學大師: ", 
     for $c in $qc return
     tlslib:guoxuedashi($c)
     }</span>,:)
     tlslib:guguolin($qc)
     ,
     (:    var url = "http://www.kaom.net/z_hmy_zidian88.php?word={string-join($qc, '')}&mode=word&bianti=no&page=no"
 :)
     <span>{" 詞典: ",
     <a class="btn badge badge-light" target="dict" title="Search {$qc} in HY dictionary (External link)" style="background-color:paleturquoise" href="http://www.kaom.net/z_hmy_zidian88.php?word={string-join($qc, '')}&amp;mode=word&amp;bianti=no&amp;page=no">{$qc}</a>
     }　</span>
     
     ,
     <span>{" 漢リポ: ",
     <a class="btn badge badge-light" target="kanripo" title="Search {$qc} in Kanseki Repository (External link)" style="background-color:paleturquoise" href="http://www.kanripo.org/search?query={string-join($qc, '')}">{$qc}</a>
     }</span>
)
};

declare function tlslib:guoxuedashi($c as xs:string){
<a class="btn badge badge-light" target="GXDS" title="Search {$c} in 國學大師字典 (External link)" style="background-color:paleturquoise" href="http://www.guoxuedashi.com/so.php?sokeytm={$c}&amp;ka=100">{$c}</a>
};

declare function tlslib:guguolin($qc){
    for $c at $pos in $qc return
<form class="btn badge badge-light"  name="guguolin" target="dict" action="http://www.kaom.net/z_hmy_zidian8.php" method="post" title="訓詁工具書查詢 {$c} (External link)" >
  {if ($pos = 1) then "字書：" else ()}
  <input type="hidden" name="word" id="word" value="{$c}="/>
  <input type="hidden" name="mode" id="mode" value="word" />
  <input type="hidden" name="bianti" id="bianti" value="no"/>
  <input type="hidden" name="page" id="page" value="no"/>
  <button class="btn badge badge-light" type="submit" style="background-color:paleturquoise">{$c}</button>
</form>
};

declare function tlslib:search-top-menu($search-type, $query, $txtmatchcount, $title, $trmatch, $textid, $qc, $count, $mode) {
  switch($search-type)
  case "5" return
       (<a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type=1&amp;textid={$textid}&amp;mode={$mode}">Click here to display all  matches</a>,<br/>)
  case "8" return
       (<a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type=1&amp;textid={$textid}&amp;mode={$mode}">Click here to display all  matches</a>,<br/>)
  default return
   (if ($count < 6000) then 
    ( <a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type=8&amp;textid={$textid}&amp;mode={$mode}">Click here to display matches tabulated by text</a>,<br/>) else (),
      
     if ($trmatch > 0 and not ($search-type="6")) then
     (<a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type=6&amp;mode={$mode}">Click here to display only {$trmatch} matching lines that have a translation</a>,<br/>)
     else 
    (<a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type=1&amp;mode={$mode}">Click here to display all  matches</a>,<br/>)
    ,
    
  if (string-length($title) > 0 and $txtmatchcount > 0) then 
    (<a class="btn badge badge-light" href="search.html?query={$query}&amp;start=1&amp;search-type=5&amp;textid={$textid}&amp;mode={$mode}">Click here to display only {$txtmatchcount} matches in {$title}</a>,<br/>)
  else ()
  ), 
  tlslib:linkheader($qc),
   <br/>
     
};

declare function tlslib:get-obs-node($type as xs:string){
  let $cm := substring(string(current-date()), 1, 7),
  $doc-name :=  $type || ".xml",
  $doc-path :=  $config:tls-data-root || "/notes/facts/" || $doc-name,
  $doc := if (not(doc-available($doc-path))) then 
    let $res := 
    xmldb:store($config:tls-data-root || "/notes/facts/" , $doc-name, 
<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="obs-{$type}">
  <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>Observations of {collection($config:tls-data-root)//tei:TEI[@xml:id="facts-def"]//tei:div[@xml:id=$type]/tei:head/text()}s</title>
         </titleStmt>
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
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
      <div><head>Items</head>
      <tls:span xmlns:tls="http://hxwd.org/ns/1.0" type="dummy" xml:id="uuid-test">
	  </tls:span>
      </div>
      </body>
  </text>
</TEI>)
    return
    (sm:chmod(xs:anyURI($res), "rw-rw-rw-"),
     sm:chgrp(xs:anyURI($res), "tls-user"),
(:     sm:chown(xs:anyURI($res), "tls"),:)
    doc($res)
    )
    else
    doc($doc-path)
  return $doc//tls:span[position()=last()]
};

declare function tlslib:textinfo($textid){
let   $user := sm:id()//sm:real/sm:username/text(),
      $d := collection($config:tls-texts-root)//tei:TEI[@xml:id=$textid],
      $charcount := string-length(normalize-space($d//tei:text)),
      $dates := if (exists(doc("/db/users/" || $user || "/textdates.xml")//date)) then 
      doc("/db/users/" || $user || "/textdates.xml")//data else 
      doc($config:tls-texts-root || "/tls/textdates.xml")//data,
      $date := $dates[@corresp="#" || $textid],
      $loewe := doc($config:tls-data-root||"/bibliography/loewe-ect.xml")//tei:bibl[tei:ref[@target = "#"||$textid]]
return
      <div class="col">
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Edition:</span></div>
           <div class="col-sm-5"><span class="sm">{collection($config:tls-texts-root)//ab[@refid=$textid]}</span>　</div>
         </div>  
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Dates:</span></div>
           <div class="col-sm-5">{
           if ($date) then 
            (<span id="textdate-outer"><span id="textdate" data-not-before="{$date/@notbefore}" data-not-after="{$date/@notafter}">{$date/text()}<span id="textdate-note" class="text-muted">{$date/note/text()}</span></span></span>,
            if (sm:is-authenticated()) then <span class="badge badge-pill badge-light" onclick="edit_textdate('{$textid}')">Edit date</span> else 
            ()) 
           else if (sm:is-authenticated()) then (<span id="textdate-outer"><span id="textdate">　</span></span>,<span class="badge badge-pill badge-light" onclick="edit_textdate('{$textid}')">Add date</span>) else 
            "　"}　</div>
         </div>
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2">{ if (sm:is-authenticated()) then <span class="font-weight-bold float-right" title="Click on one of the stars to rate the text and add to the ★ menu.">Rating:</span> else ()}</div>
           <div classe="col-sm-5">{ if (sm:is-authenticated()) then
           <input id="input-{$textid}" name="input-name" type="number" class="rating"
    min="1" max="10" step="2" data-theme="krajee-svg" data-size="xs" value="{tlslib:get-rating($textid)}"/> else ()}</div> 
        </div>
         <div class="row">        
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Textlength:</span></div>
           <div class="col-sm-5"><span>{$charcount} characters.</span></div>
         </div>   
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Comment:</span></div>
           <div class="col-sm-5"><span class="tr-x" id="{$textid}-com" contenteditable="true">　</span></div>    
         </div>  
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">References:</span></div>
           <div class="col-sm-5"><span>{if ($loewe) then <span>{$loewe/tei:author}, in Loewe(ed), <i>Early Chinese Texts</i> (1995), p.{$loewe/tei:citedRange/text()}<br/></span> else '　'}</span>{ if (sm:is-authenticated()) then <span class="badge badge-pill badge-light"  onclick="add_ref('{$textid}')" title="Add new reference">Add reference</span> else ()}</div>    
         </div>  
      </div>
};



declare function tlslib:advanced-search($query, $mode){
<div><h3>Advanced Search</h3>
</div>
};

declare function tlslib:segid2sequence($start as xs:string, $end as xs:string){
   let  $targetseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$start]
    , $end := $targetseg/following::tei:seg[@xml:id=$end]
    for $s in $targetseg | ($targetseg/following::tei:seg intersect $end/preceding::tei:seg) | $end
    return $s
};

(:~
: this is called from tlsapi:save-rdl to analyze the lines of a recipe and exract the drugs
:)
 

declare function tlslib:analyze-recipe($uuid as xs:string, $map as map(*)){
let $splitstring := "[一二三四五六七八九十半]"
, $ss2 := "[、各]"
(: here we restrict the search to materia medica :)
, $mm := "uuid-42a8724f-316c-11eb-ba56-a9a90876f6fd"
, $start := $map?line_id
, $end := $map?end_val
, $seq := tlslib:segid2sequence($start, $end)
return 
<tls:contents>{
for $s in subsequence($seq, 2)
 let   $drugx := if (contains($s, "、") and contains($s, "各")) then tokenize($s, $ss2)
    else tlslib:remove-punc(tokenize($s, $splitstring)[1])

 , $quant := if (count($drugx) > 1) then tlslib:remove-punc($drugx[3]) else 
    tlslib:remove-punc(substring-after($s, $drugx))
  for $drug in $drugx  
  let $obs := collection($config:tls-data-root || "/domain/medical")//tei:div[@xml:id=$mm]//tei:orth[. = $drug]/ancestor::tei:entry
 ,$c := $obs/ancestor::tei:div
 ,$uuid := concat("uuid-", util:uuid())
  return
  if (exists($obs)) then
  let $fln := (collection($config:tls-texts-root)//tei:seg[ngram:wildcard-contains(.,$drug||"　")])[1]/text()
  , $fl := substring-after($fln, $drug||"　")
  return
  <tls:drug xml:id="{$uuid}" ref="#{$obs/@xml:id}" flavor="{$fl}" target="#{$s/@xml:id}" concept="{$c/tei:head/text()}" concept-id="{$c/@xml:id}" quantity="{$quant}">{$drug}</tls:drug>
  else ()}
  </tls:contents>
}; 


(: 2022-02-21 - moved this from tlsapi to allow non-api use :)

declare function tlslib:store-new-translation($lang as xs:string, $txtid as xs:string, $translator as xs:string, $trtitle as xs:string, $bibl as xs:string, $vis as xs:string, $copy as xs:string, $type as xs:string, $rel-id as xs:string){
  let $user := sm:id()//sm:real/sm:username/text()
  ,$fullname := sm:id()//sm:real/sm:fullname/text()
  ,$uuid := util:uuid()
  (: 2022-02-21 new option4 == store a Research Note file in /notes/research/ :)
  ,$newid := if ($vis = "option4") then $txtid else $txtid || "-" || $lang || "-" || tokenize($uuid, "-")[1]
  ,$lg := $config:languages($lang)
  ,$title := tlslib:get-title($txtid)
  ,$trcoll := if ($vis="option3") then $config:tls-user-root || $user || "/translations" 
    else if ($vis = "option4") then $config:tls-data-root || "/notes/research" 
    else $config:tls-translation-root || "/" || $lang
  ,$trcollavailable := xmldb:collection-available($trcoll) or 
   (if ($vis="option3") then
    xmldb:create-collection($config:tls-user-root || $user, "translations")
   else
   (xmldb:create-collection($config:tls-translation-root, $lang),
    sm:chmod(xs:anyURI($trcoll), "rwxrwxr--"),
(:    sm:chown(xs:anyURI($trcoll), "tls"),:)
    sm:chgrp(xs:anyURI($trcoll), "tls-user")
    )
  )
  , $trx := if (not($translator = "yy")) then $translator else if ($vis = "option3") then $fullname else "TLS Project"
  , $doc := 
    doc(xmldb:store($trcoll, $newid || ".xml", 
   <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$newid}" type="{$type}">
  <teiHeader>
      <fileDesc>
            {if ($type = "transl") then 
         <titleStmt>
            <title>Translation of {$title} into ({$lg})</title>
            <editor role="translator">{$trx}</editor>
         </titleStmt>
            else if ($type = "notes") then
         <titleStmt>
            <title>Research Notes for {$title}</title>
            <editor role="creator">{$trx}</editor>
         </titleStmt>
            else
         <titleStmt>
            <title>Comments to {$title}</title>
            <editor role="creator">{$trx}</editor>
         </titleStmt>
            }
         <publicationStmt>
            <p>published electronically as part of the TLS project at https://hxwd.org</p>
            {if ($copy = "option1") then 
            <availability status="1">This work is in the public domain</availability> 
            else 
             if ($copy = "option2") then
            <availability status="2">This work has been licensed for use in the TLS</availability> 
            else 
             if ($copy = "option3") then
            <availability status="3">This work has not been licensed for use in the TLS</availability> 
            else
            <availability status="4">The copyright status of this work is unclear</availability> 
            }
         </publicationStmt>
         <sourceDesc>
            {if (not($bibl = "") or not ($trtitle = "")) then 
            <bibl><title>{$trtitle}</title>{$bibl}</bibl> else 
            <p>Created by members of the TLS project</p>}
            
            {if ($type="transl") then 
             <ab>Translation of <bibl corresp="#{$txtid}">
                  <title xml:lang="och">{$title}</title>
               </bibl> into <lang xml:lang="{$lang}">{$lg}</lang>.</ab>
             else 
             <p>Comments and notes to <bibl corresp="#{$txtid}">
                  <title xml:lang="och">{$title}</title>
               </bibl>{if (string-length($rel-id) > 0) then ("for translation ", <ref target="#{$rel-id}"></ref>) else ()}.</p>
             }
         </sourceDesc>
      </fileDesc>
     <profileDesc>
        <creation resp="#{$user}">Initially created: <date>{current-dateTime()}</date> by {$user}</creation>
     </profileDesc>
  </teiHeader>
  <text>
      <body>
      {if ($type = "transl") then 
      <div><head>Translated parts</head><p xml:id="{$txtid}-start"></p></div>
      else 
      <div><head>Comments</head><p xml:id="{$txtid}-start"></p></div>
      }
      </body>
  </text>
</TEI>))
return
if (not($vis="option3")) then 
 let $uri := document-uri($doc)
 return
 (
    sm:chmod(xs:anyURI($uri), "rwxrwxr--"),
(:    sm:chown(xs:anyURI($uri), "tls"),:)
    sm:chgrp(xs:anyURI($uri), "tls-user")
 )
 else ()
};

declare function tlslib:edit-fragment($request as map(*)){
    let $target := $request?parameters?type
    let $docid := $request?parameters?docid
return
switch ($target)
  case "teiheader" return
<TEI xmlns="http://www.tei-c.org/ns/1.0">
 {collection($config:tls-texts-root)//tei:TEI[@xml:id=$docid]/tei:teiHeader}
 </TEI>
default return
<root>
<test>{$docid}</test>
</root>
};

declare function tlslib:save-fragment($request as map(*)){
(:  this was used for debugging:
         let $f := function($k, $v) {map:entry($k, $v)}
         map:merge(map:for-each($request, $f))   :)

 let $data := $request?body
 let $target := $request?parameters?type
 let $docid := $request?parameters?docid
 let $targetnode := switch ($target) 
  case "teiheader" return 
    collection($config:tls-texts-root)//tei:TEI[@xml:id=$docid]/tei:teiHeader
  default return ()
 let $updatednode := $data//tei:teiHeader
 return 
 if ($targetnode and $updatednode) then 
            ( 
                 update replace $targetnode with $updatednode, 
                 map{
                   "status" : "updated",
                   "user" : sm:id()//sm:real/sm:username/text(),
                   "body" : $updatednode
                 }
            )
else map{
"status" : "not found",
 "body" : $data//tei:teiHeader,
 "data" : $data,
 "tnode" : $targetnode,
 "user" : sm:id()//sm:real/sm:username/text()
}

};


declare function local:edit-xml-transform($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(tei:teiHeader) return 
               <fx-group ref="{local-name($node)}">
                    {for $c in $node/* return
                     <fx-trigger>
                       <paper-button raised="raised">{local-name($c)}</paper-button>
                       <fx-toggle case="{local-name($c)}"></fx-toggle>
                     </fx-trigger>                    
                    }
                    <fx-switch>
                    { local:edit-xml-transform($node/node()) }
                    </fx-switch>
               </fx-group>
            case element(tei:fileDesc) | element(tei:profileDesc) | element(tei:revisionDesc) return
                <fx-case id="{local-name($node)}">
                  <h2>{local-name($node)}</h2>
                  {local:edit-xml-transform($node/node())}
                </fx-case>
            case element(tei:titleStmt) | element(tei:publicationStmt) | element (tei:sourceDesc) | element (tei:editionStmt) return 
              <details><summary>{local-name($node)}</summary>
              <fx-group ref=".//{local-name($node)}">
              {local:edit-xml-transform($node/node())}
              {if (local-name($node) = 'titleStmt' and not ($node/tei:author)) then 
              local:edit-xml-transform(<tei:author></tei:author>) else ()}
              </fx-group>
              </details>
            case element(tei:title) | element(tei:author) | element (tei:editor) return
              (<h4>{local-name($node)}</h4>,
              <fx-repeat ref="{local-name($node)}" id="{local-name($node)}s">
                <template>
                 <fx-control ref="."></fx-control>
                 <fx-trigger class="deleteIcon">
                    <button>x</button>
                    <fx-delete ref="."></fx-delete>
                </fx-trigger>
                </template>
              </fx-repeat>,
              if ($node/parent::*[$node[position() = last()]]) then
              <fx-trigger>
              <button>add {local-name($node)}</button>
              {if ($node/ancestor::tei:teiHeader) then
              <fx-insert ref="{local-name($node)}" repeat="{local-name($node)}s"></fx-insert>
              else 
               switch (local-name($node))
               case "author" return
                 <fx-insert ref="titleStmt/author" repeat="{local-name($node)}s" origin="instance('templates')//author"></fx-insert>
               default return ()
              }
              </fx-trigger> else ())
            (: leave unknown elements intact, including attributes :)
            case element(tei:p) return
             (
             <fx-control ref="{local-name($node)}">
              <label>{local-name($node)}</label>
             </fx-control>,
             <fx-trigger class="deleteIcon">
                <button>x</button>
               <fx-delete ref="{local-name($node)}"></fx-delete>
             </fx-trigger>
             )
            case element() return
                element 
                    { node-name($node) } 
                    { $node/@*, local:edit-xml-transform($node/node()) }
            case text() return
                $node
            default return
                $node
};

declare function tlslib:xml-editor($request as map(*)){
 let $target := $request?parameters?type
 let $docid := $request?parameters?docid
 let $path := "http://localhost:8080/exist/apps/tls-tp/"
 let $targetnode := switch ($target) 
  case "teiheader" return 
    collection($config:tls-texts-root)//tei:TEI[@xml:id=$docid]/tei:teiHeader
  default return ()
  return
<html lang="en" xmlns:tei="http://www.tei-c.org/ns/1.0">
<head>
    <meta charset="utf-8"/>
    <meta content="width=device-width, minimum-scale=1, initial-scale=1, user-scalable=yes" name="viewport"/>

    <title>XML Fragment editor</title>
    <link href="resources/fore/demo.css" rel="stylesheet"/>
    <link href="resources/fore/vars.css" rel="stylesheet"/>
    <style>
        html{{
            /*--inspector-bg:var(--paper-grey-700);*/
            /*--inspector-pre-bg:var(--paper-grey-100);*/
            /*--inspector-color:var(--paper-grey-800);*/
            /*--inspector-pre-bg:blue;*/
        }}
    
        body {{
            background: var(--paper-light-blue-200);
            color: var(--paper-light-blue-900)
        }}

        .card {{
            background: white;
            padding: 1rem;
            border-radius: 0.5rem;
        }}

        #changes fx-repeatitem {{
            display: grid;
            grid-template-columns: auto min-content;
            grid-column-gap: 1rem;
        }}

        #changes fx-repeatitem fx-output {{
            white-space: nowrap;
        }}

        .deleteIcon button {{
            border: none;
            cursor: pointer;
            background: transparent;
            color: red;
        }}

        details {{
            padding: 1rem;
            margin: 1rem 0;
            /*background: white;*/

        }}

        details[open] {{
            /*background: var(--paper-grey-100);*/
            /*background-color: rgba(255, 255, 255, 0.5);*/
        }}

        fx-case {{
            margin-top: 1px;
            border: 1px solid var(--paper-light-blue-900);
            padding: 2rem;
            background-color: rgba(255, 255, 255, 0.5);
        }}

        fx-control, input, textarea {{
            width: 100%;
            margin: 0.3rem 0;
        }}

        input {{
            padding: 0.3rem;
        }}

        label {{
            display: block;
            color: var(--paper-blue-900);
        }}

        fx-control {{
            /*margin-top: 1rem;*/
        }}

        fx-group {{
            margin-top: 1rem;
            padding: 1rem;
        }}

        h3, fx-output, input {{
            border: none;
        }}

        h3, h4 {{
            margin-bottom: 0;
            margin-top: 1rem;
        }}

        fx-repeat {{
            display: block;
        }}

        fx-repeatitem {{
            display: block;
        }}

        fx-repeatitem {{
            display: grid;
            grid-template-columns: auto 30px;
            width: 100%;
            align-items: baseline;
        }}

        details.log {{
            background: var(--paper-light-blue-100);
        }}

        pre {{
            overflow: auto;
        }}

        #langs fx-repeatitem, #terms fx-repeatitem {{
            display: inline-block;
            width: auto;
        }}

        #langs fx-repeatitem fx-control, #terms fx-repeatitem fx-control {{
            width: 2.5rem;
        }}
        .wrapper{{
            overflow: scroll;
        }}
        fx-inspector pre{{
            /*max-height:200px;*/
        }}
    </style>
</head>
<body unresolved="unresolved">
<div class="wrapper">

  <h1>Editing an TEI header</h1>
    <fx-fore xpath-default-namespace="http://www.tei-c.org/ns/1.0">
    <fx-model>
     <fx-instance src="{$path}tls/edit/{$target}/{$docid}">
     </fx-instance>
     <fx-instance id="templates" src="resources/fragments/teiheader.xml">
     </fx-instance>
     <fx-instance id="result">
     </fx-instance>
     <fx-submission id="save"
                           url="{$path}tls/edit/{$target}/{$docid}"
                           method="put"
                           replace="none">
                           </fx-submission>
    </fx-model>
  {local:edit-xml-transform($targetnode)}
   <fx-trigger>
      <button>save</button>
      <fx-send submission="save">
      </fx-send>
   </fx-trigger>
</fx-fore>
  </div>
  <script type="module" src="http://localhost:8090/demo/demo.js"></script>
  </body>
</html>
};


(: this is for the char editing :)


(: retrieve the pron for this entry (given through its id) :)

declare function tlslib:pron-for-entry($uuid){
let $f := collection($config:tls-data-root||"/concepts")//tei:entry[@xml:id=$uuid]/tei:form
return
$f
};

(: create tax stub for char :)
declare function tlslib:char-tax-stub($char as xs:string){
let $doc := doc($config:tls-data-root||"/core/taxchar.xml")
, $res:= tlslib:getwords($char, map{})
, $pmap := map:merge(
  for $k in map:keys($res)
   let $v := map:get($res, $k)
   , $f := tlslib:pron-for-entry($k)
   return map:entry($k, $f//@corresp))
  
, $gy := distinct-values(for $k in map:keys($pmap)
   return map:get($pmap, $k))

, $stub :=
<div xml:id="uuid-{util:uuid()}" type="taxchar" xmlns="http://www.tei-c.org/ns/1.0">
<head>{$char}</head>
{
for $g in $gy
let $c := substring($g, 2)
, $e:= collection($config:tls-data-root ||"/guangyun")//tx:guangyun-entry[@xml:id=$c]
, $p := for $s in ($e//tx:mandarin/tx:jin|$e//tx:mandarin/tx:jiu) 
       return 
       if (string-length(normalize-space($s)) > 0) then $s else (),
$py := normalize-space(string-join($p, ';'))
, $oc := normalize-space($e//tx:old-chinese/tx:pan-wuyun/tx:oc/text())
, $mc := normalize-space($e//tx:middle-chinese//tx:baxter/text())
, $fq := ($e//tx:fanqie/tx:fanqie-shangzi//tx:graph/text() || $e//tx:fanqie/tx:fanqie-xiazi//tx:graph/text())
return
<list xmlns="http://www.tei-c.org/ns/1.0">
<item type="pron" corresp="{$g}">{$py || " 反切： " || $fq || "； 聲調： " || $e//tx:調 || "； 廣韻：【" || $e//tx:gloss ||" 】"}
<list xmlns="http://www.tei-c.org/ns/1.0">{
for $k in map:keys($pmap)
let $v := map:get($pmap, $k)
where $v eq $g
return <item xmlns="http://www.tei-c.org/ns/1.0"><ref target="#{map:get($res, $k)[1]}">{map:get($res, $k)[2]}</ref></item>
}</list></item>
</list>
}
</div>

return
for $l in $stub/tei:list
return
tlslib:proc-char($l, "true")
};

(: get concepts not yet defined in taxchar :)
declare function tlslib:char-tax-newconcepts($char){
 let $cdoc := doc($config:tls-data-root || "/core/taxchar.xml")
 , $chead :=  $cdoc//tei:head[. = $char]
 , $cdiv := $chead/ancestor::tei:div[@type='taxchar']
 , $emap := tlslib:getwords($char, map{})
 , $cseq := for $r in $cdiv//tei:ref
   let $id := substring($r/@target, 2)
   return $id
  , $em1 := map:merge( for $r in map:keys($emap)
   let $k := map:get($emap, $r)[1]
   where not ($k = $cseq)
   return map:entry($r, map:get($emap, $r)))
 return 
 <div type="taxchar-add"  xmlns="http://www.tei-c.org/ns/1.0">
 <head>{$char}</head>
 <list>{
 for $r in  map:keys($em1)
 return <item corresp="#{$r}"><ref target="#{map:get($emap, $r)[1]}">{map:get($emap, $r)[2]}</ref></item>
 }</list></div>
};

(: get XML representation of char in request :)

declare function tlslib:char-tax-xml($request as map(*)){
 let $char := $request?parameters?char
 , $cdoc := doc($config:tls-data-root || "/core/taxchar.xml")
 , $chead :=  $cdoc//tei:head[. = $char]
 , $cdiv := $chead/ancestor::tei:div[@type='taxchar']
 , $emap := tlslib:getwords($char, map{})
 return if (exists($cdiv)) then $cdiv else tlslib:char-tax-stub($char)
};

declare function tlslib:char-tax-html2xml($node as node()){
let $user := sm:id()//sm:real/sm:username/text()
return
typeswitch ($node)
case element(li) return 
let $concept := data($node/@tei-ref)
,$target := $node/@tei-target
,$type := $node/@tei-type
,$ref := if (string-length($concept) > 0) then <ref xmlns="http://www.tei-c.org/ns/1.0" target="{$target}">{$concept}</ref> else ()
,$txt := if (string-length($concept) > 0) then normalize-space(substring-before(string-join(for $n in $node/node() return tlslib:char-tax-html2xml($n)), $concept))
         else 
         for $n in $node/node() return tlslib:char-tax-html2xml($n)
return
if ($type = 'pron') then 
 (: @corresp is the link to the guangyun file, currently available only for new taxchar structures :)
 if (string-length($node/@tei-corresp) > 0) then 
  <item xmlns="http://www.tei-c.org/ns/1.0" type="pron" corresp="{$node/@tei-corresp}">{for $n in $node/node() return tlslib:char-tax-html2xml($n)}</item>
 else
  <item xmlns="http://www.tei-c.org/ns/1.0" type="pron">{for $n in $node/node() return tlslib:char-tax-html2xml($n)}</item>
else
<item xmlns="http://www.tei-c.org/ns/1.0">{($txt,$ref)}
{ (: here we need to make sure to skip over the text, which has already been output, very clumsy :-( :)
for $n in $node/node() except $node/text() return if (name($n) = 'ul') then tlslib:char-tax-html2xml($n) else ()}</item>
case element(ul) return <list xmlns="http://www.tei-c.org/ns/1.0">{$node/text(), for $n in $node/node() return tlslib:char-tax-html2xml($n)}</list>
case element(div) return 
let $id := if (string-length($node/@tei-id) > 0) then $node/@tei-id else "uuid" || util:uuid()
return
<div type="taxchar" xml:id="{$id}" resp="{$user}" modified="{current-dateTime()}" xmlns="http://www.tei-c.org/ns/1.0" >
{for $h in tokenize($node/@tei-head, '/') return <head xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($h)}</head>}
{for $n in $node/node() return tlslib:char-tax-html2xml($n)}
</div>
case element(i) return for $n in $node/node() return tlslib:char-tax-html2xml($n)
case element(a) return normalize-space( for $n in $node/node() return tlslib:char-tax-html2xml($n))
case text() return $node
default 
return <name>{$node}</name>
};

