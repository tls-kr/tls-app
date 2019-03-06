describe('The dashboard', function() {
  it('should load with app link', function() {
    // Go to Dashboad
    cy.visit('/exist/apps/dashboard/index.html')
    // Click on it to open new page
    cy.get('button[title="My amazing TLS-漢學文典 application"]')
  })
})
