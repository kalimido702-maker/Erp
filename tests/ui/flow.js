/**
 * flow.js — Automated browser walkthrough for شامل ERP
 *
 * What it does:
 *   1. Launches headless Chromium via Playwright
 *   2. Walks through every major screen (login → dashboard → modules)
 *   3. Takes a screenshot at each step (desktop 1440×900 + mobile 390×844)
 *   4. Writes screenshots/ + results.json
 *
 * Environment variables:
 *   APP_URL     Flutter web URL  (default: http://localhost:8080)
 *   DEMO_EMAIL  Demo login email (default: demo-admin@erp.local)
 *   DEMO_PASS   Demo password    (default: Demo@1234)
 */

'use strict';

const { chromium } = require('playwright');
const fs   = require('fs');
const path = require('path');

const APP_URL    = process.env.APP_URL    || 'http://localhost:8080';
const DEMO_EMAIL = process.env.DEMO_EMAIL || 'demo-admin@erp.local';
const DEMO_PASS  = process.env.DEMO_PASS  || 'Demo@1234';
const OUT_DIR    = path.join(__dirname, 'screenshots');
const RESULTS    = path.join(OUT_DIR, 'results.json');

fs.mkdirSync(OUT_DIR, { recursive: true });

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const log = (emoji, msg) => console.log(`${emoji}  ${msg}`);

const steps = [];
let   backendReachable = false;

async function runStep(id, label, fn) {
  const t0 = Date.now();
  try {
    await fn();
    const ms = Date.now() - t0;
    steps.push({ id, label, status: 'pass', ms, file: `${id}.png` });
    log('✅', `[${id}] ${label} — ${ms}ms`);
    return true;
  } catch (err) {
    const ms = Date.now() - t0;
    steps.push({ id, label, status: 'fail', ms, file: `${id}.png`, error: err.message });
    log('❌', `[${id}] ${label} — ${err.message.slice(0, 120)}`);
    return false;
  }
}

async function shot(page, id, { fullPage = true } = {}) {
  await page.screenshot({ path: path.join(OUT_DIR, `${id}.png`), fullPage });
}

// Wait for Flutter's first paint to settle
async function waitFlutter(page, extra = 0) {
  try { await page.waitForLoadState('networkidle', { timeout: 20000 }); } catch (_) {}
  await page.waitForTimeout(2800 + extra);
}

// Fill a text input in Flutter web (HTML renderer exposes real <input> elements)
async function flutterFill(page, fieldIndex, value) {
  const inputs = page.locator('input:not([type="hidden"])');
  await inputs.nth(fieldIndex).click({ timeout: 8000 });
  await page.waitForTimeout(300);
  await inputs.nth(fieldIndex).fill(value);
}

// Click a Flutter button by its visible text (uses flt-semantics or role=button)
async function flutterClick(page, text) {
  // Try role=button with name first, then fall back to text matching
  try {
    await page.getByRole('button', { name: text }).first().click({ timeout: 5000 });
  } catch (_) {
    await page.getByText(text).first().click({ timeout: 5000 });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Check backend availability
// ─────────────────────────────────────────────────────────────────────────────

async function checkBackend() {
  try {
    const res = await fetch(`${process.env.API_URL || 'http://localhost:8000'}/api/v1/health`, {
      signal: AbortSignal.timeout(5000),
    });
    backendReachable = res.ok;
  } catch (_) {
    backendReachable = false;
  }
  log(backendReachable ? '🟢' : '🟡', `Backend: ${backendReachable ? 'reachable' : 'not reachable — auth steps skipped'}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop flow (1440 × 900)
// ─────────────────────────────────────────────────────────────────────────────

async function runDesktop(browser) {
  let loggedIn = false;

  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    locale: 'ar-SA',
    colorScheme: 'light',
    deviceScaleFactor: 1,
  });
  const page = await ctx.newPage();

  // ── 01: Login page · light mode ──────────────────────────────────────────
  await runStep('01-login-light', 'صفحة الدخول · الوضع الفاتح', async () => {
    await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await waitFlutter(page);
    await shot(page, '01-login-light');
  });

  // ── 02: Login page · dark mode ────────────────────────────────────────────
  // The dark-mode toggle is in the top-right of the form panel.
  // We look for the second icon button in the theme chip area.
  await runStep('02-login-dark', 'صفحة الدخول · الوضع الداكن', async () => {
    // Try clicking the dark-mode icon button (moon icon area)
    const themeButtons = page.getByRole('button').filter({ hasText: /^$/ });
    // Theme toggle is near the top-right — take the last button in the top area
    await page.evaluate(() => {
      // Walk Flutter semantics to find theme toggle
      const btns = [...document.querySelectorAll('[role="button"]')];
      // Typically the second-to-last top-level button is the theme toggle dark
      if (btns.length >= 2) btns[btns.length - 1].click();
    });
    await page.waitForTimeout(600);
    await shot(page, '02-login-dark');
    // Toggle back to light
    await page.evaluate(() => {
      const btns = [...document.querySelectorAll('[role="button"]')];
      if (btns.length >= 1) btns[btns.length - 2].click();
    });
    await page.waitForTimeout(400);
  });

  // ── 03: Validation — submit empty form ────────────────────────────────────
  await runStep('03-login-validation', 'رسائل التحقق عند الإرسال الفارغ', async () => {
    await flutterClick(page, 'دخول');
    await page.waitForTimeout(800);
    await shot(page, '03-login-validation');
  });

  // ── 04: Fill form with credentials ────────────────────────────────────────
  await runStep('04-login-filled', 'النموذج مملوء بالبيانات', async () => {
    // email is input[0], password is input[1]
    await flutterFill(page, 0, DEMO_EMAIL);
    await flutterFill(page, 1, DEMO_PASS);
    await page.waitForTimeout(500);
    await shot(page, '04-login-filled');
  });

  // ── 05: Dashboard — after login ───────────────────────────────────────────
  if (backendReachable) {
    loggedIn = await runStep('05-dashboard', 'لوحة التحكم الرئيسية', async () => {
      await flutterClick(page, 'دخول');
      await waitFlutter(page, 2000);
      // Verify we left the login page
      const url = page.url();
      if (url.includes('/login')) throw new Error('Login failed — still on login page');
      await shot(page, '05-dashboard');
    });
  } else {
    // Still snapshot the login-loading state (button clicked, no network)
    await runStep('05-login-loading', 'حالة التحميل بعد النقر على دخول', async () => {
      await flutterClick(page, 'دخول');
      await page.waitForTimeout(400);
      await shot(page, '05-login-loading');
      steps[steps.length - 1].note = 'Backend unavailable — showing loading state';
    });
  }

  // ── Module pages — only if logged in ─────────────────────────────────────
  if (loggedIn) {
    const modules = [
      ['06-inventory',  '/inventory/products',  'المخزون والمنتجات'],
      ['07-sales',      '/sales/orders',         'المبيعات والفواتير'],
      ['08-purchases',  '/purchases/orders',     'المشتريات'],
      ['09-hr',         '/hr/employees',         'الموارد البشرية'],
      ['10-finance',    '/finance/reports',      'التقارير'],
      ['11-settings',   '/settings',             'الإعدادات'],
    ];

    for (const [id, route, label] of modules) {
      await runStep(id, label, async () => {
        await page.goto(`${APP_URL}${route}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
        await waitFlutter(page, 500);
        await shot(page, id);
      });
    }
  }

  await ctx.close();
  return loggedIn;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile flow (390 × 844 — iPhone 14)
// ─────────────────────────────────────────────────────────────────────────────

async function runMobile(browser, loginAfterShot) {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
    locale: 'ar-SA',
    colorScheme: 'light',
    deviceScaleFactor: 2,
  });
  const page = await ctx.newPage();

  await runStep('12-mobile-login', 'صفحة الدخول · عرض الجوال', async () => {
    await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await waitFlutter(page);
    await shot(page, '12-mobile-login');
  });

  if (loginAfterShot && backendReachable) {
    await runStep('13-mobile-dashboard', 'لوحة التحكم · عرض الجوال', async () => {
      await flutterFill(page, 0, DEMO_EMAIL);
      await flutterFill(page, 1, DEMO_PASS);
      await flutterClick(page, 'دخول');
      await waitFlutter(page, 2000);
      if (page.url().includes('/login')) throw new Error('Mobile login failed');
      await shot(page, '13-mobile-dashboard');
    });
  }

  await ctx.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  log('🚀', `Starting UI screenshot test — ${APP_URL}`);

  await checkBackend();

  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });

  try {
    const loggedIn = await runDesktop(browser);
    await runMobile(browser, loggedIn);
  } finally {
    await browser.close();
  }

  const passed = steps.filter(s => s.status === 'pass').length;
  const failed = steps.filter(s => s.status === 'fail').length;

  const summary = {
    timestamp: new Date().toISOString(),
    app_url: APP_URL,
    backend_reachable: backendReachable,
    total: steps.length,
    passed,
    failed,
    steps,
  };

  fs.writeFileSync(RESULTS, JSON.stringify(summary, null, 2));
  log('📊', `Done — ${passed}/${steps.length} passed, ${failed} failed`);
  log('📁', `Screenshots: ${OUT_DIR}`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
