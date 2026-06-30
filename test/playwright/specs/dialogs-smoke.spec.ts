// Smoke coverage for the dialogs.xql dispatch pipeline.
//
// Each test drives the UI to the point where a dialog's trigger is
// clickable, fires the click, and asserts the modal rendered cleanly:
//   - the #<dialog-name> element gets Bootstrap's .show class
//   - a dialog-specific inner element is present (so we know body
//     content rendered, not just an empty modal-frame)
//   - no uncaught JS error fired on the page during open
//
// Guards Phase 3.1 of the refactor plan: dialogs.xql will be split into
// domain-specific modules (dialogs-translation.xqm, dialogs-user.xqm,
// ...) and the 50+ emitted `onclick="show_dialog(...)"` strings will be
// replaced with data-action / data-args attributes dispatched by a
// single delegated handler. Either change can silently break the path
// from trigger → /api/dialogs_dispatcher → modal-frame render, and a
// smoke test is how we keep that pipeline honest.
//
// Dialogs covered so far:
//   - tr-info-dialog         (info-icon button next to slot chooser)
//   - new-ai-trans-dialog    ("Request new AI translation" inside slot dropdown)
//   - text-info              (info badge on a search result row)
//   - external-resource      (Add badge on settings → External resources tab)
//
// Not covered (dispatcher entries with no reachable trigger today):
//   - search-settings        (only emit site in app.xql:1375 is inside
//                             an HTML comment — trigger is dead)
//   - att-tr-dialog          ("More translations" button next to an
//                             attributed line — needs a known-stable
//                             text/line with att context; no fixture yet)
//   - update-setting         (only renders when a search exceeds
//                             $sortmax — no deterministic trigger)
//   - passwd-dialog, add-tag (per user: not functional yet)
//
// CH1a0907 is the shared fixture text used by the Mocha XQSuite suite
// and by textview-render.spec.ts — pinned here so the test doesn't
// depend on per-user recent-visits ordering on the index page.

import { test, expect, Page } from '../fixtures/auth';

const TEXTVIEW_URL =
    '/exist/apps/tls-app/textview.html?location=CH1a0907_CHANT_016-35a.4&prec=5&foll=10';

async function openTextview(page: Page): Promise<void> {
    await page.goto(TEXTVIEW_URL);
    await expect(page.locator('#chunkrow')).toBeVisible({ timeout: 30_000 });
}

// Collect uncaught page errors. Attach BEFORE navigation so we catch
// anything thrown while the page boots.
function trackPageErrors(page: Page): { errors: Error[] } {
    const errors: Error[] = [];
    page.on('pageerror', e => errors.push(e));
    return { errors };
}

// show_dialog fetches /api/dialogs_dispatcher and injects the response
// into #remoteDialog. The underlying XQuery (ltr:transinfo,
// ltr:get-ai-translation-vendors, ...) is 15-30s cold, but in the full
// suite this spec runs near the end and the eXist executor is
// effectively single-threaded — a dispatcher call can queue behind a
// slow query from an earlier test and block well past its nominal
// cold time. 60s matches the ceiling the translation spec settled on
// for similar queue-contention reasons.
const DIALOG_OPEN_TIMEOUT = 60_000;

test.describe('dialogs smoke', () => {
    // Bump per-test timeout above the Playwright 30s default so the
    // DIALOG_OPEN_TIMEOUT assertion actually gets its full window — a
    // slow cold-cache ltr:transinfo (15-30s) would otherwise race the
    // test-level clock and produce a generic "Test timeout exceeded"
    // before the assertion's own timeout message fires. Firefox runs
    // after all chromium tests complete (workers:1), so its first
    // dispatcher call for a given trid can still be cold-ish if eXist
    // evicted the cached module under memory pressure.
    test.slow();

    test('opens tr-info-dialog from the slot info button', async ({ authenticatedPage: page }) => {
        const { errors } = trackPageErrors(page);

        await openTextview(page);

        // translation.xqm:510-512 renders an info-icon <button
        // title="More information"> inside #translation-headerline-slot1,
        // firing show_dialog('tr-info-dialog', {slot, trid}). Scope to
        // slot1 so slot2's identical button doesn't cause a strict-mode
        // match failure.
        await page
            .locator('#translation-headerline-slot1 button[title="More information"]')
            .click();

        const dialog = page.locator('#tr-info-dialog');
        await expect(dialog).toHaveClass(/\bshow\b/, { timeout: DIALOG_OPEN_TIMEOUT });
        // Title is either "Information about translation" (normal trid)
        // or "Research Note" (trid without a dash — see dialogs.xql:207).
        // Either way the header h5 should have non-empty text.
        await expect(dialog.locator('.modal-header h5')).not.toBeEmpty();

        expect(
            errors,
            `pageerror(s): ${errors.map(e => e.message).join('; ')}`,
        ).toEqual([]);
    });

    test('opens new-ai-trans-dialog from the slot dropdown', async ({ authenticatedPage: page }) => {
        const { errors } = trackPageErrors(page);

        await openTextview(page);

        // Open slot1's dropdown, wait for Bootstrap's .show, then click
        // the "Request new AI translation" item. Only renders when
        // lpm:can-use-ai() passes — CW does (confirmed 2026-04-24).
        await page.locator('#ddm-slot1').click();
        await expect(page.locator('#slot1 .dropdown-menu.show')).toBeVisible({
            timeout: 10_000,
        });

        await page.getByRole('button', { name: 'Request new AI translation' }).click();

        const dialog = page.locator('#new-ai-trans-dialog');
        await expect(dialog).toHaveClass(/\bshow\b/, { timeout: DIALOG_OPEN_TIMEOUT });
        // Title is "Request a new AI output file for <text-title>"
        // (dialogs.xql:187) — assert on the stable prefix.
        await expect(dialog.locator('.modal-header h5')).toContainText(
            'Request a new AI output file for',
        );

        expect(
            errors,
            `pageerror(s): ${errors.map(e => e.message).join('; ')}`,
        ).toEqual([]);
    });

    test('opens text-info from a search result row', async ({ authenticatedPage: page, browserName }) => {
        // Full-text search + page render is the slowest path in the
        // suite: src:ngram-query runs once up front, then every
        // result row does 3 lmd:get-metadata lookups (title/head/
        // textid). Chromium runs it in ~20s, but firefox runs last
        // under worker:1 and hits a server whose executor queue has
        // been churning for ~7 min — it blew past both 90s and 120s
        // timeouts on page.goto alone. Chromium coverage is sufficient
        // for smoke; matches the skip pattern in translation.spec.ts.
        test.skip(browserName !== 'chromium',
            'skipping: heavy full-text search contends with accumulated server load on late-running firefox worker');
        test.setTimeout(180_000);

        const { errors } = trackPageErrors(page);

        // search-type=1 is "texts" (config.xqm:148, the standard
        // corpus search dispatched via src:show-text-results). 荀子
        // chosen for narrowness — single-char queries like 子 match
        // thousands of segments and bloat the rendering batch.
        await page.goto(
            '/exist/apps/tls-app/search.html?query=%E8%8D%80%E5%AD%90&search-type=1',
            { timeout: 120_000 },
        );

        // search.xql:1176 renders each result row with an info <span>
        // carrying title="Information about this text". Scope to the
        // main results column so any other info badges on the page
        // can't win the strict-mode match.
        const infoBadge = page
            .locator('#main-section [title="Information about this text"]')
            .first();
        await expect(infoBadge).toBeVisible({ timeout: 30_000 });
        await infoBadge.click();

        const dialog = page.locator('#text-info');
        await expect(dialog).toHaveClass(/\bshow\b/, { timeout: DIALOG_OPEN_TIMEOUT });
        // Title is the constant "Text information" (dialogs.xql:255).
        await expect(dialog.locator('.modal-header h5')).toContainText('Text information');

        expect(
            errors,
            `pageerror(s): ${errors.map(e => e.message).join('; ')}`,
        ).toEqual([]);
    });

    test('opens external-resource from the settings External resources tab', async ({ authenticatedPage: page }) => {
        const { errors } = trackPageErrors(page);

        await page.goto('/exist/apps/tls-app/settings.html');

        // settings.html:27 ships three Bootstrap pill tabs; the
        // "External resources" pane is #pills-contact and only renders
        // its Add badge once we flip to it.
        await page.locator('#pills-contact-tab').click();
        await expect(page.locator('#pills-contact')).toHaveClass(/\bactive\b/);

        // user-settings.xqm:71 renders an "Add" badge inside
        // #pills-contact that fires show_dialog('external-resource', ...).
        // Scope to the pane so other pages' badges can't match.
        const addBadge = page
            .locator('#pills-contact .badge', { hasText: 'Add' })
            .first();
        await expect(addBadge).toBeVisible({ timeout: 10_000 });
        await addBadge.click();

        const dialog = page.locator('#external-resource');
        await expect(dialog).toHaveClass(/\bshow\b/, { timeout: DIALOG_OPEN_TIMEOUT });
        // Title is "Add new external ressource " (dialogs.xql:300,
        // note typo — leaving as-is until/unless fixed upstream).
        await expect(dialog.locator('.modal-header h5')).not.toBeEmpty();

        expect(
            errors,
            `pageerror(s): ${errors.map(e => e.message).join('; ')}`,
        ).toEqual([]);
    });
});
