$(function() {
    console.log( "ready!" );
});            

if (!window.x) {
    x = {};
}
// this is some plumbing to get the selection
x.Selector = {};
x.Selector.getSelected = function() {
    var t = '';
    if (window.getSelection) {
        t = window.getSelection();
    } else if (document.getSelection) {
        t = document.getSelection();
    } else if (document.selection) {
        t = document.selection.createRange().text;
    }
    return t;
};

function get_sw(){
var word = $("#swl-query-span").text();
// alert(uid);
  if (word.length > 0){
  var context = window.location.pathname;
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_sw.xql?word=" + word+"&context="+context, 
  success : function(resp){
  $('#swl-select').html(resp)
  }
  });
  }
};

function get_sf(senseid){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_sf.xql?senseid=" + senseid, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  initialize_sf_autocomplete();  
  $('#edit-sf-dialog').modal('show');
  }
  });
};

function get_guangyun(){
// this is assuming one char, TODO make this work for multiple
var word = $("#swl-query-span").text();
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_guangyun.xql?char=" + word, 
  success : function(resp){
  console.log(resp)
  $('#guangyun-group').append(resp)
  }
  });
};

function hide_new_att(){
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
  console.log("Displaying response at: " + '#'+line_id+'-swl');
//  $('#swl-select').html(resp)
  $('#'+line_id+'-swl').html(resp);
  $('#'+line_id+'-swl').show();
  }
  });
    
};

// this saves the SW for a line, called from save_this_swl (from the "Use" button)

function save_swl_line(sense_id, line_id){
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_swl.xql?line="+line_id+"&sense="+sense_id,
  success : function(resp){
  hide_swl_form("#editSWLDialog");
  console.log("Hiding form");
  show_swls_for_line(line_id);
  toastr.info("Attribution has been saved. Thank you for your contribution.", "HXWD says:")
  },
  error : function(resp){
    console.log(resp)
    alert(resp);
  }
  });       
};

// save one attribution: the "Use" button calls this function
function save_this_swl(sense_id){
    var line_id=document.getElementById( "swl-line-id-span" ).innerText;
    save_swl_line(sense_id, line_id);
};

// save edited swl
function save_swl(){
  //not sure what to do here... what kind of changes to we want to allow?  
};

// save one sw
function show_new_concept(){
  var word = $("#swl-query-span").text();
  var line_id= $( "#swl-line-id-span" ).text();  
  var line = $( "#swl-line-text-span" ).text();
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "api/get_swl.xql?type=concept&word="+word+"&line-id="+line_id+"&line="+line, 
  success : function(resp){
  $('#remoteDialog').html(resp);
  console.log("Initializing autocomplete functions");
  // lets see if this works better
  initialize_autocomplete();
  $('#editSWLDialog').modal('show');
  }
  });
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
    var synfunc_val = $("#select-synfunc" ).val();
    var semfeat_val = $("#select-semfeat").val();
    var concept_val = $("#newsw-concept-span" ).text();
    var synfunc_id = $("#synfunc-id-span" ).text();     
    var semfeat_id = $("#semfeat-id-span" ).text();
    var concept_id = $("#concept-id-span" ).text();
    var def_val = $("#input-def" ).val();

  $.ajax({
  type : "PUT",
  dataType : "json",
  async : false,
  url : "api/save_newsw.xql?concept="+concept_id+"&wid="+word_id+"&word="+word+"&py="+py+"&concept-val="+concept_val+"&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"&semfeat-val="+semfeat_val+"&def="+def_val,
  success : function(resp){
    if (resp.sense_id == "not_saved"){
    toastr.info("Could not save: " + resp.result, "HXWD says:")        
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
    alert(resp);
  }
  });
 
    
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
  if (typeof guangyun_id !== 'undefined'){
  console.log(guangyun_id);
  $.ajax({
  type : "PUT",
  dataType : "json",
  url : "api/save_to_concept.xql?line="+line_id+"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"&semfeat-val="+semfeat_val+"&def="+def_val+"&guangyun="+guangyun_id,
  success : function(resp){
    var strconfirm = confirm("Saved concept. Do you want to save attribution now?");
    if (strconfirm == true) {
        save_this_swl(resp.sense_id)
    }
//    alert(resp.sense_id);
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

// jquery selectors 
// we bind a touchend event to mouseup.  This is an attempt to make this work
// on mobile devices, but apparently not really working.
$('.zh').bind('touchend', function(){
    $(this).mouseup();
});

// here we bind the mouseup event of all elements with the class "zh" to this
// anonymous function, get the selected stuff from the x.Selector and proceed
// to show the stuff

$( ".zh" )
  .mouseup(function() {
  const sel = x.Selector.getSelected();
    const xid = sel.anchorNode.parentNode.id.toString();
    const line = sel.anchorNode.parentNode.innerText;
    var new_height = $("#chunkcol-right").outerHeight();
    var new_width = $("#chunkcol-right").outerWidth();
    console.log(xid);
    console.log(new_height);
    // this sets the selection to the search input field, to make it easy to search for this term
    // idea: write a search that displays the results on this page, so that I do
    // not need to leave the current context.
    $( 'input[name="query"]' ).val(sel.toString());
    $( "#swl-line-id-span" ).html(xid);
    $( "#swl-line-text-span" ).html(line);      
    $( "#swl-query" ).val( sel.toString());
    $( "#swl-query-span" ).html( sel.toString());
    $( "#swl-form" ).removeAttr("style");
    $( "#swl-form" ).show();
    $( "#swl-form" ).scrollTop( 0 );
    // I do see these numbers in the CSS, but they don't seem to take effect
 //   $( "#swl-form" ).width(new_width - 10);
 //   $( "#swl-form" ).height(new_height - 10);
    
   get_sw()
   // this is to activate the click on the text line to get the context
   $('[data-toggle="popover"]').popover({'content' : get_atts})
  });

//this is for the filter in browse pages
  $("#myInput")
  .keyup(function() {
    var value = $(this).val().toLowerCase();
//    console.log(value);
   $(".abbr").filter(function() {
      $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
    });
  });

// for concepts, synfunc, semfeat we provide autocomplete

function initialize_sf_autocomplete(){
    $( "#select-synfunc" ).autocomplete({
      appendTo: "#select-synfunc-group",
      response : function(event, ui){
      // need to reset this, in case of a new SF
        $("#synfunc-id-span" ).html("xxx");     
        $("#def-old-sf-span").html("<span class='warn'>If the new SF is not from the list, please add a definition below!</span>")
      },
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

// add this anonyomous function to the #new-concept dialog, so that on hiding 
// its content gets cleared away.
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

function logout(){
  $.ajax({
  type : "GET",
  dataType : "html",  
  url : "logout?logout=logout", 
  success : function(resp){
      //$('#'+uid+'-resp').html(resp)
  }
  });
}

$('#login-form').submit(function (){
        $.ajax({
            dataType: "json",
            method: "post",
            url: 'login',
            success: function(data)
            {
                if (data.status === 'OK') {
                console.log(data);
             //       window.location.replace('index.html');
                }
                else {
                console.log(data);
//                    alert(data.currentuser);
                }
            },
            error: function(data, status){
                console.log("Something went wrong" + data + "status:" + status);
//                alert("Something went wrong: " + status);
            }
        });
});

// not yet implemented

$('#settings-form').submit(function (){
    this.preventDefault();
    alert("This button does nothing.");
/*        $.ajax({
            dataType: "json",
            method: "post",
            url: 'login',
            success: function(data)
            {
                if (data.status === 'OK') {
                console.log(data);
             //       window.location.replace('index.html');
                }
                else {
                console.log(data);
                    alert(data.status, data.currentuser);
                }
            },
            error: function(data, status){
                console.log(data);
                alert(status);
            }
        });
*/});

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

// delete the attribution; this is the x on the attributions

function delete_swl(uid){
    var strconfirm = confirm("Do you really want to delete this attribution?");
    if (strconfirm == true) {
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/delete_swl.xql?type=swl&uid=" + uid, 
     success : function(resp){
   //  save_this_swl(resp.sense_id)
      var line_id = resp.replace(/"/g, '')
      console.log("Lineid: " & line_id);
      show_swls_for_line(line_id);
      toastr.info("Attribution deleted.", "HXWD says:");
   }
  });
  }
};

// for the translations (class "tr"), we save on keyup, so we check for our event
$( ".tr" ).keyup(function( event ) {
}).keydown(function( event ) {
    var trid = $(this).attr('id');
    var lineid = trid.slice(0, -3);
//    var lineid = trid.substring(0, trid.indexOf("-tr"));
    var line = document.getElementById( lineid ).innerText;
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
    var lineid = trid.slice(0, -3);
    var line = document.getElementById( lineid ).innerText;
    var tr = $(this).text()
    console.log("tab", $(this).data('before') , "h", tr)
    if ($(this).data('before') !== tr){    
          save_tr(trid, tr, line);
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  }
  if ( event.which == 13 ) {
    var trid = $(this).attr('id');
    var lineid = trid.slice(0, -3);
    var line = document.getElementById( lineid ).innerText;
    var tr = $(this).text()
    event.preventDefault();
    if ($(this).data('before') !== tr){    
          save_tr(trid, tr, line);
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  }
});

// this does the actual save
function save_tr (trid, tr, line){
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_tr.xql?trid="+trid+"&tr="+tr,
  success : function(resp){
    toastr.info("Translation for line "+line+" saved.", "HXWD says:");
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

// save modified definition of swl

$( ".swedit" ).keyup(function( event ) {
}).keydown(function( event ) {
  alert(event);
  if ( event.which == 9 | event.which == 13) {
    var defid = $(this).attr('id');
    var defel = document.getElementById( defid ).innerText;
    var def = $(this).text()
    save_def(defid, def);    
  }
});

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

function save_sf (){
    var sense_id= $( "#sense-id-span" ).text();
    var synfunc_val = $("#select-synfunc" ).val();
    var synfunc_id = $("#synfunc-id-span" ).text();     
    var def_val = $("#input-def" ).val();

  console.log(sense_id)
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_sf.xql?sense-id="+sense_id+"&sf_id="+synfunc_id+"&sf_val="+synfunc_val+"&def="+def_val,
  success : function(resp){
    hide_swl_form( "#edit-sf-dialog" );      
    toastr.info("Syntactic function updated.", "HXWD says:");
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

// stub for comment  2020-02-23, called from app:swl-form-dialog

function comment_this_line(){
    
};