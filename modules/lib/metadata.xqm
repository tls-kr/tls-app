xquery version "3.1";

(:~
 : Library module for handling translation files.
 :
 : @author Christian Wittern
 : @date 2023-10-23
 :)

module namespace lmd="http://hxwd.org/lib/metadata";

import module namespace config="http://hxwd.org/config" at "../config.xqm";
(:import module namespace lu="http://hxwd.org/lib/utils" at "utils.xqm";:)

declare namespace tei= "http://www.tei-c.org/ns/1.0";

(: for a $hit, we find the value associated with the requested genre :)
 
declare function lmd:get-metadata($hit, $field){
    let $header := try {$hit/ancestor-or-self::tei:TEI/tei:teiHeader} catch * {()}
    return
        switch ($field)
            case "textid" return if ($hit/@textid) then ($hit/@textid) else $hit/ancestor-or-self::tei:TEI/@xml:id
            case "title" return 
                string-join((
                    $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                    $header//tei:titleStmt/tei:title
                ), " - ") => normalize-space()
            case "date" return
                  let $sourcedesc-date := analyze-string(string-join($header//tei:sourceDesc//tei:bibl//text(), ''), "\d{4}")//fn:match/text()
                  return 
                    if ($sourcedesc-date) then 
                      $sourcedesc-date 
                    else
                      let $creation-date := substring(($header//tei:profileDesc/tei:creation)[1]/tei:date, 1, 4)
                      return
                       if ($creation-date) then $creation-date else "9999" 
            case "tls-dates"
            case "kr-categories"
            case "tls-regions" return
(:                let $res := for $t in $header//tei:textClass/tei:catRef[@scheme="#"||$field]/@target return if (starts-with($t, "#KR")) then substring($t, 2) else            :)
                let $res := for $t in $header//tei:textClass/tei:catRef[@scheme="#"||$field]/@target return substring($t, 2)
                return
                if (string-length(string-join($res)) > 0) then $res else "notav"
            case "extent" return
                data($header//tei:extent/tei:measure[@unit="char"]/@quantity)
            case "head" return
                $hit/ancestor::tei:div[1]/tei:head[1]/tei:seg/text() => string-join() => normalize-space()
            case "edition" return
                let $textid := $hit/ancestor-or-self::tei:TEI/@xml:id
                , $ab := doc($config:tls-texts-meta||"/chant-refs.xml")//ab[@refid=$textid]
                return
                if ($ab) then $ab/text()
                 else
                 if($header//tei:sourceDesc/tei:bibl) then 
                  string-join((
                    $header//tei:sourceDesc//tei:title[@level="s"]
                  ), " - ")                
                else
                normalize-space(string-join($header//tei:sourceDesc//text(), ' '))
            case "status" return
                 data($header//tei:availability/@status)
            case "resp" return
                 $header//tei:editor[@role='translator' or @role='creator']
            case "genre" return ()
            default return ()
};

declare function lmd:cat-title($cat){
let $title := string-join(doc($config:tls-texts-taxonomy)//tei:category[@xml:id=$cat]/tei:catDesc/text(), ' - ')
return
if (string-length($title) > 0) then $title else "Not assigned"
};

declare function lmd:delCat($node as node(), $catid as xs:string){
    let $header := $node/ancestor-or-self::tei:TEI/tei:teiHeader
    , $r := $header//tei:catRef[@target="#"||$catid]
    return 
      update delete $r
};

(: not checking for scheme here :)
declare function lmd:checkCat($node as node(), $scheme as xs:string, $catid as xs:string){
    let $tax := doc($config:tls-texts-taxonomy)
    let $catref := <catRef xmlns="http://www.tei-c.org/ns/1.0" scheme="#{$scheme}" target="#{$catid}"/>
    , $tc := <textClass xmlns="http://www.tei-c.org/ns/1.0">{$catref}</textClass>
    , $header := $node/ancestor-or-self::tei:TEI/tei:teiHeader
    return
    if ($header//tei:profileDesc) then
        if ($header//tei:catRef[@target="#"||$catid]) then 
            let $r := $header//tei:catRef[@target="#"||$catid]
            , $s := substring($r/@scheme ,2)
            return
            if ($s = $scheme) then () else
                update replace $r with $catref
        else
            if ($header//tei:textClass) then
                update insert $catref into $header//tei:textClass
            else
                update insert $tc into $header//tei:profileDesc
    else 
        let $node := <profileDesc xmlns="http://www.tei-c.org/ns/1.0">{$tc}</profileDesc>
        return
            update insert $node following $header//tei:fileDesc 
};


(: category xml:ids have to be unique across the document, so I do not need to provide the scheme here :)
declare function lmd:checkCat($node as node(), $catid as xs:string){
    let $nt  := ("kr-categories", "tls-dates", "tls-regions")
    let $tax := doc($config:tls-texts-taxonomy)
    , $scheme := $tax//tei:category[@xml:id=$catid]/ancestor::tei:category[parent::tei:taxonomy]/@xml:id
    let $catref := <catRef xmlns="http://www.tei-c.org/ns/1.0" scheme="#{$scheme}" target="#{$catid}"/>
    , $tc := <textClass xmlns="http://www.tei-c.org/ns/1.0">{$catref}</textClass>
    , $header := $node/ancestor-or-self::tei:TEI/tei:teiHeader
    return
    if ($scheme) then
    if ($header//tei:profileDesc) then
        if ($header//tei:catRef[@target="#"||$catid] or ($scheme = $nt and $header//tei:catRef[@target="#"||$scheme])) then 
            let $r := $header//tei:catRef[@target="#"||$catid]
            , $s := substring($r/@scheme ,2)
            return
            if ($s = $scheme) then () else
                update replace $r with $catref
        else
            if ($header//tei:textClass) then
                update insert $catref into $header//tei:textClass
            else
                update insert $tc into $header//tei:profileDesc
    else 
        let $node := <profileDesc xmlns="http://www.tei-c.org/ns/1.0">{$tc}</profileDesc>
        return
            update insert $node following $header//tei:fileDesc 
    else "Error: no valid scheme found for category: " || $catid
};
