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
 let $s := lrh:proc-seg($seg, map{})
 , $t := ltr:get-translation-seg-by-id($map?trans-id , $seg/@xml:id)
 return $map?format-function($s, $t, map{}) 
 , "&#10;" || ltr:translation-cit-from-id($map?trans-id)
 )
};

