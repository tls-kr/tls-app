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


declare function sgn:make-token($user-id, $ss){
(: in your database for validation purposes, you need to store: <user-id> -> (<timestamp>, <shared-secret>) :)
let $secure-salt := util:hash("your-secret-salt", "sha-256")
let $timestamp := util:system-dateTime() (: you need to store this for later validating the token:)
(:let $shared-secret := util:uuid()  (\: you need to store this for later validating the token:\):)
let $unsecure-token := $secure-salt || ":" || $user-id || ":" || $timestamp || ":" || $ss
let $secure-token := util:hash($unsecure-token, "sha-256")
let $url-safe-token := util:base64-encode($secure-token)
let $save-secret :=  <user id="{$user-id}" time-stamp="{$timestamp}" utoken="{$unsecure-token}" ust="{$url-safe-token}"></user>
let $send-message := sgn:send-verification-mail($user-id, $url-safe-token, $ss)
return

   $save-secret
    
};

declare function sgn:sgn-received($node as node()*, $model as map(*), $answer , $inputname, $inputnname, $inputpw1, $inputpw2, $inputmail, $inputarea, $inputinst, $inputcont, $ss, $vk){
let $res := xs:int($answer)
, $corr := xs:int(156)
return
if ($res = $corr) then
<div>
<h1>Congratulations!</h1>
<p>Correct answer. The first step to registration has been cleared.  You will receive a mail with a signup-link to verify your mail adress.  Please click on that link within 2 hours, or you will have to repeat the process.  If you did not receive the mail, look into your spam folder.  </p>
{sgn:store-new-user($inputname, $inputnname, $inputpw1, $inputpw2, $inputmail, $inputarea, $inputinst, $inputcont, $ss, $vk)}
</div>
else 
<p>{$answer}: Wrong answer.  Go back and try again.</p>
};

declare function sgn:store-new-user($inputname, $inputnname, $inputpw1, $inputpw2, $inputmail, $inputarea, $inputinst, $inputcont, $ss, $vk){
let $newuser := <user>
 <account>
 <name>{$inputnname}</name>
 <fullName>{$inputname}</fullName>
 <description>TLS User</description>
 <password>{$inputpw1}</password>
 <group name="tls-user"></group>
 <umask>022</umask>
 </account>
 <mail>{$inputmail}</mail>
 <area>{$inputarea}</area>
 <inst>{$inputinst}</inst>
 <cont>{$inputcont}</cont>
 <more>
 <ss>{$ss}</ss>
 <tk>{sgn:make-token($inputmail, $ss)}</tk>
 </more>
</user>
, $nu := xmldb:store("/db/groups/tls-admin/new-users", $ss|| ".xml",$newuser)
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

declare function sgn:send-verification-mail($user-id, $url-safe-token, $shared-secret){
let $message := 
  <mail>
    <from>TLS &lt;tls@hxwd.org&gt;</from>
    <to>{$user-id}</to>
    <cc>cwittern@gmail.com</cc>
    <subject>TLS Registration</subject>
    <message>
      <xhtml>
           <html>
               <head>
                 <title>Somebody has used your email alias to register for the TLS database</title>
               </head>
               <body>
                  <p>If you did not request an account for the tls, than please ignore this message.</p>
                  <p>If, on the other hand, you <b>did</b> apply for a user account, than please click on the following link to verify your address and confirm that you are indeed interested in collaborating on the TLS.</p>
                  <p><a href="https://hxwd.org/verify.html?token={$url-safe-token}&amp;uid={$shared-secret}&amp;user={$user-id}">Click here to verify you account.</a></p>
                  <p>This link is valid for two hours, after which it will expire.</p>
               </body>
           </html>
      </xhtml>
    </message>
  </mail>
return
if ( mail:send-email($message, (), ()) ) then
  <h1>Sent Message OK :-)</h1>
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


declare function sgn:verify($node as node()*, $model as map(*), $token, $shared-secret, $user-id){
(:<p>{sgn:compare-token( $token, $shared-secret, $user-id)}</p>:)
<div>
<p></p>
<p><strong>{if (sgn:compare-token( $token, $shared-secret, $user-id) = "Success") then "Verifycation of your email was successful. We will now review your application and notify you of the result.  This may take some time, so please be patient." else "Verification of your email not successful.  Please try to register again. "}</strong></p>
</div>
};

declare function sgn:review($node as node()*, $model as map(*), $uid ){
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