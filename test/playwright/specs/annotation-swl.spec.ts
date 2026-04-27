// Selecting a run of characters in the left-column text view opens the
// SWL selection popup. Guards the annotation entry point — a regression
// here breaks the primary annotation workflow.
//
// tls-webapp.js line 1204: .zh elements bind a mouseup handler that
// reads window.getSelection() and, if non-empty, calls get_sw(...) which
// shows the popup. A plain click won't trigger it; a drag-selection will.

import { test, expect } from '../fixtures/auth';

test('selecting text in textview opens the SWL popup', async ({ authenticatedPage: page }) => {
    // Includes cold-cache load of a large text.
    test.setTimeout(90_000);

    await page.goto('/exist/apps/tls-app/index.html');
    // .first() because the index renders 荀子 once in the browse list and
    // again in "Recent activity" after any CW test has visited it.
    await page.getByRole('link', { name: '荀子' }).first().click();

    // Wait for the Chinese-character spans to render before selecting.
    await expect(page.locator('.zh').first()).toBeVisible({ timeout: 30_000 });

    // Drag-select across two adjacent .zh spans.
    const first  = page.locator('.zh').first();
    const second = page.locator('.zh').nth(1);
    const b1 = await first.boundingBox();
    const b2 = await second.boundingBox();
    if (!b1 || !b2) throw new Error('.zh bounding boxes unavailable');
    await page.mouse.move(b1.x + 2, b1.y + b1.height / 2);
    await page.mouse.down();
    await page.mouse.move(b2.x + b2.width - 2, b2.y + b2.height / 2, { steps: 5 });
    await page.mouse.up();

    // Popup title is "Existing SW for <selected-text>" (rendered by
    // get_sw in tls-webapp.js via the /api/get_sw response).
    await expect(page.getByText(/Existing SW for/).first())
        .toBeVisible({ timeout: 15_000 });
});
