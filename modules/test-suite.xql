xquery version "3.1";

(:~ This library module contains XQSuite tests for the TLS-漢學文典 app.
 :
 : @author Duncan Paterson
 : @version 0.6.0
 : @see http://wittern.org
 :)

module namespace tests = "http://hxwd.org/apps/tls-app/tests";

  import module namespace app = "http://hxwd.org/apps/tls-app/templates" at "app.xql";
declare namespace test="http://exist-db.org/xquery/xqsuite";

declare variable $tests:map := map {1: 1};

declare
    %test:arg('n', 'div')
    %test:assertEquals("<p>Dummy templating function.</p>")
    function tests:templating-foo($n as xs:string) as node(){
        app:foo(element {$n} {}, $tests:map)
};
