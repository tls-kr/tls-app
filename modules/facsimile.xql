xquery version "3.1";
(:~
: This module provides display of digital facsimiles, centered on IIIF 
: 2022-11-07
: @author Christian Wittern  cwittern@yahoo.com
: @version 1.0
:)

module namespace fac="http://hxwd.org/facsimile"; 

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://hxwd.org/config" at "config.xqm"; 
import module namespace tlslib="http://hxwd.org/lib" at "tlslib.xql";
import module namespace http="http://expath.org/ns/http-client";


(: https://21dzk.l.u-tokyo.ac.jp/SAT2018/T0314.html?manifest=https://dzkimgs.l.u-tokyo.ac.jp/iiif/taisho/manifests/2185_56_manifest.json&canvas=https://dzkimgs.l.u-tokyo.ac.jp/iiif/taisho/manifests/canvas/56_0001.json :)


(: URL for T56n2185 
https://21dzk.l.u-tokyo.ac.jp/SAT2012/ddb-bdk-sat2.php?mode=detail&mode4=&nonum=&kaeri=&useid=2185_,56,0001a01&ob=1&mode2=2&_=1667785132549

Get text for T82n2582, starting at 16a01

https://21dzk.l.u-tokyo.ac.jp/SAT2012/ddb-bdk-sat2.php?mode=detail&nonum=&kaeri=&mode2=2&ob=1&mode4=&useid=2582_,82,0016a01

The response will be a text chunk, within the range of the db, which seems to include an overlap of one page. When asking for the next section beginning at the line following the last line, it will include the current page.  The above will go to 22c29; asking for 23a01 will start at 22a01 and run to 25c29
in this case, the last line starts with 0307a01
https://21dzk.l.u-tokyo.ac.jp/SAT2012/ddb-bdk-sat2.php?mode=detail&nonum=&kaeri=&mode2=2&ob=1&mode4=&useid=2582_,82,0307a01

for the latest and greatest version, with better unicode repr, this would be:

First page:
https://21dzk.l.u-tokyo.ac.jp/SAT2018/satdb2018pre.php?mode=detail&mode4=&nonum=&kaeri=&useid=2582_,82&ob=1&mode2=2
Last Page
https://21dzk.l.u-tokyo.ac.jp/SAT2018/satdb2018pre.php?mode=detail&mode4=&nonum=&kaeri=&useid=2582_,82,0306c18&ob=1&mode2=2

Referer: https://21dzk.l.u-tokyo.ac.jp/SAT2018/master30.php

This will give links to other web resources:
https://21dzk.l.u-tokyo.ac.jp/SAT2018/satdb2018pre.php?mode=owr&useid=2582_,82

And this is for CDL:
https://21dzk.l.u-tokyo.ac.jp/SAT2018/satdb2018pre.php?mode=owr&useid=2076_,52

For Taisho texts: show external link to  https://21dzk.l.u-tokyo.ac.jp/SAT2018/T<tno>.html

:)