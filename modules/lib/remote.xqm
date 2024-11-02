xquery version "3.1";

(:~ Let's see if this works: collection calls to the API here
 :
 : @author Christian Wittern
 : @version 1.0.0
 : @see http://wittern.org
 :)

module namespace remote="http://hxwd.org/remote";
import module namespace config="http://hxwd.org/config" at "../config.xqm";


import module namespace roaster="http://e-editiones.org/roaster";
import module namespace http="http://expath.org/ns/http-client";


(: 
"api/responder.xql?func=get-facs-for-page&location="+location+"&pb="+pbfacs+"&segid="+segid+"&pbed="+pbed+"&slot="+slot+"&left="+new_left+"&width="+new_width+"&height="+new_height, 

:)

declare function remote:get-facs-for-page($map as map(*)){
let $path:= "?pbed="||$map?pbed||"&amp;segid="||$map?segid||"&amp;slot="||$map?slot||"&amp;left="||$map?left||"&amp;width="||$map?width||"&amp;height="||$map?height
, $krp := "https://hxwd.org/krx/facs"
return remote:call-remote-get(map{'server': $krp, 'path': $path})
};


declare function remote:get-segs($map as map(*)){
let $path:= "?location="||$map?location||"&amp;prec="||$map?prec||"&amp;foll="||$map?foll||"&amp;type=skeleton"
, $krp := "https://hxwd.org/krx/preview"
return remote:call-remote-get(map{'server': $krp, 'path': $path})
};

declare function remote:call-remote-get($map as map(*)){
let $res :=  
            http:send-request(<http:request http-version="1.1" href="{xs:anyURI($map?server||$map?path)}" method="get">
                                <http:header name="Connection" value="close"/>
                              </http:request>)                              
return  
if ($res[1]/@status="200") then  $res[2]
(:($res[2] => util:base64-decode() => parse-json() ):)
else
<error>{$res}</error>
};
