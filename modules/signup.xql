xquery version "3.1";
(:~
: This module lets a user signup for an account on HXWD
: 2022-11-08
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
: with help from Adam Retter on @exist-db slack
:  Flow:
:    - the user fills in a form with the relevant data (name, email, password etc) and submits
:    - We will vet the request and upon approval, send a mail to the user with a token for verification
:    - The user clicks on the token and completes the registration

:)

module namespace sgn="http://hxwd.org/signup"; 

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://hxwd.org/config" at "config.xqm"; 
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace http="http://expath.org/ns/http-client";
import module namespace mail="http://exist-db.org/xquery/mail";
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace lvs="http://hxwd.org/lib/visits" at "lib/visits.xqm";
import module namespace lpm="http://hxwd.org/lib/permissions" at "lib/permissions.xqm";
import module namespace log="http://hxwd.org/log" at "log.xql";

declare variable $sgn:userhome := "/db/users";
declare variable $sgn:log := $config:tls-log-collection || "/sgn";

(: the javascript required for recaptcha v3, cf https://developers.google.com/recaptcha/docs/v3 :) 

declare function sgn:javascript($node as node(), $model as map(*)){
<script src="https://www.google.com/recaptcha/api.js"></script>
};

(: 
 <script>
   function onSubmit(token) {
     document.getElementById("demo-form").submit();
   }
 </script>

----
<button class="g-recaptcha" 
        data-sitekey="reCAPTCHA_site_key" 
        data-callback='onSubmit' 
        data-action='submit'>Submit</button>


:)
declare function sgn:compare-token($ust, $ss, $user-id){
let $secure-salt := util:hash("your-secret-salt", "sha-256")
, $doc := doc("/db/groups/tls-admin/new-users/" || $ss|| ".xml")
, $now := util:system-dateTime() 
let $timestamp := data($doc//more/tk/user/@time-stamp)
let $unsecure-token := $secure-salt || ":" || $user-id || ":" || $timestamp || ":" || $ss
let $secure-token := util:hash($unsecure-token, "sha-256")
let $url-safe-token := util:base64-encode($secure-token)
, $pd := $now - xs:dateTime($timestamp) 
return
if ($pd < xs:dayTimeDuration("PT2H")) then
if ($ust = $url-safe-token) then "Success" else "Failure" else "Failure"
};


declare function sgn:make-token($user-id, $ss, $inputname){
(: in your database for validation purposes, you need to store: <user-id> -> (<timestamp>, <shared-secret>) :)
let $secure-salt := util:hash("your-secret-salt", "sha-256")
let $timestamp := util:system-dateTime() (: you need to store this for later validating the token:)
(:let $shared-secret := util:uuid()  (\: you need to store this for later validating the token:\):)
let $unsecure-token := $secure-salt || ":" || $user-id || ":" || $timestamp || ":" || $ss
let $secure-token := util:hash($unsecure-token, "sha-256")
let $url-safe-token := util:base64-encode($secure-token)
let $save-secret :=  <user id="{$user-id}" time-stamp="{$timestamp}" utoken="{$unsecure-token}" ust="{$url-safe-token}"></user>
let $send-message := sgn:send-verification-mail($user-id, $url-safe-token, $ss, $inputname)
return

   $save-secret
    
};

declare function sgn:sgn-received($node as node()*, $model as map(*), $answer , $inputname, $inputnname, $inputpw1, $inputpw2, $inputmail, $inputarea, $inputinst, $inputcont, $inputurl, $ss, $vk){
let $res := xs:int($answer)
, $corr := xs:int(156)
return
if ($res = $corr) then
<div>
<h1>Congratulations!</h1>
<p>Correct answer. The first step to registration has been cleared.  You will receive a mail with a signup-link to verify your mail adress.  Please click on that link within 2 hours, or you will have to repeat the process.  If you did not receive the mail, look into your spam folder.  </p>
{sgn:store-new-user($inputname, $inputnname, $inputpw1, $inputpw2, $inputmail, $inputarea, $inputinst, $inputcont, $inputurl, $ss, $vk)}
{log:info($sgn:log, "Signup received, " || $inputname || "s: " || $inputpw1)}
</div>
else 
<p>{$answer}: Wrong answer.  Go back and try again.</p>
};

declare function sgn:store-new-user($inputname, $inputnname, $inputpw1, $inputpw2, $inputmail, $inputarea, $inputinst, $inputcont, $inputurl, $ss, $vk){
let $newuser := <user>
 <mail>{$inputmail}</mail>
 <area>{$inputarea}</area>
 <inst>{$inputinst}</inst>
 <cont>{$inputcont}</cont>
 <url>{$inputurl}</url>
 <more>
 <approved n="0"/>
 </more>
</user>
, $newsys := <user>
 <account>
 <name>{$inputnname}</name>
 <fullName>{$inputname}</fullName>
 <description>TLS User</description>
 <password>{$inputpw1}</password>
 <group name="tls-user"></group>
 <umask>022</umask>
 </account>
 <more>
 <ss>{$ss}</ss>
 <verified status="false"/>
 <tk>{sgn:make-token($inputmail, $ss, $inputname)}</tk>
 </more>
</user>
, $ns := xmldb:store("/db/groups/tls-admin/new-users", $ss|| ".xml",$newsys)
, $nu := xmldb:store("/db/groups/tls-editor/users", $ss|| ".xml",$newuser)
(:, $res :=     (sm:chmod(xs:anyURI($nu), "rw-rw-rw-"),
     sm:chgrp(xs:anyURI($nu), "tls-editor"))
:)
return ()
};

(: 
  <account>
    <name>zadrapa</name>
    <fullName>Zádrapa, Lukáš</fullName>
    <description>TLS User</description>
    <password>tls55</password>
    <group name="tls-user"></group>
    <umask>022</umask>
  </account>
:)
declare function sgn:send-welcome-mail($user-id, $inputname, $uname){
let $message := 
  <mail>
    <from>TLS &lt;tls@hxwd.org&gt;</from>
    <to>{$user-id}</to>
    <bcc>cwittern@gmail.com</bcc>
    <subject>TLS Account created</subject>
    <message>
      <xhtml>
           <html>
               <head>
                 <title>Somebody has used your email alias to register for the TLS database</title>
               </head>
               <body>
                <h2>Dear {$inputname}</h2> 
                 <p>The account you requested for the TLS database has been approved.</p>
                 <p>You can now log into your new account at  <a href="https://hxwd.org/">TLS database</a>, using the login name <b>{$uname}</b> and the password you previously set.</p>
               </body>
           </html>
      </xhtml>
    </message>
  </mail>
return
if ( mail:send-email($message, (), ()) ) then
(  <h1>Sent Message OK :-)</h1>,
  log:info($sgn:log, "Sent welcome mail, " || $user-id)
)
else
  <h1>Could not Send Message :-(</h1>
};

declare function sgn:send-reminder-mail($user-id){
let $nu-path := '/db/groups/tls-admin/new-users/'
(:for $m in collection('/db/groups/tls-editor')//mail[contains(.,$l)]:)
for $m in collection($nu-path)//user[@id=$user-id]
let $u:= $m/ancestor::user
, $s := $u//verified/@status
, $uname := $u//name
, $pw := $u//password
, $fn := $u//fullName
where $s = 'processed'

let $message := 
  <mail>
    <from>TLS &lt;tls@hxwd.org&gt;</from>
    <to>{$user-id}</to>
    <bcc>cwittern@gmail.com</bcc>
    <subject>TLS Account created</subject>
    <message>
      <xhtml>
           <html>
               <head>
                 <title>Reminder from the TLS database</title>
               </head>
               <body>
                <h2>Dear {$fn}</h2> 
                 <p>You have requested a reminder of the details to get in the system.</p>
                 <p>You can now log into your new account at  <a href="https://hxwd.org/">TLS database</a>, using the login name <b>{$uname}</b> and the key {$pw}.</p>
                 <p>All the best, <br/>TLS administrator</p>
               </body>
           </html>
      </xhtml>
    </message>
  </mail>
return
if ( mail:send-email($message, (), ()) ) then
(  <h1>Sent Message OK :-)</h1>,
  log:info($sgn:log, "Sent reminder mail, " || $user-id)
)
else
  <h1>Your email has not been found in the system. </h1>
};



declare function sgn:send-verification-mail($user-id, $url-safe-token, $shared-secret, $inputname){
let $message := 
  <mail>
    <from>TLS &lt;tls@hxwd.org&gt;</from>
    <to>{$user-id}</to>
    <bcc>cwittern@gmail.com</bcc>
    <subject>TLS Registration</subject>
    <message>
      <xhtml>
           <html>
               <body>
                <h2>Dear {$inputname}</h2> 
                 <p>Somebody has used your email alias to register for the TLS database</p>
                  <p>If you did not request an account for the tls, than please ignore this message.</p>
                  <p>If, on the other hand, you <b>did</b> apply for a user account, than please click on the following link to verify your address and confirm that you are indeed interested in collaborating on the TLS.</p>
                  <p><a href="https://hxwd.org/sgn-verify.html?token={$url-safe-token}&amp;uid={$shared-secret}&amp;user={$user-id}">Click here to verify you account.</a></p>
                  <p>This link is valid for two hours, after which it will expire.</p>
               </body>
           </html>
      </xhtml>
    </message>
  </mail>
return
if ( mail:send-email($message, (), ()) ) then
(  <h1>Sent Message OK :-)</h1>,
  log:info($sgn:log, "Sent verification, " || $user-id)
)
else
  <h1>Could not Send Message :-(</h1>
};
(: When the user clicks your validate-signup URL, you take the userId  from the token and lookup the previous timestamp and shared-secret from the database. You repeat the process above but using the values from the database, you then compare the two url-safe-tokens to see if they are equal :)

(:
declare variable $message {
  <mail>
    <from>John Doe &lt;sender@domain.com&gt;</from>
    <to>cwittern@yahoo.com</to>
    <cc>cwittern@gmail.com</cc>
    <subject>A new task is waiting your approval</subject>
    <message>
      <text>A plain ASCII text message can be placed inside the text elements.</text>
      <xhtml>
           <html>
               <head>
                 <title>HTML in an e-mail in the body of the document.</title>
               </head>
               <body>
                  <h1>Testing</h1>
                  <p>Test Message 1, 2, 3</p>
               </body>
           </html>
      </xhtml>
    </message>
  </mail>
};

if ( mail:send-email($message, (), ()) ) then
  <h1>Sent Message OK :-)</h1>
else
  <h1>Could not Send Message :-(</h1>
:)

(: TODO save the application, notify reviewers.   write review function :)


declare function sgn:verify($node as node()*, $model as map(*), $token, $uid, $user){
(:<p>{sgn:compare-token( $token, $shared-secret, $user-id)}</p>:)
<div>
<p></p>
<p><strong>{if (sgn:compare-token( $token, $uid, $user) = "Success") then 
let $status :=  <verified status="true"/>
, $doc := doc("/db/groups/tls-admin/new-users/" || $uid|| ".xml")
, $upd := update replace $doc//verified with $status
, $log := log:info($sgn:log, "Verification received, " || $user || "s: " || $uid)
return
"Verifycation of your email was successful. We will now review your application and notify you of the result.  This may take some time, so please be patient."
else "Verification of your email not successful.  Please try to register again. "
}</strong></p>
</div>
};

declare function sgn:review(){
let $reviewer := sm:id()//sm:real/sm:username/text()
, $visit := lvs:record-visit(<seg xmlns="http://www.tei-c.org/ns/1.0" textid="sgn:review" xml:id="sgn:review">{$reviewer}</seg>)
return
<div>
<h3>Review of account requests</h3>
<p>Please review the information and if you approve of granting access to the TLS, please click on approve. Every member of the group tls-editor has one vote.</p>
<div class="row">
<div class="col-md-1"> 
<span class="font-weight-bold">Full Name</span>
</div>
<div class="col-md-1"> 
<span class="font-weight-bold">Name</span>
</div>
<div class="col-md-2"> 
<span class="font-weight-bold">Area of interest</span>
</div>
<div class="col-md-2"> 
<span class="font-weight-bold">Affiliation</span>
</div>
<div class="col-md-2"> 
<span class="font-weight-bold">Contributions</span>
</div>
<div class="col-md-2"> 
<span class="font-weight-bold">Website</span>
</div>
<div class="col-md-2"> 
<span class="font-weight-bold">Approve</span>
</div>
</div>
{
for $u in collection("/db/groups/tls-admin/new-users")//verified[@status='true']
let $m := $u/parent::more/ss/text()
, $name := $u/ancestor::user//fullName/text()
, $sname := $u/ancestor::user//name/text()
, $doc := doc("/db/groups/tls-editor/users/" || $m || ".xml")
return
<div class="row" id="{$m}">
<div class="col-md-1 "> 
<span>{$name}</span>
</div>
<div class="col-md-1"> 
<span>{$sname}</span>
</div>
<div class="col-md-2"> 
<span>{$doc//area}</span>
</div>
<div class="col-md-2"> 
<span>{$doc//inst}</span>
</div>
<div class="col-md-2"> 
<span>{$doc//cont}</span>
</div>
<div class="col-md-2"> 
<span>{$doc//url}</span>
</div>
<div class="col-md-2"> 
<button type="button" class="btn btn-primary" onclick="sgn_approve('{$m}', '{$reviewer}')">Approve</button>
{if (lpm:can-delete-applications()) then (
<button type="button" class="btn btn-danger" onclick="sgn_approve('{$m}',
'DELETE')">Delete</button>) else ()}
<br/>
<span>Votes: {count(distinct-values(tokenize($doc//approved/@resp, ";")))}</span>
</div>
<hr/>
</div>
}
</div>
};

(: this needs to be run by the admin, the user is created etc.  maybe also schedule for a cron job? :)
(: we will need to make the user info access more restricted! :)
declare function sgn:approve($map as map(*)){
let $doc := doc("/db/groups/tls-editor/users/" || $map?uuid || ".xml")
, $appr := $doc//approved
  return
  if ($map?resp = 'DELETE') then 
  (: need to put this on record somewhere :)
  try {(
   xmldb:remove("/db/groups/tls-admin/new-users", $map?uuid || ".xml")  
   ,xmldb:remove("/db/groups/tls-editor/users/", $map?uuid || ".xml")
   )} catch * {()}
   else 
 let $resp := if ($appr/@resp) then $appr/@resp || ";#" || $map?resp else "#" || $map?resp 
, $u := if ($appr/@resp) then update delete $appr/@resp else () 
, $u2 := update insert attribute resp {$resp} into $appr
, $sss := sgn:check-approved()
return
"Success"
};

declare function sgn:check-approved(){
let $vs := collection("/db/groups/tls-admin/new-users")//verified[@status='true']
for $u in $vs
let $m := $u/parent::more/ss/text()
, $name := $u/ancestor::user//fullName/text()
, $uname := $u/ancestor::user//name/text()
, $doc := doc("/db/groups/tls-editor/users/" || $m || ".xml")
, $user-id := $doc//mail/text()
, $cnt := count(distinct-values(tokenize($doc//approved/@resp, ";")))
let $status :=  <verified status="processed"/>

return
if ($cnt > 0) then (
sgn:create-user($m),
update replace $u with $status,
sgn:send-welcome-mail($user-id, $name, $uname)
) else ()
};

declare function sgn:create-user($uuid as xs:string){
    let $doc := doc("/db/groups/tls-admin/new-users/" || $uuid|| ".xml")
    let $user := $doc/user
    let $username := $user//name/text(),
    $checkuser := if (string-length($username) != string-length(replace($username, '[^@.A-Za-z0-9]', ''))) then "Wrong" else "OK",
    $fullName := $user//fullName/text(),
    $description := $user//description/text(),
    $password := $user//password/text(),
    $disabled := false(),
    $umask := xs:int($user//umask),
    $primary-group := string($user//group/@name),
    $groups := tokenize($user//group/text(), ","),
    $gres := for $g in ($primary-group, $groups)
             return sm:group-exists($g) or sm:create-group($g),
    $home := xmldb:collection-available($sgn:userhome) or xmldb:create-collection("/db", "users"),
    $usercoll := $sgn:userhome || "/" || $username,
    $res := if ($checkuser = 'OK') then (
        sm:user-exists($username) or            
        sm:create-account($username, $password, $primary-group, $groups, $fullName, $description),
        if($disabled)then
            sm:set-account-enabled($username, false())       (: TODO add as an arg to secman:create-user function :)
        else(),
        sm:set-umask($username, $umask),
        xmldb:collection-available($usercoll) or xmldb:create-collection($sgn:userhome, $username),
        sm:chmod(xs:anyURI($usercoll), "rwxrwxr--"),
        sm:chgrp(xs:anyURI($usercoll), "tls-user"),
        sm:chown(xs:anyURI($usercoll), $username),
 log:info($sgn:log, "User account for '"||$username||"' created.")        
        ) else 
        (log:info($sgn:log, "User name '"||$username||"' invalid, could not create account."))
    return
        $username

};

declare function sgn:send-mail(){
let $mail-handle := mail:get-mail-session
  (
    <properties>
      <property name="mail.smtp.host" value="hxwd.org"/>
      <property name="mail.smtp.port" value="25"/>
      <property name="mail.smtp.auth" value="false"/>
      <property name="mail.smtp.allow8bitmime" value="true"/>
    </properties>
  )
  return ()
 };