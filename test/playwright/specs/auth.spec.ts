// Authenticated smoke test.

import { test, expect } from '../fixtures/auth';

test('shows user menu instead of Login button on index', async ({ authenticatedPage, account }) => {
    await authenticatedPage.goto('/exist/apps/tls-app/index.html');
    const menu = authenticatedPage.locator('#settingsDropdown');
    await expect(menu).toBeVisible();
    await expect(menu).toContainText(account.name);
    await expect(authenticatedPage.locator('a[data-target="#loginDialog"]')).toHaveCount(0);
});
