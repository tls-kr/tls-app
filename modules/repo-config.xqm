xquery version "3.1";

(:~
 : Configuration options for the application and a set of helper functions to access 
 : the application context.
 :)

module namespace config="http://exist-db.org/xquery/apps/config";

declare namespace system="http://exist-db.org/xquery/system";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";


declare variable $config:login-domain := "org.exist.public-repo.login";

(: Determine the application root collection from the current module load path :)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else if (starts-with($rawPath, "xmldb:exist://null")) then
                substring($rawPath, 19)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

(: Default collection and resource names for binary assets and extracted package metadata :)

declare variable $config:app-data-parent-col := "/db/apps";
declare variable $config:app-data-col-name := "public-repo-data";
declare variable $config:packages-col-name := "packages";
declare variable $config:icons-col-name := "icons";
declare variable $config:metadata-col-name := "metadata";
declare variable $config:logs-col-name := "logs";

declare variable $config:app-data-col := $config:app-data-parent-col || "/" || $config:app-data-col-name;
declare variable $config:packages-col := $config:app-data-col || "/" || $config:packages-col-name;
declare variable $config:icons-col := $config:app-data-col || "/" || $config:icons-col-name;
declare variable $config:metadata-col := $config:app-data-col || "/" || $config:metadata-col-name;
declare variable $config:logs-col := $config:app-data-col || "/" || $config:logs-col-name;


declare variable $config:package-groups-doc-name := "package-groups.xml";
declare variable $config:raw-packages-doc-name := "raw-packages.xml";
declare variable $config:package-groups-doc := $config:metadata-col || "/" || $config:package-groups-doc-name;
declare variable $config:raw-packages-doc := $config:metadata-col || "/" || $config:raw-packages-doc-name;

(: The default version number here is assumed when a client does not send a version parameter.
   It is set to 2.2.0 because this version was the last one known to work with most older packages
   before packages began to declare their version constraints in their package metadata.
   So this should stay as 2.2.0 until we (a) no longer have 2.2-era clients or (b) no longer have
   packages that we care to offer compatibility with 2.2.
 :)
declare variable $config:default-exist-version := "2.2.0";
declare variable $config:exist-processor-name := "http://exist-db.org";

(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    doc(concat($config:app-root, "/repo.xml"))/repo:meta
};

(:~
 : Returns the permissions information from the repo.xml descriptor.
 :)
declare function config:repo-permissions() as map(*) { 
    config:repo-descriptor()/repo:permissions ! 
        map { 
            "owner": ./@user/string(), 
            "group": ./@group/string(),
            "mode": ./@mode/string()
        }
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare function config:expath-descriptor() as element(expath:package) {
    doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package
};

(:~
 : For debugging: generates a table showing all properties defined
 : in the application descriptors.
 :)
declare function config:app-info($node as node(), $params as element(parameters)?, $modes as item()*) {
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return
        <table class="app-info">
            <tr>
                <td>app collection:</td>
                <td>{$config:app-root}</td>
            </tr>
            {
                for $attr in ($expath/@*, $expath/*, $repo/*)
                return
                    <tr>
                        <td>{node-name($attr)}:</td>
                        <td>{$attr/string()}</td>
                    </tr>
            }
        </table>
};