var dirty = false;

$(function() {
    console.log( "ready!" );
    //get_swl_for_page();
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

function get_swl_for_page(){
  var location = window.location.search;
/*  var url = new URL(context);
  var location = url.searchParams.get("location")*/
  console.log(location)
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_swl_for_page.xql"+location, 
  success : function(resp){
  for (index = 0; index < resp.length; ++index) {
    console.log(resp[index]);
  };
  $('#toprow').html(resp);
  }
  });
    
};
// called ftom textview, toprow
// slot is slot1 or slot2, type is 'transl' or 'comm', no is the item number in the list
function get_tr_for_page(slot, myid){
  var location = window.location.search;
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_tr_for_page.xql"+location+"&slot="+slot+"&content-id="+myid, 
  success : function(resp){
   var obj = JSON.parse(resp);
   for (var prop in obj) {
    line_id = prop.split(".").join("\\.");
    $(line_id).html(obj[prop]);
   };
  reload_selector(slot, myid);   
  }
  });
    
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
function store_new_translation(slot, textid){
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
  url : "api/store_new_translation.xql?lang="+lang+"&textid="+textid+"&transl="+transl+"&trtitle="+trtitle+"&bibl="+bibl+"&vis="+vis+"&copy="+copy+"&type="+type+"&rel="+rel, 
  success : function(resp){
  // todo : reload the selector with latest information
  $('#new-translation-dialog').modal('hide');
  reload_selector(slot);
  toastr.info("New work has been saved.", "HXWD says:")  
  }
  });
    
};

function reload_selector(slot, newid){
  var location = window.location.search;
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/responder.xql"+location+"&slot="+slot+"&content-id="+newid+"&func=reload-selector", 
  success : function(resp){
  $("#"+slot).html(resp)
  }
  });
    
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
    var synfunc_val = $("#select-synfunc" ).val();
    var semfeat_val = $("#select-semfeat").val();
    var concept_val = $("#newsw-concept-span" ).text();
    var synfunc_id = $("#synfunc-id-span" ).text();     
    var semfeat_id = $("#semfeat-id-span" ).text();
    var concept_id = $("#concept-id-span" ).text();
    var def_val = $("#input-def" ).val();
  if (synfunc_id.length == 0){
          var ndef = prompt("No syntactic function '" + synfunc_val + "' defined.  If you want to define a new one, please enter the definition here:") 
          if (ndef) {
            $.ajax({
              type: "PUT",
              datatype : "json",
              url : "api/save_sf.xql?sf_val="+synfunc_val+"&sf_id=xxx&def="+ndef,
              success : function(resp){
                toastr.info("New syntactic function has been saved.", "HXWD says:");
                alert("Please re-enter and select the new syntactic function.");   
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
    alert(resp);
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
  url : "api/save_to_concept.xql?line="+line_id+"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"&semfeat-val="+semfeat_val+"&def="+def_val+"&guangyun="+guangyun_id,
  success : function(resp){
  //  var strconfirm = confirm("Saved concept. Do you want to save attribution now?");
  //  if (strconfirm == true) {
        save_this_swl(resp.sense_id)
  //  }
//    alert(resp.sense_id);
  },
  error : function(resp){
  console.log(resp)
    alert("PROBLEM"+resp);
  }
  });
 }
}
} else {
  alert("Guangyun has not been selected!");    
}

};

// display the dialog in the right side of the screen
function get_sw(sel, xid, line){
   var dw = document.documentElement.clientWidth;
   var dh = document.documentElement.clientHeight;
   var new_width = $("#toprow").outerWidth() - $("#toprow-1").outerWidth() - $("#toprow-2").outerWidth();
   console.log(new_width);
    // this sets the selection to the search input field, to make it easy to search for this term
    // idea: write a search that displays the results on this page, so that I do
    // not need to leave the current context.
   $( 'input[name="query"]' ).val(sel);
   $( "#swl-line-id-span" ).html(xid);
   $( "#swl-line-text-span" ).html(line);      
   $( "#swl-query" ).val( sel);
   $( "#swl-query-span" ).html(sel);
//   $( "#swl-form" ).removeAttr("style");
   $( "#swl-form" ).css("max-height", dh - 51);
   $( "#swl-form" ).css("max-width", new_width - 10);
   $( "#swl-form" ).show();
   $( "#swl-form" ).scrollTop( 0 );
// alert(uid);
  if ((sel.length > 0) && (sel.length < 10)){
  var context = window.location.pathname;
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_sw.xql?word=" + sel+"&context="+context, 
  success : function(resp){
  $('#swl-select').html(resp)
  }
  });
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
  get_sw(sel.toString(), xid, line)
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

// delete the attribution; this is the x on the attributions

function delete_swl(uid){
    var strconfirm = true // confirm("Do you really want to delete this attribution?");
    if (strconfirm == true) {
     $.ajax({
     type : "GET",
     dataType : "html",  
     url : "api/delete_swl.xql?type=swl&uid=" + uid, 
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
        save_sf_def (sfid.slice(0, -3), sf)
        $(this).data('before', sf)
    }}
    });
        
function save_sf_def (sfid, def){
  console.log(sfid)
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/responder.xql?func=save-sf-def&id="+sfid+"&def="+def,
  success : function(resp){
    toastr.info("Modification for definition saved.", "HXWD says:");
  },
  error : function(resp){
  console.log(resp);
    alert("PROBLEM: "+resp.statusText + "\n " + resp.responseText);
  }
  });    
};

$( ".tr" ).blur(function (event) {
    var trid = $(this).attr('id');
    var lineid = trid.slice(0, -3);
    var line = document.getElementById( lineid ).innerText;
    var tr = $(this).text()
    console.log("blur", $(this).data('before') , "h", tr)
    if ($(this).data('before') !== tr){    
         cname = confirm("Unsaved data exist, do you want to save?");
         if (cname){
           save_tr(trid, tr, line);
          }
          // save this, in case there are more changes
          $(this).data('before', tr)
    }
  dirty = false;
});


// for the translations (class "tr"), we save on keyup, so we check for our event
$( ".tr" ).keyup(function( event ) {
}).keydown(function( event ) {
    var trid = $(this).attr('id');
    var lineid = trid.slice(0, -3);
    var line = document.getElementById( lineid ).innerText;
    dirty = true;
  if (event.ctrlKey == true){
    //var hlineid = lineid.split(".").join("\\.")
    console.log("key: ", event.which)
    if (event.which > 48 & event.which < 58) {
     event.preventDefault();
      //var line = $("#"+hlineid).text()
      var pos = event.which - 49
      var sel = line.slice(pos,pos+1)
      get_sw(sel, lineid, line)
      //copyToClipboard($( "#swl-query-span" ));
    } else
    if (event.which == 83) {
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
         var ok=("'"+ abbr +"' has been used in attributions, do you want to proceed? All attributions will be deleted as well.")
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

function quick_search(){
    var word = $("#swl-query-span").text();
    $.get("api/responder.xql?func=quick-search&query="+word+"&start=1&count=20&mode=rating", "html", 
    function(resp){
         $('#swl-select').html(resp)
        }
    )
    
}

// need to think about where to use this:
/*window.onbeforeunload = function() {
  return "";
}
 * 
 * or this:
 * 
*/

window.onbeforeunload = function() {
    return dirty ? "If you leave this page you will lose your unsaved changes." : null;
    // next: check for unsaved tr, save, then report: done
    dirty = false;
}
