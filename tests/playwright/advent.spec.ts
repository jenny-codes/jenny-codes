import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';
import { writeFileSync } from 'fs';
import { resolve } from 'path';

const ADVENT_PATH = '/advent';
const FALLBACK_BASE_URL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3000';
const DATA_PATH = resolve(process.cwd(), 'test/data/test_advent_calendar.yml');

const resetCalendarState = () => {
  writeFileSync(DATA_PATH, '---\nchecked_in: false\n');
};

const waitForHeadlineCompletion = async (page: Page) => {
  await page.waitForFunction(() => {
    const lines = document.querySelectorAll<HTMLSpanElement>('.advent-title__line');
    if (lines.length === 0) return false;

    return Array.from(lines).every((line) => line.classList.contains('is-complete') && line.textContent?.length);
  }, { timeout: 15000 });
};

test.describe('Advent Console', () => {
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
    await expect(lines.nth(1)).toHaveText(/days left to go/);
  });

  test('tabs toggle active state and panel visibility', async ({ page }) => {
    const mainTab = page.getByRole('link', { name: 'main' });
    const rewardsTab = page.getByRole('link', { name: 'rewards' });
    const faqTab = page.getByRole('link', { name: 'faq' });

    const rewardsPanel = page.locator('[data-advent-panel="rewards"]');
    const faqPanel = page.locator('[data-advent-panel="faq"]');
    const mainPanel = page.locator('[data-advent-panel="main"]');

    await waitForHeadlineCompletion(page);

    await expect(mainPanel).toBeVisible();

    await rewardsTab.click();
    await expect(rewardsTab).toHaveClass(/is-active/);
    await expect(mainTab).not.toHaveClass(/is-active/);
    await expect(rewardsPanel).toBeVisible();
    await expect(mainPanel).toHaveClass(/is-hidden/);

    await faqTab.click();
    await expect(faqTab).toHaveClass(/is-active/);
    await expect(rewardsPanel).toHaveClass(/is-hidden/);
    await expect(faqPanel).toBeVisible();
  });

  test('countdown decreases over time', async ({ page }) => {
    const checkInButton = page.getByRole('button', { name: /check in/i });
    if (await checkInButton.count()) {
      await Promise.all([
        page.waitForResponse((response) => response.url().includes('/advent/check_in') && response.status() < 400),
        checkInButton.click(),
      ]);
      await page.waitForURL(/\/advent$/);
    }

    const countdown = page.locator('.advent-countdown [data-countdown-label]');
    await countdown.waitFor({ state: 'visible', timeout: 10000 });

    await expect(countdown).toHaveText(/\d{2}:\d{2}:\d{2} left until next check-in/);

    const initial = await countdown.innerText();
    await expect
      .poll(async () => countdown.innerText(), { message: 'Expected countdown to tick down' })
      .not.toBe(initial);
  });
});
