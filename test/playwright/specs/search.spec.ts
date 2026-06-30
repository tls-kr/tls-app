// End-to-end search flow: submit the navbar search form, land on
// search.html with rendered results, and click a hit to navigate into
// textview. Guards the Phase 3.4 split of search.xql — any regression
// in the ngram-query pipeline (src:ngram-query → src:show-hits →
// src:show-text-results) or in the navbar form template would break
// the only path users have into the corpus.
//
// Chromium-only for the same reason text-info in dialogs-smoke is:
// full-text search is the heaviest server-rendered page in the suite
// (src:ngram-query runs once, then 50 result rows each do 3
// lmd:get-metadata lookups). Under the tail of a full firefox run the
// eXist executor queue is saturated enough that navigation stalls
// past even a 120s timeout.
//
// 荀子 is picked over a single-char query like 子 because the ngram
// match set is narrower (hundreds rather than thousands of segments),
// which keeps page.goto under firefox's default ceilings when this
// test *is* run solo.

import { test, expect } from '../fixtures/auth';

test.describe('search: navbar form submits and result navigates to textview', () => {
    test.skip(({ browserName }) => browserName !== 'chromium',
        'skipping: full-text search stalls on late-firefox worker, same as text-info');

    test('submit 荀子 from navbar, click first result, textview renders', async ({ authenticatedPage: page }) => {
        // Cold index load + search render + textview nav ~60s solo,
        // room for server contention in the full suite.
        test.setTimeout(180_000);

        await page.goto('/exist/apps/tls-app/index.html');

        // Navbar form: app.xql:1344. #query-inp is the text box,
        // #search-submit is the magnifying-glass button. search-type
        // select defaults to "1" (texts) on non-textview pages
        // (app.xql:1350).
        await page.locator('#query-inp').fill('荀子');

        await Promise.all([
            page.waitForURL(/search\.html/, { timeout: 120_000 }),
            page.locator('#search-submit').click(),
        ]);

        // Results render inside #main-section (search.html:9). Each
        // row is a <tr> with a <td><a href="textview.html?..."> link
        // (search.xql:1175). Wait for the first such link before
        // reading its href.
        const firstResultLink = page
            .locator('#main-section table.table td a[href^="textview.html?location="]')
            .first();
        await expect(firstResultLink).toBeVisible({ timeout: 60_000 });

        const href = await firstResultLink.getAttribute('href');
        expect(href, 'result link has a location= segment').toMatch(
            /^textview\.html\?location=[^&]+/,
        );

        // Click through to textview and verify the page boots to the
        // point where #chunkrow is visible — same readiness signal
        // textview-render.spec.ts uses.
        await Promise.all([
            page.waitForLoadState('load'),
            firstResultLink.click(),
        ]);
        await expect(page).toHaveURL(/textview\.html\?location=/, { timeout: 60_000 });
        await expect(page.locator('#chunkrow')).toBeVisible({ timeout: 60_000 });
    });
});
