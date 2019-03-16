xquery version "3.1";

(:~ This library module contains XQSuite tests for the TLS-漢學文典 app.
 :
 : @author Duncan Paterson
 : @version 0.6.0
 : @see http://wittern.org
 :)

module namespace tests = "http://hxwd.org/apps/tls-app/tests";

import module namespace app = "http://hxwd.org/app" at "app.xql";
import module namespace tlsapi="http://hxwd.org/tlsapi" at "../api/tlsapi.xql";

declare namespace test="http://exist-db.org/xquery/xqsuite";

declare variable $tests:map := map {1: 1};

declare
    %test:arg('n', 'div')
    %test:assertEquals('<img class="app-logo img-fluid" src="resources/images/hxwd.png" title="TLS"/>')
    function tests:templating-logo($n as xs:string) as node(){
        app:logo(element {$n} {}, $tests:map)
};

declare
    %test:args('宗')
    %test:assertXPath('//li')
    function tests:tlsapi-get-sw($n as xs:string) as node(){
        <div>
        {tlsapi:get-sw($n)}
        </div>
};

