// User preference round-trip: toggle a display-options select on
// settings.html, reload, verify the server persisted the change.
// Guards the session + user-settings refactor (Phase 4 cross-cutting
// cleanup + Phase 2's dom/translations/annotations modules that read
// these flags via lpm:show-setting).
//
// Chose the `wd` ("Wikidata Search and Links") toggle because it's
// declared in interface/settings.xml and its select renders with
// id="wd" and option values 0 / 1 / context (render-html.xqm:645,
// config.xqm:162). Flipping 0 ↔ 1 is enough to prove the
// /api/lus_set_user_item write → lus:get-user-item read round-trip
// survives a full page navigation. We intentionally don't do a full
// logout/login — the auth fixture is worker-scoped and shared across
// the spec, so killing the session would break other tests in the
// suite. A hard reload on a fresh request proves server-side
// persistence, which is the contract the refactor needs to preserve.

import { test, expect } from '../fixtures/auth';

const SETTINGS_URL = '/exist/apps/tls-app/settings.html';
const TOGGLE_ID = 'wd';
const SAVE_API = '/api/lus_set_user_item';

test.describe('user-settings: display-option round-trip', () => {
    // Keep originalValue in closure so afterEach can restore even if
    // the test body fails mid-flight.
    let originalValue: string | null = null;

    test.afterEach(async ({ authedContext }) => {
        if (!originalValue) return;
        try {
            // us_save_setting (tls-webapp.js:1698) POSTs this URL
            // with section=display-options, type=wd, preference=<val>,
            // action=undefined. Restore CW's baseline without
            // reloading a page.
            await authedContext.request.post(
                `/exist/apps/tls-app${SAVE_API}?section=display-options&type=${TOGGLE_ID}&preference=${encodeURIComponent(originalValue)}&action=undefined`,
            );
        } catch (e) {
            console.warn(`[user-settings] restore failed for ${TOGGLE_ID}=${originalValue}:`, e);
        } finally {
            originalValue = null;
        }
    });

    test('toggle wd display-option and verify persistence across reload', async ({ authenticatedPage: page }) => {
        await page.goto(SETTINGS_URL);

        // Display settings tab is default-selected (#pills-home-tab
        // active per settings.html:21), so the #wd <select> renders
        // without a tab switch.
        const select = page.locator(`#${TOGGLE_ID}`);
        await expect(select).toBeVisible({ timeout: 15_000 });

        originalValue = await select.inputValue();
        // Flip between 0 and 1. If the user has a 'context' selection
        // active we'd hide the select itself, but the option values
        // are always rendered — pick the opposite binary value.
        const newValue = originalValue === '1' ? '0' : '1';
        expect(newValue).not.toBe(originalValue);

        // selectOption triggers the 'change' event that the inline
        // onchange="us_save_setting(...)" handler listens on.
        await Promise.all([
            page.waitForResponse(r =>
                r.url().includes(SAVE_API) && r.request().method() === 'POST',
                { timeout: 30_000 },
            ),
            select.selectOption(newValue),
        ]);

        await page.reload();
        await expect(page.locator(`#${TOGGLE_ID}`)).toHaveValue(newValue, {
            timeout: 15_000,
        });
    });
});
