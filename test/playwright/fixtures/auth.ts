// Authenticated-page fixture.
//
// POSTs form-urlencoded creds to /exist/apps/tls-app/login and reuses the
// resulting cookie jar via a BrowserContext.
//
// Credentials come from test/mocha/.test-accounts.local.json (gitignored;
// the same file the Mocha xqSuite.js suite reads). Specs that can't find
// a usable account skip themselves so CI without secrets stays green.
//
// Picks the "regular tls-user (not dba)" entry by default — admin is
// DB-only and not used for tls-app tests.

import { test as base, expect, Page, BrowserContext } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

export type TestAccount = { name: string; password: string; note?: string };

export function loadTestAccount(noteMatch?: string): TestAccount | null {
    try {
        const p = path.resolve(__dirname, '../../mocha/.test-accounts.local.json');
        const raw = JSON.parse(fs.readFileSync(p, 'utf8')) as { users?: TestAccount[] };
        const users = raw.users || [];
        return (
            users.find(
                u =>
                    !!u.name &&
                    !!u.password &&
                    (noteMatch ? (u.note || '').includes(noteMatch) : true)
            ) || null
        );
    } catch {
        return null;
    }
}

type AuthFixtures = {
    account: TestAccount;
    authedContext: BrowserContext;
    authenticatedPage: Page;
};

export const test = base.extend<AuthFixtures>({
    account: async ({}, use, testInfo) => {
        const acct = loadTestAccount('regular tls-user');
        if (!acct) {
            testInfo.skip(true, 'No test account found in test/mocha/.test-accounts.local.json');
            return;
        }
        await use(acct);
    },

    authedContext: async ({ browser, account, baseURL }, use) => {
        const ctx = await browser.newContext({ baseURL });
        const res = await ctx.request.post('/exist/apps/tls-app/login', {
            form: { user: account.name, password: account.password },
        });
        if (!res.ok()) {
            throw new Error(`login failed: ${res.status()} ${await res.text()}`);
        }
        const body = await res.json();
        if (body.user !== account.name) {
            throw new Error(`login returned unexpected user: ${JSON.stringify(body)}`);
        }
        await use(ctx);
        await ctx.close();
    },

    authenticatedPage: async ({ authedContext }, use) => {
        const page = await authedContext.newPage();
        await use(page);
        await page.close();
    },
});

export { expect };
