xquery version "3.1";
module namespace tlslib="http://hxwd.org/lib";

import module namespace config="http://hxwd.org/config" at "config.xqm";

import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "/db/apps/tei-publisher/modules/lib/util.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare function tlslib:expath-descriptor() as element() {
    <rl/>
};

(: display $prec and $foll preceding and following segments of a given seg :)

declare function tlslib:displaychunk($targetseg as node(), $prec as xs:int?, $foll as xs:int?){

      let $fseg := if ($foll > 0) then subsequence($targetseg/following::tei:seg, 1, $foll) 
        else (),
      $pseg := if ($prec > 0) then subsequence($targetseg/preceding::tei:seg, 1, $prec) 
        else (),
      $head := $targetseg/ancestor::tei:div[1]/tei:head[1],
      $title := $targetseg/ancestor::tei:TEI//tei:titleStmt/tei:title/text(),
      $dseg := ($pseg, $targetseg, $fseg)
      return
      (
      <h1>{$title}</h1>,
      <h2>{$head/text()}</h2>,
      <p>Debug: {$prec, $foll}</p>,
      <p>{for $d in $dseg return tlslib:displayseg($d, map{})}</p>,
      <span><br/>
      {if ($dseg[1]/preceding::tei:seg[1]/@xml:id) then  
      (: currently the 0 is hardcoded -- do we need to make this customizable? :)
       <a href="?location={$dseg[1]/preceding::tei:seg[1]/@xml:id}&amp;prec={$foll+$prec}&amp;foll=0">Previous</a>
       else ()}
       　
       {
       if ($dseg[last()]/following::tei:seg[1]/@xml:id) then
      <a href="?location={$dseg[last()]/following::tei:seg[1]/@xml:id}&amp;prec=0&amp;foll={$foll+$prec}">Next</a>
       else ()}
      </span>
      )

};
(:
<span class="en">{collection($config:tls-texts-root)//tei:seg[@corresp=concat('#', $seg/@xml:id)]/text()}</span>

:)
declare function tlslib:displayseg($seg as node()*, $options as map(*) ){
<span>
<span class="zh">{$seg/text()}</span>　
<span class="en">{collection($config:tls-data-root)//tei:seg[@corresp=concat('#', $seg/@xml:id)]/text()}</span>

<br/>
</span>
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