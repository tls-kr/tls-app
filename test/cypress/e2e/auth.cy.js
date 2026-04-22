// Authenticated smoke test. Uses the shared `test`/`test` user from
// cypress.env.json via the cy.login() custom command.

describe('authenticated session', function () {
  beforeEach(function () {
    cy.login()
  })

  it('shows the user menu instead of the Login button on index', function () {
    cy.visit('/exist/apps/tls-app/index.html')
    // Anon users see an <a data-target="#loginDialog">Login</a> in the nav.
    // Authed users see a dropdown with id="settingsDropdown" labelled
    // with the username.
    cy.env(['TEST_USER']).then(({ TEST_USER }) => {
      cy.get('#settingsDropdown')
        .should('be.visible')
        .and('contain.text', TEST_USER)
    })
    cy.get('a[data-target="#loginDialog"]').should('not.exist')
  })
})
