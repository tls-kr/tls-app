xquery version "3.1";
module namespace tlslib="http://hxwd.org/lib";

import module namespace config="http://hxwd.org/config" at "config.xqm";

import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "/db/apps/tei-publisher/modules/lib/util.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare function tlslib:expath-descriptor() as element() {
    <rl/>
};

(: display $prec and $foll preceding and following segments of a given seg :)

declare function tlslib:displayseg($targetseg as node(), $prec as xs:int?, $foll as xs:int?){

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
      <p>{$dseg}</p>,
      <span><br/>
      {if ($dseg[1]/preceding::tei:seg[1]/@xml:id) then  
       <a href="?location={$dseg[1]/preceding::tei:seg[1]/@xml:id}&amp;prec={$foll}&amp;foll={$prec}">Previous</a>
       else if ($dseg[last()]/following::tei:seg[1]/@xml:id) then
      <a href="?location={$dseg[last()]/following::tei:seg[1]/@xml:id}&amp;prec={$prec}&amp;foll={$foll}">Next</a>
       else ()}
      </span>
      )

};
