
//function to detect Ctrl+Click
let detectCtrl = function (event) {
  return event.ctrlKey
}

document.addEventListener("DOMContentLoaded", function(event) {
  import ("https://cdn.jsdelivr.net/npm/alpheios-embedded@3.1.6/dist/alpheios-embedded.min.js").then(embedLib => {
    window.AlpheiosEmbed.importDependencies({
      mode: 'custom',
      libs: { 'components': 'https://cdn.jsdelivr.net/npm/alpheios-components@1.6.2-dev/dist/alpheios-components.min.js' }
    }).then(Embedded => {
      new Embedded({
        clientId: 'tls-web-app',
        enableMouseMoveOverride: true
      }).activate();
    }).catch(e => {
      console.error(`Import of Alpheios embedded library dependencies failed: ${e}`)
    })
  }).catch(e => {
    console.error(`Import of Alpheios Embedded library failed: ${e}`)
  })
})
