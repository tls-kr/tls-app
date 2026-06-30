// Anonymous smoke test: the index page loads.

import { test, expect } from '@playwright/test';

test('landing page loads', async ({ page }) => {
    const res = await page.goto('/exist/apps/tls-app/index.html');
    expect(res?.ok()).toBeTruthy();
});
