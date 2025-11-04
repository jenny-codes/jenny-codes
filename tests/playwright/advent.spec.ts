import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';
import { renameSync, writeFileSync } from 'fs';
import { resolve } from 'path';

const ADVENT_PATH = '/advent';
const FALLBACK_BASE_URL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3000';
const DATA_PATH = resolve(process.cwd(), 'test/data/test_advent_calendar.yml');

const formatDateKey = (date: Date) => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const resetCalendarState = () => {
  const todayKey = formatDateKey(new Date());
  const staticKeys = new Set(['2025-10-31', '2025-11-02', '2025-11-01', '2025-11-03']);

  const lines = [
    '---',
    'days:',
    '  2025-10-31:',
    '    checked_in: true',
    '    stars: 1',
    '    puzzle_answer: comet',
    '  2025-11-02:',
    '    checked_in: true',
    '    stars: 1',
    '    puzzle_answer: aurora',
    '  2025-11-01:',
    '    checked_in: true',
    '    stars: 1',
    '    puzzle_answer: lantern',
    '  2025-11-03:',
    '    checked_in: false',
    '    stars: 0',
    '    puzzle_answer: hooters',
    'voucher_awards: []',
    'voucher_sequence: 1',
    ''
  ];

  if (!staticKeys.has(todayKey)) {
    const insertAt = lines.findIndex((line) => line === 'voucher_awards: []');
    lines.splice(insertAt, 0,
      `  ${todayKey}:`,
      '    checked_in: false',
      '    stars: 0',
      '    puzzle_answer: hooters'
    );
  }

  const state = lines.join('\n');
  const tempPath = `${DATA_PATH}.${process.pid}.${Math.random().toString(16).slice(2)}`;
  const finalState = state.endsWith('\n') ? state : `${state}\n`;
  writeFileSync(tempPath, finalState);
  renameSync(tempPath, DATA_PATH);
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
  test.beforeEach(async ({ page, baseURL }) => {
    resetCalendarState();
    const target = baseURL ? ADVENT_PATH : `${FALLBACK_BASE_URL}${ADVENT_PATH}`;
    await page.goto(target, { waitUntil: 'networkidle' });
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
      await page.waitForURL(/\/advent(?:\?tab=main)?$/);
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
    await expect(page.getByRole('button', { name: /reset check-in/i })).toBeVisible({ timeout: 7000 });

    const afterLines = page.locator('.advent-title__line');
    await expect(afterLines.first()).toHaveClass(/is-complete/);
    await expect(afterLines.nth(1)).toHaveClass(/is-complete/);
  });

  test('reset button returns console to check-in state', async ({ page }) => {
    const checkInButton = page.getByRole('button', { name: /check in/i });
    if (await checkInButton.count()) {
      const responsePromise = page.waitForResponse((response) => response.url().includes('/advent/check_in') && response.status() < 400);
      await checkInButton.click();
      await responsePromise;
      await expect(page.getByRole('button', { name: /reset check-in/i })).toBeVisible({ timeout: 7000 });
    }

    const resetButton = page.getByRole('button', { name: /reset check-in/i });
    await expect(resetButton).toBeVisible();

    const resetResponsePromise = page.waitForResponse((response) => response.url().includes('/advent/reset_check_in') && response.status() < 400);
    await resetButton.click();
    await resetResponsePromise;

    await expect(page.getByRole('button', { name: /check in/i })).toBeVisible({ timeout: 5000 });

    const beforeLines = page.locator('.advent-title__line');
    await expect(beforeLines.first()).toHaveClass(/is-complete/);
    if (await beforeLines.count() > 1) {
      await expect(beforeLines.nth(1)).toHaveClass(/is-complete/);
    }
  });

  test('daily puzzle awards an extra star when solved', async ({ page }) => {
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

    const puzzleForm = page.locator('.advent-puzzle-form');
    await puzzleForm.waitFor({ state: 'visible' });
    const puzzleInput = puzzleForm.getByPlaceholder('Enter your guess');
    await expect(puzzleInput).toBeVisible();

    const confirmButton = page.getByRole('button', { name: /confirm/i });

    await puzzleInput.fill('wrong');
    const wrongResponse = page.waitForResponse((response) => response.url().includes('/advent/solve_puzzle'));
    await confirmButton.click();
    await wrongResponse;

    await expect(page.locator('.advent-puzzle-alert')).toHaveText(/That is not correct\. Try again\?/i);
    await expect(page.locator('.advent-puzzle-form')).toBeVisible();
    await expect(puzzleInput).toHaveValue('wrong');

    await puzzleInput.fill('hooters');
    const correctResponse = page.waitForResponse((response) => response.url().includes('/advent/solve_puzzle') && response.status() < 400);
    await confirmButton.click();
    await correctResponse;
    await page.waitForURL(/\/advent(?:\?tab=main)?$/);

    await expect(page.locator('.advent-done-message')).toBeVisible();
    await expect(page.locator('.advent-puzzle-form')).toHaveCount(0);

    page.off('response', responseListener);
    expect(puzzleStatuses).toEqual([200, 200]);

    await page.getByRole('link', { name: 'wah' }).click();
    const statsLine = page.locator('.advent-faq__response').filter({ hasText: /^You have successfully checked in/ }).first();
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

    const redeemButton = page.getByRole('button', { name: /redeem/i }).first();
    await expect(redeemButton).toBeVisible();

    await page.evaluate(() => {
      (window as any).__adventLastAlert = null;
      window.alert = (message?: string) => {
        (window as any).__adventLastAlert = message;
      };
    });

    await redeemButton.click();

    const lastAlert = await page.evaluate(() => (window as any).__adventLastAlert as string | null);
    expect(lastAlert).toMatch(/not redeemable/i);

    await expect(redeemButton).toBeVisible();
  });
});
