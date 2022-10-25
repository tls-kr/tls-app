xquery version "3.1";

module namespace wd="http://hxwd.org/wikidata"; 

import module namespace http="http://expath.org/ns/http-client";

declare variable $wd:wikidata-api := "https://www.wikidata.org/w/api.php?format=xml&amp;action=query&amp;list=search&amp;srlimit=100&amp;srprop=titlesnippet%7Csnippet&amp;uselang=zh&amp;srsearch=";


declare function wd:search($q as xs:string){
let $res :=  
            http:send-request(<http:request http-version="1.1" href="{xs:anyURI($wd:wikidata-api||$q)}" method="get">
                                <http:header name="Connection" value="close"/>
                              </http:request>)
, $s := <api batchcomplete="">
    <query>
        <searchinfo totalhits="2"/>
        <search>
            <p ns="0" title="Q704075" pageid="662383" snippet="Chinese scholar and philologist (1623-1716)" titlesnippet="&lt;span class=&#34;searchmatch&#34;&gt;毛&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;奇&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;龄&lt;/span&gt;"/>
            <p ns="0" title="Q59205807" pageid="59112037" snippet="" titlesnippet="行香子·即事 (&lt;span class=&#34;searchmatch&#34;&gt;毛&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;奇&lt;/span&gt;&lt;span class=&#34;searchmatch&#34;&gt;齡&lt;/span&gt;)"/>
        </search>
    </query>
</api>
return
(: , $r := parse-xml("<r>"||data($c/@titlesnippet)||"</r>")  :)
<div>
<h3>Searched Wikidata for {$q}, found {data($res[2]//searchinfo/@totalhits)} hits</h3>
<p class="text-muted">Showing up to 100 results here. <a style="background-color:paleturquoise" target="dict" title="Search for {$q} on WikiData (External link)" href="https://www.wikidata.org/w/index.php?search={$q}&amp;title=Special%3ASearch&amp;ns0=1&amp;ns120=1">See all</a></p>
<ul>{
for $c in $res[2]//p
   let $ts := parse-xml("<span>" || $c/@titlesnippet || "</span>")
   , $t := data($c/@snippet)
   return <li><a target="dict" title="Open page in WikiData (External link)" style="background-color:paleturquoise" href="https://www.wikidata.org/wiki/{$c/@title}">{data($c/@title)}</a> / <span class="text-muted">{$t}</span> {$ts}</li>
}</ul>
</div>
};

