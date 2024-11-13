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
  $('#cit-results').html('Processing data, just a moment please.')
};


function cit_set_value(perspective, item){
  $('#select-perspective').val(perspective).change();
  $('#input-target').val(item);
};


// for concepts, synfunc we provide autocomplete

function initialize_cit_autocomplete(){
    var type =   $('#select-perspective').val();
    $('#input-target').val('');
    console.log("Initializing autocomplete functions");
    $( "#input-target" ).autocomplete({
      appendTo: "#input-group",
      response : function(event, ui){
      // need to reset this, in case of a new SF
        $("#input-id-span" ).html("xxx");     
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
        $("#input-id-span" ).html(ui.item.id);     
        console.log( "Selected: " + ui.item.value + " aka " + ui.item.id );
      }
    } );
};

