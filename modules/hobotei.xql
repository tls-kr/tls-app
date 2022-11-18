xquery version "3.1";
(:~
: This module provides access to the digital version of the digital Fascicule annexe du Hōbōgirin :
                        Répertoire du Canon bouddhique sino-japonais. édition de Taishō (Taishō
                        Shinshū Daizōkyō)
: 2022-11-09
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace hob="http://hxwd.org/hobogirin"; 

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://hxwd.org/config" at "config.xqm"; 

declare variable $hob:teifile := $config:tls-data-root || "/external/hobotei.xml";

declare function hob:get-author($tid as xs:string){
doc($hob:teifile)//tei:person[.//tei:listBibl/tei:bibl[@sameAs="#"||$tid]]
};

declare function hob:get-title($tid as xs:string){
doc($hob:teifile)//tei:bibl[@xml:id=$tid]/tei:title
};

