/* Javascript functions to process the citations
 * The url is expected to be configured at /krx/ on the same server to avoid CORS issues.
 * The dev server mimicks this by providing dummy functions locally
 */

// the dev server needs a different prefix

const urlprefix =  window.location.host.includes('8443') ? '/exist/apps/krx-app/' : 'krx/'




function do_citation() {
  var location = window.location.search;
  $.ajax({
  type : "GET",
  dataType : "json",
  url : urlprefix +  "itemcount"+location, 
  success : function(resp){
    $('#krx_search').html(resp.responseText);
    },
  error: function(resp){
    console.log('an error has occurred?!', resp.status, urlprefix)
    },
  complete : function(resp){
  //  var res = String(resp);
    $('#krx_search').html(resp.responseText);
  }
  });
};


function cit_set_value(perspective, item){
  $('#input-target').val(item);
  $('#select-perspective').val(perspective).change();
};