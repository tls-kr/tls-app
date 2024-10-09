xquery version "3.1";
(:~
: This module provides the internal functions that do not directly control the 
: template driven Web presentation
: of the TLS. 
: 
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace tlslib="http://hxwd.org/lib";

import module namespace config="http://hxwd.org/config" at "config.xqm";

import module namespace krx="http://hxwd.org/krx-utils" at "krx-utils.xql";
import module namespace wd="http://hxwd.org/wikidata" at "wikidata.xql"; 
import module namespace tu="http://hxwd.org/utils" at "tlsutils.xql";

import module namespace ltr="http://hxwd.org/lib/translation" at "lib/translation.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "lib/utils.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "lib/metadata.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "lib/render-html.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace lv="http://hxwd.org/lib/vault" at "lib/vault.xqm";
import module namespace lvs="http://hxwd.org/lib/visits" at "lib/visits.xqm";
import module namespace lli="http://hxwd.org/lib/link-items" at "lib/link-items.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "lib/permissions.xqm";
import module namespace ltp="http://hxwd.org/lib/textpanel" at "lib/textpanel.xqm";
import module namespace lsf="http://hxwd.org/lib/syn-func" at "lib/syn-func.xqm";

import module namespace log="http://hxwd.org/log" at "log.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace  mods="http://www.loc.gov/mods/v3";

declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tx="http://exist-db.org/tls";

declare variable $tlslib:log := $config:tls-log-collection || "/tlslib";


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

(: for adding punc :)

(: get the nodes from the indexed text-node up to before the next text-node :)
declare function tlslib:subseq($i as xs:int, $s as node()*){
    let $ix := for $n at $pos in $s
        return
       typeswitch($n)
       case element(*) return ()
       (: this is the text node :)
       default return $pos
    let $e := $ix[$i+1] - 1
    return
    $s[position() = ($ix[$i]+1 to $e )]
};

declare function tlslib:add-nodes($tx as xs:string, $s as node()*){
    for $n in analyze-string($tx, "\$\d+\$")//fn:*
    let $l := local-name($n)
    return
    if ($l = 'non-match') then 
        tlslib:add-c($n/text()) 
    else 
        let $i := xs:int(replace($n, '\$', ''))
        return $s[$i]
};

(: Re-insert the nodes that have been removed from $orig-seg by tlslib:proc-seg-for-edit from $orig-node. 
 : $tx is the edited text, with each '$' replaced by '$i$', where i is the index of that '$' 
 : in the string. :)
declare function tlslib:reinsert-nodes-after-edit($tx as xs:string, $orig-seg as node()) as node()* {
    (: Only count those nodes that are actually replaced by '$' in tlslib:proc-seg-for-edit.  :)
    tlslib:add-nodes($tx, $orig-seg/child::*[local-name() = $config:proc-seg-for-edit-hidden-element-names]) 
};

(: Check whether a edit for a segment processed by tlslib:proc-seg-for-edit is valid,
 : i.e. retains the correct number of '$' that have been substituted for children. :)
declare function tlslib:check-edited-seg-valid($new-seg-text as xs:string, $orig-seg as node()) as xs:boolean {
    let $r0 := tlslib:proc-seg-for-edit($orig-seg) => string-join('') => normalize-space() => replace(' ', '') => tokenize('\$'),
        $r1 := tokenize($new-seg-text, '\$')
    return
        count($r0) = count($r1)
};

declare function tlslib:add-c($s as xs:string){
    let $x := analyze-string($s, '\p{P}')
    return 
        for $n in $x//fn:*
        let $l := local-name($n)
        return
        if ($l = 'non-match') then $n/text() else 
        <c xmlns="http://www.tei-c.org/ns/1.0" n="{$n/text()}"/>
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
   "0" || substring($h, $num + 1, 1)
  else ()
  return
  string-join($s, "")
};

declare function tlslib:expath-descriptor() as element() {
    <rl/>
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
,$tr := for $s in collection($config:tls-translation-root, $config:tls-user-root || $user || "/translations")//tei:seg[@corresp="#"||$id]
        return root($s)
,$retmap := map:merge(
          for $t in $tr
          let $lang := tokenize($tr/tei:TEI/@xml:id, '-')[last()]
          ,$ed := $tr//tei:editor[@role='translator']/text()
          return map:entry(document-uri($tr), ($lang, $ed))
)
return $retmap
};


(: prepare the character taxonomy display :)
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
    <li class="jstree-open" tei-type="{$node/@type}" tei-corresp="{$node/@corresp}">
    <span class="char-{$node/@type}">{$node/text()}</span>
    {for $n in $node/child::*
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
     , $entry-id := $swl/ancestor::tei:entry/@xml:id
     , $swl-count := count($swl)
     (: do not take the concept name from the taxonomy, it might have been changed! :)
     , $concept := (if ($swl-count = 0) then $node/text() else $swl/ancestor::tei:div[@type='concept']/tei:head/text()) => string-join() => normalize-space() 
     , $cdef := $swl/ancestor::tei:div/tei:div[@type="definition"]/tei:p/text()
     , $e := string-length($edit) > 0
     return
      if ($e) then
       let $c := $concept => replace(' ', '_')
       return
       (: only show the plain concept when editing :)
       " "|| $c
       else
      <span>
      {if ($swl-count = 0) then 
      <a href="concept.html?uuid={$id}" class="text-muted mr-2 ml-2" title="Concept pending: not yet attributed for this character">{$concept}</a>
      else 
      (
      <a href="concept.html?uuid={$id}#{$entry-id}" class="mr-2 ml-2" title="{$cdef}">{$concept}</a>
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
   

declare function tlslib:get-concept-id($str as xs:string){
let $concept := replace($str, "_", " ")
for $c in collection(concat($config:tls-data-root, '/concepts/'))//tei:head[. = $concept]
return data($c/ancestor::tei:div[@type='concept']/@xml:id)
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

(: format the app for display in the segment :)
declare function tlslib:format-app($app as node()){
 let $lwit := $app/ancestor::tei:TEI//tei:witness[@xml:id=substring($app/tei:lem/@wit, 2)]/text()
 let $lem :=  string-join($app/tei:lem//text(), ' ') || $lwit ||"；" 
 , $t := string-join(for $r in $app/tei:rdg
        let $wit := "【" || string-join(for $w in tokenize($r/@wit) return $app/ancestor::tei:TEI//tei:witness[@xml:id=substring($w, 2)]/text() , "，") ||  "】"
        return $r/text() || $wit, "；")
 , $note := if ($app/tei:note) then "&#xA;(Note: " || $app/tei:note/text() || ")&#xA;" || $app/tei:note/tei:bibl else () 
  return $lem || $t || $note
};

(: replace the nodes listed in $config:proc-seg-for-edit-hidden-element-names with a placeholder, c with the @n content :)
declare function tlslib:proc-seg-for-edit($node as node()){
  if ($node/local-name() = $config:proc-seg-for-edit-hidden-element-names) then
    "$"
  else
    typeswitch ($node)
      case element (tei:c) return data($node/@n)
      case element (tei:p) return for $n in $node/node() return tlslib:proc-seg-for-edit($n)
      case element(tei:seg) return for $n in $node/node() return tlslib:proc-seg-for-edit($n)
      case attribute(*) return () 
      default return $node    
};

(: replace the lb and pb nodes with a placeholder, c with the @n content :)
declare function tlslib:proc-p-for-edit($node as node()){
 typeswitch ($node)
  case element (tei:anchor) return "$"
  case element (tei:g) return "$"
  case element (tei:c) return data($node/@n)
  case element (tei:space)  return "$"
  case element (tei:lb)  return "$"
  case element (tei:pb)  return "$"
  case element (tei:p) return for $n in $node/node() return tlslib:proc-p-for-edit($n)
  case element(*) return "$"
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
    $ratings := doc($config:tls-user-root || $user || "/ratings.xml")//text
    return 
    if ($ratings[@id=$txtid]) then $ratings[@id=$txtid]/@rating else 0
};


(:~
: Get the documents for a given cat
: @param $cat
: @param $options 
:)
declare function tlslib:get-docs-for-cat($cat as xs:string, $options as map(*)){
collection($config:tls-texts-root)//tei:catRef[@target="#"||$cat]
};


(:~
: Extract the textid from the location.
: Special treatment for legacy files from CHANT
: @param $location
:)

declare function tlslib:get-textid ($location as xs:string){
(:if (starts-with($location, "KR")) then:)
if (1) then 
 tokenize($location, "_")[1]
else ()
};

(: -- Search / retrieval related functions -- :)


(: -- Display related functions -- :)
declare function tlslib:navbar-concept($node as node()*, $model as map(*)){
<span class="navbar-text ml-2 font-weight-bold">{$model?concept}</span> 
};

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
                                <a class="dropdown-item" href="documentation.html?section=text-crit">Critically establishing a text</a>
                                <a class="dropdown-item" href="documentation.html?section=taxonomy">Genre categories</a>
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
,$ratings := doc($config:tls-user-root || $user || "/ratings.xml")//text


return
(
 <li class="nav-item dropdown">
  <a class="nav-link dropdown-toggle" href="#"  id="navbarDropdownBookmarks" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">Bookmarks</a>
   <div class="dropdown-menu" aria-labelledby="navbarDropdownBookmarks">
   <a class="dropdown-item" onclick="display_pastebox('1')" href="#" title="Pastebox is used for more efficiently pasting translations to slot 1">Display Pastebox</a>
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
let $hl := if (tlslib:attention-needed()) then "highlight" else ""
return
 <li class="nav-item dropdown">
  <a class="nav-link dropdown-toggle {$hl}" href="#"  id="navbarDropdownEditors" role="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">內部</a>
   <div class="dropdown-menu" aria-labelledby="navbarDropdownEditors">
     {if (sm:id()//sm:group = "tls-editor") then
        (<a class="dropdown-item" href="review.html?type=swl">Review SWLs</a>,
        <a class="dropdown-item" href="review.html?type=gloss">Add pronounciation glosses</a>,
        <a class="dropdown-item" href="review.html?type=special">Special pages</a>,
        <a class="dropdown-item {$hl}" href="review.html?type=user">Account requests</a>)
       else
        ()
     }
     
     {if ($context = 'textview') then 
      (<a class="dropdown-item" href="#" onClick="zh_start_edit()">Edit Chinese text</a>,
      if (sm:id()//sm:group = "tls-admin") then
        <a class="dropdown-item" href="#" onClick="display_edit_text_permissions_dialog()">Change editing permissions</a>
      else 
        ())
     else ()}


     {if (sm:id()//sm:group = "tls-admin") then 
     <a class="dropdown-item" href="review.html?type=request">Add requested texts</a>
     else () }
   </div>
 </li>
};

declare function tlslib:attention-needed(){
 let $ux := collection("/db/groups/tls-admin/new-users")//verified[@status='true']
 , $v := xs:dateTime(lvs:visit-time("sgn:review"))
 , $c := count(for $u in $ux
  let $m := xs:dateTime($u/tk/user/@time-stamp)
  where $m > $v
  return $u)
  return $c > 0
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

declare function tlslib:tv-header($node as node()*, $model as map(*)){
   session:create(),
   let $textid := $model('textid'),
   $tsrc := if ($textid and map:contains($config:txtsource-map, $textid)) then 
          map:get($config:txtsource-map, $textid) 
      else 
         if (substring($model('textid'), 1, 3) = "KR6") then "CBETA" 
      else 
         if (substring($model('textid'), 1, 4) = "KR3e") then "中醫笈成" 
      else "CHANT", 
(:   $toc := ()   :)
   $toc := if (contains(session:get-attribute-names(), $textid || "-toc")) then 
    session:get-attribute($textid || "-toc")
    else 
    tlslib:generate-toc($model("seg")/ancestor::tei:body)
   
   let $store := 
     if (not(contains(session:get-attribute-names(),$textid || "-toc"))) 
     then session:set-attribute($textid || "-toc", $toc) else ()

   return
      (
      <span class="navbar-text ml-2 font-weight-bold">{$model('title')} <small class="ml-2">{$model('seg')/ancestor::tei:div[1]/tei:head[1]/text()}</small></span> 
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

(: 2023-06-09 working around a bug in some texts... temporarily .. :)
declare function tlslib:generate-toc($node){
subsequence (for $h in $node//tei:head
    let $locseg := $h//tei:seg/@xml:id
    , $textid := tokenize($locseg, "_")[1]
    where matches($textid, "^[A-Za-z]")
    return
    <a class="dropdown-item" title="{$locseg}" href="textview.html?location={$locseg}&amp;prec=0&amp;foll=30">{$h//text()}</a>
    , 1, 100)
};


(:~
: generate the table of contents for the textview header.  Called from
: @param $node  a node from the text to process
: @see tlslib:tv-header()
: TODO: Store a generated TOC in the text file and use if available
:)
declare function tlslib:generate-toc-correct($node){
 if ($node/tei:head) then
  let $locseg := if ($node//tei:seg/@xml:id) then ($node//tei:seg/@xml:id)[1] else $node/following::tei:seg[1]/@xml:id
  ,$head := if ($node/tei:head[1]/tei:seg) then ($node/tei:head[1]/tei:seg)/text() else ($node//text())[1]
  return 
    <a class="dropdown-item" title="{$locseg}" href="textview.html?location={$locseg}&amp;prec=0&amp;foll=30">{$head}</a>
  else ($node/text())[1],
 for $d in $node/child::tei:div
 return tlslib:generate-toc($d)
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
: display a chunk of text, surrounding the $targetsec
: @param $targetseg  a tei:seg element
: @param $prec an xs:int giving the number of tei:seg elements to display before the $targetsec
: @param $foll an xs:int giving the number of tei:seg elements following the $targetsec 
display $prec and $foll preceding and following segments of a given seg :)

declare function tlslib:display-chunk($targetseg as node(), $model as map(*), $prec as xs:int?, $foll as xs:int?){
      let $log := log:info($tlslib:log, "starting display-chunk for "|| $targetseg/@xml:id)
      let $fseg := if ($foll > 0) then $targetseg/following::tei:seg[fn:position() < $foll] 
        else (),
      $pseg := if ($prec > 0) then $targetseg/preceding::tei:seg[fn:position() < $prec] 
        else ()
      , $zh-width := 'col-sm-3'
      , $colums := if (string-length($model?columns)>0) then xs:int($model?columns) else 2 
      let $d := $targetseg/ancestor::tei:div[1],
      $state := if ($d/ancestor::tei:TEI/@state) then $d/ancestor::tei:TEI/@state else "yellow" ,
      $pb := ($targetseg/preceding::tei:pb)[last()] ,
      $facs := $pb/@facs,
      $fpref :=  $config:ed-img-map?($pb/@ed),
      $head := if ($d/tei:head[1]/tei:seg) then ( $d/tei:head[1]/tei:seg)/text() 
         else if ($d/ancestor::tei:div/tei:head) then $d/ancestor::tei:div/tei:head/tei:seg/text() 
         else ($d//text())[1],
      $sc := count($d//tei:seg),
      $xpos := index-of($d//tei:seg/@xml:id, $targetseg/@xml:id),
(:      $title := $model('title')/text(),:)
      $dseg := ($pseg, $targetseg, $fseg),
      $log := log:info($tlslib:log, "assembled dseg"),

(:      $model := if (string-length($model?textid) > 0) then $model else map:put($model, "textid", tokenize($targetseg, "_")[1]), :)
      $show-transl := lpm:should-show-translation(),
      $show-variants := xs:boolean(1),
      $visit := lvs:record-visit($targetseg),
      $tr := if (lpm:should-show-translation()) then 
         if (string-length($facs) > 0) then map:merge((ltr:get-translations($model?textid), 
            for $edx in distinct-values(for $lpb in $targetseg/ancestor::tei:div//tei:pb where string-length($lpb/@facs) > 0 return $lpb/@ed)
            return
            map:entry("facs_"||$edx, ("dummy", $edx, data($targetseg/@xml:id)) ))) 

         else ltr:get-translations($model?textid)
         else map{},
      $slot1-id := lrh:get-content-id($model?textid, 'slot1', $tr),
      $slot2-id := lrh:get-content-id($model?textid, 'slot2', $tr),
      $atypes := distinct-values(for $s in $dseg/@xml:id
        let $link := "#" || $s
        return
        for $node in (collection($config:tls-data-root|| "/notes")//tls:ann[.//tls:srcline[@target=$link]] | collection($config:tls-data-root|| "/notes")//tls:span[.//tls:srcline[@target=$link]] ) return 
        (: need to special case the legacy type ann=swl :)
        if (local-name($node)='ann') then "nswl" else data($node/@type))
      ,$log := log:info($tlslib:log, "ready to go")
    return
      (
      <div id="chunkrow" class="row">
      <div id="srcref" class="col-sm-12 collapse" data-toggle="collapse">
      {tlslib:textinfo($model?textid)}
      {log:info($tlslib:log, "textinfo done")}
      </div>
      <!-- here is where we select what kind of annotation to display -->
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
        <div class="col .no-gutters"><img class="icon state-{$state}"  src="{$config:circle}"/></div>
        <div class="{$zh-width}" id="toprow-1"><span class="font-weight-bold">{$head}</span><span class="btn badge badge-light">line {$xpos} / {($xpos * 100) idiv $sc}%</span> 
        {if (string-length($pb/@facs) > 0) then 
        let $pg := substring-before(tokenize(data($pb/@facs), '/')[last()], '.')
        return
          <span class="btn badge badge-light ed-{data($pb/@ed)}" title="Click here to display a facsimile of this page &#10; {$pg}" onclick="get_facs_for_page('slot1', '{$fpref}{$pb/@facs}', '{data($pb/@ed)}', '{data($targetseg/@xml:id)}')" >{$config:wits?(data($pb/@ed))}:{data($pb/@n)}</span>
         else <span title="No facsimile available" class="btn badge badge-light">{data($pb/@n)}</span>
         }
        <!-- zh --></div>
        <!-- 2024-09-06 this is rubbish, this needs also to be moved to textpanel and not hardcode the width -->
        {for $i in (1 to $colums)
        return 
        <div class="col-sm-4" id="top-slot{$i}"><!-- tr -->
        {if ($show-transl) then ltr:render-translation-submenu($model?textid, "slot"||$i, lrh:get-content-id($model?textid, 'slot'||$i, $tr) , $tr) else ()}
        </div>
        }
        </div>
      </div>
      <div id="chunkcol-left" class="col-sm-12">
      {log:info($tlslib:log, "starting chunkcol-left")}
      {ltp:chunkcol-left($dseg, map:put($model, "zh-width", $zh-width), $tr, $slot1-id, $slot2-id, data($targetseg/@xml:id), 0)}
      {log:info($tlslib:log, "done chunkcol-left")}
      </div>
      <div id="chunkcol-right" class="col-sm-0">
      {tlslib:swl-form-dialog('textview', $model)}
    </div>
    </div>,
      <div class="row">
      <div class="col-sm-2">
      {if ($dseg) then  
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
       <button id="nextpagebutton" type="button" class="btn" onclick="page_move('{$dseg[last()]/following::tei:seg[1]/@xml:id}&amp;prec=2&amp;foll={$foll+$prec -2}')" title="Go to the next page"><span style="color: blue">Next</span></button>
       else ()}
       </div> 
       <div class="col-sm-2">
       {
       if ($dseg/following::tei:seg[last()]/@xml:id) then
       <button type="button" class="btn" onclick="page_move('{$dseg/following::tei:seg[last()]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=0')" title="Go to the last page"><span style="color: blue">Last</span></button>
       else ()}
       </div> 
        {wd:quick-search-form('title')}
      </div>
    ,log:info($tlslib:log, "done")
)

};

(: dialog functions :) 

(: This is the stub for the dynamic display in the right section.  Called from textview, it is used for attributions; from other contexts, just for display :)

declare function tlslib:swl-form-dialog($context as xs:string, $model as map(*)) {
<div id="swl-form" class="card ann-dialog overflow-auto">
{if ($context = 'textview') then
 <div class="card-body">
    <h5 class="card-title"><span id="new-att-title">{if (sm:is-authenticated()) then "New Attribution:" else "Existing SW for " }<strong class="ml-2 chn-font"><span id="swl-query-span">Word or char to annotate</span>:</strong></span>
<span id="domain-lookup-mark">
    <span class="badge badge-info ml-2" onclick="wikidata_search('wikidata')" title="Click here for a quick search in WikiData"> WD </span>
    { if (lpm:can-search-similar-lines()) then <span class="badge badge-info ml-2" onclick="wikidata_search('similar')" title="Search for similar lines"> 似 </span> else ()}
    <span>　　Lookup domain:<select id="domain-select" onChange="update_swlist()"><option value="core">Core</option>{for $d in xmldb:get-child-collections($config:tls-data-root||'/domain') return <option value="{$d}">{tlslib:capitalize-first($d)}</option>}</select></span>
    {if (1 = 1) then
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
    {lrh:format-button-common("bookmark_this_line()","Bookmark this location", "open-iconic-master/svg/bookmark.svg"), 
     if ($model("textid") and lpm:has-edit-permission($model("textid"))) then 
      lrh:format-button("display_punc_dialog('x-get-line-id')", "Edit properties of this text segment", "octicons/svg/lock.svg", "", "close", ("tls-editor", "tls-punc"))
     else (),
      lrh:format-button("display_named_dialog('x-get-line-id', 'pb-dialog')", "Add page break of a witness edition before selected character", "octicons/svg/milestone.svg", "", "close", ("tls-editor", "tls-punc")),
      lrh:format-button("display_named_dialog('x-get-line-id', 'edit-app-dialog')", "Add content of variant edition for selected character", "octicons/svg/note.svg", "", "close", ("tls-editor", "tls-punc"))
      
     }</h6>
    <h6 class="text-muted">Line: <span id="swl-line-text-span" class="ml-2 chn-font">Text of line</span>
    {lrh:format-button-common("toggle_list_display()","Switch to different ordering of Lexical entries.", "octicons/svg/gear.svg")}
    {lrh:format-button-common("add_rd_here()","Add observation (regarding a text segment) starting on this line", "octicons/svg/comment.svg")}
    </h6>
    <!--  {lrh:format-button-common("add_parallel()","Add word relations starting on this line", "對")} -->
    <div class="card-text">
       
        <p> { if (sm:is-authenticated() and not(contains(sm:id()//sm:group, 'tls-test'))) then <span id="new-att-detail">
        <span class="badge badge-primary">Use</span> one of the following syntactic words (SW), 
        create a one of the following  
         ,add an <span class="font-weight-bold">existing</span> <span class="btn badge badge-primary ml-2" onclick="show_new_concept('existing', '')">Concept</span> to the word
         or create a <span class="btn badge badge-primary ml-2" onclick="show_new_concept('new', '')">New Concept</span>. You can also add a word relation: First set the left word with <span class="badge badge-secondary">LW</span>.
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
    <h5 class="card-title"><span id="new-att-title">Existing SW for <strong class="ml-2"><span class="chn-font" id="swl-query-span"></span></strong></span>
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
let $cnode := collection($config:tls-data-root)//tei:sense[@xml:id=$uuid]
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
$anntype := if (local-name($node)='ann') then "nswl" else 
               if (local-name($node)='drug') then "drug" else
               if (local-name($node)='item') then "wrl"
               else data($node/@type),
$type := $options?type,
$context := $options?context
let $concept := data($node/@concept),
$creator-id := if ($node/tls:metadata/@resp) then
 substring($node/tls:metadata/@resp, 2) else 
 substring($node/ancestor::tei:div[@type='word-rel-ref']/@resp, 2)  ,
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
, $exemplum := if ($node/tls:metadata/@rating) then xs:int($node/tls:metadata/@rating) else 0
, $bg := if ($exemplum > 0) then "protypical-"||$exemplum else "bg-light"
, $marktext := if ($exemplum = 0) then "Mark this attribution as prototypical" else "Currently marked as prototypical "||$exemplum ||". Increase up to 3 then reset."
, $resp := tu:get-member-initials($creator-id)
, $wr-rel :=  $node/ancestor::tei:div[@type='word-rel-ref']
(:$pos := concat($sf, if ($sm) then (" ", $sm) else "")
:)
return
if ($type = "row") then
if ($anntype = "wrl") then 
<div class="row {$bg} {$anntype}">
<div class="col-sm-1"><span class="{$anntype}-col">●</span></div>
<div class="col-sm-2"><span>{$node/text()}</span></div>
<div class="col-sm-3"><a href="concept.html?concept={$concept}{$node/@corresp}" title="{$cdef}">{$concept}</a></div>
<div class="col-sm-6"><span>WR: {$wr-rel/ancestor::tei:div[@type='word-rel-type']/tei:head/text()} /  {data($node/@p)}</span>
{ (: buttons start -- put them in extra function, together with the other version below! :)
if ("tls-editor"=sm:get-user-groups($user) and $wr-rel/@xml:id) then 
(
 (: for reviews, we display the buttons in tlslib:show-att-display, so we do not need them here :)
  if (not($context='review')) then
   (
   (: not as button, but because of the title string open-iconic-master/svg/person.svg :)
   lrh:format-button("null()", "Resp: " || $resp[1] , $resp[2], "small", "close", "tls-user"),
   (: for my own swls: delete, otherwise approve :)
   if (($user = $creator-id) or contains($usergroups, "tls-editor" )) then 
    lrh:format-button("delete_word_relation('" || data($wr-rel/@xml:id) || "')", "Immediately delete this WR", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else ()
  (:  ,   
   lrh:format-button("incr_rating('swl', '" || data($wr-rel/@xml:id) || "')", $marktext, "open-iconic-master/svg/star.svg", "small", "close", "tls-editor"),
   if (not ($user = $creator-id)) then
   (   
    lrh:format-button("save_swl_review('" || data($wr-rel/@xml:id) || "')", "Approve the SWL for " || $zi, "octicons/svg/thumbsup.svg", "small", "close", "tls-editor")
    ) else ()
  :) 
  ) else ()
)
else ()
(: buttons end :)
}

</div>
</div>
else
if ($anntype eq "nswl") then
<div class="row {$bg} {$anntype}">
{if (not($context = 'review')) then 
<div class="col-sm-1"><span class="{$anntype}-col">●</span></div>
else ()}
<div class="col-sm-2"><span class="zh chn-font">{$czi}</span> ({$cpy})
{if  ("tls-admin.x" = sm:get-user-groups($user)) then (data(($node//tls:srcline/@pos)[1]),
 <a href="{
      concat($config:exide-url, "?open=", document-uri(root($node)))}">eXide</a>)
      else ()
  }    
</div>
<div class="col-sm-3"><a href="concept.html?concept={$concept}#{$w/@xml:id}" title="{$cdef}">{$concept}</a></div>
<div class="col-sm-6">
<span><a href="browse.html?type=syn-func&amp;id={data($sf/@corresp)}">{($sf)[1]/text()}</a>&#160;</span>
{if ($sm) then 
<span><a href="browse.html?type=sem-feat&amp;id={$sm/@corresp}">{($sm)[1]/text()}</a>&#160;</span> else ()}
{($def)[1]}
{
if ("tls-editor"=sm:get-user-groups($user) and $node/@xml:id) then 
(
 (: for reviews, we display the buttons in tlslib:show-att-display, so we do not need them here :)
  if (not($context='review')) then
   (
   (: not as button, but because of the title string open-iconic-master/svg/person.svg :)
   lrh:format-button("null()", "Resp: " || $resp[1] , $resp[2], "small", "close", "tls-user"),
   (: for my own swls: delete, otherwise approve :)
   if (($user = $creator-id) or contains($usergroups, "tls-editor" )) then 
    lrh:format-button("delete_swl('swl', '" || data($node/@xml:id) || "')", "Immediately delete this SWL for "||$zi[1], "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
   else (),
   lrh:format-button("incr_rating('swl', '" || data($node/@xml:id) || "')", $marktext, "open-iconic-master/svg/star.svg", "small", "close", "tls-editor"),
   if (not ($user = $creator-id)) then
   (
<span class="rp-5">
{lrh:format-button("review_swl_dialog('" || data($node/@xml:id) || "')", "Review the SWL for " || $zi[1], "octicons/svg/unverified.svg", "small", "close", "tls-editor")}&#160;&#160;</span>,   
    lrh:format-button("save_swl_review('" || data($node/@xml:id) || "')", "Approve the SWL for " || $zi, "octicons/svg/thumbsup.svg", "small", "close", "tls-editor")
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
    lrh:format-button("delete_swl('drug', '" || data($node/@xml:id) || "')", "Immediately delete the observation "||data($node/text()), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
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
    lrh:format-button("delete_swl('rdl', '" || data($node/@xml:id) || "')", "Immediately delete the observation "||data($node/@rhet-dev), "open-iconic-master/svg/x.svg", "small", "close", "tls-editor")
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

declare function tlslib:get-first-seg($location, $mode, $first){
    let $dataroot := $config:tls-data-root
    , $user := sm:id()//sm:real/sm:username/text()
    , $usercoll := collection($config:tls-user-root || "/" || $user)
return
     if (contains($location, '_')) then
       let $textid := tokenize($location, '_')[1]
       let $firstseg := collection($config:tls-texts-root)//tei:seg[@xml:id=$location]
       return
         $firstseg
     else
      if (not($mode = 'visit') and collection($config:tls-manifests)//mf:manifest[@xml:id=$location]) then 
      krx:show-manifest(collection($config:tls-manifests)//mf:manifest[@xml:id=$location]) 
     else
      let $firstdiv := 
         if ($first = 'true') then 
            collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]//tei:body/tei:div[1]
         else
            let $rec := $usercoll//tei:list[@type='visit']/tei:item[@xml:id=$location]
            
            let $visit := if ($rec) then substring($rec/@target, 2) else
              (: 2023-05-11 -- changed to new way to record visits, will phase the following out after a while :)
              (for $v in collection($config:tls-user-root || "/" || $user)//tei:list[@type="visits"]/tei:item
               let $date := xs:dateTime($v/@modified)
               ,$target := substring($v/tei:ref/@target, 2)
               order by $date descending
               where starts-with($target, $location)
               return $target)[1]
            return
            if ($visit) then 
             let $rst := collection($config:tls-texts-root)//tei:seg[@xml:id=$visit]
             return if ($rst) then $rst else 
               let $doc := collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]
(:                , $l := log:info($app:log, "Loading text, no visit" || count($doc)):)
               return
                 subsequence($doc//tei:body, 1, 1)
            else          
             let $doc := collection($config:tls-texts-root)//tei:TEI[@xml:id=$location]
(:                , $l := log:info($app:log, "Loading text, all failed: " || count($doc)):)
             return
               subsequence($doc//tei:body, 1, 1)
    
      let $targetseg := if (local-name($firstdiv) = "seg") then $firstdiv else 
      if ($firstdiv//tei:seg) then subsequence($firstdiv//tei:seg, 1, 1) else  subsequence($firstdiv/following::tei:seg, 1, 1) 
      return
    $targetseg
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
    , $resp := tu:get-member-initials($sw/@resp)
    return
    <li id="{$id}">
    {if ($display-word) then <span class="ml-2">{$char}</span> else ()}
    <span id="sw-{$id}" class="font-weight-bold">{$sf}</span>
    <em class="ml-2">{$sm}</em> 
    <span class="ml-2">{$def}</span>
    {if ($resp) then 
    <small><span class="ml-2 btn badge-secondary" title="{$resp[1]} - {$sw/@tls:created}">{$resp[2]}</span></small> else ()}
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
      lrh:format-button("delete_word_from_concept('"|| $id || "')", "Delete the syntactic word "|| $sf || ".", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else 
      if ($count > 0) then (
      lrh:format-button("move_word('"|| $char || "', '"|| $id ||"', '"||$count||"')", "Move the SW  '"|| $sf || "' including "|| $count ||"attribution(s) to a different concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor") ,      
      lrh:format-button("merge_word('"|| $sf || "', '"|| $id ||"', '"||$count||"')", "Delete the SW '"|| $sf || "' and merge "|| $count ||"attribution(s) to a different SW.", "open-iconic-master/svg/wrench.svg", "", "", "tls-editor")       
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
(: TODO find a better way, get juan for CBETA texts :)
$loc := try {xs:int((tokenize($target, "_")[3] => tokenize("-"))[1])} catch * {0}
, $exemplum := if ($a/tls:metadata/@rating) then xs:int($a/tls:metadata/@rating) else 0
, $bg := if ($exemplum > 0) then "protypical-"||$exemplum else "bg-light"
, $creator-id := substring($a/tls:metadata/@resp, 2)
(:, $resp := doc($config:tls-data-root || "/vault/members.xml")//tei:person[@xml:id=$creator-id]//tei:persName/text():)
, $resp := tu:get-member-initials($creator-id)
return
<div class="row {$bg} table-striped">
<div class="col-sm-2"><a href="textview.html?location={$target}" class="font-weight-bold">{$src, $loc}</a></div>
<div class="col-sm-3"><span data-target="{$target}" data-toggle="popover">{$line}</span></div>
<div class="col-sm-7"><span>{$tr/text()}</span>
{if ((sm:has-access(document-uri(fn:root($a)), "w") and $a/@xml:id) and not(contains(sm:id()//sm:group, 'tls-test'))) then 
(
(:   lrh:format-button("null()", "Resp: " || $resp , "open-iconic-master/svg/person.svg", "small", "close", "tls-user"),:)
 if ($resp[1]) then 
   lrh:format-button("null()", "Resp: " || $resp[1] , $resp[2], "small", "close", "tls-user") else (),

(:lrh:format-button("review_swl_dialog('" || data($a/@xml:id) || "')", "Review this attribution", "octicons/svg/unverified.svg", "small", "close", "tls-editor"),:)
lrh:format-button("incr_rating('swl', '" || data($a/@xml:id) || "')", "Mark this attribution as prototypical", "open-iconic-master/svg/star.svg", "small", "close", "tls-editor"),
lrh:format-button("delete_swl('swl', '" || data($a/@xml:id) || "')", "Delete this attribution", "open-iconic-master/svg/x.svg", "small", "close", "tls-editor"),
 if (not ($user = substring($a/tls:metadata/@resp, 2))) then
    lrh:format-button("save_swl_review('" || data($a/@xml:id) || "')", "Approve the SWL", "octicons/svg/thumbsup.svg", "small", "close", "tls-editor") else ()
)
else ()}
</div>
</div>
};



declare function tlslib:recent-texts-list($num){
subsequence( for $l in  lvs:recent-visits()
  let $date := xs:dateTime($l/@modified)
  , $textid := $l/@xml:id
  , $title := lu:get-title($textid)
  , $target := substring($l/tei:ref/@target, 2)
  order by $date descending
  where not ($textid = $config:ignored-text-ids)
  return 
  <li><a href="textview.html?location={$target}">{$title}</a></li>
  , 1, $num)
};

(: generic function to save the setting of $map?setting to $map?value :)

declare function tlslib:save-setting($map as map(*)){
let $doc := lus:get-settings()
return
if ($doc) then 
switch($map?setting)
case "search-ratio"
case "search-cutoff"
case "search-defaultsection"
case "search-sortmax" return 
    let $section-type := tokenize($map?setting, "-")[1]
    let $item := <item xmlns="http://hxwd.org/ns/1.0" created="{current-dateTime()}" modified="{current-dateTime()}" type="{$map?setting}" value="{$map?value}"/>
   return (
    if ($doc//tls:item[@type=$map?setting]) then  
      update replace  $doc//tls:item[@type=$map?setting] with $item
    else 
     if ($doc//tls:section[@type=$section-type]) then 
      update insert $item into $doc//tls:section[@type=$section-type]
     else update insert <section  xmlns="http://hxwd.org/ns/1.0" type="search">{$item}</section> into $doc/tls:settings
     , "OK")
default return ()
else ()
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
 ,$rdoc := lv:get-crypt-file("changes")
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
 ,$rdoc := lv:get-crypt-file("changes")
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
let $resp:=  lv:get-crypt-file("changes")//tei:respStmt[@xml:id=$map?uuid]/tei:resp
return
     update insert attribute notAfter {current-dateTime()} into $resp
};




(: get related texts: look at Manifest.xml :)

declare function tlslib:get-related($map as map(*)){
let $line := $map?line
,$sid := $map?seg
, $res := krx:collate-request($sid)
, $edid := string-join(subsequence(tokenize($sid, "_"), 1,2), "_")
, $mf := collection($config:tls-manifests)//mf:edition[@id=$edid]/ancestor::mf:editions
return
<li class="mb-3">
{for $w in $res//witnesses 
return
<ul><li>{collection($config:tls-manifests)//mf:edition[@id=$w/id]/mf:description} ({$w/id})<p>
{string-join(for $t in $w/tokens return
(data($t/@t), data($t/@f)), '') 
}</p>
</li>
</ul>
}
</li>
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
  <div class="col-sm-2">{lrh:format-button("delete_pron('" || data($r/@xml:id) || "')", "Immediately delete pronounciation "||$py||" for "||$g, "open-iconic-master/svg/x.svg", "", "close", "tls-editor")}</div>
  </div>,
()
}
</div>
</div>
};

declare function tlslib:review-request(){
let $user := "#" || sm:id()//sm:username
, $text := doc($config:tls-add-titles)//work[@request]
, $recent := doc($config:tls-add-titles)//work[@requested-by]
return

<div class="container">
<div>
<h3>Requested texts: {count($text)} items</h3>
{tlslib:review-request-rows($text)}
</div>
<div>
<h3>Recently added texts: {count($recent)} items</h3>
{tlslib:review-request-rows($recent)}
</div>

</div>
};

declare function tlslib:review-request-rows($res as node()*){
for $w at $pos in $res
      let $kid := data($w/@krid)
      , $req := if ($w/@request) then 
        <span id="{$kid}-req">　Requests: {count(tokenize($w/@request, ','))}</span> else 
        <span id="{$kid}-req">　Requested by: {data($w/@requested-by)}</span>
      , $cb := $w/altid except $w/altid[matches(., "^(ZB|SB|SK)")] 
      , $cbid := if ($cb) then $cb else $kid
      , $date := if ($w/@tls-added) then xs:dateTime($w/@tls-added) else xs:dateTime($w/@request-date)
    order by $date descending
return
  <div class="row border-top pt-4" id="{data($w/@krid)}">
  <div class="col-sm-3"><a href="textview.html?location={$kid}">{$kid}　{$w/title/text()}</a></div>
  <div class="col-sm-3"><span>{$req}</span> {" "||data($w/@tls-added)}</div>  
  {if ($w/@request) then
  <div class="col-sm-3"><span id="gloss-{$pos}" title="Click here to add text" onclick="add_text('{$kid}', '{$cbid=> string-join('$')}')">Add: {$cbid}</span></div>
  else
  <div class="col-sm-3"><span id="gloss-{$pos}" title="Click here to analyze text" onclick="analyze_text('{$kid}')">Analyze this text</span></div>
  }
  <div class="col-sm-3"><a target="eXide" href="{
      concat ($config:exide-url, "?open=", $config:tls-texts-root || "/KR/", substring($kid, 1, 3) || "/" || substring($kid, 1, 4) || "/"  || $kid || ".xml")}"
      >Open in eXide</a></div>
  </div>,
()
  
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
("Taxonomy of meanings: ", for $c in $qc return  <a class="btn badge badge-light chn-font" title="Show taxonomy of meanings for {$c}" href="char.html?char={$c}">{$c}</a>,
         " Phonetic profile: ",
     for $c in $qc return  
     <a class="btn badge badge-light chn-font" style="background-color:palegreen" title="Show phonetic profile for {$c}" href="syllables.html?char={$c}">{$c}</a>,
(:     <span>{" 國學大師: ", 
     for $c in $qc return
     tlslib:guoxuedashi($c)
     }</span>,:)
     tlslib:guguolin($qc)
     , <span class="btn badge badge-light chn-font">Zi:</span>,
     for $c in $qc return
      <a class="btn badge badge-light chn-font" style="background-color:paleturquoise"  target="dict" title="Search zi.tools for {$c} (External link)" href="https://zi.tools/zi/{$c}">{$c}</a>, "　",
     (:    var url = "http://www.kaom.net/z_hmy_zidian88.php?word={string-join($qc, '')}&mode=word&bianti=no&page=no"
 :)
     <span>{" 詞典: ",
     <a class="btn badge badge-light chn-font" target="dict" title="Search {$qc} in HY dictionary (External link)" style="background-color:paleturquoise" href="http://www.kaom.net/hemoye/z_hmy_zidian88.php?word={string-join($qc, '')}&amp;mode=word&amp;bianti=no&amp;page=no">{$qc}</a>
     }　</span>
     
     ,
     <span>{" 漢リポ: ",
     <a class="btn badge badge-light chn-font" target="kanripo" title="Search {$qc} in Kanseki Repository (External link)" style="background-color:paleturquoise" href="http://www.kanripo.org/search?query={string-join($qc, '')}">{$qc}</a>
     }</span>
)
};

declare function tlslib:guoxuedashi($c as xs:string){
<a class="btn badge badge-light chn-font" target="GXDS" title="Search {$c} in 國學大師字典 (External link)" style="background-color:paleturquoise" href="http://www.guoxuedashi.com/so.php?sokeytm={$c}&amp;ka=100">{$c}</a>
};

declare function tlslib:guguolin($qc){
    for $c at $pos in $qc return
<form class="btn badge badge-light chn-font"  name="guguolin" target="dict" action="http://www.kaom.net/hemoye/z_hmy_zidian8.php" method="post" title="訓詁工具書查詢 {$c} (External link)" >
  {if ($pos = 1) then "字書：" else ()}
  <input type="hidden" name="word" id="word" value="{$c}="/>
  <input type="hidden" name="mode" id="mode" value="word" />
  <input type="hidden" name="bianti" id="bianti" value="no"/>
  <input type="hidden" name="page" id="page" value="no"/>
  <button class="btn badge badge-light" type="submit" style="background-color:paleturquoise">{$c}</button>
</form>
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
      $cat := lmd:get-metadata($d, "kr-categories"),
      $datecat := lmd:get-metadata($d, "tls-dates"),
      $charcount := lmd:get-metadata($d, "extent"),
      $dates := if (exists(doc($config:tls-user-root || $user || "/textdates.xml")//date)) then 
      doc($config:tls-user-root || $user || "/textdates.xml")//data else 
      doc($config:tls-texts-meta  || "/textdates.xml")//data,
      $mdate := <date>{lmd:get-metadata($d, "date")}</date>,
      $date := if ($mdate) then $mdate else $dates[@corresp="#" || $textid],
      $loewe := doc($config:tls-data-root||"/bibliography/loewe-ect.xml")//tei:bibl[tei:ref[@target = "#"||$textid]]
return
      <div class="col">
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Edition:</span></div>
           <div class="col-sm-9"><span class="sm">{lmd:get-metadata($d, "edition")}</span></div>　
         </div>  
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Catalog category:</span></div>
           <div class="col-sm-9"><span class="sm" id="text-cat" data-text-cat="{$cat}">{lmd:cat-title($cat)}</span>
           {if (sm:is-authenticated()) then <span class="badge badge-pill badge-light" onclick="edit_textcat('{$textid}')">Edit category</span> else ()} </div>　
         </div>  
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Dates:</span></div>
           <div class="col-sm-9"><span class="sm badge badge-pill" id="date-cat" data-date-cat="{$datecat}">{lmd:cat-title($datecat)}</span>　{
           if ($date) then 
            (<span id="textdate-outer"><span id="textdate" data-not-before="{$date/@notBefore}" data-not-after="{$date/@notAfter}">{$date/text()}<span id="textdate-note" class="text-muted">{$date/note/text()}</span></span></span>,
            if (sm:is-authenticated()) then <span class="badge badge-pill badge-light" onclick="edit_textdate('{$textid}')">Edit date</span> else 
            ()
            ) 
           else
           if (sm:is-authenticated()) then (<span id="textdate-outer"><span id="textdate">　</span></span>,<span class="badge badge-pill badge-light" onclick="edit_textdate('{$textid}')">Add date</span>) else 
            "　"}　</div>
         </div>
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2">{ if (sm:is-authenticated()) then <span class="font-weight-bold float-right" title="Click on one of the stars to rate the text and add to the ★ menu.">Rating:</span> else ()}</div>
           <div class="col-sm-9">{ if (sm:is-authenticated()) then
           <input id="input-{$textid}" name="input-name" type="number" class="rating"
    min="1" max="10" step="2" data-theme="krajee-svg" data-size="xs" value="{tlslib:get-rating($textid)}"/> else ()}</div> 
        </div>
         <div class="row">        
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Textlength:</span></div>
           <div class="col-sm-9"><span>{$charcount} characters.</span></div>
         </div>   
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Comment:</span></div>
           <div class="col-sm-9"><span class="tr-x" id="{$textid}-com" contenteditable="true">　</span></div>    
         </div>  
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">Wikidata:</span></div>
           <div class="col-sm-9">{wd:display-qitems($textid, 'title', lu:get-title($textid))}</div>    
         </div>  
         <div class="row">
           <div class="col-sm-1"/>
           <div class="col-sm-2"><span class="font-weight-bold float-right">References:</span></div>
           <div class="col-sm-9"><span>{if ($loewe) then <span>{$loewe/tei:author}, in Loewe(ed), <i>Early Chinese Texts</i> (1995), p.{$loewe/tei:citedRange/text()}<br/></span> else '　'}</span>
           <span>{for $r in $d//tei:witness 
           let $ref := $r//tei:ref/@target
           return <span>{
             if ($ref) then 
             <a class="badge badge-pill badge-light" title="Show bibliography" href="bibliography.html?uuid={substring($r//tei:ref/@target, 2)}&amp;textid={$textid}"><span>{data($r/@xml:id)}:</span>{$r/text()}<br/></a> 
             else 
             <span class="badge badge-pill badge-light">{data($r/@xml:id)}:{$r/text()}<br/></span>
             }</span>
           }</span>
           { if (sm:is-authenticated()) then <a class="badge badge-pill badge-light"  href="search.html?query={lu:get-title($textid)}&amp;textid={$textid}&amp;search-type=10" title="Add new reference">Add reference to source or witness</a> else ()}</div>    
         </div>  
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


(: this is for the char editing :)


(: retrieve the pron for this entry (given through its id) :)

declare function tlslib:pron-for-entry($uuid){
let $f := collection($config:tls-data-root||"/concepts")//tei:entry[@xml:id=$uuid]/tei:form
return
$f
};

(: create tax stub for char :)
declare function tlslib:char-tax-stub($char as xs:string, $type as xs:string){
let $doc := if ($type = 'taxchar') then 
   doc($config:tls-data-root||"/core/taxchar.xml")
   else 
   doc($config:tls-data-root||"/core/taxword.xml")   
, $res:= tlslib:getwords($char, map{})
, $pmap := map:merge(
  for $k in map:keys($res)
   let $v := map:get($res, $k)
   , $f := tlslib:pron-for-entry($k)
   return map:entry($k, $f//@corresp))
  
, $gy := distinct-values(for $k in map:keys($pmap)
   return map:get($pmap, $k))

, $stub :=
<div xml:id="uuid-{util:uuid()}" type="{$type}" xmlns="http://www.tei-c.org/ns/1.0">
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
, $fq := try { ($e//tx:fanqie/tx:fanqie-shangzi//tx:graph/text() || $e//tx:fanqie/tx:fanqie-xiazi//tx:graph/text()) } catch
* { () }
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
declare function tlslib:char-tax-newconcepts($char as xs:string, $type as xs:string){
 let $cdoc := if ($type = "taxchar") then  
   doc($config:tls-data-root || "/core/taxchar.xml")
   else
   doc($config:tls-data-root || "/core/taxword.xml")
   
 , $chead :=  $cdoc//tei:head[. = $char]
 , $cdiv := $chead/ancestor::tei:div[@type=$type]
 , $emap := tlslib:getwords($char, map{})
 , $cseq := for $r in $cdiv//tei:ref
   let $id := substring($r/@target, 2)
   return $id
  , $em1 := map:merge( for $r in map:keys($emap)
   let $k := map:get($emap, $r)[1]
   where not ($k = $cseq)
   return map:entry($r, map:get($emap, $r)))
 return 
 <div type="{$type}-add"  xmlns="http://www.tei-c.org/ns/1.0">
 <head>{$char}</head>
 <list>{
 for $r in  map:keys($em1)
 let $p := (tlslib:pron-for-entry($r)/tei:pron[@xml:lang="zh-Latn-x-pinyin"]/text())[1]
 , $concept := map:get($emap, $r)[2]
 order by $p || $concept
 return <item corresp="#{$r}">{$p}  <ref target="#{map:get($emap, $r)[1]}">{$concept}</ref></item>
 }</list></div>
};


declare function tlslib:char-tax-contentline($str as xs:string){
let $as := analyze-string(normalize-space($str), $config:concept-name-chars||"+$")//fn:*
, $concept := $as[last()]/text()
return ($as[position() < last()]/text() || " ", 
 <ref xmlns="http://www.tei-c.org/ns/1.0" target="#{tlslib:get-concept-id($concept)}">{$concept => replace("_", " ")}</ref>)
};
(: the pinyin handling is broken, we dont go down this rabbit hole :)
declare function tlslib:char-tax-html2xml-py($node as node(), $type as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
return
typeswitch ($node)
  case element(li) return 
    (: Problem with this code:  can't rely on @tei-*, since they do not get updated during the editing process. :)
    let $new-node-w-py := starts-with($node/child::a, "@py:")
    let $type := if ($new-node-w-py) then "pron" else $node/@tei-type
    return
       if ($type = 'pron') then 
        (: @corresp is the link to the guangyun file, currently available only for new taxchar structures :)
        if (string-length($node/@tei-corresp) > 0) then 
            <item xmlns="http://www.tei-c.org/ns/1.0" type="pron" corresp="{$node/@tei-corresp}">{for $n in $node/node() return tlslib:char-tax-html2xml($n, $type)}</item>
        else
            <item xmlns="http://www.tei-c.org/ns/1.0" type="pron">{for $n in $node/node() return tlslib:char-tax-html2xml($n, $type)}</item>
      else
      <item xmlns="http://www.tei-c.org/ns/1.0">
       { for $n in $node/node() return tlslib:char-tax-html2xml($n, $type)}</item>
  case element(ul) return <list xmlns="http://www.tei-c.org/ns/1.0">{$node/text(), for $n in $node/node() return tlslib:char-tax-html2xml($n, $type)}</list>
  case element(div) return 
     let $id := if (string-length($node/@tei-id) > 0) then $node/@tei-id else "uuid" || util:uuid()
     return
     <div type="taxchar" xml:id="{$id}" resp="{$user}" modified="{current-dateTime()}" xmlns="http://www.tei-c.org/ns/1.0" >
       {for $h in tokenize($node/@tei-head, '/') return <head xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($h)}</head>}
       {for $n in $node/node() return tlslib:char-tax-html2xml($n, $type)}
     </div>
  case element(i) return for $n in $node/node() return tlslib:char-tax-html2xml($n, $type)
  case element(a) return 
    let $str := string-join($node) => replace("@py:", "")
    return
    if ($node/parent::li[@tei-type='pron'] or starts-with($node, "@py:")) then replace($node/text(), "@py:", "")
    else if (string-length($str) > 0) then tlslib:char-tax-contentline($str) else ()
  case text() return $node
  default 
  return <name>{$node}</name>
};


declare function tlslib:char-tax-html2xml($node as node(), $ctype as xs:string){
let $user := sm:id()//sm:real/sm:username/text()
return
typeswitch ($node)
  case element(li) return 
    let $type := $node/@tei-type
    return
       if ($type = 'pron') then 
        (: @corresp is the link to the guangyun file, currently available only for new taxchar structures :)
        if (string-length($node/@tei-corresp) > 0) then 
            <item xmlns="http://www.tei-c.org/ns/1.0" type="pron" corresp="{$node/@tei-corresp}">{for $n in $node/node() return tlslib:char-tax-html2xml($n, $ctype)}</item>
        else
            <item xmlns="http://www.tei-c.org/ns/1.0" type="pron">{for $n in $node/node() return tlslib:char-tax-html2xml($n, $ctype)}</item>
      else
      <item xmlns="http://www.tei-c.org/ns/1.0">
       { for $n in $node/node() return tlslib:char-tax-html2xml($n, $ctype)}</item>
  case element(ul) return <list xmlns="http://www.tei-c.org/ns/1.0">{$node/text(), for $n in $node/node() return tlslib:char-tax-html2xml($n, $ctype)}</list>
  case element(div) return 
     let $id := if (string-length($node/@tei-id) > 0) then $node/@tei-id else "uuid" || util:uuid()
     return
     <div type="{$ctype}" xml:id="{$id}" resp="{$user}" modified="{current-dateTime()}" xmlns="http://www.tei-c.org/ns/1.0" >
       {for $h in tokenize($node/@tei-head, '/') return <head xmlns="http://www.tei-c.org/ns/1.0">{normalize-space($h)}</head>}
       {for $n in $node/node() return tlslib:char-tax-html2xml($n, $ctype)}
     </div>
  case element(i) return for $n in $node/node() return tlslib:char-tax-html2xml($n, $ctype)
  case element(a) return 
    let $str := string-join($node) 
    return
    if ($node/parent::li[@tei-type='pron']) then $str
    else if (string-length($str) > 0) then tlslib:char-tax-contentline($str) else ()
  case text() return $node
  default 
  return <name>{$node}</name>
};

(: Generate a fresh xml:id for a segment based on some base line id that an index is appended to. 
 : If appending the index results in an id that is already present in the database, the level
 : parameter is also appended to the id. The level argument will be increased until a
 : id that is not present in the database is found. :)
declare function tlslib:generate-new-line-id($base-id as xs:string, $index as xs:int, $level as xs:int) as xs:string {
    let $nid := $base-id || "." || $index || (if ($level = 0) then "" else "." || $level)
    return
        if (collection($config:tls-texts-root)//tei:seg[@xml:id=$nid]) then
            tlslib:generate-new-line-id($base-id, $index, $level + 1)
        else
            $nid
};

(: Just like the above function, with $level set to 0 as a default. :)
declare function tlslib:generate-new-line-id($base-id as xs:string, $index as xs:int) as xs:string {
    tlslib:generate-new-line-id($base-id, $index, 0)
};

(: we get a nodeset of wr to display :)
declare function tlslib:display-word-rel($word-rel, $char, $cname){
<ul><span class="font-weight-bold">Word relations</span>{for $wr in $word-rel 
    let $wrt := $wr/ancestor::tei:div[@type="word-rel-type"]/tei:head/text()
    , $entry-id := substring(($wr//tei:item[. = $char])[1]/@corresp, 2)
    , $wrid := ($wr/tei:div[@type="word-rel-ref"]/@xml:id)[1]
    , $count := count($wr//tei:item[@p="left-word"]/@textline)
    , $oid := substring(($wr//tei:list/tei:item/@corresp[not(. = "#" || $entry-id)])[1], 2)
    , $oword := collection($config:tls-data-root||"/concepts")//tei:entry[@xml:id=$oid]
    , $other := string-join($oword/tei:form/tei:orth/text() , " / ")
    , $cid := $oword/ancestor::tei:div[@type='concept']/@xml:id
    , $concept := $oword/ancestor::tei:div[@type='concept']/tei:head/text()
    , $uuid := substring(util:uuid(), 1, 16)
    , $tnam := data(($wr//tei:list/tei:item[@corresp = "#" || $entry-id]/@concept)[1])
    , $show := (string-length($entry-id) > 0) and (if (string-length($cname) > 1) then $cname = $tnam else true())
    where $show
    return 
    <li><span class="font-weight-bold"><a href="browse.html?type=word-rel-type&amp;mode={$wrt}#{$wrid}">{$wrt}</a></span>: {if (string-length($cname) > 1) then () else <span>({$tnam})</span>}<a title="{$concept}" href="concept.html?uuid={$cid}#{$oid}">{$other}/{$concept}</a>{$oword/tei:def[1]}
         <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$wrid}-{$uuid}-resp" onclick="show_wr('{$wrid}', '{$uuid}')">
          {if ($count) then ( $count ,
          if ($count = 1) then " Attribution" else  " Attributions")
          else ()}
      </button>
    <div id="{$wrid}-{$uuid}-resp" class="collapse container"></div>

</li>
    }</ul>
};

declare function tlslib:word-rel-table($map as map(*)){
let $rels := collection($config:tls-data-root)//tei:TEI[@xml:id="word-relations"]//tei:body/tei:div[@xml:id=$map?reltype]
, $start := if ($map?start) then $map?start else 1
, $cnt := if ($map?cnt) then $map?cnt else 2000
return
(<div>
<p><span class="font-weight-bold ml-2">About word relations:</span><span class="ml-2">{$rels[1]/ancestor::tei:TEI//tei:front/tei:p/text()}</span></p></div>,
<h3><span class="font-weight-bold ml-2">{$rels/tei:head/text()}:</span><span class="ml-2">{$rels[1]/tei:div[@type="word-rels"]/tei:p/text()}</span></h3>
,
 <div class="row">
 <div class="col-md-1">
 　
 </div> 
 <div class="col-md-2">
 Left Word
 </div>
 <div class="col-md-2">
 Right Word
 </div>
 <div class="col-md-2">
 　　Text / Ref
 </div>
 </div>, 
for $r in subsequence($rels//tei:div[@type='word-rel'], $start, $cnt)
 let $lw := (($r//tei:list[1])/tei:item)[1]
 , $wrid := ($r/tei:div[@type='word-rel-ref']/@xml:id)[1]
 , $rw := (($r//tei:list[1])/tei:item)[2]
 , $txt := data($lw/@txt)
 , $lc := data($lw/@concept)
 , $lid := data($lw/@concept-id)
 , $rc := data($rw/@concept)
 , $rid := data($rw/@concept-id)
 , $bibs := $r//tei:div[@type='source-references']//tei:bibl
 , $srt :=  switch($map?mode)  
            case 'rw' return $rw
            case 'txt' return $txt
            case 'rc' return $rc
            case 'lc' return $lc
            default return $lw
 order by $srt 
 return 
 if (string-length($lw) > 0 or string-length($rw) > 0) then
 (<div class="row" id="{$wrid}">
 <div class="col-md-1">
 </div>
 <div class="col-md-2">
 <a href="concept.html?uuid={$lid}{$lw/@corresp}">{$lw}/{$lc}</a>
 </div>
 <div class="col-md-2">
 <a href="concept.html?uuid={$rid}{$rw/@corresp}">{$rw}/{$rc}</a>
 </div>
 <div class="col-md-">
 {for $l in $r/tei:div[@type='word-rel-ref']
  let $tid := $l/@xml:id
  , $lwn := ($l//tei:list/tei:item)[1]
  , $rwn := ($l//tei:list/tei:item)[2]
 , $txt := data($lwn/@txt)
 , $ll := try {<span>{substring(data($lwn/@textline), 1, xs:int($lwn/@offset) - 1)}<b>{substring(data($lwn/@textline), xs:int($lwn/@offset), xs:int($lwn/@range))}</b>{substring(data($lwn/@textline), xs:int($lwn/@offset) + xs:int($lwn/@range))}</span> } catch * {<span>{data($lwn/@textline)}</span>}
 , $rl := try {<span>{substring(data($rwn/@textline), 1, xs:int($rwn/@offset) - 1)}<b>{substring(data($rwn/@textline), xs:int($rwn/@offset), xs:int($rwn/@range))}</b>{substring(data($rwn/@textline), xs:int($rwn/@offset) + xs:int($rwn/@range))}</span> } catch * {<span>{data($rwn/@textline)}</span>}
 , $lnk := if (string-length($lwn/@line-id) > 0) then ($lwn/@line-id)[1] else if (string-length($rwn/@line-id) > 0) then ($rwn/@line-id)[1] else ()
 return 
  (:delete :)
  (lrh:format-button("delete_word_relation('"|| $tid || "')", "Delete this word relation.", "open-iconic-master/svg/x.svg", "", "", "tls-editor")
,     (: move :)
    lrh:format-button("change_word_rel('"|| $tid || "')", "Change the type of word relation for this attribution.", "open-iconic-master/svg/move.svg", "", "", "tls-editor")  
,if (string-length($ll) > 0) then 
  ($ll, " / ", $rl ,  "(", if (string-length($lnk) > 0) then 
   <a href="textview.html?location={$lnk}">{$txt}{xs:int(tokenize(tokenize($lnk, "_")[3], "-")[1])}</a>
   else
   $txt , ")"
   , if (string-length($l/tei:p) > 0) then 
    (<span><span class="text-muted">　Note: </span>{$l/tei:p/text()}</span>) else () 
   )
else  
 for $bib in $bibs
 return
 (<a href="bibliography.html?uuid={substring(($bib//tei:ref/@target)[1],2)}">{$bib//tei:title/text()}</a>, 
 $bib
 ), <br/>)
 }
 </div>
 </div>
 ,if (string-length($r/tei:p)> 0) then 
 <div class="row" id="{$wrid}-note">
 <div class="col-md-1">
 </div>
 <div class="col-md-10"><span class="text-muted">Note:　</span>{$r/tei:p/text()}</div>
 </div>
 else ()
 , <hr/>
 )
  else
 ()
 )
};



declare function tlslib:getlistwit($textid as xs:string){
let $text := collection($config:tls-texts)//tei:TEI[@xml:id=$textid]
, $lw := $text//tei:listWit
return
  if ($lw) then $lw else 
    let $wl := <listWit xmlns="http://www.tei-c.org/ns/1.0"></listWit> 
    , $uw := update insert $wl into $text//tei:sourceDesc
  return $text//tei:listWit
};