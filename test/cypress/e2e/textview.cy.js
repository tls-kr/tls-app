// Anonymous smoke tests for textview.html: the main reading UI.
// Uses CH1a0907 (also used by the XQSuite tests) so the same fixture
// text drives both server- and browser-side coverage.

const TEXTID = 'CH1a0907'
const SEG    = 'CH1a0907_CHANT_016-35a.4'
const URL    = `/exist/apps/tls-app/textview.html?location=${SEG}&prec=5&foll=10`

describe('textview.html', function () {
  beforeEach(function () {
    cy.visit(URL)
  })

  it('renders chunkrow with the requested seg present', function () {
    cy.get('#chunkrow').should('be.visible')
    cy.get(`#${CSS.escape(SEG)}`).should('exist')
  })

  it('lazy-loads the TOC dropdown on first click', function () {
    // TOC is now fetched on demand — tls-webapp.js binds a one-shot
    // click handler on #navbar-mulu that fires api/get_toc and swaps
    // the "Loading…" placeholder for <a class="dropdown-item"> entries.
    // Before the click, no dropdown items should have been loaded.
    cy.get('#toc-dropdown')
      .should('have.attr', 'data-textid', TEXTID)
      .find('a.dropdown-item')
      .should('not.exist')
    cy.get('#navbar-mulu').click()
    cy.get('#toc-dropdown a.dropdown-item', { timeout: 30000 })
      .should('have.length.greaterThan', 0)
  })

  it('populates .swlid containers via the batched get_swls call', function () {
    // get_swls() posts all visible .swlid ids to api/show_swl_for_lines
    // and injects the per-seg annotation HTML. The #blue-eye button's
    // title changes from "Please wait…" once the load is done; wait on
    // either signal.
    cy.get('.swlid').should('have.length.greaterThan', 0)
    cy.get('#blue-eye', { timeout: 15000 })
      .should('not.have.attr', 'title', 'Please wait, SWL are still loading.')
  })
})
