xquery version "3.1";

module namespace ltp="http://hxwd.org/lib/template";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";

declare function ltp:process-ltp($node, $map){
  for $n in $node
  return
  typeswitch($n)
  case element(ltp:editor)|element(ltp:title)|element(ltp:year)|element(ltp:lang)|element(ltp:creation)
  |element(ltp:prompt) return 
    let $name := local-name($n)
    return $map?($name)
  case attribute(*) return 
    if (contains($n, 'ltp--')) then 
     let $v := tokenize($n, 'ltp--')
     , $pf := if(count($v) = 2) then $v[1] else ()
    return 
    attribute {name($n)} {$pf||$map?($v[last()])}  
    else $n
  case element(*) return
   element {QName(namespace-uri($n), local-name($n))} 
   { ltp:process-ltp($n/@*, $map) 
    ,ltp:process-ltp($n/node(), $map)   
    }
  default return $n
};

(: sample map

let $map:= {
  'title' : 'Dummy'
  ,'editor' : 'DeepSeek'
  ,'year' : '2025'
  ,'lang' : 'English' 
  ,'tr-id' : 'CHxx-en-dd'
  ,'textid' : 'CH7x2046'
  ,'lang-code' : 'en'
  ,'bot' : 'bot'
  ,'creation' : <creation resp="#chris">Initially created: <date>2025-11-11T05:54:04.251Z</date> by chris
            <code lang="sytem-prompt" resp="openai"></code>
            <code lang="user-prompt" resp="openai"></code></creation>
}



:)