const { defineConfig } = require('cypress')

// Target selection: defaults to the local dev server. Override with
//   CYPRESS_baseUrl=https://krx.hxwd.org:8443 npx cypress run
// to exercise production. Cypress reads the CYPRESS_ prefix automatically.
const DEV_BASE_URL = 'http://localhost:8088'

module.exports = defineConfig({
    screenshotsFolder: 'reports/screenshots',
    videosFolder: 'reports/videos',
    fixturesFolder: 'test/cypress/fixtures',
    e2e: {
	viewportHeight : 800,
	viewportWidth : 1200,
	setupNodeEvents (on, config) {
      // implement node event listeners here
    },
    baseUrl: DEV_BASE_URL,
    includeShadowDom: true,
    specPattern: 'test/cypress/e2e/**/*.cy.{js,jsx,ts,tsx}',
    supportFile: 'test/cypress/support/e2e.js',
    // Disables the deprecated Cypress.env() browser-side accessor.
    // Tests read env values via cy.env() instead (test-side only, keeps
    // secrets out of the application window).
    allowCypressEnv: false
  }
})
