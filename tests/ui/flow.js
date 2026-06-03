/**
 * flow.js — Automated browser walkthrough for شامل ERP
 *
 * Strategy for Flutter web (HTML renderer):
 *   - Buttons/text are NOT standard DOM elements — use coordinate-based clicks.
 *   - Clicking a Flutter TextField at (x, y) triggers Flutter to create and
 *     focus a real <input> DOM element; subsequent keyboard.type() fills it.
 *   - All interaction steps are best-effort: they always produce a screenshot
 *     and never mark the step as failed due to missed clicks.
 *   - Navigation steps (goto + screenshot) always succeed.
 *
 * Environment variables:
 *   APP_URL     Flutter web URL  (default: http://localhost:8080)
 *   API_URL     Backend API URL  (default: http://localhost:8000)
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
// Core helpers
// ─────────────────────────────────────────────────────────────────────────────

const log = (emoji, msg) => console.log(`${emoji}  ${msg}`);
const steps = [];
let backendReachable = false;

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
    log('❌', `[${id}] — ${err.message.slice(0, 120)}`);
    return false;
  }
}

async function shot(page, id) {
  await page.screenshot({ path: path.join(OUT_DIR, `${id}.png`), fullPage: true });
}

// Inject before navigation: sets __flutterFirstFrame when Flutter fires
// the built-in 'flutter-first-frame' CustomEvent after painting its first frame.
// Also surfaces browser console errors + uncaught JS exceptions to the CI log
// so a blank-screen root cause (e.g. an exception before runApp) is visible.
async function setupFlutterListener(page) {
  await page.addInitScript(() => {
    window.__flutterFirstFrame = false;
    window.addEventListener('flutter-first-frame', () => {
      window.__flutterFirstFrame = true;
    }, { once: true });
  });
  page.on('pageerror', err => log('🛑', `[page error] ${err.message}`));
  page.on('console', msg => {
    if (msg.type() === 'error') log('🟠', `[console] ${msg.text().slice(0, 200)}`);
  });
}

// Wait for Flutter to finish rendering.
//   1. networkidle — all JS/assets fetched
//   2. flutter-first-frame event — fired by Flutter after the first real paint
//      (much more reliable than polling DOM elements)
//   3. Settle delay so any entrance animations finish
async function waitFlutter(page, extra = 0) {
  try { await page.waitForLoadState('networkidle', { timeout: 20000 }); } catch (_) {}
  const gotFrame = await page.waitForFunction(
    () => window.__flutterFirstFrame === true,
    { timeout: 12000, polling: 150 },
  ).then(() => true).catch(() => false);
  // Confirmed first paint → short settle; no event (SPA nav) → longer fallback.
  await page.waitForTimeout(gotFrame ? 1200 + extra : 3000 + extra);
}

// Best-effort coordinate click — never throws
async function coordClick(page, x, y) {
  try { await page.mouse.click(x, y); } catch (_) {}
  await page.waitForTimeout(300);
}

// Coordinate-based text fill for Flutter TextFields:
//   1. Click at (x, y) → Flutter focuses the field + creates a real <input>
//   2. Wait for the <input> to appear in the DOM
//   3. Type the value (keyboard.type goes into the focused element)
async function coordFill(page, x, y, value) {
  try {
    await page.mouse.click(x, y);
    await page.waitForTimeout(700); // Flutter materialises <input> after click
    await page.keyboard.type(value, { delay: 35 });
  } catch (_) {
    // absolute fallback — type anyway
    try { await page.keyboard.type(value, { delay: 35 }); } catch (_2) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backend probe
// ─────────────────────────────────────────────────────────────────────────────

async function checkBackend() {
  try {
    const res = await fetch(
      `${process.env.API_URL || 'http://localhost:8000'}/api/v1/health`,
      { signal: AbortSignal.timeout(5000) },
    );
    backendReachable = res.ok;
  } catch (_) {
    backendReachable = false;
  }
  log(backendReachable ? '🟢' : '🟡',
    `Backend: ${backendReachable ? 'reachable' : 'not reachable — auth steps will screenshot login state'}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop layout constants (1440 × 900)
//
// IMPORTANT: the UI is RTL (Arabic). _WebLayout is Row([BrandPanel, FormPanel]);
// under RTL the FIRST child renders on the RIGHT, so the brand panel is on the
// RIGHT and the LOGIN FORM is on the LEFT half. Form flex 95 of 200 → form
// occupies x≈0–684, centered around x≈342. The theme toggle sits top-LEFT.
// (Coordinates read off the rendered 1440×900 login screenshot.)
// ─────────────────────────────────────────────────────────────────────────────

const D = {
  cx:          342, // horizontal center of the LEFT form panel (RTL)
  emailY:      371, // email TextField
  passY:       463, // password TextField
  btnY:        568, // "دخول" ElevatedButton
  themeX:       58, // dark-mode toggle (top-left chip)
  themeY:       49,
};

async function runDesktop(browser) {
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    locale: 'ar-SA',
    colorScheme: 'light',
    deviceScaleFactor: 1,
  });
  const page = await ctx.newPage();
  await setupFlutterListener(page);
  let loggedIn = false;

  // ── 01: Login · light mode ────────────────────────────────────────────────
  await runStep('01-login-light', 'صفحة الدخول · الوضع الفاتح', async () => {
    await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await waitFlutter(page);
    await shot(page, '01-login-light');
  });

  // ── 02: Login · dark mode (best-effort toggle click) ──────────────────────
  await runStep('02-login-dark', 'صفحة الدخول · الوضع الداكن', async () => {
    await coordClick(page, D.themeX, D.themeY);
    await page.waitForTimeout(700);
    await shot(page, '02-login-dark');
    await coordClick(page, D.themeX, D.themeY); // toggle back to light
    await page.waitForTimeout(500);
  });

  // ── 03: Empty-form validation ─────────────────────────────────────────────
  await runStep('03-login-validation', 'رسائل التحقق عند الإرسال الفارغ', async () => {
    await coordClick(page, D.cx, D.btnY);
    await page.waitForTimeout(1000);
    await shot(page, '03-login-validation');
  });

  // ── 04: Fill credentials ──────────────────────────────────────────────────
  await runStep('04-login-filled', 'النموذج مملوء بالبيانات', async () => {
    await coordFill(page, D.cx, D.emailY, DEMO_EMAIL);
    await page.waitForTimeout(400);
    await coordFill(page, D.cx, D.passY, DEMO_PASS);
    await page.waitForTimeout(500);
    await shot(page, '04-login-filled');
  });

  // ── 05: Submit → dashboard ────────────────────────────────────────────────
  await runStep('05-dashboard', 'لوحة التحكم الرئيسية', async () => {
    if (backendReachable) {
      await coordClick(page, D.cx, D.btnY);
      await waitFlutter(page, 2000);
      loggedIn = !page.url().includes('/login');
    }
    await shot(page, '05-dashboard');
  });

  // ── Module pages (always navigate — shows login redirect if not logged in) ─
  const modules = [
    ['06-inventory',  '/inventory/products', 'المخزون والمنتجات'],
    ['07-sales',      '/sales/orders',        'المبيعات والفواتير'],
    ['08-purchases',  '/purchases/orders',    'المشتريات'],
    ['09-hr',         '/hr/employees',        'الموارد البشرية'],
    ['10-finance',    '/finance/reports',     'التقارير'],
    ['11-settings',   '/settings',            'الإعدادات'],
  ];

  for (const [id, route, label] of modules) {
    await runStep(id, label, async () => {
      await page.goto(`${APP_URL}${route}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
      await waitFlutter(page, 500);
      await shot(page, id);
    });
  }

  await ctx.close();
  return loggedIn;
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile layout constants (390 × 844 — iPhone 14)
//
// Hero gradient section ≈ 260 px; scrollable card below.
// ─────────────────────────────────────────────────────────────────────────────

// New mobile login: full gradient with a white card occupying the bottom ~67%
// (card top ≈ y280). Fields sit inside the card.
const M = {
  cx:     195, // horizontal center
  emailY: 438, // email field
  passY:  538, // password field
  btnY:   645, // "تسجيل الدخول" button
};

async function runMobile(browser) {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
    locale: 'ar-SA',
    colorScheme: 'light',
    deviceScaleFactor: 2,
  });
  const page = await ctx.newPage();
  await setupFlutterListener(page);

  // ── 12: Mobile login page ─────────────────────────────────────────────────
  await runStep('12-mobile-login', 'صفحة الدخول · عرض الجوال', async () => {
    await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await waitFlutter(page);
    await shot(page, '12-mobile-login');
  });

  // ── 13: Mobile login attempt + dashboard ──────────────────────────────────
  await runStep('13-mobile-dashboard', 'لوحة التحكم · عرض الجوال', async () => {
    if (backendReachable) {
      await coordFill(page, M.cx, M.emailY, DEMO_EMAIL);
      await page.waitForTimeout(400);
      await coordFill(page, M.cx, M.passY, DEMO_PASS);
      await page.waitForTimeout(400);
      await coordClick(page, M.cx, M.btnY);
      await waitFlutter(page, 2000);
    }
    await shot(page, '13-mobile-dashboard');
  });

  await ctx.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  log('🚀', `Starting UI screenshot test — ${APP_URL}`);
  await checkBackend();

  const browser = await chromium.launch({
    // headless:false + Xvfb (DISPLAY=:99 exported in CI) is the only reliable
    // way to get non-blank screenshots from Flutter web, which composites its
    // canvas layers via the GPU pipeline.  Headless Chrome ignores DISPLAY and
    // therefore never composites GPU layers → all-white screenshots.
    headless: false,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-background-timer-throttling',
      '--disable-renderer-backgrounding',
      '--force-color-profile=srgb',
    ],
  });

  try {
    await runDesktop(browser);
    await runMobile(browser);
  } finally {
    await browser.close();
  }

  const passed = steps.filter(s => s.status === 'pass').length;
  const failed = steps.filter(s => s.status === 'fail').length;

  fs.writeFileSync(RESULTS, JSON.stringify({
    timestamp:         new Date().toISOString(),
    app_url:           APP_URL,
    backend_reachable: backendReachable,
    total:             steps.length,
    passed,
    failed,
    steps,
  }, null, 2));

  log('📊', `Done — ${passed}/${steps.length} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
