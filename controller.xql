xquery version "3.0";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace config="http://hxwd.org/config" at "modules/config.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

declare variable $logout := request:get-parameter("logout", ());

declare variable $local:HTTP_OK := xs:integer(200);
declare variable $local:HTTP_CREATED := xs:integer(201);
declare variable $local:HTTP_NO_CONTENT := xs:integer(204);
declare variable $local:HTTP_BAD_REQUEST := xs:integer(400);
declare variable $local:HTTP_UNAUTHORIZED := xs:integer(401);
declare variable $local:HTTP_FORBIDDEN := xs:integer(403);
declare variable $local:HTTP_NOT_FOUND := xs:integer(404);
declare variable $local:HTTP_METHOD_NOT_ALLOWED := xs:integer(405);
declare variable $local:HTTP_INTERNAL_SERVER_ERROR := xs:integer(500);

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
else if (ends-with($exist:resource, ".xql")) then (
        login:set-user($config:login-domain, (), false()),
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/{$exist:path}"/>
            <cache-control cache="no"/>
        </dispatch>
)
else if ($logout) then (
    login:set-user($config:login-domain, (), false()),
    session:invalidate(),
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{replace(request:get-uri(), "^(.*)\?", "$1")}"/>
    </dispatch>
)
(:else if ($exist:resource = "login") then (
(\:    util:declare-option("exist:serialize", "method=json media-type=application/json"),:\)
(\:    util:declare-option("exist:serialize", "method=text media-type=text/plain"),:\)
        login:set-user($config:login-domain, (), false()),
(\:        need to redirect to the referring page, not the current one! :\)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{replace(request:get-uri(), "^(.*)\?", "$1")}"/>
    </dispatch>

)
:)    
(: this seems to work for now... CW 2019-02-18 :) 
else if ($exist:resource = "login") then (
    util:declare-option("exist:serialize", "method=json media-type=application/json"),
    try {
        login:set-user($config:login-domain, (), false()),
        if ((sm:id()//sm:username/text()) != "guest") then (
            response:set-status-code($local:HTTP_OK),
            <response>
                <user>{sm:id()//sm:username/text()}</user>
                <isDba>{sm:is-dba(sm:id()//sm:username/text())}</isDba>
            </response>
        )
        else (
            response:set-status-code($local:HTTP_OK),
            <response>
                <fail>Authentication failed -- please check your credentials and try again.</fail>
                <currentuser>{sm:id()//sm:username/text()}</currentuser>
            </response>
        )
    } catch * {
        response:set-status-code($local:HTTP_INTERNAL_SERVER_ERROR),
        <response>
            <fail>{$err:description}</fail>
        </response>
    }
)


else if (ends-with($exist:resource, ".html")) then (
    login:set-user($config:login-domain, (), false()),
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
)
(: Resource paths starting with $app-root are resolved relative to app :)
else if (contains($exist:path, "/$app-root/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{concat($exist:controller,'/', substring-after($exist:path, '/$app-root/'))}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>        

(: Resource paths starting with $nav-base are resolved relative to app :)
(:else if (contains($exist:path, "/$nav-base/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{concat($exist:controller,'/', substring-after($exist:path, '/$nav-base/'))}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch> :)
(:temporarily disabling $nav-base, CW 2019-02-02 :)        
else if (contains($exist:path, "$nav-base/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{replace($exist:path, '\$nav-base/', '/')}">
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
