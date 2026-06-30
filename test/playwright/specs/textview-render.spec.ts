// Anonymous smoke tests for textview.html.

import { test, expect } from '@playwright/test';
import {
    TEST_TEXTID,
    TEST_SEG,
    escapeId,
    textviewURL,
    waitForSWLBatchComplete,
} from '../helpers/textview';

test.describe('textview.html', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto(textviewURL());
    });

    test('renders chunkrow with the requested seg present', async ({ page }) => {
        await expect(page.locator('#chunkrow')).toBeVisible();
        await expect(page.locator(`#${escapeId(TEST_SEG)}`)).toBeAttached();
    });

    test('lazy-loads the TOC dropdown on first click', async ({ page }) => {
        // TOC is fetched on demand: tls-webapp.js binds a one-shot click
        // handler on #navbar-mulu that fires api/get_toc and swaps the
        // "Loading…" placeholder for <a class="dropdown-item"> entries.
        // get_toc takes 15-25s on a cold cache (see info/log.md /
        // tools/time-queries.xq); test timeout sized to cover that plus
        // headroom for parallel worker contention.
        test.setTimeout(90_000);
        const dropdown = page.locator('#toc-dropdown');
        await expect(dropdown).toHaveAttribute('data-textid', TEST_TEXTID);
        await expect(dropdown.locator('a.dropdown-item')).toHaveCount(0);
        await page.locator('#navbar-mulu').click();
        // Items are appended to the (closed) dropdown after the fetch —
        // assert DOM presence, not visibility.
        await expect(dropdown.locator('a.dropdown-item').first()).toBeAttached({ timeout: 60_000 });
    });

    test('populates .swlid containers via batched get_swls', async ({ page }) => {
        // .swlid divs are hidden placeholders until get_swls() injects the
        // per-seg annotation HTML — just assert presence, not visibility.
        const swlCount = await page.locator('.swlid').count();
        expect(swlCount).toBeGreaterThan(0);
        await waitForSWLBatchComplete(page);
    });
});
