

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare option exist:output-size-limit "10000000";

declare function local:proctei($nodes){
   for $node at $pos in $nodes
   return
   typeswitch($node)
   case element(tls:ann) return
     if ($node/@xml:id) then $node else
    let $uid := 'uuid-'||util:uuid()
    return
     element {QName(namespace-uri($node), local-name($node))} {
     $node/@* , 
     attribute xml:id {$uid},
      local:proctei($node/node())
     }
   case element(*) return 
     element {QName(namespace-uri($node), local-name($node))} {
     $node/@* ,
     local:proctei($node/node())
     }
     
   case text() return  $node
   default return $node
};  


declare function local:add-xml-id($node){
let $uid := 'uuid-'||util:uuid()
, $new := element{ QName(namespace-uri($node), local-name($node)) } {
   $node/@* , 
   attribute xml:id {$uid},
   $node/node()
}

return
    update replace $node with $new
};

<div>{
for $doc in collection('/db/apps/tls-data/notes')//tei:TEI
(:let $id := 'CH1a0907-ann':)
let $id := $doc/@xml:id
(:let $doc := collection('/db/apps/tls-data/notes')//tei:TEI[@xml:id=$id]:)
let $uri := base-uri($doc)

, $s := reverse(tokenize($uri, '/'))
, $col := string-join(reverse(tail($s)), '/') 
, $file := head($s)
, $cnt := count($doc//tls:ann[not(@xml:id)] )
where $cnt > 0
order by $cnt descending
return  
 <li cnt="{$cnt}" uri="{$uri}">
 {
     xmldb:store($col, $file, local:proctei($doc))
 }
     
 </li>   
(:xmldb:store('/db', $file, local:proctei($doc) ) :)
}</div>