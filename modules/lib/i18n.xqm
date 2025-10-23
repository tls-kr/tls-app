xquery version "3.1";

(:~
 : Library module internationalization
 :
 : @author Christian Wittern
 : @date 2024-11-20
 :)

module namespace i18n="http://hxwd.org/lib/i18n";


import module namespace config="http://hxwd.org/config" at "../config.xqm";


import module namespace tlslib="http://hxwd.org/lib" at "../tlslib.xql";


(: this module will get the desired language from a global configuration or the browser session and will select  the appropriate files  :)

(: url for github issues  https://api.github.com/repos/tls-kr/tls-app/issues?labels=RFC 
this returns JSON that can be parsed and injected in the page.
:)

declare function i18n:welcome-message(){
let $user := sm:id()//sm:real/sm:username/text()
  , $r := tlslib:recent-texts-list(10)
return
<div>
     {if ($user = 'guest') then collection($config:tls-app-interface)//div[@xml:id='for-guests']
     else
        <div>
         <h3>Welcome back!</h3>

         <ul>{for $l in $r return $l}</ul>
                <p>
                    Please acknowledge your use of TLS in your publications.
                </p>                
        </div>
      }  
      <p><a href="browse.html?type=welcome">Browse the database </a></p>
<p>
     <span class="text-danger">This website is under development.</span>
        </p>
        <p>Problems and suggestions can be reported and discussed also on <a href="https://github.com/tls-kr/tls-app/issues">GitHub Issues</a></p>
        <hr/>
</div>
};

declare function i18n:display($map as map(*)){
collection($config:tls-app-interface)//div[@xml:id=$map?id]
};