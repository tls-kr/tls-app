$(function() {
    console.log( "ready!" );
});            

if (!window.x) {
    x = {};
}
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
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/get_sw.xql?word=" + word, 
  success : function(resp){
  $('#swl-select').html(resp)
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

function hide_swl_form(){
    $( "#swl-form" ).hide();    
    console.log("Clearing SWL form");
    $("#select-synfunc" ).val("");
    $("#select-semfeat").val("");
    $("#select-concept" ).val("");
 
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
};

function show_swls_for_line(line_id){
  $.ajax({
  type : "GET",
  dataType : "html",
  url : "api/show_swl_for_line.xql?line=" + line_id, 
  success : function(resp){
  console.log("Displaying response"+resp);
  $('#'+line_id+'-swl').append(resp)
  }
  });
    
};

// save one attribution
function save_this_swl(sense_id){
    var line_id=document.getElementById( "swl-line-id-span" ).innerText;
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_swl.xql?line="+line_id+"&sense="+sense_id,
  success : function(resp){
  hide_swl_form();
  console.log("Hiding form");
  show_swls_for_line(line_id);
//  alert(resp);
  },
  error : function(resp){
    alert(resp);
  }
  });
    
}

function save_to_concept(){
    var guangyun_id = $("input[name='guangyun-input']:checked").val();
    var line_id= $( "#swl-line-id-span" ).text();
    var word = $("#swl-query-span").text();
    var synfunc_val = $("#select-synfunc" ).val();
    var semfeat_val = $("#select-semfeat").val();
    var concept_val = $("#select-concept" ).val();
    var synfunc_id = $("#synfunc-id-span" ).text();     
    var semfeat_id = $("#semfeat-id-span" ).text();
    var concept_id = $("#concept-id-span" ).text();
    var def_val = $("#input-def" ).val();
  $.ajax({
  type : "PUT",
  dataType : "html",
  url : "api/save_to_concept.xql?line="+line_id+"&word="+word+"&concept="+concept_id+"&concept-val="+concept_val+"&synfunc="+synfunc_id+"&synfunc-val="+synfunc_val+"&semfeat="+semfeat_id+"&semfeat-val="+semfeat_val+"&guangyun="+guangyun_id+"&def="+def_val,
  success : function(resp){
    alert("OK");
  },
  error : function(resp){
    alert("PROBLEM"+resp);
  }
  });



};

// jquery selectors 

$('.zh').bind('touchend', function(){
    $(this).mouseup();
});

$( ".zh" )
  .mouseup(function() {
  const sel = x.Selector.getSelected();
    const xid = sel.anchorNode.parentNode.id.toString();
    const line = sel.anchorNode.parentNode.innerText;
    var new_height = $("#chunkcol-right").outerHeight();
    var new_width = $("#chunkcol-right").outerWidth();
    console.log(xid);
    console.log(new_width);
    $( "#swl-line-id-span" ).html(xid);
    $( "#concept-line-id-span" ).html(xid);
//    $( "#swl-line-text" ).val(line);      
    $( "#swl-line-text-span" ).html(line);      
    $( "#concept-line-text-span" ).html(line);      
    $( "#swl-query" ).val( sel.toString());
    $( "#concept-query-span" ).html( sel.toString());
    $( "#swl-query-span" ).html( sel.toString());
    $( "#swl-form" ).removeAttr("style");
    $( "#swl-form" ).show();
    $( "#swl-form" ).scrollTop( 0 );
//    $( "#swl-form" ).css({'width' : 'new_width'+px});
    $( "#swl-form" ).width(new_width);
    
   get_sw()
   $('[data-toggle="popover"]').popover({'content' : get_atts})
  });
//$(document).ready(function(){  

//this is for the filter in browse pages
  $("#myInput")
  .keyup(function() {
    var value = $(this).val().toLowerCase();
//    console.log(value);
   $(".abbr").filter(function() {
      $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
    });
  });
//});
    $( "#select-concept" ).autocomplete({
      appendTo: "#select-concept-group",
      source: function( request, response ) {
        $.ajax( {
          url: "api/autocomplete.xql",
          dataType: "jsonp",
          data: {
            term: request.term,
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
      minLength: 2,
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
      minLength: 2,
      select: function( event, ui ) {
        $("#semfeat-id-span" ).html(ui.item.id);     
        console.log( "Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );
    
// clear the modal form

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
    
    
//    $(window).load(function(){
      $(".mysticky").sticky({ topSpacing: 50 });
//    });


// popover

$(document).ajaxComplete(function() {
  $("[data-toggle='popover']").popover(
  {'content' : function(){
    var target=$(this).attr("data-target");
    var div_id =  "tmp-id-" + $.now();
    return get_atts(target, div_id);}, 
  'html' : true});
});

/*
$(function () {
  $('[data-toggle="popover"]').popover({'content' : get_atts(this)})
}) */

function get_atts(target, div_id){
   console.log(target)
   $.ajax( {
    url: "api/get_text_preview.xql?loc="+target,
    dataType: "html",
    success: function( data ) {
    $('#'+div_id).html(data);    
    }
    });
   return '<div id="'+ div_id +'">Loading...</div>';
};