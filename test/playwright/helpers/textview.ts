// Selectors and actions for textview.html, the main reading UI.
//
// CH1a0907 is the shared fixture text also used by the XQSuite Mocha
// tests (see test/mocha/xqSuite.js) so server- and browser-side coverage
// exercise the same data.

import { Page, expect } from '@playwright/test';

export const TEST_TEXTID = 'CH1a0907';
export const TEST_SEG    = 'CH1a0907_CHANT_016-35a.4';

export function textviewURL(seg: string = TEST_SEG, prec = 5, foll = 10): string {
    return `/exist/apps/tls-app/textview.html?location=${seg}&prec=${prec}&foll=${foll}`;
}

// Playwright CSS selectors need dots in IDs escaped (CSS.escape in the
// browser; regex in the test).
export function escapeId(id: string): string {
    return id.replace(/[.:]/g, '\\$&');
}

export async function openTextview(page: Page, seg: string = TEST_SEG): Promise<void> {
    await page.goto(textviewURL(seg));
    await expect(page.locator('#chunkrow')).toBeVisible();
}

// #blue-eye's title reads "Please wait, SWL are still loading." until the
// batched /api/show_swl_for_lines call resolves and tls-webapp.js updates
// it. Allow generous timeout for cold-cache loads.
export async function waitForSWLBatchComplete(page: Page, timeoutMs = 15000): Promise<void> {
    await expect(page.locator('#blue-eye')).not.toHaveAttribute(
        'title',
        'Please wait, SWL are still loading.',
        { timeout: timeoutMs }
    );
}
