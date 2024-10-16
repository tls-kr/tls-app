// var containsJapanese = string.match(/[\u3400-\u9FBF]/);
var dirty = false;
var cancelmove = false;
var currentline = "";
var current_id = "";
var leftword = "";
var lw_id = "";
var lwobj = {};
var lwpos = 0;
$(function() {
    console.log( "ready!" );
    try {
     $("#blue-eye").attr("title", "Press here to show annotations.");
    } catch (err) {}
    // this is for the taxchar editing
    try { 
    // it seems this does not work... but the uncaught error does not seem to matter...
    // a few weeks later... this works!!
    if ( $( "#chartree" ).length ) {
     $('#chartree').jstree({
     "core" : {
       // so that create works
       "check_callback" :  true 
       },
     "plugins" : ["dnd", "contextmenu" ]
     });
    }
} finally {}    
    set_keyup ();
    set_currentline("mark");
    var pbx = window.localStorage.getItem('display-pastebox');
    if (pbx) {
        display_pastebox(pbx);
    }
    // only relevant for search pages
    krx_itemcount();
    // only relevant for textview pages
    get_swls();
});            



if (!window.x) {
    x = {};
}
// this is some plumbing to get the selection
x.Selector = {};
x.Selector.getSelected = function() {
    var t = '';
    if (window.getSelection) {
        t = window.getSelection ();    
    } else if (document.getSelection) {
        t = document.getSelection();
    } else if (document.selection) {
        t = document.selection.createRange().text;
    }
    return t;
};

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function get_text_line(tabidx){
    var nid = "" 
    try {
      tid = $("[tabindex='" + tabidx.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '').split(".").join("\\.");
    } catch (err) {
      ntab = tabidx - 1
      nid = $("[tabindex='" + ntab.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '').split(".").join("\\.");
      more_display_lines(nid, tabidx );                
      return $("#" + nid).text();
    }
//    console.log("tid:", tid, nid);
    return $("#" + tid).text();
}

function set_currentline(newid){
var nl = "";
$('#current-line').text("");
if (newid === "mark"){
    try {
    current_id = $(".mark:first > .zh").attr('id').split(".").join("\\.");
    } catch (err) {}
} else {
    current_id = newid.split(".").join("\\.")
    cp = $("#" + current_id).parent();
    $(".mark:first").removeClass("mark");
    cp.addClass("mark")
}   
 tab = parseInt($("#"+current_id+"-slot1").attr("tabindex")) + 1;
    try {
      currentline = $('#' + current_id).text();
      tid = $("[tabindex='" + tab.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '').split(".").join("\\.");
      nl = $("#" + tid).text();
    } catch (err) {
    }
//    console.log("tid:", tid, nid);
/*    $.when(get_text_line(tab)).then(function (r){
        nl = r;
    }, function (r){
        nl = ""
    })*/
 $('#current-line').html('<span class="font-weight-bold">'+currentline+'</span>'+nl)
 console.log("Currentid:", current_id, "Currentline: ", currentline, nl);
};


function set_leftword(obj){
  var tsel = window.getSelection();
  var r = [tsel.anchorOffset, tsel.focusOffset]
  lwpos = Math.min.apply(Math, r) + 1;
  var end = Math.max.apply(Math, r);
  lw_id = tsel.anchorNode.parentNode.id.toString();
  lwobj = obj
  var line = tsel.anchorNode.parentNode.innerText;
  leftword = line.substring(lwpos - 1, end)
//  $("#"+lw_id.split(".").join("\\.")).html(line.substring(0, lwpos - 1)+ "<span class='highlight'>" + leftword + "</span>" + line.substring(end))
  $( "#swl-form" ).hide()
  toastr.info("Now select the right word and then set the relation type.", "漢學文典 says:");
  
};

// the highlight throws the offset off, so I have to remove the element before getting the right word

function set_rightword(obj){
//  $(".highlight").removeClass("highlight");
  var tsel = window.getSelection();
  var r = [tsel.anchorOffset, tsel.focusOffset]
  var pos = Math.min.apply(Math, r) + 1;
  var end = Math.max.apply(Math, r);
  var rw_id = tsel.anchorNode.parentNode.id.toString();
  var line = tsel.anchorNode.parentNode.innerText;
  var rightword = line.substring(pos - 1, end)
  console.log("rw", rightword)
  console.log("tset", tsel)
  console.log("lwpos, rwpos", lwpos, pos)
  $( "#swl-form" ).hide()
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?func=dialogs:word-rel-dialog&lw="+leftword+"&lwlineid="+lw_id+"&lwconcept="+lwobj.concept+"&lwconceptid="+lwobj.concept_id+"&lwwid="+lwobj.wid+"&rw="+rightword+"&rwlineid="+rw_id+"&rwconcept="+obj.concept+"&rwconceptid="+obj.concept_id+"&rwwid="+obj.wid+"&rwoffset="+pos+"&lwoffset="+lwpos, 
  success : function(resp){

    $('#remoteDialog').html(resp);
    $('#word-rel-dialog').show();
    
   }
  })  
};

function change_word_rel(wrid){
    $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=change-word-relation&wrid="+ wrid, 
     success : function(resp){
     if (resp.length > 2){
         toastr.info(resp, "HXWD says:");     
     } else {
         $('#'+wrid).html("");
         toastr.info("Word relation has been moved.", "漢學文典 says:");     
     }
   }
  })  
}

function save_wr(obj){
  obj.relid = $("#rel-type").val()
  obj.note_inst = $("#note-inst").val()
  obj.note = $("#input-note").val()
  $.get(
   "api/responder.xql?func=save-wr", obj,
    function(resp){
    $('#word-rel-dialog').hide();
    toastr.info("Relation type has been saved.", "漢學文典 says:");
    remove_highlight();
   })
};

function delete_word_relation(wrid){
    $.ajax({
     type : "GET",
     dataType : "json",  
     url : "api/responder.xql?func=delete-word-relation&wrid="+ wrid, 
     success : function(resp){
     if (resp[0].startsWith("Error")){
         toastr.error(resp, "HXWD says:");     
     } else {
         $('#'+wrid).html("");
        resp.forEach((el)=> {
         line_id = el.replace(/"/g, '')
         show_swls_for_line(line_id);
        })
        toastr.info("Word relation has been deleted.", "漢學文典 says:");     
     }
   }
  })  
};

function reset_leftword(){
  remove_highlight()
  $( "#swl-form" ).hide()
  $( "#word-rel-dialog" ).hide()
};


function remove_highlight(){
 $(".highlight").removeClass("highlight");
 lw_id = "";
 leftword = "";
 lwobj = {};
 lwpos = 0;
 document.getSelection().removeAllRanges(); 
};

function page_move(target){
    var url = "?location="+target;
    console.log("page_move");
    console.log(cancelmove);
    if (cancelmove === false){
       window.location = url;
    } else {
       toastr.info("Cancelling move to store data. Please press button again.", "HXWD says:")          
    }
    // need to reset this at some point :-)
    cancelmove = false;

}

// get search info from krx
function krx_itemcount(){
  var location = window.location.search;
  $.ajax({
  type : "GET",
  dataType : "json",
  url : "krx/itemcount"+location, 
  success : function(resp){
    console.log("here");
    sleep(3000);
    console.log(resp);
    $('#krx_search').html(resp);
  }
  });
};

function krx_items(){
  var location = window.location.search;
  $.ajax({
  type : "GET",
  dataType : "json",
  url : "/krx/items"+location, 
  success : function(resp){
    $('#show_text_results').html(resp);
  }
  });
};



function get_swls(){
    $(".swlid").each(function () {
    var swid = $(this).attr('id');
    var line_id = swid.substr(0, swid.length - 4)
    show_swls_for_line(line_id);
    });
}

function test_segs1(){
    $(".swlid").each(function () {
    var sw = $(this).attr('id');
  $.ajax({
  type : "GET",
  dataType : "json",
  url : "api/get_swl_for_page.xql"+location, 
  success : function(resp){
  for (index = 0; index < resp.length; ++index) {
    console.log(resp[index]['id']);
  };
  $('#toprow').html(resp);
  }
  });
    console.log(sw)
    })
}

function get_swl_for_page(){
  var location = window.location.search;
/*  var url = new URL(context);
  var location = url.searchParams.get("location")*/
  console.log(location)
  $.ajax({
  type : "GET",
  dataType : "json",
  url : "api/get_swl_for_page.xql"+location, 
  success : function(resp){
  for (index = 0; index < resp.length; ++index) {
    console.log(resp[index]['id']);
  };
  $('#toprow').html(resp);
  }
  });
};

function hide_pastebox(){
  $('#pastebox').hide();    
   lines = $('#input-pastebox').val()
   window.localStorage.setItem('pastebox', lines);
   window.localStorage.removeItem('display-pastebox');  
   $('#remoteDialog').html("");
}
// save the line and move to the next line
function save_pastebox_line(){
    var nl = "";
    $('#current-line').html('');
    var lines = $('#input-pastebox').val().split('\n');//gives all lines
    var firstLine=lines[0];
    var remainingLines = lines.slice(1,).join('\n');
    // console.log('firstLine:',firstLine);
    $('#'+current_id+"-slot1").html(firstLine);
    thisid = current_id.replaceAll("\\", "")
    save_tr(thisid+"-slot1", firstLine, currentline);
    tab = parseInt($("#"+current_id+"-slot1").attr("tabindex")) + 1;
    ntab = tab + 1
    // console.log("Tab: ", "[tabindex='" + tab.toString() + "']")
    $('#input-pastebox').val(remainingLines);
    window.localStorage.setItem('pastebox', remainingLines);
    // cf https://stackoverflow.com/questions/51933513/jquery-usage-of-done-then-and-when-for-making-ajax-requests-in-a-giv
    $.when(get_text_line(ntab)).then(function (r){
       tid = $("[tabindex='" + ntab.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '').split(".").join("\\.");
       nl = $("#" + tid).text();
       set_keyup ();
       // console.log("when:r", r, nl);
       nextid = $("[tabindex='" + tab.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '');
       set_currentline(nextid)
       $('#current-line').html('<span class="font-weight-bold">'+currentline+'</span>'+nl);
    }, function (r){
        nl = ""
    })
//        more_display_lines(current_id, tab );        
//        $('#current-line').text(currentline)
};

//display the Pastebox
function display_pastebox(slot){
  var dw = document.documentElement.clientWidth;
  var dh = document.documentElement.clientHeight - 51;
  var new_width = $("#toprow").outerWidth() - $("#toprow-1").outerWidth() - $("#toprow-2").outerWidth() + $("#chunkcol-right").outerWidth();
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?func=dialogs:pastebox", 
  success : function(resp){
    var new_height = $("#"+slot).outerHeight();
    var new_width = $("#"+slot).outerWidth();
    var remainingLines = window.localStorage.getItem('pastebox');
    window.localStorage.setItem('display-pastebox', slot)
    //var targetline = document.getElementById( currentline.slice(-3) ).innerText;

    $('#remoteDialog').html(resp);
    $('#pastebox').width(new_width);
    $('#pastebox').height(dh / 2);
    $('#pastebox').css({top: dh / 2 + 49})
//    $('#pastebox').position({my: 'bottom right'});
    $('#current-line').html('<span class="font-weight-bold">'+currentline+'</span>')
    $('#input-pastebox').val(remainingLines);    
    $('#input-pastebox').keydown(function(e) {
       if (e.ctrlKey == true) {
       var code = e.keyCode
       if (e.which == 78) { // the key is ctrl-n
          event.preventDefault();
          save_pastebox_line()
        }
      }  
    });
    $('#pastebox').show();
  }
  });
};

//get more lines, once we are at the end of the page
function more_display_lines(lineid, tab){
  cnt = tab - 501;
  np = tab + 29;
  var thisid = lineid.replaceAll("\\", "");
      // avoid adding resp multiple times
  r1 = $("#"+lineid+'-'+cnt.toString()).attr("class");
  console.log("r1", r1, r1 != "row");
  if (r1 != "row"){ 
  toastr.info("Requesting more text lines, please wait a moment.", "HXWD says:")          
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?lineid="+thisid+"&cnt="+cnt+"&func=morelines", 
  success : function(resp){
      $("#"+lineid+"-swl").parent().after(resp);
      console.log("LID", lineid);
      npid = $("[tabindex='" + np.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '')
      $('#nextpagebutton').on('click', function()
        {page_move(npid+'&amp;prec=1&amp;foll=29');}
        )
  }
  });
        }
  
}

/*
      set_keyup ()
      nextid = $("[tabindex='" + tab.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '');
      set_currentline(nextid)
//      $('#current-line').text(currentline)
      $('#current-line').html('<span class="font-weight-bold">'+currentline+'</span>')
      npid = $("[tabindex='" + np.toString() + "']").attr('id').replace(/-slot.|-tr|-ex/, '')
      $('#nextpagebutton').on('click', function()
        {page_move(npid+'&amp;prec=1&amp;foll=29');}
        )

 * 
 */
 
function get_canvas_for_page(slot, myid){
}; 
 
function get_facs_for_page(slot, pbfacs, pbed, segid){
  var location = $('#chunkcol-left').children('div').eq(0).children('div').eq(0).attr('id');
  var dw = document.documentElement.clientWidth;
  var dh = document.documentElement.clientHeight;
  var new_height = $('#chunkcol-left').outerHeight();
  var new_width = $("#top-"+slot).outerWidth();
  var new_left = $("#top-"+slot).position().left;
  $(".ed-"+pbed).show();
  console.log(location, pbed, new_left);
   $.ajax({
   type : "GET",
   dataType : "html",
   url : "api/responder.xql?func=get-facs-for-page&location="+location+"&pb="+pbfacs+"&segid="+segid+"&pbed="+pbed+"&slot="+slot+"&left="+new_left+"&width="+new_width+"&height="+new_height, 
   success : function(resp){
   // xxx###
   $('#fac'+slot).html(resp);
    $('#viewer'+slot).width(new_width);
    $('#viewer'+slot).height(new_height);
    $('#viewer'+slot).css({ 'left' : new_left});
    $('#viewer-wrap-'+slot).show();
    $('#viewer'+slot).show();
   // reload_selector(slot, myid);   
   }
  });
  event.preventDefault()
};

function move_to_page(slot){
    page = $('#current-page-'+slot).html()
    var location = $('#chunkcol-left').children('div').eq(0).children('div').eq(1).attr('id');
    $.get("api/responder.xql?func=move-to-page&page="+page+"&location="+location,
    function(resp){
//      console.log(resp)
      page_move(resp)    
   })
    
//    alert(page)
}

function set_new_tileSources (slot, pb_ed_n, tileSources){
    $('#current-page-'+slot).html(pb_ed_n)
    $('.page-link').removeClass('font-weight-bold')
    $('#'+ pb_ed_n).addClass('font-weight-bold')
    if (slot === 'slot1'){
     viewerslot1.open (tileSources);
    } else {
     viewerslot2.open (tileSources);        
    }
};

// called ftom textview, toprow
// slot is slot1 or slot2, type is 'transl' or 'comm', no is the item number in the list
function get_tr_for_page(slot, myid, ai){
//  var location = window.location.search;
  var location = $('#chunkcol-left').children('div').eq(0).children('div').eq(1).attr('id');
  var foll = $('#chunkcol-left').children('div').length / 2
   $.ajax({
   type : "GET",
   dataType : "html",
   url : "api/get_tr_for_page.xql?location="+location+"&prec=0&foll="+foll+"&slot="+slot+"&content-id="+myid+"&ai="+ai, 
   success : function(resp){
    var obj = JSON.parse(resp);
    for (var prop in obj) {
     line_id = prop.split(".").join("\\.");
     $(line_id).html(obj[prop]);
    }; 
    reload_selector(slot, myid);   
   }
  });
  if (ai = 'undefined') {
  } else {
  toastr.info("Translation draft requested. Please wait a moment.", "HXWD says:")        
  }
};
// called from tranlation dropdown in toprow
// slot is slot1 or slot2, 
function new_translation(slot){
  var location = window.location.search;
  console.log(location)
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/new_translation.xql"+location+"&slot="+slot, 
  success : function(resp){
    $('#remoteDialog').html(resp);
    $('#new-translation-dialog').modal('show');
  
  }
  });
    
};


// called from new tranlation dialog
// slot is slot1 or slot2, 
// 2023-05-27: if trid is present, we are editing metadata for an existing file
function store_new_translation(slot, textid, trid){
  var lang = $('#select-lang').val()
  var transl = $('#select-transl').val()
  var bibl = $('#input-biblio').val()
  var trtitle = $('#select-trtitle').val()
  var rel = $('#select-rel').val()
  var vis = $('input[name=visradio]:checked').val()
  var copy = $('input[name=copradio]:checked').val()
  var type = $('input[name=typradio]:checked').val()
  
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/store_new_translation.xql?lang="+lang+"&textid="+textid+"&transl="+transl+"&trtitle="+trtitle+"&bibl="+bibl+"&vis="+vis+"&copy="+copy+"&type="+type+"&rel="+rel+"&trid="+ trid, 
  success : function(resp){
  // todo : reload the selector with latest information
  $('#new-translation-dialog').modal('hide');
  reload_selector(slot, trid);
  toastr.info("New work has been saved.", "HXWD says:")  
  }
  });
    
};

function reload_selector(slot, newid){
  var location = window.location.search;
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql"+location+"&slot="+slot+"&content-id="+newid+"&func=ltr:reload-selector", 
  success : function(resp){
  $("#top-"+slot).html(resp)
  }
  });    
};

function showhide_passwd(elid) {
//  var x = document.getElementById(elid);
  els = elid.split(",")
  els.forEach((el)=> {
  var x = $("#"+el);
  console.log("x:", x, x.attr('type'), elid)
  if (x.attr('type') === "password") {
    x.attr('type', "text");
  } else {
    x.attr('type', "password");
  }
  })
};

function goto_translation_seg(trid, dir){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?func=goto-translation-seg&trid="+trid+"&dir="+dir, 
  success : function(resp){
    if (resp.length > 0) {
     window.location = resp;
    }
    }
  });        
};

function get_sf(senseid, type){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_sf.xql?senseid=" + senseid + "&type=" + type, 
  success : function(resp){
    $('#remoteDialog').html(resp);
    initialize_sf_autocomplete(type);  
    $('#edit-sf-dialog').modal('show');
  }
  });
};

//cw 2021-10-21
//show or hide the elements with this class attribute
function showhide(cl){
    $("."+cl).toggle()
};

//cw 2021-10-06, revised 2023-12-04
function get_more_lines(el, count){
 var cnt = Number(count)
 $('#' + el +' option[value="none"]').remove();
 if (cnt < 0) { 
  var csel = $('#'+el+' option:first').val();
 } else {
  var csel = $('#'+el+' option:last').val();
 }
 var len = $('#'+el+' option').length; 
//console.log("len select-end: "+csel)
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?func=get-more-lines&cnt="+count+"&len="+len+"&line="+csel,
  success : function(resp){
  console.log(resp)
  if (cnt <0) {
     $('#'+el).prepend(resp)      
  } else {
     $('#'+el).append(resp)
  }
  }
  });
};



function get_guangyun(){
// this is assuming one char, TODO make this work for multiple
var word = $("#swl-query-span").text();
  var ch = $("#input-char").val();
  if (ch){
      w = ch
      $('#guangyun-group').html("")
      gyonly = false
  } else {
      w = word
      gyonly = true
  }
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_guangyun.xql?char=" + w+"&gyonly="+gyonly, 
  success : function(resp){
  console.log(resp)
  $('#guangyun-group').append(resp)
  }
  });
};

function hide_form(form){
  console.log("Hiding ..")
  var f1 = form.replace('-wrap-', '')
  $("#"+form).hide()  
  $("#"+f1).hide()  
  $(".lb").hide();
};

function hide_new_att(){
// restore the search button to its original function
  $('#search-submit' ).attr("type", "submit");
  $( '#search-submit' ).attr("onclick", ""); 
  $("#swl-form").hide()  
};

function hide_swl_form(selector){
    $( selector ).modal('hide');    
    console.log("Clearing SWL form");
    $("#select-synfunc" ).val("");
    $("#select-semfeat").val("");
    $("#select-concept" ).val("");
    $("#input-def" ).val("");
    $("#guangyun-group").html('<span class="text-muted" id="guangyun-group-pl"> Press the 廣韻 button above and select the pronounciation</span>');
};

// show attributions for a certain swl

function show_att(uid){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/show_att.xql?uid=" + uid, 
  success : function(resp){
  $('#'+uid+'-resp').html(resp)
  }
  });
  $('#'+uid+'-resp').html("Searching, please wait...")  
};

function show_wr(uid, extra){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=show-wr&uid=" + uid, 
  success : function(resp){
  $('#'+uid+'-'+extra+'-resp').html(resp)
  }
  });
  $('#'+uid+'-'+extra+'-resp').html("Searching, please wait...")  
};


// show use for sem-feat and syn-func
function show_use_of(type, uid){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/show_use_of.xql?uid=" + uid + "&type=" + type, 
  success : function(resp){
  $('#'+uid+'-resp').html(resp)
  }
  });
};

// This is called after either adding or deleting a SWL to update the display

function show_swls_for_line(line_id){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/show_swl_for_line.xql?line=" + line_id, 
  success : function(resp){
  line_id = line_id.split(".").join("\\.")
//  console.log("Displaying response at: " + '#'+line_id+'-swl');
//  $('#swl-select').html(resp)
  $('#'+line_id+'-swl').html(resp);
  $('#'+line_id+'-swl').show();
  }
  });
    
};

// this saves the SW for a line, called from save_this_swl (from the "Use" button)

function save_swl_line(sense_id, line_id, pos){
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_swl.xql?line="+line_id+"&sense="+sense_id+"&pos="+pos,
  success : function(resp){
  hide_swl_form("#editSWLDialog");
  console.log("Hiding form");
  show_swls_for_line(line_id);
  console.log("Response:", resp)
  if (resp.startsWith("Attribution has")) {
  toastr.info(resp, "HXWD says:")
  } else {
  toastr.error(resp, "HXWD says:")      
  }
  },
  error : function(resp){
    console.log(resp)
    toastr.error("An unknown error happened on the system."+resp, "漢學文典 says:");
  }
  });       
};

// save one attribution: the "Use" button calls this function
function save_this_swl(sense_id){
    var line_id=document.getElementById( "swl-line-id-span" ).innerText;
    var pos = $( "#swl-query-span" ).attr("data-pos");
    save_swl_line(sense_id, line_id, pos);
};

// save edited swl
function save_swl(){
  //not sure what to do here... what kind of changes to we want to allow?  
};

// here we ask for a concept, to combine with a character to form a new SW and then assign a SWL
function show_new_concept(mode, py){
  var word = $("#swl-query-span").text();
  var line_id= $( "#swl-line-id-span" ).text();  
  var line = $( "#swl-line-text-span" ).text();
  if (mode == "new"){
      cname = prompt("Please enter the name of the new concept:", "");
      if (cname){
       var uri = "api/get_swl.xql?type=concept&word="+word+"&concept="+cname+"&line-id="+line_id+"&line="+line;      } 
       else {var uri = null}
  } else if (mode == "existing") {
      var uri = "api/get_swl.xql?type=concept&word="+word+"&mode="+mode+"&line-id="+line_id+"&line="+line;
  } else {
      var uri = "api/get_swl.xql?type=concept&word="+word+"&concept="+mode+"&line-id="+line_id+"&line="+line+"&py="+py;      
  }   
  if (uri){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : uri, 
  success : function(resp){
   if(resp.startsWith("Concept")){
       alert("Concept already exists.")
   } else {
   // lets see if this works better
   if (mode == "existing"){
   $('#remoteDialog').html(resp);
     initialize_autocomplete();
     console.log("Initializing autocomplete functions");
    $('#editSWLDialog').modal('show');       
   } else {
   $('#remDialog2').html(resp);
    initialize_autocomplete_nc();
     console.log("Initializing autocomplete nc functions");
    $('#new-concept-dialog').modal('show');
   }
   }
  }
  });
  }
};

// save one sw OR one new word
function show_newsw(para){
  var word = $("#swl-query-span").text();
  var line_id= $( "#swl-line-id-span" ).text();  
  var line = $( "#swl-line-text-span" ).text();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/get_swl.xql?type=word&concept="+para.concept+"&word="+word+"&wid="+para.wid+"&py="+para.py+"&concept-id="+para.concept_id+"&line-id="+line_id+"&line="+line, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  console.log("Initializing autocomplete functions");
  // lets see if this works better
  initialize_autocomplete();
  $('#editSWLDialog').modal('show');
  }
  });
};


// this is called from the "editSWLDialog" dialog, assembling the 
// bits and pieces and saving them.
// we need to do some more error-checking here
function save_newsw(){
    var line_id= $( "#swl-line-id-span" ).text();
    var word = $("#swl-query-span").text();
    var word_id = $("#word-id-span").text();
    var py = $("#py-span").text();
    var synfunc_val = $("#select-synfunc" ).val().replace(/\+/g, "$x$");
    var semfeat_val = $("#select-semfeat").val().replace(/\+/g, "$x$");
    var concept_val = $("#newsw-concept-span" ).text();
    var synfunc_id = $("#synfunc-id-span" ).text();     
    var semfeat_id = $("#semfeat-id-span" ).text();
    var concept_id = $("#concept-id-span" ).text();
    var def_val = $("#input-def" ).val().replace(/\+/g, "$x$");
  if (synfunc_id.length == 0){
          var ndef = prompt("No syntactic function '" + synfunc_val + "' defined.  If you want to define a new one, please enter the definition here:") 
          if (ndef) {
            $.ajax({
              type: "PUT",
              datatype : "json",
              url : "api/save_sf.xql?sf_val="+synfunc_val+"&sf_id=xxx&def="+ndef+"&type=syn-func",
              success : function(resp){
                toastr.info("New syntactic function has been saved.", "HXWD says:");
                $("#synfunc-id-span" ).text(resp);
                save_newsw();
                // alert("Please re-enter and select the new syntactic function.");   
              }
          })
          } else {
              $("#select-synfunc" ).val("");          
          }
//          alert("No syntactic function defined. Can not save SW to concept.");
  }
  else if(def_val.length < 1) {
      alert("Newly defined SW need a definition. Can not save SW to concept.")
      $("#input-def").val("");
  } else {

  $.ajax({
  type : "PUT",
  dataType : "json",
  async : false,
  url : "api/save_newsw.xql?concept="+concept_id+"&wid="+word_id+"&word="+word+"&py="+py+"&concept-val="+concept_val+"&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"&semfeat-val="+semfeat_val+"&def="+def_val,
  success : function(resp){
    if (resp.sense_id == "not_saved"){
    toastr.error("Could not save: " + resp.result, "HXWD says:")        
    } else {
    save_this_swl(resp.sense_id)
    toastr.info("Concept has been saved.", "HXWD says:")
    hide_swl_form("#editSWLDialog");
    }
//  console.log("Hiding form");
  show_swls_for_line(line_id);
//  alert(resp);
  },
  error : function(resp){
  // resp is an object, find out what to display!
    console.log(resp)
    toastr.error("An unknown error happened on the system.", "漢學文典 says:");
  }
  });
 
}

};

// saving the concept, from editSWLDialog, with the new SW 
function save_to_concept(){
    var guangyun_id = $(".guangyun-input:checked,.guangyun-input-checked").map(function(){
    console.log($(this).text());
    return $(this).val();
    }).get().join("xxx");
    var line_id= $( "#swl-line-id-span" ).text();
    var word = $("#swl-query-span").text();
    var synfunc_val = $("#select-synfunc" ).val();
    var semfeat_val = $("#select-semfeat").val();
    var concept_val = $("#select-concept" ).val();
    var synfunc_id = $("#synfunc-id-span" ).text();     
    var semfeat_id = $("#semfeat-id-span" ).text();
    var concept_id = $("#concept-id-span" ).text();
    var def_val = $("#input-def" ).val();
  if (typeof guangyun_id !== 'undefined' && guangyun_id.length > 0){
  console.log(guangyun_id);
  if (concept_id.length == 0){
      var strconfirm = confirm("No existing concept selected. Do you want create a new concept named "+concept_val+" ?")
      if (strconfirm == true){
          // new concept
          show_new_concept(concept_val)
          $('#editSWLDialog').modal('hide');
      } else {
          $("#select-concept").val("")
      }
  } else {
      if (synfunc_id.length == 0){
          alert("No syntactic function defined. Can not save SW to concept.");
          $("#select-synfunc" ).val("");
      }
  else if(def_val.length < 1) {
      alert("Newly defined SW need a definition. Can not save SW to concept.")
      $("#input-def" ).val("");
  } else {
  // need to show the selected stuff again to the user to confirm
  $.ajax({
  type : "PUT",
  dataType : "json",
  url : "api/save_to_concept.xql?line="+line_id+"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"&semfeat-val="+semfeat_val+"&def="+def_val+"&guangyun-id="+guangyun_id,
  success : function(resp){
  //  var strconfirm = confirm("Saved concept. Do you want to save attribution now?");
  //  if (strconfirm == true) {
        save_this_swl(resp.sense_id)
  //  }
//    alert(resp.sense_id);
  },
  error : function(resp){
    console.log(resp)
    toastr.error("An unknown error happened on the system."+resp, "漢學文典 says:");
  }
  });
 }
}
} else {
  alert("Guangyun has not been selected!");    
}

};

// link to the website by Gu Guolin
function link_guguolin(word){
var data = "word="+encodeURI(word)+"&mode=word&bianti=no&page=no"
$.get("http://www.kaom.net/z_hmy_zidian88.php?"+data, function (data) {
    var w = window.open('about:blank', 'cishu');
    w.document.write(data);
    w.document.close();
});
};

// this sets the selected as alternate word/name for the already defined leftword / lwobj.  
// We need to assign the pron, then save it to the concept/word in lwobj

function alt_name(sel){
    alert("Not yet implemented ");
    
};

// display the dialog (floater) in the right side of the screen
function get_sw(sel, xid, line){
   var dw = document.documentElement.clientWidth;
   var dh = document.documentElement.clientHeight;
   var new_width = $("#toprow").outerWidth() - $("#toprow-1").outerWidth() - $("#toprow-2").outerWidth();
   $('#domain-lookup-mark').show();

   var domain = $('#domain-select').val();
   var tsel = window.getSelection();
   var r = [tsel.anchorOffset, tsel.focusOffset]
   var pos = Math.min.apply(Math, r);
   var len = Math.max.apply(Math, r);
   console.log("selection: ", sel, pos);
   var url = "http://www.kaom.net/hemoye/z_hmy_zidian88.php?"+"word="+encodeURI(sel)+"&mode=word&bianti=no&page=no";
   // this needs to produce the form link for the lookup
/*   字書：
<form class="btn badge badge-light" name="guguolin" target="dict" action="http://www.kaom.net/z_hmy_zidian8.php" method="post" title="訓詁工具書查詢 法 (External link)"><input type="hidden" name="word" id="word" value="法="><input type="hidden" name="mode" id="mode" value="word"><input type="hidden" name="bianti" id="bianti" value="no"><input type="hidden" name="page" id="page" value="no"><button class="btn badge badge-light" type="submit" style="background-color:paleturquoise">法</button></form>
<form class="btn badge badge-light" name="guguolin" target="dict" action="http://www.kaom.net/z_hmy_zidian8.php" method="post" title="訓詁工具書查詢 度 (External link)"><input type="hidden" name="word" id="word" value="度="><input type="hidden" name="mode" id="mode" value="word"><input type="hidden" name="bianti" id="bianti" value="no"><input type="hidden" name="page" id="page" value="no"><button class="btn badge badge-light" type="submit" style="background-color:paleturquoise">度</button></form>
*/
    var h2 = "";
/*   for (let i = 0; i < sel.length; i++) {
     h2 = h2  sel[i];
   }*/
   console.log(new_width);
    // this sets the selection to the search input field, to make it easy to search for this term
    // idea: write a search that displays the results on this page, so that I do
    // not need to leave the current context.
   $( 'input[name="query"]' ).val(sel);
   $( '#search-submit' ).attr("type", "button");
   $( '#search-submit' ).attr("onclick", "quick_search()");
   $( "#swl-line-id-span" ).html(xid);
   $( "#swl-line-text-span" ).html(line);      
   $( "#swl-query" ).val( sel);
//   $( "#swl-query-span" ).html(sel);
   $( "#swl-select").html("");
   if (sel.length == 0) {
       $ ("#new-att-title").html("In other editions: ");
       $ ('#new-att-detail').html("　　　　　　　　　　　　　　　　　　　　　　　　　　　　");       
       $ ("#new-att-no-perm").html("");
       $ ('#swl-select').html("Collecting information, please wait ..."); 
} else {
//       $ ("#new-att-title").html('Existing SW for <strong class="ml-2"><span id="swl-query-span" onclick="link_guguolin(\''+sel+'\')">'+sel+'</span></strong>');
       $ ("#new-att-title").html('Existing SW for <strong class="ml-2"><span id="swl-query-span"><a target="GXDS" href="'+url+'">'+sel+'</a></span></strong>');   
       // ><a ></a>
       
       // $ ("#swl-jisho").html('<a  title="Look up in Hy Dictionary" style="background-color:paleturquoise" target="GXDS" href="'+url+'">'+sel+'</a>');    
       
   }
//   $( "#swl-form" ).removeAttr("style");
   $( "#swl-query-span" ).attr("data-pos", pos);
   $( "#swl-form" ).css("max-height", dh - 51);
   $( "#swl-form" ).css("max-width", new_width - 10);
   $( "#swl-form" ).show();
   $( "#swl-form" ).scrollTop( 0 );
// alert(uid);
  if ((sel.length > 0) && (sel.length < 10)){
  var context = window.location.pathname;
  if (leftword.length > 0) {
  $("#new-att-detail").html('The left word for a word relation has been defined: <br/><span class="font-weight-bold">' + leftword + '/' + lwobj.concept + '</span>. <br/>To continue, please select the right word, or <span title="Reset the left word" class="btn badge badge-primary ml-2" onclick="reset_leftword()">cancel</span>.<br/>Or you can set '+ sel +' as <span title="Alternate name or word" class="btn badge badge-primary ml-2" onclick="alt_name(\''+sel+'\')">alternate name</span> for ' + leftword + '.')    
  } else {
  $("#new-att-detail").html('<span class="badge badge-primary">Use</span> one of the following syntactic words (SW), create a <span class="mb-2 badge badge-secondary">New SW</span>, add an <span class="font-weight-bold">existing</span> <span class="btn badge badge-primary ml-2" onclick="show_new_concept(\'existing\', \'\')">Concept</span> to the word or create a <span class="btn badge badge-primary ml-2" onclick="show_new_concept(\'new\', \'\')">New Concept</span>. You can also add a word relation: First set the left word with <span class="badge badge-secondary">LW</span>.')
  }
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_sw.xql?word=" + sel+"&context="+context+"&domain="+domain+"&leftword="+leftword, 
  success : function(resp){
  $('#swl-select').html(resp)
  }
  });
  } else {
      var slot1 = $("#slot1").attr('data-trid')
      console.log("No selection, show variants?");
      $.ajax({
      type : "GET",
      dataType : "html",
      url : "api/responder.xql?func=ltr:get-other-translations&line="+line+"&seg="+xid+"&slot1="+slot1, 
      success : function(resp){
      $('#swl-select').html(resp)
      $('#new-att-detail').html("");
    }
  });
  }
};

// when the domain in the Floater is changed, this will trigger a new search
function update_swlist(){
    var domain = $('#domain-select').val();
    var xid = $("#swl-line-id-span" ).html();
    var line = $( "#swl-line-text-span" ).html();      
    //var sel = $( "#swl-query-span" ).html();
    var sel =  x.Selector.getSelected();
    get_sw(sel.toString(), xid, line);
    console.log("Selected domain:", domain);
};

function save_mark(mark, label){
    var sel =  x.Selector.getSelected().toString();
    var xid = $("#swl-line-id-span" ).html();
    // will have loop through multiple elements to construct a select/option element
    var el = $('.med-recipe-name').html()
    $("#new-att-detail").html('');
    $ ("#new-att-no-perm").html("");
    $("#swl-select").html("Current recipe: "+el+"<br/>Selected for mark as "+label+": <span id='sel-mark'>"+sel+"</span><br/><span onClick='do_save_mark(\""+mark+"\")' class='badge badge-primary'>Save</span>");
    console.log("Selected mark:", el);   
};

function do_save_mark(mark){
    var xid = $("#swl-line-id-span" ).html();
    var line = $( "#swl-line-text-span" ).html();      
    var sel =  x.Selector.getSelected().toString();
    console.log("Selected mark:", mark);   
};

function modify_rel_display(){
    var reltype = $('#rel-type').val()
    var mode = $('#rel-type-sort').val()
      $.ajax({
      type : "GET",
      dataType : "html",
      url : "api/responder.xql?func=tlslib:word-rel-table&reltype="+reltype+"&mode="+mode, 
      success : function(resp){
      $('#rel-table').html(resp);
      }
      })
      $('#rel-table').html("Retrieving data, please wait...")
};

function modify_rd_dialog(){
    var obstype = $('#block-type').val()
    var obslabel = $('#block-type option:selected').text();
    var line = $('#concept-line-text-span').text();
    if (obstype == 'rhetdev'){
        $('#select-rhetdev').val("");
    } else {
    // facts.xml should declare wether first line is used as name for block object (or whether it needs a name)
    // the name should not be empty!
       $('#select-rhetdev').val(line);
    }
    $('#block-name').html(obslabel);
    console.log("Selected obstype:" , obstype, " ", obslabel);
};

// jquery selectors 
// we bind a touchend event to mouseup.  This is an attempt to make this work
// on mobile devices, but apparently not really working.
$('.zh').bind('touchend', function(){
    $(this).mouseup();
});

// 　
// here we bind the mouseup event of all elements with the class "zh" to this
// anonymous function, get the selected stuff from the x.Selector and proceed
// to show the stuff

$( ".zh" )
  .mouseup(function() {
  const sel = x.Selector.getSelected();
  // 2021-04-05
  // this used to be id.toString() instead of getAttribute("xml:id"), but due to the astral bug, I have now the tei:seg element to deal with, thus retrieving xml:id
//  const xid = sel.anchorNode.parentNode.getAttribute("xml:id");
  // 2021-04-22 temporarily changin this back
  var in_id = sel.anchorNode.parentNode.id.toString();
  if (in_id.length > 0) {
      var xid = in_id
  }  else {
      var xid = sel.anchorNode.parentNode.parentNode.id.toString()
  }
  console.log("XID", xid);
//  if (sel.anchorNode.parentNode === 'div') {
     var line = sel.anchorNode.parentNode.innerText.trim().replace(' ','');
//  } else { 
//     var line = sel.anchorNode.parentNode.parentNode.innerText.trim().replace(' ','');
//  }
  console.log("LINE", line);
  if (sel.rangeCount > 1) {
  var storedSelections = [];
  for (var i = 0; i < sel.rangeCount; i++) {
        storedSelections.push (sel.getRangeAt (i));
  }
  t = storedSelections.join(";");
  } else {
  t = sel.toString().replace(' ','');    
  }  
  get_sw(t, xid, line)
   // this is to activate the click on the text line to get the context
  $('[data-toggle="popover"]').popover({'content' : get_atts})
  });

//this is for the filter in browse pages
  $("#myInput")
  .keyup(function() {
    var value = $(this).val().toLowerCase();
//    console.log(value);
   $(".abbr").filter(function() {
      $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1);
    });
  });


function countrows(){
      var rowCount = $('#filtertable tr:visible').length - 1;
      $("#rowCount" ).html(rowCount);
}

// for concepts, synfunc, semfeat we provide autocomplete

function initialize_sf_autocomplete(type){
    $( "#select-synfunc" ).autocomplete({
      appendTo: "#select-synfunc-group",
      response : function(event, ui){
      // need to reset this, in case of a new SF
        $("#synfunc-id-span" ).html("xxx");     
        $("#def-old-sf-span").html("<span class='warn'>If the new item is not from the list, please add a definition below!</span>")
      },
      source: function( request, response ) {
        $.ajax( {
          url: "api/autocomplete.xql",
          dataType: "jsonp",
          data: {
            term: request.term,
	        type: type
          },
          success: function( data ) {
            response( data );
          }
        } );
      },
      minLength: 1,
      select: function( event, ui ) {
        $("#synfunc-id-span" ).html(ui.item.id);     
        console.log( "Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );
};


function initialize_autocomplete_nc(){
    $( "#select-concept-nc" ).autocomplete({
      appendTo: "#select-concept-group-nc",
      source: function( request, response ) {
        $.ajax( {
          url: "api/autocomplete.xql",
          dataType: "jsonp",
          data: {
            term: request.term.toUpperCase(),
	        type: "concept"
          },
          success: function( data ) {
            response( data );
          }
        } );
      },
      minLength: 2,
      select: function( event, ui ) {
        $("#concept-id-span-nc" ).html(ui.item.id);     
        console.log( "NC Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );
};

function initialize_autocomplete(){
    $( "#select-concept" ).autocomplete({
      appendTo: "#select-concept-group",
      source: function( request, response ) {
        $.ajax( {
          url: "api/autocomplete.xql",
          dataType: "jsonp",
          data: {
            term: request.term.toUpperCase(),
	        type: "concept"
          },
          success: function( data ) {
            response( data );
          }
        } );
      },
      minLength: 2,
      select: function( event, ui ) {
        $("#concept-id-span" ).html(ui.item.id);     
        console.log( "Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );
// mighty stupid, works now, TODO: rework later
    $( "#select-synfunc" ).autocomplete({
      appendTo: "#select-synfunc-group",
      source: function( request, response ) {
        $.ajax( {
          url: "api/autocomplete.xql",
          dataType: "jsonp",
          data: {
            term: request.term,
	        type: "syn-func"
          },
          success: function( data ) {
            response( data );
          }
        } );
      },
      minLength: 1,
      select: function( event, ui ) {
        $("#synfunc-id-span" ).html(ui.item.id);     
        console.log( "Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );

    $( "#select-semfeat" ).autocomplete({
      appendTo: "#select-semfeat-group",
      source: function( request, response ) {
        $.ajax( {
          url: "api/autocomplete.xql",
          dataType: "jsonp",
          data: {
            term: request.term,
	        type: "sem-feat"
          },
          success: function( data ) {
            response( data );
          }
        } );
      },
      minLength: 1,
      select: function( event, ui ) {
        $("#semfeat-id-span" ).html(ui.item.id);     
        console.log( "Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );
};

function initialize_autocomplete_rd(){
    $( "#select-rhetdev" ).autocomplete({
      appendTo: "#rhetdev",
      source: function( request, response ) {
        $.ajax( {
          url: "api/autocomplete.xql",
          dataType: "jsonp",
          data: {
            term: request.term.toUpperCase(),
	        type: "rhet-dev"
          },
          success: function( data ) {
            response( data );
          }
        } );
      },
      minLength: 2,
      select: function( event, ui ) {
        $("#rhetdev-id-span" ).html(ui.item.id);     
        console.log( "Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );
};


// add this anonyomous function to the #new-concept dialog, so that on hiding 
// its content gets cleared away.
// 2020-04-04: is this still in use?
$('#new-concept').on('hidden.bs.modal', function(e){
        console.log("Clearing form");
        $("#select-synfunc" ).val("");
        $("#select-semfeat").val("");
        $("#select-concept" ).val("");
        $("#synfunc-id-span" ).html();     
        $("#semfeat-id-span" ).html();
        $("#concept-id-span" ).html();
        $("#input-def" ).val("");
        $("#guangyun-input-dyn").html();
    });
    
    
// this prevents the top menubar from covering text 
$(".mysticky").sticky({ topSpacing: 50 });


// popover

$(document).ajaxComplete(function() {
  $("[data-toggle='popover']").popover(
  {'content' : function(){
    var target=$(this).attr("data-target");
    var div_id =  "tmp-id-" + $.now();
    return get_atts(target, div_id);}, 
  'html' : true,
  container: 'body'});
});

// this is a bit of a misnamer. Gets the preview
// TODO: rename

function get_atts(target, div_id){
   console.log(target)
   $.ajax( {
    url: "api/get_text_preview.xql?loc="+target,
    dataType: "html",
    success: function( data ) {
    $('#'+div_id).css("width", "400px");
    $('#'+div_id).html(data);    
    }
    });
   return '<div id="'+ div_id +'">Loading...</div>';
};

function dologout(){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url: 'login?logout=logout',
  success : function(resp){
     $("#settingsDialog").modal('hide');
     alert("You have been logged out.")
     window.location.reload(true)
  }
  });
}

function dologin(){
   var name = $("input[name='user']").val()
   var pw = $("input[name='password']").val()
   var dur = $("input[name='duration']").val()   
   $.post( 
   "login", 
   { user: name, password: pw , duration: dur },
   function (data, textStatus){
     console.log("data ", data, "s:", textStatus)
     if (data.user == null){
         alert("Password or user name wrong, please try again!")
     } else {
        $("#loginDialog").modal('hide');
        window.location.reload(true) 
     }
   }, 
   "json"
   );
};

// save changes on ratings of the texts
$('.rating').on('rating:change', function(event, value, caption) {
        console.log(value);
        console.log(this.id);
  $.ajax({
  type : "PUT",
  url : "api/save_ratings.xql?textid="+this.id+"&rating="+value,
  success : function(resp){
    toastr.info("Your rating has been saved.", "HXWD says:")
  },
  error : function(resp){
    console.log(resp)
    alert(resp);
  }
 });
});
// save deletion of ratings of the texts
$('.rating').on('rating:clear', function(event, value, caption) {
        console.log(value);
        console.log(this.id);
  $.ajax({
  type : "PUT",
  url : "api/save_ratings.xql?textid="+this.id+"&delete=y",
  success : function(resp){
    toastr.info("Your rating has been cleared.", "HXWD says:")
  },
  error : function(resp){
    console.log(resp)
    toastr.error("An unknown error happened on the system.", "漢學文典 says:");
  }
 });
});
// ratings for the SWL ratings
$('.starRating').on('click', function(event, value, caption) {
        console.log(value);
        console.log(this.id);
  $.ajax({
  type : "PUT",
  url : "api/save_ratings.xql?textid="+this.id+"&rating="+value,
  success : function(resp){
    toastr.info("Your rating has been saved.", "HXWD says:")
  },
  error : function(resp){
    console.log(resp)
    toastr.error("An unknown error happened on the system.", "漢學文典 says:");
  }
 });
});



// this is for the button "Attributions" search
function search_and_att(sense_id){
 //   toastr.info("Not ready yet :-(", "HXWD says:");
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/search_att.xql?sense-id=" + sense_id, 
  success : function(resp){
  $('#'+sense_id+'-resp1').html(resp)
  }
  });
  $('#'+sense_id+'-resp1').html("Searching, please wait...")  
}
// we save this on focus to compare with it later
$('body').on('focus', '[contenteditable]', function() {
    const $this = $(this);
    $this.data('before', $this.text());
});

// to update the swl for a certain sense uuid
function edit_swl(uid){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/get_swl.xql?type=swl&uid=" + uid, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  console.log("Initializing autocomplete functions");
  // lets see if this works better
  initialize_autocomplete();
  $('#editSWLDialog').modal('show');
  }
  });
};

// call update_setting for settings; needs to be an array
function save_sset(sets){
  els = sets.split(",")
  els.forEach((el)=> {
  update_setting(el, el);
  })  
};

function update_setting(setting, val_el){
  var value =  $('#' + val_el).val();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=tlslib:save-setting&setting=" + setting + "&value="+value, 
  success : function(resp){
     if (resp.startsWith("OK")) {
       toastr.info("Setting has been changed.", "HXWD says:");
     } else {
      toastr.error("A problem occurred.", "HXWD says:");
     }
  }
  });  
  $('#update-setting').modal('hide');
};

function merge_word(word, wid, count, type){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=dialogs:merge-word&word=" + word+"&wid="+wid+"&count="+count+"&type="+type, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  $('#merge-word-dialog').modal('show');
  }
  });
};

function do_merge_word(wid){
 // $("#select-target option:selected" ).text();
  var target =  $('#select-target').val();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=tlslib:merge-sw-word&wid=" + wid + "&target="+target, 
  success : function(resp){
     console.log(resp)
     if (resp.startsWith("OK")) {
       $('#'+wid).html("");
       toastr.info("Merged into target.", "HXWD says:");
       //now delete the sense from this word
       delete_word_from_concept(wid, 'sense')
     } else {
      toastr.error("A problem occurred.", "HXWD says:");
     }
  }
  });
  $('#merge-word-dialog').modal('hide');
  toastr.info("SW is being moved.", "HXWD says:");   
}





function move_word(word, wid, count, type){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=dialogs:move-word&word=" + word+"&wid="+wid+"&count="+count+"&type="+type, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  console.log("Initializing autocomplete functions");
  // lets see if this works better
  initialize_autocomplete();
  $('#move-word-dialog').modal('show');
  }
  });
};

function do_move_word(word, wid, type){
  var sc = $("#concept-id").attr("data-id");
  var tc = $("#concept-id-span").text();
  if (tc.length < 1) {
      alert("Concept ID not set.  Please select the concept name with the mouse!");
      $("#select-concept").val("")
  } else {
  $.ajax({
  type : "GET",
  dataType : "json",  
  url : "api/responder.xql?func=tlslib:move-word-to-concept&word=" + word + "&src-concept="+sc+"&trg-concept="+tc+"&type="+type+"&wid="+wid, 
  success : function(resp){
     console.log(resp.uuid, resp.mes)
     if (resp.uuid) {
       $('#'+wid).html("");
       toastr.info(resp.mes, "HXWD says:");
       move_word_done(resp.uuid, word);
     } else {
      toastr.error(resp.mes, "HXWD says:");
     }
  }
  });
  $('#move-word-dialog').modal('hide');
  toastr.info("Word "+ word +" is being moved.", "HXWD says:");
  }  
}

function move_word_done(uuid, word){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=tlslib:move-done&uuid=" + uuid, 
  success : function(resp){
//     console.log(resp.uuid)
     toastr.info("Move of "+ word +" has been completed.", "HXWD says:");
  }
  });
    
}
// delete word from concept 
function delete_word_from_concept(wid, type){
    $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/delete_word_from_concept.xql?wid=" + wid+"&type="+type, 
     success : function(resp){
     if (resp.length > 2){
         toastr.info(resp, "HXWD says:");     
     } else {
         $('#'+wid).html("");
         toastr.info("Word has been deleted.", "HXWD says:");     
     }
   }
  })  
};

// increase rating of the attribution; this is the star on the attributions
// for the moment, type is 'swl', but ...
function incr_rating(type, uid){
    var strconfirm = true 
    if (strconfirm == true) {
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=incr-rating&uid="+uid+"&type="+type,
     success : function(resp){
   //  save_this_swl(resp.sense_id)
      var line_id = resp.replace(/"/g, '')
   //   console.log("Lineid: " & line_id);
      show_swls_for_line(line_id);
      toastr.info("Attribution has been marked.", "HXWD says:");
   }
  });
  }
};


// delete the attribution; this is the x on the attributions

function delete_swl(type, uid){
    var strconfirm = true // confirm("Do you really want to delete this attribution?");
    if (strconfirm == true) {
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/delete_swl.xql?type="+type+"&uid=" + uid, 
     success : function(resp){
   //  save_this_swl(resp.sense_id)
      var line_id = resp.replace(/"/g, '')
   //   console.log("Lineid: " & line_id);
      show_swls_for_line(line_id);
      toastr.info("Attribution deleted.", "HXWD says:");
   }
  });
  }
};

// review the attribution; this is the ? on the attributions

function review_swl_dialog(uid){
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/review_swl_dialog.xql?type=swl&uid=" + uid, 
     success : function(resp){
     $('#remoteDialog').html(resp);
     initialize_autocomplete();
     $('#review-swl-dialog').modal('show');
   }
  });
};



function save_swl_review(uid){
   var com_val = $("#input-comment" ).val();
   var action_val = $("input[name='actions']:checked").attr('id');
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/save_swl_review.xql?com="+com_val+"&uid=" + uid + "&action="+action_val, 
     success : function(resp){
     console.log("RESP" + resp, resp.startsWith('"Error'))
     if (resp.startsWith('"Error')) {
     toastr.error(resp, "HXWD says:");
     } else {
     toastr.info("Review has been saved. Thank you for your effort!", "HXWD says:");
     }
   }});
   $('#review-swl-dialog').modal('hide');
};
// this is for editing the definitions in the syntactic functions and semantic features
$( ".sf").keyup(function ( event ) {
}).keydown( function( event ){
  if ( event.which == 9 ) {
    var sfid = $(this).attr('id');
    //var def = document.getElementById( sfid ).innerText;
    var sf = $(this).text()
    console.log("tab", $(this).data('before') , "h", sf)
    if ($(this).data('before') !== sf){    
        // we keep the end of the id to distinguish different use cases
        var dat = $(this).html();
        save_sf_def (sfid.slice(0, -3), dat, sfid.slice(-3));
        $(this).data('before', sf);
    }}
    });
        
function save_sf_def (sfid, def, tp){
  console.log(sfid)
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/responder.xql?func=save-sf-def&id="+sfid+"&def="+def+"&type="+tp,
  success : function(resp){
    toastr.info("Modification for definition saved.", "HXWD says:");
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

// for the notes (class "nedit"), we save on keyup, so we check for our event
$( ".nedit" ).keyup(function( event ) {
}).keydown(function( event ) {
  var nid = $(this).attr('id');
  if ( event.which == 9 ) {
    var trid = $(this).attr('id');
    var tr = $(this).text()
    console.log("tab", $(this).data('before') , "h", tr)
    if ($(this).data('before') !== tr){    
           var savedata = $(this).html()
           save_note(nid, savedata);
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  }
  //dont save on enter, onle on tab
  if ( event.which == 1300000 ) {
    var trid = $(this).attr('id');
    var tr = $(this).text()
    event.preventDefault();
    if ($(this).data('before') !== tr){    
           save_note(nid, tr);
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  }
});

$( ".nedit" ).blur(function (event) {
    var nid = $(this).attr('id');
    var tr = $(this).text()
    console.log("blur", $(this).data('before') , "h", tr)
    if ($(this).data('before') !== tr){    
         cname = confirm("Unsaved data exist, do you want to save?");
         if (cname){
           var savedata = $(this).html()
           save_note(nid, savedata);
           cancelmove = true;
          }
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  dirty = false;
});

function save_note (trid, tr){
  $.ajax({
  type : "POST",
  dataType : "html",
  url : "api/save_note.xql",
  data: {"trid" : trid.slice(0, -3), "tr" : tr},
  success : function(resp){
    if (resp.startsWith("Could not")) {
    toastr.error(resp, "漢學文典 says:");
/*    toastr.error("Could not save translation for "+line+".", "HXWD says:");        */
    } else {
    toastr.info("Modification saved.", "漢學文典 says:");
    dirty = false;
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};



// tr




// for the translations (class "tr"), we save on keyup, so we check for our event
function set_keyup (){
$(".tr").click(function (event) {
    var trid = $(this).attr('id');
    var lineid = trid.replace(/-slot.|-tr|-ex/,'')
    var line = document.getElementById( lineid ).innerText;
    set_currentline(lineid)
});

$( ".tr" ).blur(function (event) {
    var trid = $(this).attr('id');
    var lineid = trid.replace(/-slot.|-tr|-ex/,'')
    var line = document.getElementById( lineid ).innerText;
    var tr = $(this).text()
    var lang = $(this).attr('lang');
    console.log("blur", $(this).data('before') , "h", tr)
    if ($(this).data('before') !== tr){    
         cname = confirm("Unsaved data exist, do you want to save?");
         if (cname){
           if (lang == 'zho') {
               save_zh(trid, line)
           } else {
               save_tr(trid, tr, line);
           }    
           cancelmove = true;
          }
          // save this, in case there are more changes
          $(this).data('before', tr)
    } else {
           cancelmove = false;
    }
  dirty = false;
});


$( ".tr" ).keyup(function( event ) {
}).keydown(function( event ) {
    var trid = $(this).attr('id');
//    var lineid = trid.slice(0, -3);
    var lineid = trid.replace(/-slot.|-tr|-ex/, '');
    var line = document.getElementById( lineid ).innerText;
    var lang = $(this).attr('lang');
    dirty = true;
  if (event.ctrlKey == true){
    //var hlineid = lineid.split(".").join("\\.")
    console.log("key: ", event.which)
    if (event.which > 48 & event.which < 58) { // ctrl 1 to 9 selects the nth character
     event.preventDefault();
      //var line = $("#"+hlineid).text()
      var pos = event.which - 49
      var sel = line.slice(pos,pos+1)
      get_sw(sel, lineid, line)
      //copyToClipboard($( "#swl-query-span" ));
    } else
    if (event.which == 83) { // the key is ctrl-s
     event.preventDefault();
     quick_search();   
    } else
    if (event.which == 191 || event.which == 173){
     event.preventDefault();
     var sw = document.getElementById( lineid + "-swl" ).parentNode;
      if (sw.style.display === "block") {
          sw.style.display = "none";          
      } else {
          sw.style.display = "block";
      }
//      console.log(sw);      
    } else if (event.which == 188 || event.which == 190){
        event.preventDefault();
        var sel = $( "#swl-query-span" ).text();
        var ix = line.indexOf(sel)
        if (event.which == 188){
            var ex = -1
        } else {
            var ex = +1
        }   
        var newsel = line.slice(ix, ix+sel.length+ex);
        get_sw(newsel, lineid, line);
        //copyToClipboard($( "#swl-query-span" ));
      //  console.log("IX", newsel);
    }
   }
// this is disabled for the moment. procline.xql does not exist
 if ( event.which == 5200 & event.shiftKey == true) {
    event.preventDefault();
    console.log(lineid, line, event.shiftKey)    
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/procline.xql?line="+line,
  success : function(resp){
    var new_height = $("#chunkcol-right").outerHeight();
    var new_width = $("#chunkcol-right").outerWidth();
    $('#swl-select').html(resp);
    $( "#swl-form" ).show();
    $( "#swl-form" ).scrollTop( 0 );
//    $( "#swl-form" ).css({'width' : 'new_width'+px});
    $( "#swl-form" ).width(new_width);
  },
  error : function(resp){
  console.log(resp)
    alert("PROBLEM"+resp);
  }
  });
      
  }
  // we save the translation on either tab or enter
  if ( event.which == 9 ) {
    var trid = $(this).attr('id');
    var lineid = trid.replace(/-slot.|-tr|-ex/,'')
    var line = document.getElementById( lineid ).innerText;
    var tr = $(this).text()
    var lang = $(this).attr('lang');
    console.log("tab", $(this).data('before') , "h", tr)
    if ($(this).data('before') !== tr){    
           if (lang == 'zho') {
               save_zh(trid, line)
           } else {
               save_tr(trid, tr, line);
           }    
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  }
  if ( event.which == 13 ) {
    var trid = $(this).attr('id');
    var lineid = trid.replace(/-slot.|-tr|-ex/,'')
    var line = document.getElementById( lineid ).innerText;
    var tr = $(this).text()
    event.preventDefault();
    if ($(this).data('before') !== tr){    
           if (lang == 'zho') {
               save_zh(trid, line)
           } else {
               save_tr(trid, tr, line);
           }    
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  }
});
};

// this does the actual save
// the backend actually also saves the language, which defaults to "en", param is lang
function save_tr (trid_in, tr, line){
  var trid = trid_in.replaceAll("\\", "")
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_tr.xql?trid="+trid+"&tr="+tr,
  success : function(resp){
    if (resp.startsWith("Could not")) {
    toastr.error(resp, "漢學文典 says:");
/*    toastr.error("Could not save translation for "+line+".", "HXWD says:");        */
    } else {
    toastr.info("Translation for line "+line+" saved.", "HXWD says:");
    dirty = false;
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

// 2021-06-18: Save text.  First shift editing from translation to text.
// then modify blue eye's function
function zh_start_edit(){
    $(".zh").off("mouseup");
    $(".tr").attr("contenteditable", "false");
    $(".tr").removeClass("tr");
    $(".zh").addClass("tr");
    $(".zh").addClass("zhed");
    $(".tr").removeClass("zh");
    $(".tr").attr("contenteditable", "true");
    $("#blue-eye").attr("onclick", "location.reload()");   
    $("#blue-eye").removeClass("btn-primary");
    $("#blue-eye").addClass("btn-warning");
    $("#blue-eye").removeAttr("data-toggle");    
    $("#blue-eye").removeAttr("data-target");    
    $("#blue-eye").attr("title", "Click here to end editing");
    toastr.info("Click the yellow eye to end the editing.", "漢學文典 says:");
    $(".zhed").each(function (){
      var zh_line_id = $(this).attr('id');
      var but = '<button type="button" class="btn close" onclick="zh_delete_line(\''+zh_line_id+'\')" title="Immediately remove the line ('+zh_line_id+')"><img class="icon" style="width:12px;height:15px;top:0;align:top" src="resources/icons/open-iconic-master/svg/x.svg"></button>';
      $(this).prepend(but);
    });
    
    set_keyup();
}

// this does the actual save
function save_zh (id, line){
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/responder.xql?func=save-zh&id="+id+"&line="+line,
  success : function(resp){
    if (resp.startsWith("Could not")) {
    toastr.error(resp, "漢學文典 says:");
    } else {
    toastr.info("Modification for line "+line+" saved.", "漢學文典 says:");
    dirty = false;
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

// this does the actual save
function zh_delete_line (id){
  var lid = id.split(".").join("\\.")
  var line = $("#"+lid).text()
  var ok=confirm("'"+ line +"' ("+ id +") will be deleted and removed, do you want to proceed?.")
  if (ok){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?func=zh-delete-line&id="+id,
  success : function(resp){
    if (resp.startsWith("Could not delete")) {
    toastr.error(resp, "漢學文典 says:");
    } else {
    toastr.info("Deletion for line "+id+" completed.", "漢學文典 says:");
    $("#"+lid).remove();
    dirty = false;
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
  }
};


// save modified definition of swl
// 2020-04-04: I think this is not used, we use the save button now
$( ".swedit" ).keyup(function( event ) {
}).keydown(function( event ) {
  alert(event);
  if ( event.which == 9 | event.which == 13) {
    var defid = $(this).attr('id');
    var defel = document.getElementById( defid ).innerText;
    var def = $(this).text()
    save_def(defid);    
  }
});
// called from save button
function save_def (defid){
  console.log(defid)
  var def = document.getElementById( defid ).innerText;
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_def.xql?defid="+defid+"&def="+def,
  success : function(resp){
    toastr.info("Modification for definition saved.", "HXWD says:");
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

//stub for new sf

function save_sf (type){
    var sense_id= $( "#sense-id-span" ).text();
    var synfunc_val = $("#select-synfunc" ).val().replace(/\+/g, "$x$");
    var synfunc_id = $("#synfunc-id-span" ).text();     
    var def_val = $("#input-def" ).val().replace(/\+/g, "$x$");

  console.log(sense_id)
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_sf.xql?sense-id="+sense_id+"&sf_id="+synfunc_id+"&sf_val="+synfunc_val+"&def="+def_val+"&type="+type,
  success : function(resp){
    hide_swl_form( "#edit-sf-dialog" );      
    if (type == "syn-func") {
       toastr.info("Syntactic function updated.", "HXWD says:");
    } else {
       toastr.info("Semantic feature updated.", "HXWD says:");        
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

// stub for bookmark  2020-02-23, called from app:swl-form-dialog

function bookmark_this_line(){
  var word = $("#swl-query-span").text();
  var line_id= $( "#swl-line-id-span" ).text();  
  var line = $( "#swl-line-text-span" ).text();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/save_bookmark.xql?word="+word+"&line-id="+line_id+"&line="+line, 
  success : function(resp){
  toastr.info("Bookmark has been saved.", "HXWD says:")
  }
  });
};


function add_parallel(){
  var word = $("#swl-query-span").text();
  var line_id= $( "#swl-line-id-span" ).text();  
  var line = $( "#swl-line-text-span" ).text();
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:add-parallel&word="+word+"&line-id="+line_id+"&line="+line, 
     success : function(resp){
     $('#remoteDialog').html(resp);
     //initialize_autocomplete_rd();
     $('#add-parallel-dialog').modal('show');
   }
  });
};

// 
function toggle_list_display(){
  $.ajax({
  type : "PUT",
  url : "api/responder.xql?func=lus:toggle-list-display",
  success : function(resp){
    toastr.info("List display option changed.", "HXWD says:");
    update_swlist()
  }
  }
  )
  
};

// stub for comment  2020-02-23, called from app:swl-form-dialog
// use this for RD instead 2021-09-21, called from tlslib:swl-form-dialog
function add_rd_here(){
  var word = $("#swl-query-span").text();
  var line_id= $( "#swl-line-id-span" ).text();  
  var line = $( "#swl-line-text-span" ).text();
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:add-rd-dialog&word="+word+"&line-id="+line_id+"&line="+line, 
     success : function(resp){
     $('#remoteDialog').html(resp);
     initialize_autocomplete_rd();
     $('#add-rd-dialog').modal('show');
   }
  });
};

function save_rdl(word, lineid, line){
  var end_val = $("#select-end" ).val().split('#')[0];
  var end = $("#select-end option:selected" ).text();
  var rd = $("#select-rhetdev").val();
  var rdid = $("#rhetdev-id-span").text();
  var note = $("#input-note").val();
  var type = $('#block-type').val();
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/responder.xql?func=save-rdl&line_id="+lineid+"&line="+line+"&end="+end+"&end_val="+end_val+"&rhet_dev="+rd+"&rhet_dev_id="+rdid+"&word="+word+"&note="+note+"&type="+type,
  success : function(resp){
    $( "#add-rd-dialog" ).modal('hide');      
    hide_swl_form("#editSWLDialog");
    //show_swls_for_line(lineid); 
    // this might be overkill, but is needed for the recipe & drug stuff
    get_swls();
    toastr.info("Observation location " + rd + " saved.", "HXWD says:");
  },
  error : function(resp){
    toastr.error("Could not save observation.\n" + resp.responseText , "HXWD says:");
    console.log(resp);
 //   alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
    
};

// new concept definition dialog etc.
function new_concept_dialog(){
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=new-concept-dialog", 
     success : function(resp){
     $('#remoteDialog').html(resp);
     initialize_autocomplete();
     $('#new-concept-dialog').modal('show');
   }
  });
};

// new synonym definition for concept 
function new_syn_dialog(para){
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:new-syn-dialog&concept-id="+para.concept_id+"&concept="+para.concept+"&char="+para.char, 
     success : function(resp){
     $('#remoteDialog').html(resp);
     $('#new-syn-dialog').modal('show');
   }
  });
};

function save_syn (para){
  var crit_val = $("#input-crit" ).val();
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/responder.xql?func=save-syn&concept-id="+para.concept_id+"&crit="+crit_val,
  success : function(resp){
    $( "#new-syn-dialog" ).modal('hide');      
    toastr.info("New synonyms for " + para.concept + " saved.", "HXWD says:");
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};


function add_to_tax(){
  var ptr = $("#select-tax").val();
  var relcon = $("#select-concept-nc").val()
  var relcon_id = $("#concept-id-span-nc").html()
  var chtml = $("#stag-"+ptr+"-span").html()
  $("#stag-"+ptr+"-span").html(chtml+"<span class='badge badge-dark staged' data-cid='"+relcon_id+"' title='"+relcon_id+"'>"+relcon+"</span>")
  $("#stag-"+ptr).show();
  $("#staging").show();
  $("#select-concept-nc").val("")
  $("#concept-id-span-nc").html("")
  
};

function reset_tax(){
    $(".staging-span").html("")
}

function save_new_concept (uuid, concept){
  var och_val = $("#name-och" ).val();
  var zh_val = $("#name-zh" ).val();
  var def_val = $("#input-def" ).val();
  var crit_val = $("#input-crit" ).val();
  var notes_val = $("#input-notes" ).val();
  var ont_ant = $("#stag-antonymy-span .staged").map(function(){
    if ($(this).attr("data-cid")){
      return $(this).text() + "::" + $(this).attr("data-cid");
    } else {return "yyy"} }).get().join("xxx");
  var ont_hyp = $("#stag-hypernymy-span .staged").map(function(){
    if ($(this).attr("data-cid")){
      return $(this).text() + "::" + $(this).attr("data-cid");
    } else {return "yyy"} }).get().join("xxx");
  var ont_see = $("#stag-see-span .staged").map(function(){
    if ($(this).attr("data-cid")){
      return $(this).text() + "::" + $(this).attr("data-cid");
    } else {return "yyy"} }).get().join("xxx");
  var ont_tax = $("#stag-taxonymy-span .staged").map(function(){
    if ($(this).attr("data-cid")){
      return $(this).text() + "::" + $(this).attr("data-cid");
    } else {return "yyy"} }).get().join("xxx");
  var labels = $("#select-labels").val();
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/responder.xql?func=save-new-concept&concept_id="+uuid+"&concept="+concept+"&crit="+crit_val+"&def="+def_val+"&notes="+notes_val+"&ont_ant="+ont_ant+"&ont_hyp="+ont_hyp+"&ont_see="+ont_see+"&ont_tax="+ont_tax+"&labels="+labels+"&och="+och_val+"&zh="+zh_val,
  success : function(resp){
    $( "#new-concept-dialog" ).modal('hide');      
    toastr.info("New concept " + concept + " saved.", "HXWD says:");
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

// delete syntactic function or semantic feature (called from browse page)
function delete_sf(uid, type){
    var abbr = $("#"+uid+'-abbr').text()
    $.get("api/show_use_of.xql?uid=" + uid + "&type=" + type, "html", 
    function(resp){
        if (resp.startsWith("No usage")){
        console.log(uid, resp)
        do_delete_sf(uid, type, false);
        } else {
         $('#'+uid+'-resp').html(resp)
         var ok=confirm("'"+ abbr +"' has been used in attributions, do you want to proceed? All attributions will be deleted as well.")
         if (ok) {
         console.log("OK", ok)
         do_delete_sf(uid, type, ok)
         } else {
             //change ??
         }
        }
    })
    toastr.info("Checking for usage, please wait.", "HXWD says:");
}

function do_delete_sf(uid, type, ed){
    $.get("api/responder.xql?func=do-delete-sf&uid=" + uid+"&ok="+ed+"&type="+type, "html", function(resp){
         toastr.info("Syntactic function entry had been deleted.", "HXWD says:");
         $('#'+uid).html("")
    })
}

// not working properly.
function copyToClipboard(element) {
    var $temp = $("<input>");
    var focused = document.activeElement;
    var tx = $(element).text()
    console.log(tx)
    $("body").append($temp);
    $temp.val($(element).text()).select();
    document.execCommand("copy");
    $temp.remove();
    focused.focus();
}

/* Wikidata related stuff */

// this function is called from a link, without direct text input / the type of id depends on the item given in context
function do_wikidata_search(query,context,id,qitem){
    $("#wd-query-span").text(query);
    $("#wd-search").val(query)
    $("#wd-qitem").text(qitem)
    $("#wd-form" ).show(); 
    $.get("api/responder.xql?func=wd:search&query="+query+"&context="+context+"&id="+id+"&qitem="+qitem, 
    function(resp){
         $('#wd-search-results').html(resp);
         $('#wd-detail').html("");
        }
    )
  $('#wd-title').html("Associate <span id='wd-textid'>"+id+"</span>:");
  $('#wd-detail').html("　　　　　　　　　　　　　　　　　　　　　　　　　　　　");
  $('#wd-search-results').html("Please wait ...");  
};

function wikidata_search_again(){
    var query = $("#wd-search").val();
    var context = 'title' ;
    $("#wd-recent").html('')
    var type = $("#wd-stype option:selected").val();
    var id = $("#wd-textid").text()
    $.get("api/responder.xql?func=wd:search&query="+query+"&context="+context+"&id="+id+"&type="+type+"&qitem=None",  
    function(resp){
         $('#wd-search-results').html(resp);
         $('#wd-detail').html("");
        }
    )
};

// this function is called from the attribution floater, works similar to the quick search for texts
function wikidata_search(target){
   var start = 1;
   var count = 25;
   var stype = '5'; // search only this text
   var mode = 'rating';
//   var target = 'wikidata';
   $('#domain-lookup-mark').hide();
   do_quick_search(start, count, stype, mode, target);
};


// this gets called from the "Use" button, we now do the work:)
function save_qitem(qitem,context,id,label){
    var title = $("#wd-query-span").text();
    var oldqitem = $("#wd-qitem").text()
    
    $.get("api/responder.xql?func=wd:save-qitem&qitem="+qitem+"&context="+context+"&id="+id+"&title="+title+"&label="+label+"&locallabel="+title+"&oldqitem="+oldqitem, 
    function(resp){
         toastr.info(qitem+" has been saved.", "漢學文典 says:");
         $('#wd-search-results').html(resp);
         $('#wd-detail').html("");
         $('#wd-form' ).hide(); 
        }
    )
    
}


function quick_search(){
   var start = 1;
   var count = 25;
   var stype = '5'; // search only this text
   var mode = 'rating';
   var target = 'texts';
   $('#domain-lookup-mark').hide();
   do_quick_search(start, count, stype, mode, target);
};

function do_quick_search(start, count, stype, mode, target){
//    var word = $("#swl-query-span").text();
    var word = $("input[name=query]").val();
    var uuid = $("input[name=qs-uuid]").val();
    var textid = $("#swl-line-id-span" ).text().split("_")[0]
    var lineid = $("#swl-line-id-span" ).text()
    $.get("api/responder.xql?func=quick-search&query="+word+"&uuid="+uuid+"&start="+start+"&count="+count+"&mode="+mode+"&search-type="+stype+"&textid="+textid+"&target="+target+"&line="+lineid, 
      "html", 
    function(resp){
         $('#swl-select').html(resp);
         // we might introduce buttons for the other search functions here at some point
         $('#new-att-detail').html("");
        }
    )
  $('#new-att-title').html("Searching for "+word);
  $('#new-att-detail').html("　　　　　　　　　　　　　　　　　　　　　　　　　　　　");
  $('#swl-select').html("Please wait ...");  
};



// delete_zi_from_word('uuid-f1f8819f-cfae-4128-a9ed-8e9586c9e146','1','咳欬')
function delete_zi_from_word(wid, pos, ch){
$.get("api/responder.xql?func=delete-zi-from-word&wid="+wid+"&pos="+pos+"&char="+ch, "html", 
    function(resp){
       toastr.info(ch+" has been deleted.", "HXWD says:");
       //$('#' + wid + '-' + pos).html()
       document.getElementById(wid + '-' + pos).style.display = "none";
       }
    )
    
};

// save updated pinyin
function save_updated_pinyin(concept_id, wid, ch, pos){
    var guangyun_id = $(".guangyun-input:checked,.guangyun-input-checked").map(function(){
    console.log($(this).text());
    return $(this).val();
    }).get().join("xxx");
    var zi = $("#input-char" ).val();
    var sources = $("#sources" ).val();
    var gloss = $("#input-gloss").val();
  if (typeof guangyun_id !== 'undefined' && guangyun_id.length > 0){
  console.log(guangyun_id);
  $.ajax({
  type : "PUT",
  url : "api/responder.xql?func=update-pinyin&wid="+wid+"&concept="+concept_id+"&sources="+sources+"&gloss="+gloss+"&guangyun-id="+guangyun_id+"&zi="+zi+"&char="+ch,
  success : function(resp){
    if(resp.startsWith("OK")){
      var zih = '#'+wid+'-'+pos+'-zi';
      var pyh = '#'+wid+'-'+pos+'-py';
      console.log(zih, zi)
      $('#assign-guangyun').modal('hide');
      toastr.info("Pinyin has been saved. Please reload page to see all changes.", "HXWD says:")  
      // todo: show changes on page!
      $(zih).html(zi)
      $(pyh).html("　"+resp.substring(2))
    } else {
       alert("PROBLEM: "+resp);
    }
  },
  error : function(resp){
  console.log(resp)
    alert("PROBLEM"+resp);
  }
  });
} else {
  alert("Guangyun has not been selected!");    
}

};


// {{'zi':'{$zi}', 'wid':'{$wid}','py': '{$py}','concept' : '{$esc}', 'concept_id' : '{$id}'}}
function assign_guangyun_dialog(para){
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:assign-guangyun&char="+para.zi+"&concept_id=" + para.concept_id + "&pinyin="+para.py+"&concept="+para.concept+"&wid="+para.wid+"&pos="+para.pos, 
     success : function(resp){
     $('#remoteDialog').html(resp);
     // initialize_autocomplete();
     $('#assign-guangyun').modal('show');
   }
  });   
}

// udpate gloss 2021-06-24
function delete_pron(uuid){
    $.get("api/responder.xql?func=delete-pron&uuid=" + uuid, "html", function(resp){
     if (resp=="OK") {
         toastr.info("Pronounciation has been deleted.", "HXWD says:");
         $('#'+uuid).html("")
         } else {
         toastr.error("Pronounciation is in use, can not be deleted.", "HXWD says:");             
         }
    })
}

// {'zi':'{$g}', 'py': '{$py}', 'uuid': '{$r/@xml:id}',  'pos' : '{$pos}'}
function update_gloss_dialog(para){
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:update-gloss&char="+para.zi+"&uuid=" + para.uuid + "&pinyin="+para.py+"&pos="+para.pos, 
     success : function(resp){
     $('#remoteDialog').html(resp);
     // initialize_autocomplete();
     $('#update-gloss').modal('show');
   }
  });   
}

// save updated gloss
function save_updated_gloss(uuid, ch, pos){
  var gloss = $("#input-gloss").val();
  var gid = '#gloss-'+pos;  
  $.ajax({
  type : "PUT",
  url : "api/responder.xql?func=update-gloss&uuid="+uuid+"&gloss="+gloss,
  success : function(resp){
   if(resp.startsWith("OK")){
      $('#update-gloss').modal('hide');
      toastr.info("Gloss has been saved.", "HXWD says:")  
      // todo: show changes on page!
      $(gid).html("　"+resp.substring(2))
    } else {
       alert("PROBLEM: "+resp);
    }
  },
  error : function(resp){
   console.log(resp)
  alert("PROBLEM"+resp);
  }

  }); 
}

// add or edit text cat
function edit_textcat(textid){
  $('.modal').modal('hide');
  var src = $('#text-cat-note').text();
  var textcat = $('#text-cat').attr('data-text-cat');
  //var datecat = $("#select-text-cat").val();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=dialogs:edit-textcat&textid="+textid+"&textcat="+textcat, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  $('#edit-textcat-dialog').modal('show');
  }
  });
    
};
function save_textcat(textid){
  var nb = $('#input-nb').val();
  var na = $('#input-na').val();
  var prose = $('#input-prose').val();
  var src = $('#input-src').val();
  var textcat = $("#select-text-cat").val();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=save-textcat&textid="+textid+"&textcat="+textcat, 
  success : function(resp){
      $('#edit-textcat-dialog').modal('hide');
      toastr.info("Text category has been saved.", "HXWD says:");  
      $('#textcat-outer').html(resp);
  },
  error : function(resp){
   console.log(resp)
  alert("PROBLEM"+resp);
  }

  }); 
};



// add or edit text date
function edit_textdate(textid){
  $('.modal').modal('hide');
  var nb = $('#textdate').attr('data-not-before');
  var na = $('#textdate').attr('data-not-after');  
  var prose = document.getElementById( "textdate" ).childNodes[0].nodeValue;
  var src = $('#textdate-note').text();
  var datecat = $('#date-cat').attr('data-date-cat');
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=dialogs:edit-textdate&textid=" + textid+"&datecat="+datecat+"&nb="+nb+"&na="+na+"&prose="+prose+"&src="+src, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  $('#edit-textdate-dialog').modal('show');
  }
  });
    
};

function save_textdate(textid){
  var nb = $('#input-nb').val();
  var na = $('#input-na').val();
  var prose = $('#input-prose').val();
  var src = $('#input-src').val();
  var datecat = $("#select-date-cat").val();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=save-textdate&textid="+textid+"&datecat="+datecat+"&nb="+nb+"&na="+na+"&prose="+prose+"&src="+src, 
  success : function(resp){
      $('#edit-textdate-dialog').modal('hide');
      toastr.info("Textdate has been saved.", "HXWD says:");  
      $('#textdate-outer').html(resp);
  },
  error : function(resp){
   console.log(resp)
  alert("PROBLEM"+resp);
  }

  }); 
};

// add new reference to bibliography
function edit_bib(uid, textid){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=bib:new-entry-dialog&uuid="+uid+"&textid="+textid, 
  success : function(resp){
      $('#remoteDialog').html(resp);
      $('#new-entry-dialog').modal('show');
  },
  error : function(resp){
   console.log(resp)
   alert("PROBLEM"+resp);
  }

  }); 
};

function bib_genre_change(){
    sval = $("#select-genre").val()
    if ((sval == "article") || (sval == "chapter")){
       $(".article").show()
       $(".book").hide()
    } else {
       $(".article").hide()
       $(".book").show()
    }
}

function bib_remove_line(lid){
$("#"+lid).html('')
};

function bib_add_topic(n, lid){
 m = n+1
 newtopic = `<div class="col-md-3" id="topic-field-${n}">\
               <small class="text-muted"></small>\
               <input name="topic-${n}" class="form-control" value=""></input>\
             </div>`
 $("#"+lid).after(newtopic)
 $("#new-topic").html(`<span onclick="bib_add_topic(${m}, 'topic-field-${n}')">Add topic</span>`)
};

function bib_add_new_line(n, lid){
 m = n+1
 newline = `<div class="form-row" id="role-group-${n}"><div class="form-group col-md-2"><small class="text-muted">Role<br/>　</small><select class="form-control" name="select-role-${n}">\
                                <option value="aut">Author</option>\
                                <option value="cmp">Compiler</option>\
                                <option value="com">Commentator</option>\
                                <option value="edi">Editor</option>\
                                <option value="trl">Translator</option></select></div>\
                        <div class="col-md-2"><small class="text-muted">Family Name (transcribed)</small><input name="fam-name-latn-${n}" class="form-control" value=""></div>\
                        <div class="col-md-2"><small class="text-muted">Given Name (transcribed)</small><input name="giv-name-latn-${n}" class="form-control" value=""></div>\
                        <div class="col-md-2"><small class="text-muted">Family Name (characters)</small><input name="fam-name-hant-${n}" class="form-control" value=""></div>\
                        <div class="col-md-2"><small class="text-muted">Given Name (characters)</small><input name="giv-name-hant-${n}" class="form-control" value=""></div>\
                        <div class="col-md-2"><span id="rem-line-${n}" onclick="bib_remove_line('role-group-${n}')">Remove this line</span><br><span id="add-line-${n}" onclick="bib_add_new_line(${m}, 'role-group-${n}')">Add new line</span></div>\
                        </div>`
 $("#"+lid).after(newline)                       
};

// save bib entry in the form
function save_entry(uuid){
  formData = $("#new-entry-form").serialize()
  $.ajax({
  type : "POST",
  url : "api/responder.xql?func=bib:save-entry&uuid="+uuid,
  data: formData,
  success : function(resp){
    if (resp.startsWith("Could not")) {
    toastr.error(resp, "漢學文典 says:");
/*    toastr.error("Could not save translation for "+line+".", "HXWD says:");        */
    } else {
    toastr.info("Modification saved.", "漢學文典 says:");
    $('#new-entry-dialog').modal('hide');
    $('#remoteDialog').html('');
    window.location = 'bibliography.html?uuid='+uuid
    dirty = false;
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
  
};

// add new reference to bibliography 
// textid might be empty
function add_ref(textid){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=bib:new-entry-dialog&textid="+textid, 
  success : function(resp){
      $('#remoteDialog').html(resp);
      $('#new-entry-dialog').modal('show');
  },
  error : function(resp){
   console.log(resp)
   alert("PROBLEM"+resp);
  }

  }); 
};

// add new observation template
function add_obs(){
    alert("Not yet implemented");
};

// show observations for template
function show_obs(templ_id){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?func=show-obs&templ-id="+templ_id,
  success : function(resp){
//  console.log("Displaying response at: " + '#'+line_id+'-swl');
//  $('#swl-select').html(resp)
  $('#'+templ_id+'-obs').html(resp);
  }
  });
    
};

//delete bookmark
function delete_bm(uuid){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=delete-bm&uuid=" + uuid, 
  success : function(resp){
//     console.log(resp.uuid)
     $("#"+uuid).html("");
     toastr.info("Bookmark has been deleted.", "HXWD says:");
  }
  });
    
}

// signup 
function sgn_approve(uuid, resp){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=sgn:approve&uuid=" + uuid + "&resp=" + resp , 
  success : function(resp){
//     $("#"+uuid).html("");
     toastr.info("Your vote has been registered. Thank you", "HXWD says:");
  }
  });
    
}




function toggle_alt_labels(){
  $(".altlabels").toggle();   
};

// need to think about where to use this:
/*window.onbeforeunload = function() {
  return "";
}
 * 
 * or this:
 * 
*/

function save_taxchar(type){
  // save the tree in #chartree
// alert("Not yet implemented")  
  var data = $("#chartree").prop('outerHTML');
//  console.log("data:"+data);
  $.ajax({
  type : "POST",
  dataType : "html",
  contentType: 'application/xml',
  url : "api/responder.xql?func=save-taxchar&type="+type,
  data: data,
  success : function(resp){
    if (resp.startsWith("Could not")) {
    toastr.error(resp, "漢學文典 says:");
/*    toastr.error("Could not save translation for "+line+".", "HXWD says:");        */
    } else {
    toastr.info("Modification saved.", "漢學文典 says:");
    dirty = false;
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

// display dialog for pb
// fname is the name of the function in dialogs, has to be the same as the ID of the remote dialog returned by that function
function add_bibref_dialog(bibcnt){
     var apdname = "edit-app-dialog";     
     var fname = "add-bibref-dialog";
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:"+fname+"&bibcnt=" + bibcnt,
     success : function(resp){
     $('#remBibRef').html(resp);
     $('#'+apdname).modal('hide');
     $('#'+fname).modal('show');
   }
  });
    
};

function bibref_search(){
  var query = $('#input-bib').val() 
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=bib:quick-search&query=" + query,
     success : function(resp){
     $('#bib-results').html(resp);
   }
  });
  
};

// bibref_attach('{$uuid}')"
function bibref_attach(action){
     var apdname = "edit-app-dialog";     
     var fname = "add-bibref-dialog";
     var bibref = $('input[name=select-bib]:checked').attr('id')
     var content = $('#content-'+bibref).html()
     var page = $('#input-page').val()
     if (action == 'select'){
        $('#bibl-refs').html('<p id="selected-bibref" data-uuid="'+bibref+'" data-page="'+page+'"><b>See:</b></br>'+content+', p.' + page + '</p>')
     }
     $('#'+apdname).modal('show');
     $('#'+fname).modal('hide');     
};


function show_new_link_dialog(){
    var items = $('input[name=res-check]:checked').attr('id')
    var arr = [];
        $.each($("input[name='res-check']:checked"), function(){
                  arr.push($(this).attr('id'));
         });
//    alert("Your selected items are: " + arr.join(", "));
   var word = $("input[name=query]").val();
   var line_id = $("#swl-line-id-span").text();
  if (arr.length > 0) { 
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=lli:new-link-dialog&line="+line_id+"&word="+word+"&items="+arr.join(","), 
  success : function(resp){
      $('#remoteDialog').html(resp);
      $('#new-link-dialog').modal('show');
  },
  error : function(resp){
   console.log(resp)
   alert("PROBLEM"+resp);
  }

  }); 
  }  
//    alert(items)
};

function add_context_lines(el){
  var sel = Number($('#'+el+ ' option:selected').val().split('#')[1]) 
  var selarr = [];
  $('#' + el +' option').each(function(){
      var cval = Number($(this).val().split('#')[1]);
      if (cval <= sel) {
        selarr.push($(this).text());
      } else {
      }
  });
  $('#' + el.replace("select", "staging-area")).text(selarr.join(''))
  //alert(sel + 'xx' + selarr.join(","))  
};


// save link items in the form
// TODO make generic and merge with bib:new-entry
function save_link_items(){
  formData = $("#new-link-form").serialize()
  var uuid = $("input[name=qs-uuid]").val();
  var vis = $('input[name=visradio]:checked').val();
  $.ajax({
  type : "POST",
  url : "api/responder.xql?func=lli:save-link-items&uuid="+uuid+"&vis="+vis,
  data: formData,
  success : function(resp){
    if (resp.startsWith("Could not")) {
    toastr.error(resp, "漢學文典 says:");
/*    toastr.error("Could not save translation for "+line+".", "HXWD says:");        */
    } else {
    toastr.info("Modification saved.", "漢學文典 says:");
    $('#new-link-dialog').modal('hide');
    $('#remoteDialog').html('');
    //window.location = 'bibliography.html?uuid='+uuid
    dirty = false;
    }
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
  
};




// add a url to a bibliographic item
function add_url(modsid){
     var fname = "add-url-dialog"
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:"+fname+"&modsid=" + modsid,
     success : function(resp){
     $('#remoteDialog').html(resp);
     $('#'+fname).modal('show');
     }
    });
};

function biburl_save(modsid){
     var fname = "add-url-dialog"
//     var url = encodeURI($('#input-url').val());
//     var desc = $('#input-desc').val();
//     var note = $('#input-note').val();
     formData = $("#add-url-form").serialize()  
     $.ajax({
     type : "POST",
//     dataType : "html",  
     data: formData,
     url : "api/responder.xql?func=bib:url-save&modsid=" + modsid,
      success : function(resp){
      toastr.info("New URL saved.", "漢學文典 says:");
      }
     });
     $('#'+fname).modal('hide');
     $('#remoteDialog').html('');
     window.location = 'bibliography.html?uuid='+modsid
};

function show_dialog(dialog_name, options){
     var opt = JSON.stringify(options);
     $('.modal').modal('hide');
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:dispatcher&name="+dialog_name+"&options="+opt,
     success : function(resp){
     $('#remoteDialog').html(resp);
     $('#'+dialog_name).modal('show');
   }
  });  
};

function change_passwd(user){
   var newpw = $("input[name='password']").val()
   $.ajax({ 
    type : "POST",
    dataType : "json",
    url : "api/changepw.xql",
    data: {"passwd" : newpw, "user": user},
    success : function (resp){
     toastr.info("Your password has been changed.  You will be logged out.", "漢學文典 says:");
     dologout()
   }
   });
    
};

function showtab(uuid){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql?func=showtab&uuid="+uuid, 
  success : function(resp){
    $('#show-text-results').html(resp);
  }
  });
};

function display_tr_file_dialog(dialog_name, slot, trid){
   $('#'+dialog_name).modal('hide');
  var location = window.location.search;
  console.log(location)
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/new_translation.xql"+location+"&slot="+slot+"&trid="+trid, 
  success : function(resp){
    $('#remoteDialog').html(resp);
    $('#new-translation-dialog').modal('show');  
  }
  });
};


//delete translation file
function delete_tr_file(dialog_name, slot, trid){
  var strconfirm = confirm("Do you really want to delete this translation?")
  if (strconfirm == true){
  $('#'+dialog_name).modal('hide');
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/responder.xql?func=ltr:delete-translation&trid=" + trid, 
  success : function(resp){
     if (resp.startsWith("Translation")) {
      toast.error(resp, "HXWD says:")
     } else {
      toastr.info("Translation has been deleted.", "HXWD says:");
     }
  }
  });
  reload_selector(slot, "");
  }  
}



// display dialog for pb
// fname is the name of the function in dialogs, has to be the same as the ID of the remote dialog returned by that function
function display_named_dialog(uid, fname){
     //what an ugly kludge... repeated again!!
     if (uid == 'x-get-line-id') {
        var line_id= $( "#swl-line-id-span" ).text();  
        uid = line_id
     }
     pos = $("#swl-query-span" ).attr("data-pos");
     sel = $("#swl-query-span").text();
     line = $( "#swl-line-text-span" ).text();
     console.log("pos:", pos, sel, line)
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:"+fname+"&uid=" + uid + "&pos=" + pos + "&sel=" + sel + "&line="+line,
     success : function(resp){
     $('#remoteDialog').html(resp);
     $('#'+fname).modal('show');
   }
  });
    
};

function save_pb(){
     var line_id= $( "#swl-line-id-span" ).text();  
     uid = line_id;
     pos = $("#swl-query-span" ).attr("data-pos");
     sel = $("#swl-query-span").text();
     line = $( "#swl-line-text-span" ).text();
     pb = $("#page-num").val();
     wit = $("#witness option:selected").val();
     console.log("pos:", pb, wit)
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=save-pb&uid=" + uid + "&pos=" + pos + "&sel=" + sel + "&line="+line+"&pb="+pb+"&wit="+wit,
     success : function(resp){
     toastr.info("Pagebreak saved.", "漢學文典 says:");
     $('#pb-dialog').modal('hide');
     $('#remoteDialog').html();
   }
  });
};

function save_txc(){
  formData = $("#edit-app-form").serialize();
  var line_id= $( "#swl-line-id-span" ).text();  
  uid = line_id;
  pos = $("#swl-query-span" ).attr("data-pos");
  sel = $("#swl-query-span").text();
  line = $("#swl-line-text-span" ).text();
  bibref = $('#selected-bibref').attr('data-uuid');
  bibpage = $('#selected-bibref').attr('data-page');
  $.ajax({
  type : "POST",
  url : "api/responder.xql?func=txc:save-txc&uid="+uid + "&pos=" + pos + "&sel=" + sel + "&line="+line+ "&bibref=" + bibref + "&bibpage=" + bibpage,
  data: formData,
  success : function(resp){
   if (resp.startsWith('Error')) {
     toastr.error(resp, "漢學文典 says:");
   } else {
     toastr.info("Variant recorded.", "漢學文典 says:");
   }  
   $('#edit-app-dialog').modal('hide');
   $('#remoteDialog').html();
  }
  });
};

function edit_app(textid,appid){
//    alert("Edit the apparatus: coming soon!!");
     var fname = "edit-app-dialog"
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:"+fname+"&appid=" + appid+"&textid="+textid,
     success : function(resp){
     $('#remoteDialog').html(resp);
     $('#'+fname).modal('show');
   }
  });


};

// display dialog for punctuation
function display_punc_dialog(uid){
     //what an ugly kludge...
     if (uid == 'x-get-line-id') {
        var line_id= $( "#swl-line-id-span" ).text();  
        uid = line_id
     }
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/responder.xql?func=dialogs:punc-dialog&uid=" + uid,
     success : function(resp){
     $('#remoteDialog').html(resp);
     $('#punc-dialog').modal('show');
   }
  });
};
// also used for merge-following-seg 
function save_punc(line_id, next){
  var seg = $('#current-seg').text();
  var type = $("#type" ).val();
  if (next == 'merge') {
    var url = "api/responder.xql?func=merge-following-seg&line_id="+line_id+"&type="+type;
    next = line_id;
  } else if (next == 'no_split') {
    var url = "api/responder.xql?func=save-punc&line_id="+line_id+"&type="+type+"&action="+next;
    next = "";
  } else {
    var url = "api/responder.xql?func=save-punc&line_id="+line_id+"&type="+type;
  }
  $.ajax({
  type : "PUT",
  contentType: "text/plain;charset=UTF-8",
  processData: false,
  data: seg,
  dataType : "html",
  url : url,
  success : function(resp){
    if (resp.startsWith("Error")) {
         toastr.error(resp, "漢學文典 says:");
    }
      // if cont = 'true', than the return value is the new segment id
    $('#punc-dialog').modal('hide');
    if (next.length > 1){
      display_punc_dialog(next)
    } else {
      window.location.reload(true)
    }
  },
  error : function(resp){
    console.log(resp)
    toastr.error("An unknown error happened on the system.", "漢學文典 says:");
  }
  });      
};

function text_request(kid){
  $.ajax({
  type : "GET",
  contentType: "text/plain;charset=UTF-8",
  dataType : "html",
  url : "api/responder.xql?func=text-request&kid="+kid,
  success : function(resp){
     if (resp.startsWith('Error')) {
     toastr.error(resp, "HXWD says:");
     } else {
     toastr.info("Request received. Please leave a few days for processing", "漢學文典 says:");
    }
  },
  error : function(resp){
    console.log(resp)
    toastr.error("An unknown error happened on the system.", "漢學文典 says:");
  }
  });
};

function add_text(kid, cbid){
  $.ajax({
  type : "GET",
  contentType: "text/plain;charset=UTF-8",
  dataType : "html",
  url : "api/responder.xql?func=add-text&kid="+kid+"&cbid="+cbid,
  success : function(resp){
     if (resp.startsWith('Error')) {
     toastr.error(resp, "HXWD says:");
     } else {
     toastr.info("Request processed", "漢學文典 says:");
     }
  },
  error : function(resp){
    console.log(resp)
    toastr.error("An unknown error happened on the system.", "漢學文典 says:");
  }
  });
    
};
// display dialog for text permission editing
function display_edit_text_permissions_dialog(){
  const queryString = window.location.search;
  $.ajax({
    type : "GET",
    dataType : "html",  
    url : "api/responder.xql" + queryString + "&func=dialogs:edit-text-permissions-dialog",
    success : function(resp){
      $('#remoteDialog').html(resp);
      $('#edit-text-permissions-dialog').modal('show');
    }
  });
};

function add_editing_permissions(textid) {
  const selecton = document.getElementById("edit-text-permissions-dialog-add-users-select").selectedOptions;

  if (selecton.length != 1) {
    alert("Please select a user!");
    return;
  }

  const userid = selecton[0].value;

  $.ajax({
    type: "GET",
    dataType: "html",
    url: "modules/admin/text-editing-permissions.xql" + "?action=add&userid=" + userid + "&textid=" + textid,
    success: function(resp) {
      toastr.info("Permission added for user " + userid, "HXWD says:");
      // Reload dialog
      $('#edit-text-permissions-dialog').modal('hide');
      display_edit_text_permissions_dialog();
    },
    error: function(resp) {
      console.log(resp);
      toastr.error("Error occured when trying to add permission", "HXWD says:");
    }
  });
}

function remove_editing_permissions(textid, userid) {
  $.ajax({
    type: "GET",
    dataType: "html",
    url: "modules/admin/text-editing-permissions.xql" + "?action=remove&userid=" + userid + "&textid=" + textid,
    success: function(resp) {
      toastr.info("Permission revoked for user " + userid, "HXWD says:");
      // Reload dialog
      $('#edit-text-permissions-dialog').modal('hide');
      display_edit_text_permissions_dialog();
    },
    error: function(resp) {
      console.log(resp);
      toastr.error("Error occured when trying to revoke permission", "HXWD says:");
    }
  });
}

window.onbeforeunload = function() {
    return dirty ? "If you leave this page you will lose your unsaved changes." : null;
    // next: check for unsaved tr, save, then report: done
    dirty = false;
}

/* from https://getbootstrap.com/docs/4.2/components/modal/
  $('#exampleModal').on('show.bs.modal', function (event) {
  var button = $(event.relatedTarget) // Button that triggered the modal
  var recipient = button.data('whatever') // Extract info from data-* attributes
  // If necessary, you could initiate an AJAX request here (and then do the updating in a callback).
  // Update the modal's content. We'll use jQuery here, but you could use a data binding library or other methods instead.
  var modal = $(this)
  modal.find('.modal-title').text('New message to ' + recipient)
  modal.find('.modal-body input').val(recipient)
})
 * 
 */
