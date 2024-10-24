/* Javascript functions to remotely access the krx server through the API 
 * The url is expected to be configured at /krx/ on the same server to avoid CORS issues.
 * The dev server mimicks this by providing dummy functions locally
 */

// the dev server needs a different prefix

const urlprefix =  window.location.host.includes('8443') ? '/exist/apps/krx-app/' : 'krx/'


// get search info from krx


function krx_itemcount(){
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

function krx_items(start){
  if (start === 'undefined'){
  var location = window.location.search;
  } else {
      const regex = /start=\d+/i;
      var location = window.location.search.replace(regex, 'start='+start);
  }
  console.log(location);
  $.ajax({
  type : "GET",
  dataType : "json",
  url : urlprefix + "items"+location, 
  complete : function(resp){
    var ic = $('#krxitemcount').text();
    $('#show_text_results').html(resp.responseText);
    $('#search-results-top').html('<h1>Searching in Kanseki Repository</h1>');
    $('#text_results_menu').html('<h4>Found <span id="krxitemcount">'+ic+'</span></h4>');
    $('#search-results-count').html('');
    $('#facets-top').html('<h1>Facets</h1><p>Facets are not yet available for searches in the Kanseki Repository.</p>');
  }
  });
  $('#show_text_results').html('<p>Searching in the new Kanseki Repository, please wait for a moment...</p>')
};

function krx_preview(loc, query){
  $.ajax({
  type : "GET",
  dataType : "json",
  url : urlprefix + "preview?location="+loc+"&query="+query, 
  complete : function(resp){
    var ic = $('#krxitemcount').text();
    $('#search-results-count').html(resp.responseText);
    $('#preview-frame').show();
  }
  });
    
}

function krx_hide(form){
  $("#"+form).hide();  
};


