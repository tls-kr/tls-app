xquery version "3.1";

(:~
 : Library module for rendering html fragments
 :
 : @author Christian Wittern
 : @date 2023-10-24
 :)

module namespace lrh="http://hxwd.org/lib/render-html";

import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";


import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";
import module namespace lus="http://hxwd.org/lib/user-settings" at "user-settings.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace mf="http://kanripo.org/ns/KRX/Manifest/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function lrh:display-row($map as map(*)){
  <div class="row">
    <div class="col-sm-1">{$map?col1}</div>
    <div class="col-sm-4" title="{$map?col2-tit}"><span class="font-weight-bold float-right">{$map?col2}</span></div>
    <div class="col-sm-7" title="{$map?col3-tit}"><span class="sm">{$map?col3}</span></div>　
  </div>  
};


declare function lrh:get-content-id($textid as xs:string, $slot as xs:string, $tr as map(*)){
   let $show-transl := not(contains(sm:id()//sm:group/text(), "guest")),
   $slot-no := xs:int(substring-after($slot, 'slot')) - 1,
   $usergroups := sm:id()//sm:group/text(),   
   $select := for $t in map:keys($tr)
        let $lic := $tr($t)[4]
        where if ($show-transl) then $lic < 5 else $lic < 3
        (: TODO in the future, maybe also consider the language :)
        order by $lic ascending
        return $t,
   $content-id := if (("tls-test", "guest") = $usergroups) then 
     lu:session-att($textid || "-" || $slot, $select[1 + $slot-no]) else
        let $t1 := lus:get-settings()//tls:section[@type='slot-config']/tls:item[@textid=$textid and @slot=$slot]/@content
        return
        if ($t1) then data($t1)
        else if (count($select) > $slot-no) then $select[1 + $slot-no] else "new-content"
  return if (string-length($content-id) > 0) then $content-id else "new-content"
};

