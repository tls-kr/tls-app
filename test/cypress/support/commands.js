// Custom Cypress commands for the TLS app.

// Log in as the given user. Defaults pull from cypress.env.json
// (TEST_USER / TEST_PASSWORD) via cy.env(), which keeps credentials
// on the test side — unlike Cypress.env() they are never exposed to
// the application window.
//
// Uses cy.session() so the login POST runs once per session key and
// the cookie is reused across tests.
//
// The login endpoint only accepts application/x-www-form-urlencoded,
// not multipart/form-data, so cy.request uses `form: true`.
Cypress.Commands.add('login', (user, password) => {
  cy.env(['TEST_USER', 'TEST_PASSWORD']).then(({ TEST_USER, TEST_PASSWORD }) => {
    const u = user || TEST_USER
    const p = password || TEST_PASSWORD
    cy.session([u, p], () => {
      cy.request({
        method: 'POST',
        url: '/exist/apps/tls-app/login',
        form: true,
        body: { user: u, password: p }
      }).its('body.user').should('eq', u)
    })
  })
})
