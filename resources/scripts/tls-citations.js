/* Javascript functions to process the citations
 * The url is expected to be configured at /krx/ on the same server to avoid CORS issues.
 * The dev server mimicks this by providing dummy functions locally
 */

// the dev server needs a different prefix

const urlprefix =  window.location.host.includes('8443') ? '/exist/apps/tls-app/' : '/'




function do_citation() {
  var item = $('#input-target').val();
  var perspective = $('#select-perspective').val()
  var group1 = $('#select-grouping-1').val()
  var group2 = $('#select-grouping-2').val()
  $.ajax({
  type : "GET",
  dataType : "html",
  url : urlprefix +  "citations/"+perspective+"/"+group1+"?item="+item+"&group2="+group2, 
  success : function(resp){
    $('#cit-results').html(resp.responseText);
    },
  error: function(resp){
    console.log('an error has occurred?!', resp.status, urlprefix)
    },
  complete : function(resp){
  //  var res = String(resp);
    $('#cit-results').html(resp.responseText);
  }
  });
  $('#cit-results').html('Processing data, please wait for a moment.')
};


function cit_set_value(perspective, item){
  $('#input-target').val(item);
  $('#select-perspective').val(perspective).change();
};