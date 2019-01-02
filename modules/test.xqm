module namespace test="http://tls.kanripo.org/test";


import module namespace config="http://tls.kanripo.org/config" at "/db/apps/myapp1/modules/config.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://tls.kanripo.org/ns/1.0";

declare function local:tls-summary() as element()* {
let $tlsroot := $config:tls-data-root
return
<table>
{for $a in collection($tlsroot)//tei:head
group by $key := $a/ancestor::tei:div/@type
order by $key
return
  <tr>
  <td>{$key}</td>
  <td>{count($a)}</td>
</tr>
}
</table>};
