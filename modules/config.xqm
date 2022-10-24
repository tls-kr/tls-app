xquery version "3.1";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace config="http://hxwd.org/config";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";

declare namespace templates="http://exist-db.org/xquery/templates";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

(:
    Determine the application root collection from the current module load path.
:)
declare variable $config:test := system:get-module-load-path();
declare variable $config:login-domain := "org.hxwd.tls";

declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
               if (starts-with($rawPath, "xmldb:exist://null/")) then
                 substring($rawPath, 19) 
                 else
                 substring($rawPath, 15)
        else 
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare variable $config:repo-descriptor := doc(concat($config:app-root, "/repo.xml"))/repo:meta;

declare variable $config:expath-descriptor := doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package;

declare variable $config:tls-data-root := substring-before($config:app-root, data($config:expath-descriptor/@abbrev)) || "tls-data";
declare variable $config:tls-texts-root := substring-before($config:app-root, data($config:expath-descriptor/@abbrev)) || "tls-texts";
declare variable $config:tls-krx-root := substring-before($config:app-root, data($config:expath-descriptor/@abbrev)) || "tls-krx";
declare variable $config:tls-translation-root := concat($config:tls-data-root, "/translations");
declare variable $config:tls-user-root := "/db/users/";
declare variable $config:tls-add-titles := $config:tls-texts-root || "/krp-titles.xml";
declare variable $config:exide-url := "/exist/apps/eXide/index.html";
declare variable $config:tls-manifests := 
  let (:$user := sm:id()//sm:real/sm:username/text()
  , $approot := substring-before($config:app-root, data($config:expath-descriptor/@abbrev))
  , :)$mf := "/manifests"
  return ((:"/db/users/"||$user||$mf,:) $config:tls-texts-root||$mf, $config:tls-krx-root||$mf) ;

declare variable $config:seg-split-tokens := '[，。：．；？﹖！，』」/、]';

(: the underscore is in reality a space, for the purpose at hand has to be escaped :) 
declare variable $config:concept-name-chars := "['_,-/3ABCDEFGHIJKLMNOPQRSTUVWXYZx:]";
declare variable $config:pinyin-chars := "[abcdefghijklmnopqrstuwxyzàáèéìíòóùúüāēěīōūǎǐǒǔǘǚǜ̀́]";
declare variable $config:pua-base-cbeta := 983040;
declare variable $config:pua-base-krp := 1069056;

declare variable $config:seg-types := map{
"root" : "Root Text",
"comm" : "Commentary",
"p" : "New paragraph",
"fw" : "Forme work",
"byline" : "Author, Compiler etc.",
"head" : "Heading (same level)",
"head+" : "Heading (lower)",
"head-" : "Heading (higher)"
};

declare variable $config:status-map := map{
0 : "pending",
1 : "proposed",
2 : "checked",
4 : "published"
};

declare variable $config:languages := map{
"en" : "English",
"zh" : "Chinese",
"de" : "German",
"fr" : "French",
"ru" : "Russian",
"ko" : "Korean",
"it" : "Italian",
"la" : "Latin",
"ogr" : "Old Greek",
"ja" : "Japanese",
"ja-ku" : "Japanese Kundoku"
};

declare variable $config:circle := "resources/icons/open-iconic-master/svg/media-record.svg";

(: translation attribution :)
(: Just for reference, might want to use this later...
"None" : "TJAN TJOE SOM 1949FF", (\: BHT 白虎通 :\)
"None" : "Stephen Owen", (\: CEN SHEN 岑參 :\)
"None" : "Stephen Owen", (\: CHEN ZIANG 陳子昂 :\)
"None" : "Legge", (\: CQ 春秋 :\)
"None" : "Christoph Anderl", (\: XINXINGLUN 大乘心行論 :\)
"None" : "Stephen Owen", (\: DU FU 杜甫 :\)
"None" : " ", (\: XIAOFUXU 馮夢龍笑府序 :\)
"None" : "C. Harbsmeier,  based on Dirk Meier", (\: GD.XZMC 郭店。性自命出 :\)
"None" : "C. Harbsmeier", (\: GD.YUCONG 郭店語叢 :\)
"None" : "Dirk Meier", (\: GD.ZHONGXIN 郭店.忠信之道 :\)
"None" : "PINE 2000", (\: HANSHAN 寒山詩 :\)
"None" : "HARPER 1998", (\: HEYINYANG 合陰陽 :\)
"None" : "C. Harbsmeier", (\: HUAZAN 畫贊 :\)
"None" : "Keightley, Takashima, Qiu", (\: HEJI 甲骨文字合集 :\)
"None" : "C. Harbsmeier", (\: KQ 孔雀東南飛 :\)
"None" : "Stephen Owen", (\: Li Bai 李白 :\)
"None" : "Stephen Owen", (\: LISHIMIN 李世民 :\)
"None" : "C. Harbsmeier, based on Pelliot 1920 and Keenan 1994", (\: MOUZI 牟子：理惑論 :\)
"None" : "C. Harbsmeier, based on SWANN 1960", (\: NJ 女戒 :\)
"None" : "C. Harbsmeier", (\: QYX 切韻序 :\)
"None" : "Martin Kern, modified by C. Harbsmeier", (\: STELAE 秦刻石 :\)
"None" : "C. Harbsmeier", (\: RENJING 吳亮：忍經 :\)
"None" : "Duyvendak", (\: SHANG 商君書 :\)
"None" : "P. Thompson", (\: SHENDAO 慎到 :\)
"None" : "Owen 1992", (\: SIKUNGTU.SHIPIN 司空圖:二十四詩品 :\)
"None" : "HULSEWE", (\: SHUIHUDI 睡虎地 :\)
"None" : "C. Harbsmeier", (\: SHUOWEN XU 説文解字序 :\)
"None" : "C. Harbsmeier", (\: SUMMA SUMMA.THEOL :\)
"None" : "LAU AND AMES 1996", (\: SB 孫臏 :\)
"None" : "Ralph D. Sawyer", (\: SUN 孫子 :\)
"None" : "Hightower", (\: TYM 陶淵明詩 :\)
"None" : "Stephen Owen", (\: Wang Ji 王績 :\)
"None" : "none", (\: WEN 文子 :\)
"None" : "Pang Pu et al.", (\: WXP 五行篇 :\)
"None" : "C. Harbsmeier", (\: XIAOLIN 笑林 :\)
"None" : "Pokora, Michigan University Press", (\: XINLUN 新論 :\)
"None" : "C. Harbsmeier", (\: ZHONGJING 忠經 :\)
:)

declare variable $config:translation-map := map{
"KR1a0001" : "[Lynn, Columbia Unversity Press]", (: XC 繫辭 :)
"KR1b0001" : "Karlgren", (: SHU 尚書 :)
"KR1c0001" : "Karlgren, BMFEA", (: SHI 詩經 :)
"KR1c0003" : "Stephen Owen 1992", (: DAXU 詩。大序 :)
"KR1c0066" : "Hightower", (: HSWZ 韓詩外傳 :)
"KR1d0052" : "Legge", (: LJ 禮記 :)
"KR1e0001" : "Legge", (: ZUO 左傳 :)
"KR1e0008" : "MALMQVIST 1972ff", (: CQGL 穀梁傳 :)
"KR1f0001" : "L. Zádrapa", (: XJ 孝經 :)
"KR1h0001" : "David Sehnal; D.C. Lau", (: MENG 孟子 :)
"KR1h0004" : "C. Harbsmeier", (: LY 論語 :)
"KR2a0001" : "Watson", (: SJ 史記 :)
"KR2e0001" : "none", (: GY 國語 :)
"KR2e0003" : "Crump, Oxford University Press", (: ZGC 戰國策 :)
"KR2g0003" : "none", (: YAN 晏子春秋 :)
"KR2g0017" : "O'HARA 1945", (: LNZ 列女傳 :)
"KR3a0001" : "KRAMER 1950", (: KJ 孔子家語 :)
"KR3a0002" : "Knoblock and Riegel", (: XUN 荀子 :)
"KR3a0006" : "GALE 1931", (: YTL 鹽鐵論 :)
"KR3a0047" : "C. Harbsmeier", (: YULEI 朱子語類 :)
"KR3c0001" : "Rickett, Princeton University Press", (: GUAN 管子 :)
"KR3c0005" : "C. Harbsmeier", (: HF 韓非子 :)
"KR3e0001" : "C. Harbsmeier", (: SUWEN 素問 :)
"KR3j0002" : "Mei Yi Pao", (: MOZI 墨子 :)
"KR3j0006" : "Wells", (: HEGUAN 鶡冠子 :)
"KR3j0009" : "Knoblock &amp; Riegel", (: LS 呂氏春秋 :)
"KR3j0010" : "Wallacker, Ames, LeBlanc, Kraft, Morgan", (: HNZ 淮南子 :)
"KR3j0080" : "Hu Chirui and Michael Nylan", (: LH 論衡 :)
"KR3l0002" : "Mather", (: SSXY 世說新語 :)
"KR3l0090" : "Anne Birrell", (: SHJ 山海經 :)
"KR4a0001" : "HAWKES 1985 ", (: CC 楚辭 :)
"KR5c0057" : "Karlgren 1975", (: LAO 道德經 :)
"KR5c0124" : "GRAHAM 1960", (: LIE 列子 :)
"KR5c0126" : "[Watson 1969]", (: ZHUANG 莊子 :)
"KR5f0010" : "Graham 1998", (: MOJ 墨經 :)
"KR6b0059" : "Sun Xixin and Victor Mair", (: XYJ 賢愚經 :)
"KR6b0066" : "C. Harbsmeier ", (: BAIYU 百喻經 :)
"KR6b0067" : "DHARMAJOTI 1990", (: FAJU 法句經 :)
"KR6b0070" : " ", (: SONGJING 法集要頌經 :)
"KR6d0001" : "WATSON 1993 ", (: FAHUA 法華經 :)
"KR6q0002" : "Christoph Anderl", (: ZTJ 祖堂集 :)
"KR6q0053" : "Christoph Anderl", (: LINJILU 臨濟錄 :)
"KR6q0082" : "YAMPOLSKY 1996" (: TANJING 六祖壇經 :),
"KR6s0019" : "?" (: FYMYJ 翻譯名義序 :)
};

declare variable $config:txtsource-map := map{
"KR3a0047" : "Kanseki Repository",
"KR6q0002" : "Kanseki Repository"
};

(: Get repo-config.xml to parse global varaibles :)
declare variable $config:get-config := doc($config:app-root || '/repo-config.xml');

(: Get access-config.xml to parse global varaibles for git-sync and recaptcha  :)
declare variable $config:get-access-config := doc($config:app-root || '/access-config.xml');

(: Establish eXist-db data root defined in repo.xml 'data-root':)
declare variable $config:data-root := 
    let $app-root := $config:get-config//repo:app-root/text()  
    let $data-root := concat($config:get-config//repo:data-root/text(),'/data') 
    return replace($config:app-root, $app-root, $data-root);

(: Establish main navigation for app, used in templates for absolute links. :)
declare variable $config:nav-base := 
    if($config:get-config//repo:nav-base/text() != '') then $config:get-config//repo:nav-base/text()
    else if($config:get-config//repo:nav-base/text() = '/') then ''
    else '';

(: Base URI used in record tei:idno :)
declare variable $config:base-uri := $config:get-config//repo:base_uri/text();

(: Webapp title :)
declare variable $config:app-title := $config:get-config//repo:title/text();

(: Webapp URL :)
declare variable $config:app-url := $config:get-config//repo:url/text();

(: Element to use as id xml:id or idno :)
declare variable $config:document-id := $config:get-config//repo:document-ids/text();

(: Map rendering, google or leaflet :)
declare variable $config:app-map-option := $config:get-config//repo:maps/repo:option[@selected='true']/text();
declare variable $config:map-api-key := $config:get-config//repo:maps/repo:option[@selected='true']/@api-key;


(: Recaptcha Key :)
declare variable $config:recaptcha := 
    if($config:get-access-config//recaptcha/site-key-variable != '') then 
        environment-variable($config:get-access-config//recaptcha/site-key-variable/text())
    else if($config:get-access-config//private-key/text() != '') then $config:get-access-config//private-key/text() 
    else ();


declare function config:get-configuration() as element(configuration) {
    doc(concat($config:app-root, "/access-config.xml"))/config
};

(:~
 : Get collection data
 : @param $collection match collection name in repo-config.xml 
:)
declare function config:collection-vars($collection as xs:string?) as node()?{
    let $collection-config := $config:get-config//repo:collections
    for $collection in $collection-config/repo:collection[@name = $collection]
    return $collection
};

(:~
 : Get collection data
 : @param $collection match collection name in repo-config.xml 
:)
declare function config:collection-title($node as node(), $model as map(*), $collection as xs:string?) as xs:string?{
    if(config:collection-vars($collection)/@title != '') then 
        string(config:collection-vars($collection)/@title)
    else $config:app-title
  
};

(:~
 : Resolve the given path using the current application context.
 : If the app resides in the file system,
 :)
declare function config:resolve($relPath as xs:string) {
    if (starts-with($config:app-root, "/db")) then
        doc(concat($config:app-root, "/", $relPath))
    else
        doc(concat("file://", $config:app-root, "/", $relPath))
};

(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare function config:expath-descriptor() as element(expath:package) {
    $config:expath-descriptor
};

declare %templates:wrap function config:app-title($node as node(), $model as map(*)) as text() {
    $config:expath-descriptor/expath:title/text()
};

declare function config:app-meta($node as node(), $model as map(*)) as element()* {
    <meta xmlns="http://www.w3.org/1999/xhtml" name="description" content="{$config:repo-descriptor/repo:description/text()}"/>,
    for $author in $config:repo-descriptor/repo:author
    return
        <meta xmlns="http://www.w3.org/1999/xhtml" name="creator" content="{$author/text()}"/>
};

(:~
 : For debugging: generates a table showing all properties defined
 : in the application descriptors.
 : No idea what the parameters have to do here?!
 :)
declare function config:app-info($node as node(), $model as map(*)) {
    session:create(),
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    let $user := session:get-attribute($config:login-domain || ".user")
    let $user1 := request:get-attribute($config:login-domain || ".user"),
    $cookie := request:get-cookie-value($config:login-domain)
    return
        <table class="app-info">
        <tr><td>user</td><td>{$user}{if (sm:is-authenticated()) then sm:id() else ("NO")}
        </td></tr>
        <tr><td>user-req</td><td>{request:attribute-names()}</td></tr>
        <tr><td>session-atts</td><td>{session:get-attribute-names()}</td></tr>
        <tr><td>cookies</td><td>{request:get-cookie-names()}</td></tr>
        <tr>
        <td>tls-data</td>
        <td>{$config:tls-data-root}</td>
        </tr>
        <tr>
        <td>tls-texts</td>
        <td>{$config:tls-texts-root}</td>
        </tr>
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
