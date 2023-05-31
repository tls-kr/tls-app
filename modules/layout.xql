xquery version "3.1";
(:~
: This module provides the layout in the bootstrap grid used by the web version
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace ly="http://hxwd.org/layout";

import module namespace config="http://hxwd.org/config" at "config.xqm";

import module namespace krx="http://hxwd.org/krx-utils" at "krx-utils.xql";
import module namespace wd="http://hxwd.org/wikidata" at "wikidata.xql"; 
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace log="http://hxwd.org/log" at "log.xql";
import module namespace tu="http://hxwd.org/utils" at "tlsutils.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tx="http://exist-db.org/tls";

declare variable $ly:log := $config:tls-log-collection || "/app";


(: Set up the grid with the required number of columns requested in
$map?slots 
the grid will be attached to the #content div with class container-fluid
:)

declare function ly:setup-grid($map as map(*)){
(: we only allow between two and six slots :)
  let $message := (for $k in map:keys($map) return $k) => string-join(",")
    , $l := log:info($ly:log, "Entering ly:setup-grid; $map keys: " || $message)

 let $slots := if ($map?slots) then
       let $s := xs:int($map?slots)
       return
       if ($s < 2) then
        2
       else 
       if ($s < 7 ) 
        then xs:int($map?slots)
        else 6
       else 3
 , $slot-map := ly:get-slot-map($slots, $map)
 , $context := tu:html-file()
 , $targetseg := $map?targetseg 
 , $prec := if ($map?prec) then xs:int($map?prec) else 2
 , $foll := if ($map?foll) then xs:int($map?foll) else 28
 , $fseg := if ($foll > 0) then $targetseg/following::tei:seg[fn:position() < $foll]  else ()
 , $pseg := if ($prec > 0) then $targetseg/preceding::tei:seg[fn:position() < $prec]  else ()
 , $dseg := ($pseg, $targetseg, $fseg)
 return
(: this contains the text parts of the page and the header :)
 (<div id="chunkrow" class="row">
  <div id="srcref" class="col-sm-12 collapse" data-toggle="collapse">
   {tlslib:textinfo($map?textid)}
  </div>
  <div id="toprow" class="col-sm-12">
  </div>
  <div id="chunkcol-left" class="col-sm-12">  
 {ly:slot-menu($slot-map),
  ly:fill-slots($dseg, map:merge(map:entry("slot-map", $slot-map)))
 }
 </div>
 <!-- end of chunkcol-left -->
 <div id="chunkcol-right" class="col-sm-0">
  {tlslib:swl-form-dialog($context, $map)}
 </div>
 </div>
(: ,
 <div id="lv-bottom" class="row">
 {ly:page-nav($dseg, $map)}
, {wd:quick-search-form('title')}
 </div>:)
 )
 
};

declare function ly:slot-menu($slot-map as map(*)){
<div class="row">
{for $slot in map:keys($slot-map)
  return
<div class="{$slot-map($slot)?col-class}" id="menu--{$slot}">
<div class="btn-toolbar mb-3 justify-content-end" role="toolbar" aria-label="Toolbar with button groups">
  {if ($slot = "lv-slot-1") then () else
  <div class="btn-group btn-group-sm" role="group">
    <button type="button" class="btn btn-secondary dropdown-toggle" data-toggle="dropdown" aria-expanded="false">
      Dropdown
    </button>
    <div class="dropdown-menu">
      <a class="dropdown-item" href="#">Dropdown link</a>
      <a class="dropdown-item" href="#">Dropdown link</a>
    </div>
  </div> }
  <div class="btn-group mr-2  btn-group-sm" role="group" aria-label="First group">
    <button type="button" class="btn btn-secondary">1</button>
    <button type="button" class="btn btn-secondary">2</button>
    <button type="button" class="btn btn-secondary">3</button>
    <button type="button" class="btn btn-secondary">4</button>
  </div>
  <!--
  <div class="input-group">
    <div class="input-group-prepend">
      <div class="input-group-text" id="btnGroupAddon">@</div>
    </div>
    <input type="text" class="form-control" placeholder="Input group example" aria-label="Input group example" aria-describedby="btnGroupAddon"/>
  </div> -->
</div>
</div>
}
</div>
};


 (: find the setup for this text :) 
declare function ly:get-slot-map($slots as xs:int, $map as map(*)){
(: TODO :)
let $col-class := "col-sm-" || 12 idiv $slots
return
map:merge(for $i in 1 to $slots
  let $slot-id := "lv-slot-" || $i
  , $type := if ($i = 2) then "facsimile" else "translation"
  return
  map:entry($slot-id, map{"type" : $type, "col-class" : $col-class})
)
};

declare function ly:fill-slots($dseg, $map as map(*)){
<div class="row">
{for $d in $dseg return
for $slot in map:keys($map?slot-map)
 return 
 if ($slot = "lv-slot-1") then
  <div class="{$map?slot-map($slot)?col-class} zho" id="{$d/@xml:id}--{$slot}">{$d}</div>
 else
  if ($map?slot-map($slot)?type = "translation") then
  <div class="{$map?slot-map($slot)?col-class}" id="{$d/@xml:id}--{$slot}">{data($d/@xml:id)}--{$slot}</div>
  else 
  <div class="{$map?slot-map($slot)?col-class}" id="{$d/@xml:id}--{$slot}"/>
}
</div>
};
(: fills the slot of $slot-id with the desired content / stub :)

declare function ly:fill-slot($dseg, $map as map(*)){
 if ($map?slot-id = "lv-slot-1") then ly:line-view($dseg, $map) 
 else switch ($map?type)
  case "translation" return ly:translation-slot($dseg, $map)
  case "facsimile"  return ly:facsimile-slot($dseg, $map)
  case "canvas"  return ly:canvas-slot($map)
  default return ()
};

declare function ly:line-view($dseg, $map as map(*)){
for $d at $pos in $dseg 
   let $s-id := $d/@xml:id || "--" || $map?slot-id
   return
   (<div class="row" id="{$s-id}">{$d/text()}</div>
    , <div class="row" data-toggle="collapse">
        <div class="col-sm-10 swlid" id="{$s-id}-swl">{$s-id}-swl</div>
      <div class="col-sm-2"></div>
    </div>)
    
};

declare function ly:translation-slot($dseg, $map as map(*)){
for $d at $pos in $dseg 
   let $s-id := $d/@xml:id || "--" || $map?slot-id
   return
   <div class="row" id="{$s-id}">{$s-id}</div>

};

declare function ly:facsimile-slot($dseg, $map as map(*)){
};

declare function ly:canvas-slot($map as map(*)){
};

declare function ly:page-nav($dseg, $map as map(*)){
let $prec := if ($map?prec) then xs:int($map?prec) else 2
 , $foll := if ($map?foll) then xs:int($map?foll) else 28
return
(
      <div class="col-sm-2">
      {if ($dseg) then  
       <button type="button" class="btn" onclick="page_move('{tokenize($dseg/@xml:id, "_")[1]}&amp;first=true')" title="Go to the first page"><span style="color: blue">First</span></button>
       else ()}
       </div>
,      <div class="col-sm-2">
      {if ($dseg[1]/preceding::tei:seg[1]/@xml:id) then  
       <button type="button" class="btn" onclick="page_move('{$dseg[1]/preceding::tei:seg[1]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=2')" title="Go to the previous page"><span style="color: blue">Previous</span></button>
       else ()}
       </div>
,       <div class="col-sm-2">
       {
       if ($dseg[last()]/following::tei:seg[1]/@xml:id) then
       <button type="button" class="btn" onclick="page_move('{$dseg[last()]/following::tei:seg[1]/@xml:id}&amp;prec=2&amp;foll={$foll+$prec -2}')" title="Go to the next page"><span style="color: blue">Next</span></button>
       else ()}
       </div> 
,       <div class="col-sm-2">
       {
       if ($dseg/following::tei:seg[last()]/@xml:id) then
       <button type="button" class="btn" onclick="page_move('{$dseg/following::tei:seg[last()]/@xml:id}&amp;prec={$foll+$prec -2}&amp;foll=0')" title="Go to the last page"><span style="color: blue">Last</span></button>
       else ()}
       </div> 
)
};

declare function ly:chunkcol-right(){
};