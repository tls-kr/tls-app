xquery version "3.1";

(:~ This library runs the XQSuite unit tests for the TLS-漢學文典 app.
 :
 : @author Duncan Paterson
 : @version 0.6.0
 : @see http://www.exist-db.org/exist/apps/doc/xqsuite
 :)
import module namespace test="http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";
import module namespace tests="http://hxwd.org/apps/tls-app/tests" at "test-suite.xql";

declare namespace tei= "http://www.tei-c.org/ns/1.0";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "json";
declare option output:media-type "application/json";

test:suite(
  inspect:module-functions(xs:anyURI("test-suite.xql"))
)
