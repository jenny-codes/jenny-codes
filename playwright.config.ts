import { defineConfig } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3000';

export default defineConfig({
  testDir: './tests/playwright',
  timeout: 60_000,
  expect: {
    timeout: 7_000,
  },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.PLAYWRIGHT_REPORT ?? 'list',
  use: {
    baseURL,
    trace: process.env.CI ? 'retain-on-failure' : 'off',
  },
  webServer: process.env.PLAYWRIGHT_WEB_SERVER === 'off'
    ? undefined
    : {
        command: 'bin/rails server -e test -p 3000',
        url: baseURL,
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
        env: {
          ...process.env,
          RAILS_ENV: 'test',
          NODE_ENV: 'test',
          PORT: '3000',
        },
      },
});
