xquery version "3.1";
module namespace tlslib="http://hxwd.org/lib";

import module namespace config="http://hxwd.org/config" at "config.xqm";

import module namespace app="http://hxwd.org/app" at "app.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function tlslib:expath-descriptor() as element() {
    <rl/>
};

(: helper functions :)
declare function tlslib:iskanji($string as xs:string) as xs:boolean {
let $kanji := '&#x3400;-&#x4DFF;&#x4e00;-&#x9FFF;&#xF900;-&#xFAFF;&#xFE30;-&#xFE4F;&#x00020000;-&#x0002A6DF;&#x0002A700;-&#x0002B73F;&#x0002B740;-&#x0002B81F;&#x0002B820;-&#x0002F7FF;',
$pua := '&#xE000;-&#xF8FF;&#x000F0000;-&#x000FFFFD;&#x00100000;-&#x0010FFFD;'
return 
matches(replace($string, '\s', ''), concat("^[", $kanji, $pua, "]+$" ))
};

declare function tlslib:is-first-in-p($seg as node()){
    $seg/@xml:id = $seg/parent::tei:p/tei:seg[1]/@xml:id    
};

declare function tlslib:is-first-in-div($seg as node()){
    $seg/@xml:id = $seg/ancestor::tei:div/tei:p[1]/tei:seg[1]/@xml:id    
};


declare function tlslib:tv-header($node as node()*, $model as map(*)){
    let $location := request:get-parameter("location", "xx")
    ,$targetseg := 
     if (string-length($location) > 0) then
     if (contains($location, '_')) then
      let $textid := tokenize($location, '_')[1]
      return
      collection($config:tls-texts-root)//tei:*[@xml:id=$location]
     else
      let $firstdiv := (collection($config:tls-texts-root)//tei:*[@xml:id=$location]//tei:body/tei:div[1])
      return
      if ($firstdiv//tei:seg) then ($firstdiv//tei:seg)[1] else $firstdiv/following::tei:seg[1]
    else ()
    
    let $head := if ($targetseg) then $targetseg/ancestor::tei:div[1]/tei:head[1] else (),
    $title := if ($targetseg) then $targetseg/ancestor::tei:TEI//tei:titleStmt/tei:title/text() else "No title"
    return
      (
      <span class="navbar-text ml-2 font-weight-bold">{$title} <small class="ml-2">{$head/text()}</small></span> 
      ,<li class="nav-item dropdown">
       <a id="navbar-mulu" role="button" data-toggle="dropdown" href="#" class="nav-link dropdown-toggle">目錄</a> 
       <div class="dropdown-menu">
       {tlslib:generate-toc($targetseg/ancestor::tei:body)}
       </div>
      </li>
      ,<button title="Show SWL" class="btn btn-primary ml-2" type="button" data-toggle="collapse" data-target=".swl">
            
     <img class="icon" src="resources/icons/open-iconic-master/svg/eye.svg"/>

      </button>
      
      )
};

declare function tlslib:generate-toc($node){
 if ($node/tei:head) then
  let $locseg := if ($node//tei:seg/@xml:id) then ($node//tei:seg/@xml:id)[1] else $node/following::tei:seg[1]/@xml:id
  return 
    <a class="dropdown-item" title="{$locseg}" href="textview.html?location={$locseg}&amp;prec=0&amp;foll=30">{$node/tei:head/text()}</a>
  else (),
 for $d in $node/child::tei:div
 return tlslib:generate-toc($d)
};

(: display $prec and $foll preceding and following segments of a given seg :)

declare function tlslib:displaychunk($targetseg as node(), $prec as xs:int?, $foll as xs:int?){

      let $fseg := if ($foll > 0) then $targetseg/following::tei:seg[fn:position() < $foll] 
        else (),
      $pseg := if ($prec > 0) then $targetseg/preceding::tei:seg[fn:position() < $prec] 
        else (),
      $head := $targetseg/ancestor::tei:div[1]/tei:head[1],
      $title := $targetseg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
      $dseg := ($pseg, $targetseg, $fseg)
      return
      (
      <div id="chunkrow" class="row">
      <div id="chunkcol-left" class="col-sm-8">{for $d in $dseg return tlslib:displayseg($d, map{'loc' : data($targetseg/@xml:id) })}</div>
      <div id="chunkcol-right" class="col-sm-4">
      {app:swl-form-dialog($targetseg, map{})}
    </div>
    </div>,
      <div class="row">
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
      </div>
      )

};
(:
<span class="en">{collection($config:tls-texts-root)//tei:seg[@corresp=concat('#', $seg/@xml:id)]/text()}</span>

:)

declare function tlslib:format-swl($node as node(), $type as xs:string?){
let $concept := data($node/@concept),
$zi := $node/tei:form[1]/tei:orth[1]/text(),
$py := $node/tei:form[1]/tei:pron[starts-with(@xml:lang, 'zh-Latn')][1]/text(),
$sf := $node//tls:syn-func,
$sm := $node//tls:sem-feat,
$def := $node//tei:def[1]
(:$pos := concat($sf, if ($sm) then (" ", $sm) else "")
:)
return
if ($type = "row") then
<div class="row bg-light ">
<div class="col-sm-1">&#160;</div>
<div class="col-sm-2"><span class="zh">{$zi}</span> ({$py})</div>
<div class="col-sm-3"><a href="concept.html?concept={$concept}">{$concept}</a></div>
<div class="col-sm-6">
<span><a href="browse.html?type=syn-func&amp;id={data($sf/@corresp)}">{$sf/text()}</a>&#160;</span>
{if ($sm) then 
<span><a href="browse.html?type=sem-feat&amp;id={$sm/@corresp}">{$sm/text()}</a>&#160;</span> else ()}
{$def/text()}
{if (sm:has-access(document-uri(fn:root($node)), "w") and $node/@xml:id) then 
<div style="height:13px;position:absolute; top:0; right:0;">
 <!-- for the time being removing the button, don't really now what I want to edit here:-)
 <button type="button" class="btn" onclick="edit_swl('{$node/@xml:id}')" style="width:10px;height:20px;" 
 title="Edit Attribution">
 <img class="icon" onclick="edit_swl('{$node/@xml:id}')" style="width:10px;height:13px;top:0;align:top" src="resources/icons/open-iconic-master/svg/pencil.svg"/>
 </button> 
 -->
 <button type="button" class="btn" onclick="delete_swl('{$node/@xml:id}')" style="width:10px;height:20px;" 
 title="Delete Attribution">
 <img class="icon" onclick="delete_swl('{$node/@xml:id}')" style="width:10px;height:13px;top:0;align:top" src="resources/icons/open-iconic-master/svg/x.svg"/>
 </button>
 
 
</div>
else ()
}
</div>
</div>
else 
<li class="list-group-item" id="{$concept}">{$py} {$concept} {$sf} {$sm} {
if (string-length($def) > 10) then concat(substring($def, 10), "...") else $def}</li>
};


declare function tlslib:displayseg($seg as node()*, $options as map(*) ){
let $link := concat('#', $seg/@xml:id),
$ann := lower-case(map:get($options, "ann")),
$loc := map:get($options, "loc"),
$mark := if (data($seg/@xml:id) = $loc) then "mark" else ()
return
(
if (tlslib:is-first-in-p($seg)) then
 if (tlslib:is-first-in-div($seg)) then 
  let $hx := $seg/ancestor::tei:div[1]/tei:head/text()
  return
 <div class="row"><!-- head! -->
 <div class="col-sm-12"><h5>{$hx}　　　</h5></div>
 </div>
 else
 <div class="row">
 <!-- p --> 
 <div class="col-sm-12 my-6">　　　</div>
 </div> 
 else
 (),
if (string-length(string-join($seg/text(), "")) > 0) then
(<div class="row {$mark}">
<div class="col-sm-4 zh" id="{$seg/@xml:id}">{$seg/text()}</div>　
<div class="col-sm-7 tr" id="{$seg/@xml:id}-tr" 
contenteditable="{if (sm:has-access(xs:anyURI($config:tls-translation-root), "r")) then 'true' else 'false'}">
{  (: if there is more than one translation, we take the one with the shorter path (outrageous hack) :)
   let $tr:= for $t in collection($config:tls-data-root)//tei:seg[@corresp=$link]
             let $p := string-length(document-uri(root($t)))
             order by $p ascending
             return $t
 return $tr[1]
}</div>
</div>,
<div class="row swl collapse" data-toggle="collapse">
<div class="col-sm-12" id="{$seg/@xml:id}-swl">
{if ($ann = "false") then () else 
for $swl in collection($config:tls-data-root|| "/notes")//tls:srcline[@target=$link]
let $pos := if (string-length($swl/@pos) > 0) then xs:int($swl/@pos) else 0
order by $pos
return
tlslib:format-swl($swl/ancestor::tls:ann, "row")}
</div>
</div>
) else ()
)
};


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

declare function tlslib:getwords($word as xs:string, $map as map(*))
{
map:merge(
   for $s in collection(concat($config:tls-data-root, '/concepts/'))//tei:orth[. = $word]
   return 
   map:entry(string($s/ancestor::tei:entry/@xml:id), (string($s/ancestor::tei:div/@xml:id), string($s/ancestor::tei:div/tei:head)))
 )
};


declare function tlslib:capitalize-first ( $arg as xs:string? )  as xs:string? {
   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
 } ;
 
 
 declare function tlslib:display_sense($sw as node()){
    let $id := data($sw/@xml:id),
    $sf := $sw//tls:syn-func/text(),
    $sm := $sw//tls:sem-feat/text(),
    $def := $sw//tei:def/text()
    return
    <li><span class="font-weight-bold">{$sf}</span>
    <em class="ml-2">{$sm}</em> 
    <span class="ml-2">{$def}</span>
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp" onclick="show_att('{$id}')">
           Attributions
      </button>
     <button title="Search for this word" class="btn badge btn-outline-success ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp" onclick="search_and_att('{$id}')">
      <img class="icon-small" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
      </button>
      <div id="{$id}-resp" class="collapse container"></div>
    </li>
 
 };