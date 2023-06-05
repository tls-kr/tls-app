xquery version "3.1";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace  cb="http://www.cbeta.org/ns/1.0";

import module namespace config="http://hxwd.org/config" at "/db/apps/tls-app/modules/config.xqm";
import module namespace tlslib="http://hxwd.org/lib" at "/db/apps/tls-app/modules/tlslib.xql";
import module namespace imp="http://hxwd.org/xml-import" at "/db/apps/tls-app/modules/import.xql"; 
import module namespace xed="http://hxwd.org/xml-edit" at "/db/apps/tls-app/modules/xml-edit.xql"; 
import module namespace dbu="http://exist-db.org/xquery/utility/db" at "/db/apps/tls-app/modules/db-utility.xqm";
import module namespace log="http://hxwd.org/log" at "/db/apps/tls-app/modules/log.xql";

declare variable $local:perm := map{"owner" : "tls", "group":"tls-user", "mode":"rwxrwxr--"};
declare variable $local:log := $config:tls-log-collection || "/convert";


declare function local:teiheader($map as map(*)){
   <teiHeader xmlns="http://www.tei-c.org/ns/1.0">
      <fileDesc>
         <titleStmt>
            <title>{$map?title}</title>
         </titleStmt>
         <editionStmt>
            <edition>
               <idno type="kanripo">{$map?krid}</idno>
            </edition>
         </editionStmt>
         <extent>
         </extent>
         <publicationStmt>
            <p>Published electronically</p>
         </publicationStmt>
         <sourceDesc>
            <p>{$map?byline}</p>
         </sourceDesc>
      </fileDesc>
      <profileDesc>
         <textClass>
            <catRef scheme="#kr-categories" target="#{$map?cat}"/>
         </textClass>
         <creation>
         </creation>
      </profileDesc>
      <encodingDesc>
         <variantEncoding location="external" method="double-end-point"/>
      </encodingDesc>
   </teiHeader>
};

declare function local:page($f, $map){
    let $pid := $map?krid||"_tls_p"||$map?pid
    return
        for $g in $f//*[local-name()='region']
        return
        if ($g/@type='vtext') then
         for $r at $pos in $g//*[local-name()="row"] 
         let $hd := if ($r/mark/@type='title.start') then "head" else "root"
         , $lb := <lb xmlns="http://www.tei-c.org/ns/1.0" n="{$pos}" ed="KX" />
         , $row := local:proc-row($r/node())
         return 
        if (string-length(string-join($row, '')) > 0) then 
         if ($hd = 'head') then
            <seg xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$pid}.s{$pos}" state="locked" type="{$hd}">{$lb}{$row}</seg>
         else
         <seg  xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$pid}.s{$pos}" state="locked">{$lb}{$row}</seg>
        else 
            if ($row//@quantity) then (
(:                log:info($local:log,  $row//@quantity):)
()
                ,
                <pb xmlns="http://www.tei-c.org/ns/1.0" ed="KX" n="{$map?id}.{$map?uri}" xml:id="{$map?krid}_tls_{$map?uri}b"/>
            )
            else ()
        else if ($g/@type="image2") then 
(:            let $cp := local:cp-res($g/@src, $map?krid, $map?id):)
(:            return:)
            <figure>
                <graphic facs="{$map?krid}/{$g/@src}.png" type="inline" />
             </figure>
        else <problem>Unknown region type {data($g/@type)}</problem>
    (: $f :) 
    
};

declare function local:cp-res($name, $krid, $id){
    let $dzp := "/db/apps/tls-texts/incoming/20230209/"    
    let $target-coll := dbu:ensure-collection($config:tls-texts-img || "/" || $krid , $local:perm)
    , $src-coll := $dzp || $id
    , $res := xmldb:copy-resource($src-coll, $name, $target-coll, $name || ".jpg")
    , $acl := dbu:set-permissions( $res , $local:perm)
    return $res
};

declare function local:proc-row($nodes){
    for $node in $nodes
    return
    typeswitch ($node)
    case element(mark) return
        switch ($node/@type)
         case "small.start" return "("
         case "small.end" return ")"
         case "sbr" return "/"
        default return ()
    case text() return 
      let $as := analyze-string($node, "[䶻　]+")
      for $n in $as/node() return
        if (local-name($n)='match') then 
         element {QName(xs:anyURI("http://www.tei-c.org/ns/1.0"), "space")} { 
         attribute n {$n},
         attribute quantity {string-length($n)}}
        else 
            (:  TODO normalize text :)
            xed:normalize-chars($n)
        (: ︻ ︼ :)
    default return $node/text()
};


declare function local:save-doc($doc, $krid){
 let  $top := tokenize ($krid, "\d{2,4}")[1]
 , $bu := substring($top, 1, 3)
 , $sub := substring($top, 1, 4)
 , $targetcoll := dbu:ensure-collection ($config:tls-texts-root || "/KR/" || $bu || "/" || $sub || "/" || $top , $local:perm )
 , $uri :=  xmldb:store($targetcoll, $krid || ".xml", $doc)
 , $acl := dbu:set-permissions($uri , $local:perm)
return $uri
};


declare function local:convert-kx($map){
    let $dzp := "/db/apps/tls-texts/incoming/20230209/"
    let $h := local:teiheader($map)
    , $path := $dzp||$map?id||"/xml"
    , $pn := collection($dzp||$map?id||"/xml")//page
   , $log := log:info($local:log, "Page path: " || $path || "count: " || count($pn))
    let $txt := <text xmlns="http://www.tei-c.org/ns/1.0"><body><div><p  xmlns="http://www.tei-c.org/ns/1.0" >{
       for $f in $pn
       let $uri := substring-before(tokenize(document-uri(root($f)), "/")[last()], ".xml") => xs:int()
       
       order by $uri
       return
        (<pb xmlns="http://www.tei-c.org/ns/1.0" ed="KX" n="{$map?id}.{$uri}" xml:id="{$map?krid}_tls_{$uri}a"/>,
        local:page($f, map{"krid": $map?krid, "pid" : $uri, "id" : $map?id, "uri" : $uri})
        )
    }</p></div></body></text>    
    , $doc := <TEI xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$map?krid}">
        {$h}
        {$txt}
    </TEI>
    return local:save-doc($doc, $map?krid)
};


let $dzp := "/db/apps/tls-texts/incoming"
, $krtitles := doc("/db/apps/tls-texts/meta/krp-titles.xml")
for $d in collection($dzp)//metadata
  let $t := $d/title/text()
  , $uri := document-uri(root($d))
  , $id := tokenize($uri, "/")[7]
  , $w := $krtitles//work[altid[.="KX"||$id]]
  , $krid := data($w/@krid)
(:  , $log := log:info($local:log, "Text: " || $krid || " - " || $w/title/text()):)
  , $cat := tokenize ($krid, "\d{2,4}")[1]
(:  where $krid = "KR3fa002" :)
  order by $id
return
    local:convert-kx(map{"id" : $id, "krid": $krid, "title": $w/title/text(), "md" : $d, "cat" : $cat, "byline" : $d/creator/text()})

(::)
(:let $p := doc("/db/apps/tls-texts/incoming/20230209/03-07-002/xml/1.xml"):)
(::)
(:return :)
(:    local:page($p, map{"krid" : "KR3fa001", "pid" : 1}):)

(:return local:cp-res("28CF736B_DA8B_4275_96CD_49B1255CF3D3", "KR3fa002", "03-07-003"):)