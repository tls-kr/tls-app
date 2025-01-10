xquery version "3.1";

(:~
 : Library module for analyzing citations.
 :
 : @author Christian Wittern
 : @date 2024-11-05
 :)

module namespace ltg="http://hxwd.org/tags";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";
import module namespace lrh="http://hxwd.org/lib/render-html" at "render-html.xqm";
import module namespace ltx="http://hxwd.org/taxonomy" at "taxonomy.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "permissions.xqm";

import module namespace src="http://hxwd.org/search" at "../search.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

(:~ 
Called from tag_selected_items(), which is written for example by citations.xqm 
:)
declare function ltg:save-tags($map as map(*)){

};

(:
                <span id="concept-id-span" style="display:none;"></span>
                <div id="select-concept-group" class="form-group ui-widget">
                    <input id="select-concept" class="form-control" required="true" value=""/>
                </div>

    <li><input name="tag-input"></input></li>


:)


declare function ltg:tag-actions($uid){
let $ns := ()
return
<nav aria-label="Tag actions">
  <ul class="pagination">
    <li class="page-item"><a class="page-link" onclick="" href="#">Select all</a></li>
    <li class="page-item"><a class="page-link" onclick="" href="#">Select none</a></li>
    <li class="page-item"><span class="btn">Enter a tag: </span><span id="tag-id-span-{$uid}" style="display:none;"></span></li>
                <div id="tag-input-group" class="form-group ui-widget">
                    <input id="tag-input-{$uid}" class="form-control" required="true" value=""/>
                </div>
    <li class="page-item"> <span class="btn" onclick="tag_selected_items('{$uid}')"> Tag selected items in </span></li>
    <li class="page-item"><select class="form-control input-sm" id="tag-name-space-{$uid}">
      <option selected="true" value="personal">personal namespace</option>
      <option value="global">global namespace</option>
    </select></li>
  </ul>
 
</nav>
};
