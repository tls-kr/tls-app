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
  url : "api/get_sw.xql?word=" + word, 
//  url : "/tls/lexicon/quotations/",
  success : function(resp){
  $('#swl-select').html(resp)
  }
  });
};

function show_att(uid){
  $.ajax({
  type : "GET",
  url : "api/show_att.xql?uid=" + uid, 
//  url : "/tls/lexicon/quotations/",
  success : function(resp){
  $('#'+uid+'-resp').html(resp)
  }
  });
};

function save_this_swl(sense_id){
    var line_id=document.getElementById( "swl-line-id" );
  $.ajax({
  type : "PUT",
  url : "api/save_swl.xql?line="+line_id+"&sense="+sense_id,
  success : function(resp){
  alert(resp);
  }
  });
    
}

$( ".zh" )
  .mouseup(function() {
  const sel = x.Selector.getSelected();
    const xid = sel.anchorNode.parentNode.id.toString()
    const line = sel.anchorNode.parentNode.innerText
    console.log(xid);
    console.log(line);
    $( "#swl-line-id" ).val(xid);
    $( "#swl-line-id-span" ).html(xid);
    $( "#swl-line-text" ).val(line);      
    $( "#swl-line-text-span" ).html(line);      
    $( "#swl-query" ).val( sel.toString());
    $( "#swl-query-span" ).html( sel.toString());
//    $( "#swl-form").style.display = 'block';
   get_sw()
  });
//$(document).ready(function(){  
  $("#myInput")
  .keyup(function() {
    var value = $(this).val().toLowerCase();
//    console.log(value);
   $(".abbr").filter(function() {
      $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
    });
  });
//});