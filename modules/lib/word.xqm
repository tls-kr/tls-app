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

import module namespace tlslib="http://hxwd.org/lib" at "../tlslib.xql";
import module namespace bib="http://hxwd.org/biblio" at "../biblio.xql";


declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(: prepare for moving words out of concept  :)
declare function lw:get-words($concept){
 $concept//tei:entry
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
    return tlslib:display-word-rel($word-rel, $char, $map?concept)}
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
    tlslib:display-sense($sw, $sw/@n, false())
    }</ul>
    </div>

};

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
