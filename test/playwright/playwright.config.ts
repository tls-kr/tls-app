import { defineConfig, devices } from '@playwright/test';

// Default to the local dev eXist server.
// Override for production: PLAYWRIGHT_BASE_URL=https://hxwd.org npx playwright test
const BASE_URL = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:8088';

export default defineConfig({
    testDir: './specs',
    fullyParallel: true,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 2 : 0,
    // Dev eXist effectively serializes large XQueries (textview render,
    // ltr:get-translations) behind a single executor, so any parallelism
    // at the worker level makes /api/* calls queue past their timeouts.
    // Even two workers push save_slot_config past 30s and cause
    // page.goto on the idle worker to miss its 30s default. Run serially
    // locally; CI uses its own worker budget.
    workers: process.env.CI ? undefined : 1,
    reporter: [
        ['list'],
        ['html', { outputFolder: '../../reports/playwright/html', open: 'never' }],
    ],
    outputDir: '../../reports/playwright/artifacts',
    use: {
        baseURL: BASE_URL,
        trace: 'on-first-retry',
        video: 'retain-on-failure',
        screenshot: 'only-on-failure',
        viewport: { width: 1200, height: 800 },
    },
    projects: [
        { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
        { name: 'firefox',  use: { ...devices['Desktop Firefox'] } },
    ],
});
