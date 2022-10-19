xquery version "3.1";

module namespace wd="http://hxwd.org/wikidata"; 

import module namespace http="http://expath.org/ns/http-client";

declare variable $wd:wikidata-api := "https://www.wikidata.org/w/api.php?format=xml&amp;action=query&amp;list=search&amp;srsearch=";


declare function wd:search($q as xs:string){
let $res :=  
            http:send-request(<http:request http-version="1.1" href="{xs:anyURI($wikidata-api||$q)}" method="get">
                                <http:header name="Connection" value="close"/>
                              </http:request>)

return $res[2]

};