xquery version "3.1";

(:~ This library manages user permissions for the TLS-漢學文典 app and its companion apps.
 :
 : @author Duncan Paterson
 : @version 0.6.0
 : @see http://www.exist-db.org/exist/apps/doc/security
 :)

module namespace ace="http://hxwd.org/ace";
import module namespace sm="http://exist-db.org/xquery/securitymanager";
import module namespace dbutil="http://exist-db.org/xquery/dbutil";

declare variable $ace:editor := sm:group-exists('tls-editor') or sm:create-group('tls-editor', 'Editors for TLS');
(: user restrictions: tls-text/chant :)
declare variable $ace:texts := '/db/apps/tls-texts';
(: user restrictions: tls-data/translations, tls-data/concepts, tls-data/core, tls-data/notes  :)
declare variable $ace:data := '/db/apps/tls-data';

(:~ promote registered tls-user to tls-editor
 : @param $usr the account's username
 :)
declare function ace:promote-user ($usr as xs:string+) as empty-sequence() {
  sm:add-group-member('tls-editor', $usr)
};

(:~
 : editors group gets full write-access to tls-text, and tls-data
 : @see https://github.com/tls-kr/tls-app/issues/7
 :)
declare function ace:super-editor() as item()* {
  let $txt := xs:anyURI($ace:texts)
  let $data := xs:anyURI($ace:data)
  return
    (
      dbutil:scan-collections($txt, sm:add-group-ace(., 'tls-editor', true(), 'rwx')),
      dbutil:scan-collections($data, sm:add-group-ace(., 'tls-editor', true(), 'rwx'))
    )
};

(:~
 : limit editor user write access to collection.
 : @param $usr the account's username
 : @param $col URI of collection containing the resources for which $usr should not have write access
 :)
declare function ace:limit-editor($usr as xs:string, $col as xs:anyURI+) as item()* {
  dbutil:scan-resources($col, sm:insert-user-ace($col, 1, $usr, false(), '-w-'))
};

declare function ace:set-tls-user-permissions-col($res){
(
sm:chmod(xs:anyURI($res), "rwxrwxrwx"),
sm:chgrp(xs:anyURI($res), "tls-user")
)
};
