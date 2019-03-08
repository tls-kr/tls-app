xquery version "3.1";

module namespace tlsapi="http://hxwd.org/tlsapi"; 

import module namespace config="http://hxwd.org/config" at "../modules/config.xqm";

declare namespace tei= "http://www.tei-c.org/ns/1.0";
declare namespace tls="http://hxwd.org/ns/1.0";
declare namespace tx = "http://exist-db.org/tls";


declare function tlsapi:swl-dialog($swl as node(), $type as xs:string, $title as xs:string, $word as xs:string){

<div id="editSWLDialog" class="modal" tabindex="-1" role="dialog" style="display: none;">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                {if ($type = "concept") then
                <h5 class="modal-title">{$title} <strong class="ml-2"><span id="{$type}-query-span">{$word}</span></strong>
                    <button class="btn badge badge-primary ml-2" type="button" onclick="get_guangyun()">
                        廣韻
                    </button>
                </h5>
                else if ($type = "swl") then
                <h5 class="modal-title">{$title} <strong class="ml-2"><span id="{$type}-query-span">{$swl//tei:form/tei:orth/text()}</span></strong>
                </h5>
                else
                <h5 class="modal-title">Adding SW to concept <strong class="ml-2"><span id="{$type}-query-span">{$word}</span></strong></h5>
                }
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    ×
                </button>
            </div>
            <div class="modal-body">
                {if ($type = ("concept", "swl")) then
                (<h6 class="text-muted">At:  <span id="concept-line-id-span" class="ml-2">{tokenize(substring($swl//tei:link/@target, 2), " #")[1]}</span></h6>,
                <h6 class="text-muted">Line: <span id="concept-line-text-span" class="ml-2">{$swl//tls:srcline/text()}</span></h6>
                ) else () }
                <div>
                   {if ($type = ("concept", "swl")) then
                    <span id="concept-id-span" style="display:none;">{data($swl/@xml:id)}</span>
                    else 
                    <span id="word-id-span" style="display:none;"/>
                    }
                    <span id="synfunc-id-span" style="display:none;">{data($swl//tls:syn-func/@corresp)=>substring(2)}</span>
                    <span id="semfeat-id-span" style="display:none;">{data($swl//tls:sem-feat/@corresp)=>substring(2)}</span>
                    
                </div>
                   {if ($type = "concept") then 
                <div class="form-group" id="guangyun-group">                
                    <span class="text-muted" id="guangyun-group-pl"> Press the 廣韻 button above and select the pronounciation</span>
                </div> else if ($type = "swl") then
                <div class="form-group" id="guangyun-group">     
                   {tlsapi:get-guangyun($swl//tei:form/tei:orth/text(), $swl/tei:form/tei:pron[@xml:lang="zh-Latn-x-pinyin"]/text())}
                </div>
                else (),
                if ($type = ("concept", "swl")) then
                <div id="select-concept-group" class="form-group ui-widget">
                    <label for="select-concept">Concept: </label>
                    <input id="select-concept" class="form-control" required="true" value="{data($swl/@concept)}"/>
                </div>
                    else ()}                
                <div class="form-row">
                <div id="select-synfunc-group" class="form-group ui-widget col-md-6">
                    <label for="select-synfunc">Syntactic function: </label>
                    <input id="select-synfunc" class="form-control" required="true" value="{data($swl//tei:sense/tei:gramGrp/tls:syn-func/text())}"/>
                </div>
                <div id="select-semfeat-group" class="form-group ui-widget col-md-6">
                    <label for="select-semfeat">Semantic feature: </label>
                    <input id="select-semfeat" class="form-control" value="{data($swl//tei:sense/tei:gramGrp/tls:sem-feat/text())}"/>
                </div>
                </div>
                <div id="input-def-group-{$type}">
                    <label for="input-{$type}-def">Definition </label>
                    <textarea id="input-{$type}-def" class="form-control">{data($swl//tei:sense/tei:def/text())}</textarea>                   
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                   {if ($type = "concept") then 
                <button type="button" class="btn btn-primary" onclick="save_to_concept()">Save changes</button>
                else if ($type = "swl") then
                <button type="button" class="btn btn-primary" onclick="save_swl()">Save SWL</button>
                else                
                <button type="button" class="btn btn-primary" onclick="save_newsw()">Save SW</button>
                }
            </div>
        </div>
    </div>    
    <!-- temp -->
    
</div>    
};

declare function tlsapi:get-guangyun($chars as xs:string, $pron as xs:string){

for $char at $cc in  analyze-string($chars, ".")//fn:match/text()
return
<div id="guangyun-input-dyn-{$cc}">
<h5><strong class="ml-2">{$char}</strong></h5>
{
for $g at $count in collection(concat($config:tls-data-root, "/guangyun"))//tx:attested-graph/tx:graph[contains(.,$char)]
let $e := $g/ancestor::tx:guangyun-entry,
$p := for $s in $e//tx:mandarin/* 
       return 
       if (string-length(normalize-space($s)) > 0) then $s else (),
$py := normalize-space(string-join($p, ';'))
return

<div class="form-check">
   { if (contains($py, $pron)) then
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}" checked="checked"/>
   else
   <input class="form-check-input guangyun-input" type="radio" name="guangyun-input-{$cc}" id="guangyun-input-{$cc}-{$count}" 
   value="{$e/@xml:id}"/>
   }
   <label class="form-check-label" for="guangyun-input-{$cc}-{$count}">
     {$e/tx:gloss/text()} -  {$py}
   </label>
  </div>
}
</div>
};
