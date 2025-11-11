import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';
import { execSync } from 'child_process';
import { resolve } from 'path';

const ADVENT_PATH = '/advent';
const FALLBACK_BASE_URL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3000';
const PLAYWRIGHT_STORE_PATH = process.env.ADVENT_CALENDAR_FILE_PATH ?? resolve(process.cwd(), 'tmp', 'playwright_store.yml');
const ADVENT_PASSWORD_VALUE = 'cremebrulee';
const DEFAULT_INSPECT_DAY = '1108';

process.env.ADVENT_CALENDAR_FILE_PATH = PLAYWRIGHT_STORE_PATH;

const resetCalendarState = () => {
  execSync('bin/rails runner test/support/reset_calendar_state.rb', {
    stdio: 'pipe',
    env: {
      ...process.env,
      RAILS_ENV: 'test',
      ADVENT_CALENDAR_FILE_PATH: PLAYWRIGHT_STORE_PATH,
    },
  });
};

const visitAdvent = async (page: Page, target: string) => {
  await page.goto(target, { waitUntil: 'networkidle' });
};

const waitForMainTab = async (page: Page) => {
  await page.waitForFunction(() => {
    try {
      const parsed = new URL(window.location.href);
      if (parsed.pathname !== '/advent') return false;
      const tab = parsed.searchParams.get('tab');
      return tab === null || tab === 'main';
    } catch (error) {
      console.warn('[advent] unable to parse URL during wait', error);
      return false;
    }
  }, { timeout: 15000 });
};

const waitForHeadlineCompletion = async (page: Page) => {
  await page.waitForFunction(() => {
    const lines = document.querySelectorAll<HTMLSpanElement>('.advent-title__line');
    if (lines.length === 0) return false;

    return Array.from(lines).every((line) => line.classList.contains('is-complete') && line.textContent?.length);
  }, { timeout: 15000 });
};

test.describe('Advent Console', () => {
  test.describe.configure({ mode: 'serial' });
  test.beforeEach(async ({ page, baseURL, context }) => {
    resetCalendarState();
    await context.setHTTPCredentials({ username: 'advent', password: ADVENT_PASSWORD_VALUE });
    const target = baseURL
      ? `${ADVENT_PATH}?inspect=${DEFAULT_INSPECT_DAY}`
      : `${FALLBACK_BASE_URL}${ADVENT_PATH}?inspect=${DEFAULT_INSPECT_DAY}`;
    await visitAdvent(page, target);
  });

  test.afterEach(() => {
    resetCalendarState();
  });

  test('headline types out both lines in sequence', async ({ page }) => {
    const lines = page.locator('.advent-title__line');

    await waitForHeadlineCompletion(page);

    await expect(lines).toHaveCount(2);
    await expect(lines.nth(0)).toHaveClass(/is-complete/);
    await expect(lines.nth(0)).toHaveText(/Today is/);
    await expect(lines.nth(1)).toHaveClass(/is-complete/);
    await expect(lines.nth(1)).toHaveText(/days to go/);
  });

  test('tabs toggle active state and panel visibility', async ({ page }) => {
    const mainTab = page.getByRole('link', { name: 'main' });
    const rewardsTab = page.getByRole('link', { name: 'wah' });
    const faqTab = page.getByRole('link', { name: 'faq' });

    const rewardsPanel = page.locator('[data-advent-panel="wah"]');
    const faqPanel = page.locator('[data-advent-panel="faq"]');
    const mainPanel = page.locator('[data-advent-panel="main"]');

    await waitForHeadlineCompletion(page);

    await expect(mainPanel).toBeVisible();

    await rewardsTab.click();
    await expect(rewardsTab).toHaveClass(/is-active/);
    await expect(mainTab).not.toHaveClass(/is-active/);
    await expect(rewardsPanel).toBeVisible();
    await expect(mainPanel).toHaveClass(/is-hidden/);
    await expect(page).toHaveURL(/tab=wah/);

    await faqTab.click();
    await expect(faqTab).toHaveClass(/is-active/);
    await expect(rewardsPanel).toHaveClass(/is-hidden/);
    await expect(faqPanel).toBeVisible();
    await expect(page).toHaveURL(/tab=faq/);

    await mainTab.click();
    await expect(mainTab).toHaveClass(/is-active/);
    await expect(page).toHaveURL(/tab=main/);
  });

  test('countdown decreases over time', async ({ page }) => {
    const checkInButton = page.getByRole('button', { name: /check in/i });
    if (await checkInButton.count()) {
      await Promise.all([
        page.waitForResponse((response) => response.url().includes('/advent/check_in') && response.status() < 400),
        checkInButton.click(),
      ]);
      await waitForMainTab(page);
    }

    const countdown = page.locator('.advent-countdown [data-countdown-label]');
    await countdown.waitFor({ state: 'visible', timeout: 10000 });

    await expect(countdown).toHaveText(/\d+ (hour|minute|second)/);

    const initial = await countdown.innerText();
    await expect
      .poll(async () => countdown.innerText(), { message: 'Expected countdown to tick down' })
      .not.toBe(initial);
  });

  test('check in triggers fireworks before submission', async ({ page }) => {
    const checkInButton = page.getByRole('button', { name: /check in/i });
    await expect(checkInButton).toBeVisible();

    const responsePromise = page.waitForResponse((response) => response.url().includes('/advent/check_in') && response.status() < 400);

    await checkInButton.click();
    await page.waitForTimeout(200);

    const starCount = await page.locator('.advent-starfield__star').count();
    expect(starCount).toBeGreaterThan(0);

    await responsePromise;

    const afterLines = page.locator('.advent-title__line');
    await expect(afterLines.first()).toHaveClass(/is-complete/);
    await expect(afterLines.nth(1)).toHaveClass(/is-complete/);
  });

  test('reset query parameter returns console to check-in state', async ({ page, baseURL }) => {
    const inspectDay = '1108';
    const target = baseURL ? `${ADVENT_PATH}?inspect=${inspectDay}` : `${FALLBACK_BASE_URL}${ADVENT_PATH}?inspect=${inspectDay}`;

    await visitAdvent(page, target);

    const checkInButton = page.getByRole('button', { name: /check in/i });
    await expect(checkInButton).toBeVisible();

    const responsePromise = page.waitForResponse((response) => response.url().includes('/advent/check_in') && response.status() < 400);
    await checkInButton.click();
    await responsePromise;

    await expect(page.getByRole('button', { name: /what happens\?/i })).toBeVisible({ timeout: 7000 });

    const resetTarget = baseURL
      ? `${ADVENT_PATH}?inspect=${inspectDay}&reset=${inspectDay}`
      : `${FALLBACK_BASE_URL}${ADVENT_PATH}?inspect=${inspectDay}&reset=${inspectDay}`;
    await visitAdvent(page, resetTarget);

    const currentURL = page.url();
    expect(currentURL).toContain(`inspect=${inspectDay}`);
    expect(currentURL).not.toContain('reset=');
    await expect(page.getByRole('button', { name: /check in/i })).toBeVisible({ timeout: 5000 });

    const beforeLines = page.locator('.advent-title__line');
    await expect(beforeLines.first()).toHaveClass(/is-complete/);
    if (await beforeLines.count() > 1) {
      await expect(beforeLines.nth(1)).toHaveClass(/is-complete/);
    }
  });

  test('daily puzzle awards an extra star when solved', async ({ page, baseURL }) => {
    const puzzleStatuses: number[] = [];
    const responseListener = (response: any) => {
      if (response.url().includes('/advent/solve_puzzle')) {
        puzzleStatuses.push(response.status());
      }
    };

    page.on('response', responseListener);

    const checkInButton = page.getByRole('button', { name: /check in/i });
    await expect(checkInButton).toBeVisible();

    const checkInResponse = page.waitForResponse((response) => response.url().includes('/advent/check_in') && response.status() < 400);
    await checkInButton.click();
    await checkInResponse;

    const actionButton = page.getByRole('button', { name: /what happens\?/i });
    await expect(actionButton).toBeVisible();

    const correctResponse = page.waitForResponse((response) => response.url().includes('/advent/solve_puzzle') && response.status() < 400);
    await actionButton.click();
    await correctResponse;

    await expect(page.getByRole('button', { name: /what happens\?/i })).toHaveCount(0);

    page.off('response', responseListener);
    expect(puzzleStatuses).toEqual([200]);

    const wahTarget = baseURL
      ? `${ADVENT_PATH}?inspect=${DEFAULT_INSPECT_DAY}&tab=wah`
      : `${FALLBACK_BASE_URL}${ADVENT_PATH}?inspect=${DEFAULT_INSPECT_DAY}&tab=wah`;

    await visitAdvent(page, wahTarget);

    const statsLine = page.locator('.advent-section__text').filter({ hasText: /^You have successfully checked in/ }).first();
    await expect(statsLine).toContainText(/collected .*5.* stars/i);
  });

  test('voucher draw dispenses a surprise and hides the button', async ({ page }) => {
    await page.getByRole('link', { name: 'wah' }).click();

    await expect(page.getByRole('button', { name: /check in/i })).toHaveCount(0);

    const drawButton = page.getByRole('button', { name: /weee/i });
    await expect(drawButton).toBeVisible();

    const drawResponse = page.waitForResponse((response) => response.url().includes('/advent/draw_voucher') && response.status() < 400);
    await drawButton.click();
    await drawResponse;

    const latestPrize = page.locator('.advent-voucher-card--latest .advent-voucher-card__prize');
    await expect(latestPrize).toBeVisible();

    await expect(page.getByRole('button', { name: /weee/i })).toHaveCount(0);
    await expect(page.locator('.advent-voucher-card')).not.toHaveCount(0);

    const redeemForm = page.locator("form[data-advent-voucher-action='redeem']").first();
    await expect(redeemForm).toBeVisible();

    const redeemSubmit = redeemForm.locator('input[type="submit"], button[type="submit"]').first();
    await expect(redeemSubmit).toBeVisible();

    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle' }),
      redeemSubmit.click(),
    ]);

    await expect(page).toHaveURL(/tab=wah/);
    await expect(page.locator('.advent-voucher-alert')).toContainText(/Voucher redeemed\. Please allow a few second for the request to be processed/i);
    await expect(page.locator('.advent-voucher-card--latest')).toHaveCount(0);
    await expect(page.locator('.advent-voucher-card.is-redeemed')).toHaveCount(1);
  });
});
