// Two translation-slot flows for CW on 荀子, run back-to-back:
//
//   1. "stickiness" — pick a specific translation for slot1, click Next
//      twice, verify the choice survives each full-page navigation.
//      Guards the save_slot_config fix (info/log.md, 2026-04-23): /api/*
//      endpoints with security:[] were running as `guest` because the
//      controller.xql /api/* branch never called login:set-user, so the
//      slot-persist write silently no-op'd against /db/users/guest/.
//
//   2. "create + edit" — create a new translation via the New-translation
//      dialog, select it into slot1, type into two consecutive segments
//      with save-on-Tab, reload, and verify persistence. Guards the main
//      "start translating" workflow (store_new_translation, save_tr).
//      Cleans up via /api/ltr_delete_translation in afterEach.
//
// Both tests mutate CW's slot1 config on 荀子. They MUST run serially —
// if they race, one's save_slot_config clobbers the other's, and the
// create test's post-reload contenteditable assertion fails. They're
// also chromium-only: running the same tests on firefox re-authenticates
// as the same CW account, so cross-project parallelism would re-
// introduce the same contention. Hence the merged file + describe.serial
// + browserName skip.

import { test, expect } from '../fixtures/auth';

test.describe.configure({ mode: 'serial' });

test.describe('translation: slot + create for CW on 荀子', () => {
    test.skip(({ browserName }) => browserName !== 'chromium',
        'skipping: cross-project slot contention on shared CW account');

    // Shared across both tests via describe-scope closure so afterEach
    // only does work for the create test (which is the only one that
    // sets it).
    let createdTrid: string | null = null;

    test.afterEach(async ({ authedContext }) => {
        if (!createdTrid) return;
        try {
            await authedContext.request.post(
                '/exist/apps/tls-app/api/ltr_delete_translation',
                { form: { trid: createdTrid } }
            );
        } catch (e) {
            console.warn(`[translation] cleanup failed for ${createdTrid}:`, e);
        } finally {
            createdTrid = null;
        }
    });

    test('slot1 translation choice survives pagination', async ({ authenticatedPage: page }) => {
        // Cold text load + two full-page navigations; each Next triggers a
        // fresh textview render that re-runs ltr:get-translations (30-50s).
        // 180s covers initial load + slot click + two Next navigations
        // with headroom for warm-but-contended caches.
        test.setTimeout(180_000);

        await page.goto('/exist/apps/tls-app/index.html');
        await page.getByRole('link', { name: '荀子' }).first().click();

        // translation.xqm:471 renders the dropdown toggle as id="ddm-{slot}".
        // Its label reflects the currently-selected translation, so asserting
        // on #ddm-slot1's text is how we verify stickiness across reloads.
        const slotChooser = page.locator('#ddm-slot1');
        await slotChooser.click();

        // Bootstrap adds .show to .dropdown-menu once the toggle finishes
        // opening it. Wait on that so the link click can't race an unopened
        // dropdown.
        await expect(page.locator('#slot1 .dropdown-menu.show')).toBeVisible({ timeout: 10_000 });

        // Can't hardcode a target: the dropdown excludes whatever's
        // currently selected, so a fixed name flakes depending on what
        // prior test runs left behind. Instead, pick the first stable
        // "Translation by …" entry (skipping "PW Test" / "Jimmy Test"
        // leftovers, AI outputs, meta rows). Capture its full label so
        // the post-reload assertion doesn't need a partial match.
        const items = await page.locator('#slot1 a.dropdown-item').allTextContents();
        const target = items
            .map(s => s.trim())
            .find(s =>
                s.startsWith('Translation by') &&
                !s.includes('PW Test') &&
                !s.includes('Jimmy Test')
            );
        expect(target, `no stable translation in #slot1 dropdown: ${JSON.stringify(items)}`).toBeTruthy();

        // get_tr_for_page's onclick fires TWO AJAX calls back-to-back
        // (tls-webapp.js:498,504): save_slot_config first (intended to
        // be fast <100ms — commits the selection), then get_tr_for_page
        // (slow, 30-50s — rebuilds dropdown + swaps segment HTML). Wait
        // on the fast one to confirm the click handler ran. Timeout is
        // generous (60s) because both requests go through the same
        // XQuery executor — under parallel-worker load save_slot_config
        // can queue behind a large get-translations call from another
        // worker and block well past its nominal 100ms.
        await Promise.all([
            page.waitForResponse(r => r.url().includes('/api/save_slot_config'), { timeout: 60_000 }),
            page.locator('#slot1 a.dropdown-item', { hasText: target! }).first().click(),
        ]);

        // Extract just the translator name — slot1 header renders a
        // slightly different formatting than the dropdown item (no
        // "[count]" suffix), so assert on a stable substring instead.
        // Generous timeout because reload_selector (which updates the
        // header label) only runs in the get_tr_for_page success handler.
        const nameOnly = target!.replace(/^Translation by\s+/, '').replace(/\s*\(.*$/, '').trim();
        await expect(slotChooser).toContainText(nameOnly, { timeout: 60_000 });

        // Each Next is window.location = url (tls-webapp.js:240, page_move);
        // waitForLoadState('load') ensures the new render's inline JS has
        // run and populated the slot chooser label.
        await Promise.all([
            page.waitForLoadState('load'),
            page.getByRole('button', { name: 'Next' }).click(),
        ]);
        await expect(slotChooser).toContainText(nameOnly, { timeout: 15_000 });

        await Promise.all([
            page.waitForLoadState('load'),
            page.getByRole('button', { name: 'Next' }).click(),
        ]);
        await expect(slotChooser).toContainText(nameOnly, { timeout: 15_000 });
    });

    test('add a translation, select it, edit two segments', async ({ authenticatedPage: page, authedContext }) => {
        // Covers cold text load + dialog + two save-on-Tab round-trips
        // + two reloads. Runs ~70s solo.
        test.setTimeout(180_000);

        const stamp = Date.now().toString(36);
        const title   = `Playwright test ${stamp}`;
        const creator = `PW Test ${stamp}`;

        await page.goto('/exist/apps/tls-app/index.html');
        await page.getByRole('link', { name: '荀子' }).first().click();

        // translation.xqm:471 renders the dropdown toggle as
        // id="ddm-{$slot}"; target slot1 directly rather than relying on
        // the user-visible label, which changes after save.
        const slotChooser = page.locator('#ddm-slot1');
        await slotChooser.click();
        await page.getByRole('button', { name: 'New translation / comments' }).click();

        await page.getByRole('textbox', { name: 'Title:' }).fill(title);
        await page.getByRole('textbox', { name: 'Creator: AI' }).fill(creator);

        // Wait for the save round-trip, then reopen the slot chooser.
        // store_new_translation does not echo the trid in its response
        // body, so we capture it from the new dropdown entry's onclick
        // attribute (translation.xqm renders `get_tr_for_page('{$slot}',
        // '{$trid}')` on each link).
        await Promise.all([
            page.waitForResponse(r => r.url().includes('/api/store_new_translation') && r.ok()),
            page.getByRole('button', { name: 'Save' }).click(),
        ]);

        // TODO(tls-app bug): after Save the new translation should auto-
        // select into the slot. It does not — re-open the chooser and
        // pick it manually. Remove these re-select lines once fixed.
        //
        // Note: the Bootstrap dropdown auto-closes on any outside focus
        // change, so we don't rely on the item being visible. We grab
        // the onclick attribute (attached-but-hidden is fine), extract
        // the trid, and then call save_slot_config directly. That's
        // enough to make the selection sticky — a reload then re-renders
        // slot1 with our new translation AND contenteditable="true" on
        // each segment div (textpanel.xqm:275,434, only set when the
        // logged-in user owns the translation).
        await slotChooser.click();
        const newLink = page.locator('#slot1 a.dropdown-item', { hasText: new RegExp(creator) });
        await expect(newLink).toBeAttached({ timeout: 15_000 });
        const onclick = await newLink.getAttribute('onclick');
        const tridMatch = onclick?.match(/get_tr_for_page\('[^']+',\s*'([^']+)'/);
        createdTrid = tridMatch?.[1] ?? null;
        expect(createdTrid, `trid extractable from onclick: ${onclick}`).toBeTruthy();

        // Persist the slot choice server-side (fast, <100ms — see
        // tls-webapp.js:498-503 for the endpoint contract) and reload.
        // Calling get_tr_for_page via page.evaluate only swaps segment
        // inner HTML via AJAX; it does NOT toggle contenteditable on
        // the .tr divs, which is what lets fill() work. A reload does.
        //
        // textid derivation mirrors get_tr_for_page in tls-webapp.js:488-497:
        // the first segment's id split on '_' gives the collection prefix.
        // For 荀子 (KR3a0002_tls_006-<seg>), that's "KR3a0002".
        const textid = await page.evaluate(() => {
            const w = window as unknown as { jQuery?: (s: string) => { children: (s: string) => { eq: (i: number) => { children: (s: string) => { eq: (i: number) => { attr: (n: string) => string | undefined } } } } } };
            const jq = w.jQuery;
            if (!jq) return '';
            const loc = jq('#chunkcol-left').children('div').eq(0).children('div').eq(1).attr('id') || '';
            return loc.split('_')[0];
        });
        expect(textid, 'textid derivable from first chunkcol-left segment').toBeTruthy();
        await authedContext.request.get(
            `/exist/apps/tls-app/api/save_slot_config?textid=${textid}&slot=slot1&content-id=${createdTrid}`
        );
        await page.reload();

        // Segment slot ids are "<seg-id>-slot1". We can't hardcode the
        // seg id because lvs:record-visit makes the server redirect CW
        // back to whatever page they were last on — if a prior test in
        // this file paged forward (e.g. the stickiness test), the
        // default landing page shifts. Grab the first two slot1 segment
        // divs by position instead; they render with
        // contenteditable="true" now that the server knows slot1 = our
        // (owned) translation.
        const slot1Cells = page.locator('#chunkcol-left [id$="-slot1"]');
        await expect(slot1Cells.first()).toHaveAttribute('contenteditable', 'true', { timeout: 15_000 });
        const slot1 = slot1Cells.nth(0);
        const slot2 = slot1Cells.nth(1);
        const slot1Id = await slot1.getAttribute('id');
        const slot2Id = await slot2.getAttribute('id');

        // The save-on-Tab handler (tls-webapp.js:2058, set_keyup) compares
        // $(this).data('before') against current text; data('before') is
        // populated by a focus handler (tls-webapp.js:1620). fill() with
        // force bypasses visibility but uses insertText under the hood,
        // which doesn't emit a DOM focus event — so data('before') never
        // gets set and the Tab handler's "did the text change?" check
        // fails silently. click() triggers a real focus; pressSequentially
        // emits per-character keydown/keyup so dirty state propagates.
        const line1 = 'This is the first line of the test translation.';
        const line2 = 'And this is the second line.';

        await slot1.click({ force: true });
        await slot1.pressSequentially(line1);
        const [resp1] = await Promise.all([
            page.waitForResponse(r => r.url().includes('/api/save_tr'), { timeout: 30_000 }),
            slot1.press('Tab'),
        ]);
        expect(resp1.status(), `save_tr #1: ${await resp1.text().catch(() => '')}`).toBe(200);

        await slot2.click({ force: true });
        await slot2.pressSequentially(line2);
        const [resp2] = await Promise.all([
            page.waitForResponse(r => r.url().includes('/api/save_tr'), { timeout: 30_000 }),
            slot2.press('Tab'),
        ]);
        expect(resp2.status(), `save_tr #2: ${await resp2.text().catch(() => '')}`).toBe(200);

        // Reload a second time to prove the save persisted (not just
        // in-page state).
        await page.reload();

        // Segment ids contain '.' (e.g. "KR3a0002_tls_006-11a.29-slot1"),
        // which breaks `#id` CSS selectors — use an attribute selector.
        await expect(page.locator(`[id="${slot1Id}"]`)).toContainText(line1, { timeout: 15_000 });
        await expect(page.locator(`[id="${slot2Id}"]`)).toContainText(line2);
    });
});
