xquery version "3.1";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace  cb="http://www.cbeta.org/ns/1.0";

import module namespace config="http://hxwd.org/config" at "/db/apps/tls-app/modules/config.xqm";
import module namespace tlslib="http://hxwd.org/lib" at "/db/apps/tls-app/modules/tlslib.xql";
import module namespace imp="http://hxwd.org/xml-import" at "/db/apps/tls-app/modules/import.xql"; 
import module namespace xed="http://hxwd.org/xml-edit" at "/db/apps/tls-app/modules/xml-edit.xql"; 
import module namespace tlsapi="http://hxwd.org/tlsapi" at "/db/apps/tls-app/api/tlsapi.xql";
import module namespace txc="http://hxwd.org/text-crit" at "/db/apps/tls-app/modules/text-crit.xql";
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "/db/apps/tls-app/modules/db-utility.xqm";
import module namespace log="http://hxwd.org/log" at "/db/apps/tls-app/modules/log.xql";

let $cbid:= "ZW07n0064d"
, $pid := "pT08p0146a0705"
, $node := collection("/db/apps/tls-texts/tmp")//tei:p[@xml:id=$pid]

for $cbid in collection("/db/apps/tls-texts/tmp/xml")//tei:TEI/@xml:id
order by $cbid
return
    if (collection("/db/apps/tls-texts/data")//tei:TEI[@xml:id=$cbid]) then () 
    else
    (    
    try {imp:do-cbeta-conversion($cbid)}
    catch * {log:info($imp:log, "Error in " || $cbid)}
)
    

(:data($node/preceding::cb:juan[last()]/@n):)