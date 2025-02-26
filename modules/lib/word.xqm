xquery version "3.1";

(:~
 : Display words.
 :
 : @author Christian Wittern
 : @date 2024-11-27
 :)

module namespace lw="http://hxwd.org/word";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace ltx="http://hxwd.org/taxonomy" at "taxonomy.xqm";
import module namespace wd="http://hxwd.org/wikidata" at "wikidata.xql"; 

(:import module namespace tlslib="http://hxwd.org/lib" at "../tlslib.xql";:)
import module namespace bib="http://hxwd.org/biblio" at "../biblio.xql";


declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(: prepare for moving words out of concept  :)
declare function lw:get-words($concept){
let $entries := collection($config:tls-data-word-root)//tei:entry[@tls:concept-id=$concept/@xml:id]
return $entries
};

declare function lw:get-words-by-concept-id($cid){
let $entries := collection($config:tls-data-word-root)//tei:entry[@tls:concept-id=$cid]
return $entries
};


declare function lw:display-word($e, $map){
let $update := if ($e/@n) then () else lw:update-word-ann-count($e)
let $zi := string-join($e/tei:form/tei:orth, " / ")
 ,$entry-id := $e/@xml:id
 ,$pr := $e/tei:form/tei:pron
 ,$def := $e/tei:def/text()
 ,$resp := tu:get-member-initials($e/@resp)
(: ,$ann := $config:tls-ann:)
 ,$word-rel := doc($config:tls-data-root || "/core/word-relations.xml")//tei:div[@type='word-rel' and .//tei:item[@corresp="#"||$entry-id]]
 return 
    (: tls-div will, together with the defs in style.css allow jumps to land here accurately :)
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
    <span id="{$entry-id}-{$pos}-py" title="Click here to change pinyin" onclick="assign_guangyun_dialog({{'zi':'{$zi}', 'wid':'{$entry-id}','py': '{normalize-space($l/text())}','concept' : '{$map?concept}', 'concept_id' : '{$map?key}', 'pos':'{$pos}'}})">&#160;&#160;{
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

    <small>{"  " || $e/@n} {if ($map?ann = 1) then " Attribution" else " Attributions"}</small>
    {if ($map?ann = 0) then
    lrh:format-button("delete_word_from_concept('"|| $entry-id || "', 'word')", "Delete the word "|| $zi || ", including all syntactic words.", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else 
    (: move :)
    lrh:format-button("move_word('"|| $zi || "', '"|| $entry-id ||"', '"||$map?ann||"', 'word')", "Move the word "|| $zi || ", including all syntactic words to another concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor")
    }
    {if (lpm:show-setting('wd', 'concept')) then wd:display-qitems($entry-id, 'concept', $zi) else ()}
    </h5>
    {if ($def) then <p class="ml-4">{$def[1]}</p> else ()}
    {if ($word-rel) then <p class="ml-4">
    {let $char := $e/tei:form/tei:orth[1]/text()
    return lw:display-word-rel($word-rel, $char, $map?concept)}
    </p> else ()}
    {if ($e//tei:listBibl) then 
         <div><button class="btn" data-toggle="collapse" data-target="#bib-{$entry-id}">Show references</button><ul id="bib-{$entry-id}" class="collapse" data-toggle="collapse">
        {for $d in $e//tei:bibl
        return
        bib:display-bibl($d)
     }</ul></div>  
    else ()} 
    <ul><span class="font-weight-bold">Syntactic words</span>{for $sw in $e/tei:sense
    let $sf := lower-case(($sw//tls:syn-func/text())[1])
    , $sm := lower-case($sw//tls:sem-feat/text())
    order by $sf || $sm
    return
    lw:display-sense($sw, $sw/@n, false())
    }</ul>
    </div>

};

(:~ This is called after adding/deleting an attribution to update the total count accordingly :)
declare function lw:update-sense-id-ann-count($sid, $cnt){
let $s := collection($config:tls-data-word-root)//tei:sense[@xml:id=$sid]
  , $p := $s/parent::tei:entry
return
if ($cnt != 0 and $s/@n) then 
 let $new := xs:int($s/@n) + $cnt
   , $pn := xs:int($p/@n) + $cnt
 return
 (
 update replace $s/@n with $new
 , update replace $p/@n with $pn
 ) 
else 
 lw:update-word-ann-count($p)
};

(:~ 
  Count and update the annotations that use senses this word node and then update the count for the entry
:)

declare function lw:update-word-ann-count($e){
let $c := sum(for $s in $e/tei:sense
              return lw:update-sense-ann-count($s) )
, $update:= lw:do-update($e, $c)
return $c   
};

(:~ 
  Count the annotations that use this sense node and write it into the definition
:)
declare function lw:update-sense-ann-count($s){
let $c := count($config:tls-ann[tei:sense[@corresp="#"||$s/@xml:id]])
, $update:= lw:do-update($s, $c)
return $c
};

declare function lw:do-update($n, $c){
if (lpm:is-testuser()) then () else
 if ($n/@n) then 
   update replace $n/@n with $c
 else
   update insert attribute n {$c} into $n
};

declare function lw:make-super-entry($word){

let $uid := "uuid-" || util:uuid()
, $se :=
    <superEntry xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$uid}" n="1">
    <form>
        <orth>{$word}</orth>
    </form>    
    </superEntry>    
 , $path := tu:uuid-to-path('/db/apps/tls-data/words', $uid)
return xmldb:store($path, $uid || ".xml", $se)

};  

 (:~ 
 : called from function tlsapi:show-use-of($uid as xs:string, $type as xs:string), which is called via XHR from concept.html and char.html through 
 : tls-app.js -> show_use_of(type, uid) 
 : @param $sw the tei:sense to display 
 : 2020-02-26 it seems this belongs to tlsapi
 :)
 
declare function lw:display-sense($sw as node(), $count as xs:int?, $display-word as xs:boolean){
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
    {if ($resp[1]) then 
    <small><span class="ml-2 btn badge-secondary" title="{$resp[1]} - {$sw/@tls:created}">{$resp[2]}</span></small> else ()}
     <button class="btn badge badge-light ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp" onclick="show_att('{$id}')">
          {if ($count > -1) then $count else ()}
          {if (not($count)) then "" else 
          if ($count = 1) then " Attribution" else  " Attributions" }
      </button>
     {if ($user = "guest") then () else 
      if ( not($display-word)) then
     <button title="Search for this word" class="btn badge btn-outline-success ml-2" type="button" 
     data-toggle="collapse" data-target="#{$id}-resp1" onclick="search_and_att('{$id}')">
      <img class="icon-small" src="resources/icons/open-iconic-master/svg/magnifying-glass.svg"/>
      </button> else (),
      if ($count = 0 or not($count)) then
      lrh:format-button("delete_word_from_concept('"|| $id || "')", "Delete the syntactic word "|| $sf || ".", "open-iconic-master/svg/x.svg", "", "", "tls-editor") else 
      if ($count > 0) then (
      (: it seems to me that a move to another concept does not make sense, disabled for now with tls-editor-x // cw 2025-02-26 :)
      lrh:format-button("move_word('"|| $char || "', '"|| $id ||"', '"||$count||"', 'sw')", "Move the SW  '"|| $sf || "' including "|| $count ||" attribution(s) to a different concept.", "open-iconic-master/svg/move.svg", "", "", "tls-editor-x") ,      
      lrh:format-button("merge_word('"|| $sf || "', '"|| $id ||"', '"||$count||"')", "Delete the SW '"|| $sf || "' and merge "|| $count ||"attribution(s) to a different SW.", "open-iconic-master/svg/wrench.svg", "", "", "tls-editor")       
      )
      else ()
      }
      <div id="{$id}-resp" class="collapse container"></div>
      <div id="{$id}-resp1" class="collapse container"></div>
    </li>
 
 };


(: we get a nodeset of wr to display :)
declare function lw:display-word-rel($word-rel, $char, $cname){
<ul><span class="font-weight-bold">Word relations</span>{for $wr in $word-rel 
    let $wrt := $wr/ancestor::tei:div[@type="word-rel-type"]/tei:head/text()
    , $entry-id := substring(($wr//tei:item[. = $char])[1]/@corresp, 2)
    , $wrid := ($wr/tei:div[@type="word-rel-ref"]/@xml:id)[1]
    , $count := count($wr//tei:item[@p="left-word"]/@textline)
    , $oid := substring(($wr//tei:list/tei:item/@corresp[not(. = "#" || $entry-id)])[1], 2)
    , $oword := collection($config:tls-data-word-root)//tei:entry[@xml:id=$oid]
    , $other := string-join($oword/tei:form/tei:orth/text() , " / ")
    , $cid := $oword/@tls:concept-id/string()
    , $concept := $oword/@tls:concept/string()
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

