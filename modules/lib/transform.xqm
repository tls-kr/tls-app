xquery version "3.1";

module namespace tr="http://hxwd.org/lib/transform";

declare function tr:transform($nodes, $map){
 for $node in $nodes
 return
 typeswitch ($node)
  case element(*) return
   let $name := local-name($node)
   return
   if ($name = map:keys($map)) then 
    $map?($name)()
   else
    element {QName(namespace-uri($node), local-name($node))} 
    {$node/@* 
    , tr:transform($node/node(), $map)   
    }
  case attribute(*) return
   let $name := local-name($node)
   return
   if ('@'||$name = map:keys($map)) then 
    $map?('@'||$name)()
   else
    $node  
  case text() return
   if ('text' = map:keys($map)) then 
    $map?text()
   else
    $node
  default return $node    

};