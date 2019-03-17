xquery version "3.1";

(: inspired by functx, but slightly adopted :)

module namespace functx = "http://www.functx.com";
declare function functx:index-of-string
  ( $arg as xs:string? ,
    $substring as xs:string )  as xs:integer* {

  if (contains($arg, $substring))
  then (string-length(substring-before($arg, $substring))+1,
        for $other in
           functx:index-of-string(substring-after($arg, $substring),
                               $substring)
        return
          $other +
          string-length(substring-before($arg, $substring)) +
          string-length($substring))
  else ()
};
