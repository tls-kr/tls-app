xquery version "3.1";

(:~
 : Library module for adding and analyzing tags.
 :
 : @author Christian Wittern
 : @date 2024-11-05
 :)

module namespace ltg="http://hxwd.org/tags";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";


declare function ltg:tag-actions($uid as xs:string){
<span>Action!</span>
};


(:~ Interface element to open the dialog to add tag to element defined with the uid,   :)
declare function ltg:save-tags($uid as xs:string, $map as map(*) ){
<button class="btn btn-badge btn-primary" onclick="show_dialog('add-tag', {{'id': '{$uid}'}})" title="add a tag for this instance">#</button>
};

declare function ltg:show-tags($node as node(), $map as map(*) ){
for $tag in $node//tei:list[@type='tags']/tei:item
return
<span class="badge">#{$tag/text()}</span>
};

declare function ltg:add-tag($uid as xs:string, $map as map(*) ){
<button class="btn btn-badge btn-primary" onclick="show_dialog('add-tag', {{'id': '{$uid}'}})" title="add a tag for this instance">#</button>
};

