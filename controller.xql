xquery version "3.0";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace config="http://hxwd.org/config" at "modules/config.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(:declare variable $logout := request:get-parameter("logout", ());
declare variable $login := request:get-parameter("user", ());
:)
declare variable  $login := login:set-user("org.exist.login", (), false());


if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
(:else if ($logout or $login) then (
    login:set-user($config:login-domain, (), false()),
    (\: redirect successful login attempts to the original page, but prevent redirection to non-local websites:\)
    let $referer := request:get-header("Referer")
    let $this-servers-scheme-and-domain := request:get-scheme() || "://" || request:get-server-name()
    return
        if (starts-with($referer, $this-servers-scheme-and-domain)) then
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <redirect url="{request:get-header("Referer")}"/>
            </dispatch>
        else
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <redirect url="{replace(request:get-uri(), "^(.*)\?", "$1")}"/>
            </dispatch>
)    
:)
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/modules/view.xql"/>
		</error-handler>
    </dispatch>
(: Resource paths starting with $app-root are resolved relative to app :)
else if (contains($exist:path, "/$app-root/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{concat($exist:controller,'/', substring-after($exist:path, '/$app-root/'))}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>        

(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>
