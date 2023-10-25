const { defineConfig } = require('cypress')

module.exports = defineConfig({
    screenshotsFolder: 'reports/screenshots',
    videosFolder: 'reports/videos',
    fixturesFolder: 'test/cypress/fixtures',
    e2e: {
//	baseUrl: 'https://krx.hxwd.org:8443/exist/apps/tls-app',
	viewportHeight : 800,
	viewportWidth : 1200,
	setupNodeEvents (on, config) {
      // implement node event listeners here
    },
    baseUrl: 'https://krx.hxwd.org:8443/exist/apps/tls-app/index.html',
    includeShadowDom: true,
    specPattern: 'test/cypress/e2e/**/*.cy.{js,jsx,ts,tsx}',
    supportFile: 'test/cypress/support/e2e.js'
  }
})
