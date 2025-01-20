xquery version "3.1";

(:~
 : Library module for exporting to external formats
 :
 : @author Christian Wittern
 : @date 2024-01-09
 :)

module namespace lxp="http://hxwd.org/lib/export";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";

import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace ltr="http://hxwd.org/lib/translation" at "translation.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "../db-utility.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function lxp:process-segs($map){
 let $segs := lu:get-seg-sequence-by-id($map?start-seg-id, $map?end-seg-id)
 return
 (
 for $seg in $segs
 let $s := string-join(lrh:proc-seg($seg, map{'punc' : 'yes'}) ) => normalize-space()
 , $t := ltr:get-translation-seg-by-id($map?trans-id , $seg/@xml:id)[1]
 return $map?format-function($s, $t, map{}) 
 , "&#10;[[https://hxwd.org/textview.html?location=" || $map?start-seg-id || "][" || lmd:get-metadata($segs[1], "title") || "/" || lmd:get-metadata($segs[1], "head") || "]]"
 , "" || ltr:translation-cit-from-id($map?trans-id)
 , "&#10;"
 , "&#10;"
 )
};

declare function lxp:process-all-segs($map){
 let $segs := lu:get-seg-sequence-by-id($map?start-seg-id, $map?end-seg-id)
 , $textid := tokenize($map?start-seg-id, "_")[1]
 , $tr := for $t in ltr:find-translators($textid) return $t/ancestor::tei:TEI
 return
 (
 for $seg in $segs
 let $s := string-join(lrh:proc-seg($seg, map{'punc' : 'yes'}) ) => normalize-space()
 , $sid := $seg/@xml:id
 , $trs := for $ts in $tr//tei:seg[@corresp="#"||$sid]
          let $trid := lmd:get-metadata($ts, "textid")
          , $date := lmd:get-metadata($ts, "date")[1]
          order by $date
          return $ts

 return $map?format-function($s, $trs, map{}) 
 , "&#10;[[https://hxwd.org/textview.html?location=" || $map?start-seg-id || "][" || lmd:get-metadata($segs[1], "title") || "/" || lmd:get-metadata($segs[1], "head") || "]]"
 , "" || ltr:translation-cit-from-id($map?trans-id)
 , "&#10;"
 , "&#10;"
 )
};

