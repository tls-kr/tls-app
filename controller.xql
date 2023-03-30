xquery version "3.0";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace config="http://hxwd.org/config" at "modules/config.xqm";
declare namespace json="http://www.json.org";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

declare variable $logout := request:get-parameter("logout", ());
declare variable $allowOrigin := local:allowOriginDynamic(request:get-header("Origin"));

declare variable $local:HTTP_OK := xs:integer(200);
declare variable $local:HTTP_CREATED := xs:integer(201);
declare variable $local:HTTP_NO_CONTENT := xs:integer(204);
declare variable $local:HTTP_BAD_REQUEST := xs:integer(400);
declare variable $local:HTTP_UNAUTHORIZED := xs:integer(401);
declare variable $local:HTTP_FORBIDDEN := xs:integer(403);
declare variable $local:HTTP_NOT_FOUND := xs:integer(404);
declare variable $local:HTTP_METHOD_NOT_ALLOWED := xs:integer(405);
declare variable $local:HTTP_INTERNAL_SERVER_ERROR := xs:integer(500);

declare variable $local:isget := request:get-method() = ("GET","get");

declare function local:allowOriginDynamic($origin as xs:string?) {
    let $origin := replace($origin, "^(\w+://[^/]+).*$", "$1")
    return
        if (local:checkOriginWhitelist($config:origin-whitelist, $origin)) then
            $origin
        else
            "*"
};

declare function local:checkOriginWhitelist($regexes, $origin) {
    if (empty($regexes)) then
        false()
    else if (matches($origin, head($regexes))) then
        true()
    else
        local:checkOriginWhitelist(tail($regexes), $origin)
};


declare function local:user-allowed() {
    (
        request:get-attribute($config:login-domain || ".user") and
        request:get-attribute($config:login-domain || ".user") != "guest"
    ) or config:get-configuration()/restrictions/@guest = "yes"
};

declare function local:query-execution-allowed() {
    (
    config:get-configuration()/restrictions/@execute-query = "yes"
        and
    local:user-allowed()
    )
        or
    sm:is-dba((request:get-attribute("org.exist.login.user"),request:get-attribute("xquery.user"), 'nobody')[1])
};

util:log("debug", map {
    "$exist:path": $exist:path,
    "$exist:resource": $exist:resource,
    "$exist:controller": $exist:controller,
    "$exist:prefix": $exist:prefix,
    "$exist:root": $exist:root,
    "$local:isget": $local:isget
}),

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>

else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>

(: static HTML page for API documentation should be served directly to make sure it is always accessible :)
else if ($exist:path eq '/api.html') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/api.html"/>
    </dispatch>
else if ($exist:path eq '/api.json') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/api.json"/>
    </dispatch>
else if ($exist:path eq '/api-jwt.json') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/api-jwt.json"/>
    </dispatch>


else if (ends-with($exist:resource, ".xql")) then (
        (: log the user in again! :)
        login:set-user($config:login-domain, (), false()),
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/{$exist:path}"/>
            <cache-control cache="no"/>
        </dispatch>
)

else if ($exist:resource = "login") then (
    util:declare-option("exist:serialize", "method=json media-type=application/json"),
    let $loggedIn := login:set-user($config:login-domain, (), false())
    return
        try {
            if (local:user-allowed()) then
                <status>
                    <user>{request:get-attribute($config:login-domain||".user")}</user>
                    <isAdmin json:literal="true">{ sm:is-dba((request:get-attribute("org.exist.login.user"),request:get-attribute("xquery.user"), 'guest')[1]) }</isAdmin>
                </status>
            else
                (
                    response:set-status-code(401),
                    <status>fail</status>
                )
        } catch * {
            response:set-status-code(401),
            <status>{$err:description}</status>
        }

)

else if (ends-with($exist:resource, ".html")) then (
    if (matches($exist:resource, "sgn-verify")) then () else
    login:set-user($config:login-domain, (), false()),
    (: the html page is run through view.xql to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xql">
                <set-header name="Last-Modified" value="{current-dateTime()}"/>
            </forward>
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

(: static resources from the resources, transform, templates, odd or modules subirectories are directly returned :)
else if (matches($exist:path, "^.*/(resources|transform|templates)/.*$")
    or matches($exist:path, "^.*/odd/.*\.css$")
    or matches($exist:path, "^.*/tls-texts/img/.*\.png$")
    or matches($exist:path, "^.*/modules/.*\.json$")) then
    let $d := replace($exist:path, "^.*/(resources|transform|modules|templates|odd)/.*$", "$1"),
    $dir := replace($d, "/tls-texts", "../tls-texts")
    return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}/{$dir}/{substring-after($exist:path, '/' || $dir || '/')}">
            {
                if ($dir = "transform") then
                    <set-header name="Cache-Control" value="no-cache"/>
                else if (contains($exist:path, "/resources/fonts/")) then
                    <set-header name="Cache-Control" value="max-age=31536000"/>
                else (
                    <set-header name="Access-Control-Allow-Origin" value="{$allowOrigin}"/>,
                    if ($allowOrigin = "*") then () else <set-header name="Access-Control-Allow-Credentials" value="true"/>
                )
            }
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

(: This is for the open api, but not ready yet...  :)


(:    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/modules/api.xql">
            <set-header name="Access-Control-Allow-Origin" value="*"/>
            <set-header name="Access-Control-Allow-Credentials" value="true"/>
            <set-header name="Access-Control-Allow-Methods" value="GET, POST, DELETE, PUT, PATCH, OPTIONS"/>
            <set-header name="Access-Control-Allow-Headers" value="Accept, Content-Type, Authorization, X-Start"/>
            <set-header name="Cache-Control" value="no-cache"/>
        </forward>
    </dispatch>
:)