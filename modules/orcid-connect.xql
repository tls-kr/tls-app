xquery version "3.1";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace config="http://hxwd.org/config" at "config.xqm";
declare namespace orcid="http://hxwd.org/orcid";

login:set-user($config:login-domain, (), false()),
if (sm:is-authenticated() and string(sm:id()//sm:real/sm:username) != "guest") then (
    if (request:get-attribute('xquery.password')) then
        if (xmldb:login('/db', string(sm:id()//sm:real/sm:username),
                        string(request:get-attribute('xquery.password')), true())) then ()
        else error(xs:QName('orcid:LOGIN'), 'Could not establish TLS session')
    else (),
    session:create(),
    session:set-attribute("tls.orcid.link-user", string(sm:id()//sm:real/sm:username)),
    response:redirect-to(xs:anyURI("../orcid/start?mode=link"))
) else (
    response:set-status-code(403),
    "Sign in to TLS before connecting ORCID."
)
