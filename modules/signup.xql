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

declare function sgn:make-token(){
(: in your database for validation purposes, you need to store: <user-id> -> (<timestamp>, <shared-secret>) :)
let $secure-salt := util:hash("your-secret-salt", "sha-256")
let $timestamp := util:system-dateTime() (: you need to store this for later validating the token:)
let $shared-secret := util:uuid()  (: you need to store this for later validating the token:)
let $unsecure-token := $secure-salt || ":" || $user-id || ":" || $timestamp || ":" || $shared-secret
let $secure-token := util:hash($unsecure-token, "sha-256")
let $url-safe-token := util:base64-encode($secure-token)
return

   $url-safe-token
    
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