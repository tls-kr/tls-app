xquery version "3.1";

(:~
 : Library module for functionality of special interest to some users.
 :
 : @author Christian Wittern
 : @date 2024-11-05
 :)

module namespace lsi="http://hxwd.org/special-interest";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
import module namespace tu="http://hxwd.org/utils" at "../tlsutils.xql";
import module namespace lmd="http://hxwd.org/lib/metadata" at "metadata.xqm";

declare namespace os="http://a9.com/-/spec/opensearch/1.1/";

declare variable $lsi:general := 
  map{"moedict" : ("MoeDict", "", "https://www.moedict.tw/#{searchTerms}"),
  "concise" : ("《國語辭典簡編本》", "", "https://dict.concised.moe.edu.tw/search.jsp?md=1&amp;word={searchTerms}&amp;size=-1"),
  "gouyu" : ("《重編國語辭典修訂本》", "", "https://dict.revised.moe.edu.tw/search.jsp?md=1&amp;word={searchTerms}&amp;&amp;size=1000&amp;sound=1")
  };
declare variable $lsi:buddhist := 
  map{
  "dbdextern" : ("Digital Dictionary of Buddhism", "Edited by Charles Muller", "http://www.buddhism-dict.net/cgi-bin/search-ddb4.pl?Terms={searchTerms}")
  , "cbc" : ("CBC Attributions", "The Chinese Buddhist Canonical Attributions project by Michael Radich and Jamie Norrish", "https://dazangthings.nz/cbc/text/?q={searchTerms}")
  , "translations" : ("Bibliography of Translations", "Marcus Bingenheimer", "https://mbingenheimer.net/tools/bibls/transbibl.html#{searchTerms}")
  };
  
(:
also add chise ids-find :: need to separate character only and word type SE.

"https://dict.concised.moe.edu.tw/search.jsp?md=1&amp;word=%E5%A4%A2&amp;size=-1"
:)
declare variable $lsi:label := map{
'buddhdic.xml' : 'DDB',
'cjkvedic.xml' : 'CJKV'
};

declare function lsi:ddb-lookup($word, $map){
for $w in collection($config:tls-data-root||"/external")//orth[. = $word]
let $link := $w/parent::entry/href/text()
, $def := $w/parent::entry/def/text()
, $r := tokenize(base-uri($w), '/')[last()]
return <li><span class="ml-2 badge">{$lsi:label($r)}</span><a target="docs" href="{$link}">{$word}</a>:<span class="ml-2">{$def}</span></li>
};

declare function lsi:parse-opensearch($nodes, $map){
for $node in $nodes
return
typeswitch($node)
case element(os:Url) return ()
case element(os:OpenSearchDescription) return
   for $n in $node/node()
   return lsi:parse-opensearch($n, $map)
default return ()

};