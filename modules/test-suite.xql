xquery version "3.1";

(:~ This library module contains XQSuite tests for the TLS-漢學文典 app.
 :
 : @author Christian Wittern
 : @version 0.6.0
 : @see http://wittern.org
 :)

module namespace tests = "http://hxwd.org/apps/tls-app/tests";

import module namespace app = "http://hxwd.org/app" at "app.xql";
import module namespace tlsapi="http://hxwd.org/tlsapi" at "../api/tlsapi.xql";
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace lu="http://hxwd.org/lib/utils" at "lib/utils.xqm";

declare namespace test="http://exist-db.org/xquery/xqsuite";
declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare variable $tests:map := map {1: 1};

declare variable $tests:seg := element {QName("http://www.tei-c.org/ns/1.0", "seg")} {};

declare
    %test:arg('n', 'div')
    %test:assertEquals('<img class="app-logo img-fluid" src="resources/images/hxwd.png" title="TLS"/>')
    function tests:templating-logo($n as xs:string) as node(){
        app:logo(element {$n} {}, $tests:map)
};

(:  :)


declare
    %test:args('宗', "concept", "core", "")
    %test:assertXPath('//li')
    %private
    function tests:tlslib-get-sw($n, $context, $domain, $leftword) as node(){
        <div>
        {tlslib:get-sw($n, $context, $domain, $leftword)}
        </div>
};


declare
    %test:args('CH1a0907_CHANT_016-35a.4')
    %test:assertXPath('$result//[@xml:id="CH1a0907_CHANT_016-35a.4"]')
    %test:assertXPath('namespace-uri($result)="http://www.tei-c.org/ns/1.0"')
    function tests:lu-get-seg($seg-id){
    lu:get-seg($seg-id)
    };

declare
    %test:args('CH1a0907_CHANT_016-35a.4')
    %test:assertXPath('//div[@id="chunkrow"]')
    %private
    function tests:tlslib-display-chunk($segid as xs:string) as node(){
    let $targetseg := lu:get-seg($segid)
    , $textid := tokenize($segid, "_")[1]
    , $model := map{"textid" : $textid, "title" : lu:get-title($textid)}
    return
        <div>
        {tlslib:display-chunk($targetseg, $model , 15, 15)}
        </div>
};

