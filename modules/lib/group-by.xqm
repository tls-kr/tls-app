xquery version "3.1";
(:~
: This module provides the internal functions that do not directly control the 
: template driven Web presentation
: of the TLS. 

: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace lgrp="http://hxwd.org/lib/group-by";

import module namespace config="http://hxwd.org/config" at "../config.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare function lgrp:seg-text($node as node(), $options as map(*)){
 typeswitch ($node)
  case element(tei:note) return ()
  case element (tei:l) return ()
  case element (tei:c) return data($node/@n)
  case element (tei:g) return $node/text()
  case element (tei:lb)  return ()
  case element (tei:space)  return "　"
  case element (exist:match) return $node/text()
  case element (tei:anchor) return  ()
  case element(tei:seg) return (if (string-length($node/@n) > 0) then data($node/@n)||"　" else (), for $n in $node/node() return lgrp:seg-text($n, $options))
  case attribute(*) return () 
  default return $node    
};

declare function local:proc-ul($node as node(), $map as map(*)){
 typeswitch ($node)
 case element (ul) return 
 element {"ul"}{
   $node/@*,
   for $n in $node/node()
   return
   local:proc-ul($n, $map),
   let $sum := sum(for $c in $node/li[@type="other"] return xs:int($c/text()))
   , $key := data($node/@key)
   , $search-type := if (string-length($map?textid) > 0) then 5 else 1
   return 
   if ($sum > 0 and $sum != xs:int($node/@data-cnt)) then   ()
(:   <li type="other" ><a href="search.html?query={$key}&amp;textid={data($node/@textid)}&amp;search-type={$search-type}&amp;mode=other">other</a></li>:)
   else ()
 }
 case element (li) return
  if ($node/@type = "other") then () else 
    $node
 default return $node()  
};

(:  :)

declare function lgrp:group-collocation($seq as xs:string* , $options as map(*)){
  let $s := $options?key
  , $res :=
  <ul key="{$s}" textid="{$options?textid}" data-cnt="{$options?cnt}">
  {
  for $t at $pos in $seq
  for $a in tail(tokenize($t, $s))
  let $g := substring($a, 1, 1)
  let $key := $s||$g
  group by $key
  let $cnt := count($t)
  order by $cnt descending
  return
  if (($cnt > $options?cutoff and $options?level < $options?max-level and $cnt < $options?cnt) ) then
(:    let $key := $s||$g:)
    let $search-type := if (string-length($options?textid) > 0) then 5 else 1
    return
    <li data-cnt="{$cnt}">|<a href="search.html?query={$key}&amp;textid={$options?textid}&amp;search-type={$search-type}">{$key}</a>|{$cnt}|
    <button title="click to reveal" class="btn badge badge-light" type="button" data-toggle="collapse" data-target="#{$key}--{$options?level}">{$cnt}</button>
    <ul id="{$key}--{$options?level}" class="collapse">
    {lgrp:group-collocation($t, map{"key" : $key, "cutoff" : $options?cutoff, "textid" : $options?textid, "level" : $options?level + 1, "max-level" : $options?max-level, "cnt" : $cnt, "pos" : $pos})}</ul>
    </li>
  else  
  <li type="other" key="{$options?key}">{$cnt}</li>
  }
  </ul>
  return local:proc-ul($res, map{"textid" : $options?textid, "key": $options?key})
};

declare function lgrp:group-collocation-org($seq as xs:string* , $options as map(*)){
  let $s := $options?key
  return
  <ul>
  {
  for $t in $seq
  for $a in tail(tokenize($t, $s))
  let $g := substring($a, 1, 1)
  group by $g
  let $cnt := count($t)
  order by $cnt descending
  return
  if (($cnt > $options?cutoff and $options?level < $options?max-level and $cnt < $options?cnt) ) then
    let $key := $s||$g
    , $search-type := if (string-length($options?textid) > 0) then 5 else 1
    return
    <li>{$cnt}: <a href="search.html?query={$key}&amp;textid={$options?textid}&amp;search-type={$search-type}">{$key}</a>
    {lgrp:group-collocation($t, map{"key" : $key, "cutoff" : $options?cutoff, "textid" : $options?textid, "level" : $options?level + 1, "max-level" : $options?max-level, "cnt" : $cnt})}
    </li>
  else  
  $cnt
  }
  </ul>
};


declare function lgrp:group-collocation-other($seq as xs:string* , $options as map(*)){
  let $s := $options?key
  return
  <ul>
  {
  for $t in $seq
  for $a in tail(tokenize($t, $s))
  let $g := substring($a, 1, 1)
  group by $g
  let $cnt := count($t)
  order by $cnt descending
  return
  if (($cnt > $options?cutoff and $options?level < $options?max-level and $cnt < $options?cnt) ) then
    let $key := $s||$g
    , $search-type := if (string-length($options?textid) > 0) then 5 else 1
    return
    <li>{$cnt}: <a href="search.html?query={$key}&amp;textid={$options?textid}&amp;search-type={$search-type}">{$key}</a>
    {lgrp:group-collocation($t, map{"key" : $key, "cutoff" : $options?cutoff, "textid" : $options?textid, "level" : $options?level + 1, "max-level" : $options?max-level, "cnt" : $cnt})}
    </li>
  else  
  $cnt
  }
  </ul>
};