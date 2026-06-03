/**
 * report.js — Generate GitHub Actions Job Summary + HTML report
 *
 * Reads screenshots/results.json (produced by flow.js + gofile.js) and:
 *   1. Writes a Markdown table to $GITHUB_STEP_SUMMARY (shows in Actions UI)
 *   2. Writes screenshots/report.html (uploadable artifact with embedded images)
 */

'use strict';

const fs   = require('fs');
const path = require('path');

const OUT_DIR = path.join(__dirname, 'screenshots');
const RESULTS = path.join(OUT_DIR, 'results.json');
const HTML    = path.join(OUT_DIR, 'report.html');

const log = (emoji, msg) => console.log(`${emoji}  ${msg}`);

// ─────────────────────────────────────────────────────────────────────────────
// Load results
// ─────────────────────────────────────────────────────────────────────────────

if (!fs.existsSync(RESULTS)) {
  console.error('results.json not found — run flow.js first');
  process.exit(1);
}

const summary = JSON.parse(fs.readFileSync(RESULTS, 'utf8'));
const { steps, passed, failed, total, timestamp, backend_reachable, gofile_folder } = summary;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function imgB64(file) {
  const full = path.join(OUT_DIR, file);
  if (!fs.existsSync(full)) return null;
  return `data:image/png;base64,${fs.readFileSync(full).toString('base64')}`;
}

function fmtMs(ms) {
  return ms < 1000 ? `${ms}ms` : `${(ms / 1000).toFixed(1)}s`;
}

function statusIcon(s) {
  return s.status === 'pass' ? '✅' : '❌';
}

// ─────────────────────────────────────────────────────────────────────────────
// GitHub Actions Markdown Summary
// ─────────────────────────────────────────────────────────────────────────────

function buildMarkdown() {
  const date = new Date(timestamp).toLocaleString('ar-SA', {
    timeZone: 'UTC', dateStyle: 'medium', timeStyle: 'short',
  });

  const passRate = total > 0 ? Math.round((passed / total) * 100) : 0;
  const badge = passRate === 100 ? '🟢 جميع الخطوات نجحت' :
                passRate >= 80   ? '🟡 معظم الخطوات نجحت' :
                                   '🔴 فشل في خطوات عديدة';

  let md = '';
  md += `# 📸 تقرير الاختبار البصري — شامل ERP\n\n`;
  md += `**${badge}** &nbsp;|&nbsp; `;
  md += `**التاريخ:** ${date} UTC &nbsp;|&nbsp; `;
  md += `**الخادم:** ${backend_reachable ? '🟢 متصل' : '🟡 غير متاح'}\n\n`;
  md += `---\n\n`;

  md += `## ملخص النتائج\n\n`;
  md += `| | |\n|---|---|\n`;
  md += `| ✅ ناجحة | **${passed}** |\n`;
  md += `| ❌ فاشلة | **${failed}** |\n`;
  md += `| 📊 المجموع | **${total}** |\n`;
  md += `| 📈 نسبة النجاح | **${passRate}%** |\n`;
  if (gofile_folder) {
    md += `| 📂 مجلد الصور | [gofile.io](${gofile_folder}) |\n`;
  }
  md += `\n---\n\n`;

  md += `## تفاصيل الخطوات\n\n`;
  md += `| # | الشاشة | الحالة | الوقت | رابط الصورة |\n`;
  md += `|---|--------|--------|-------|-------------|\n`;

  for (const [i, s] of steps.entries()) {
    const icon  = statusIcon(s);
    const t     = fmtMs(s.ms);
    const link  = s.gofile_url ? `[🖼️ عرض](${s.gofile_url})` : '—';
    const err   = s.error ? ` _(${s.error.slice(0, 60)})_` : '';
    const note  = s.note  ? ` _(${s.note})_` : '';
    md += `| ${i + 1} | ${s.label}${note}${err} | ${icon} | ${t} | ${link} |\n`;
  }

  md += `\n---\n`;
  md += `> _تم التوليد تلقائياً بواسطة Playwright — شامل ERP UI Test Bot_\n`;

  return md;
}

// ─────────────────────────────────────────────────────────────────────────────
// Standalone HTML report (with embedded screenshots)
// ─────────────────────────────────────────────────────────────────────────────

function buildHtml() {
  const date = new Date(timestamp).toISOString().replace('T', ' ').slice(0, 19);
  const passRate = total > 0 ? Math.round((passed / total) * 100) : 0;

  const cards = steps.map((s, i) => {
    const b64 = imgB64(s.file);
    const img = b64
      ? `<img src="${b64}" alt="${s.label}" loading="lazy">`
      : `<div class="no-img">لا توجد صورة</div>`;
    const badge = s.status === 'pass'
      ? `<span class="badge pass">✅ نجح</span>`
      : `<span class="badge fail">❌ فشل</span>`;
    const link = s.gofile_url
      ? `<a href="${s.gofile_url}" target="_blank" class="ext-link">🔗 gofile.io</a>`
      : '';
    const err = s.error
      ? `<p class="err-msg">⚠️ ${s.error}</p>`
      : '';

    return `
      <div class="card ${s.status}">
        <div class="card-head">
          <span class="num">${String(i + 1).padStart(2, '0')}</span>
          <span class="lbl">${s.label}</span>
          ${badge}
          <span class="timing">${fmtMs(s.ms)}</span>
          ${link}
        </div>
        ${err}
        <div class="thumb">${img}</div>
      </div>`;
  }).join('\n');

  return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>تقرير الاختبار البصري — شامل ERP</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Segoe UI', Tahoma, 'Arial', sans-serif;
      background: #EAEEF7; color: #0E1730;
      direction: rtl; text-align: right;
    }
    header {
      background: linear-gradient(150deg, #0C4FE0 0%, #0A3FC0 48%, #0B6BD6 78%, #12B5F0 130%);
      color: #fff; padding: 32px 40px;
    }
    header h1 { font-size: 28px; font-weight: 800; }
    header .meta { font-size: 14px; opacity: .8; margin-top: 8px; display: flex; gap: 24px; flex-wrap: wrap; }
    .summary-row {
      display: flex; gap: 16px; flex-wrap: wrap;
      padding: 24px 40px; background: #fff;
      border-bottom: 1px solid #E3E8F2;
    }
    .stat {
      background: #F5F7FC; border: 1px solid #E3E8F2;
      border-radius: 12px; padding: 16px 24px;
      min-width: 140px; text-align: center;
    }
    .stat .val { font-size: 32px; font-weight: 800; }
    .stat .key { font-size: 13px; color: #4A5470; margin-top: 4px; }
    .stat.pass .val { color: #15976A; }
    .stat.fail .val { color: #D8453C; }
    .stat.rate .val { color: #0C4FE0; }
    main { padding: 24px 40px 60px; max-width: 1400px; margin: 0 auto; }
    h2 { font-size: 20px; font-weight: 800; margin: 24px 0 16px; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(420px, 1fr));
      gap: 16px;
    }
    .card {
      background: #fff; border: 1px solid #E3E8F2;
      border-radius: 16px; overflow: hidden;
    }
    .card.fail { border-color: #D8453C; }
    .card-head {
      display: flex; align-items: center; gap: 10px;
      padding: 14px 16px; border-bottom: 1px solid #E3E8F2;
      flex-wrap: wrap;
    }
    .num { font-size: 11px; font-weight: 700; background: #EDF1F9; border-radius: 6px; padding: 3px 7px; color: #4A5470; }
    .lbl { flex: 1; font-weight: 700; font-size: 14.5px; }
    .badge { font-size: 12px; font-weight: 700; padding: 4px 10px; border-radius: 999px; }
    .badge.pass { background: #E0F4EC; color: #15976A; }
    .badge.fail { background: #FBE7E5; color: #D8453C; }
    .timing { font-size: 12px; color: #8A93AC; }
    .ext-link { font-size: 12px; color: #0C4FE0; font-weight: 700; text-decoration: none; }
    .ext-link:hover { text-decoration: underline; }
    .err-msg { font-size: 12.5px; color: #D8453C; padding: 8px 16px; background: #FBE7E5; }
    .thumb img { width: 100%; display: block; max-height: 480px; object-fit: contain; background: #EDF1F9; }
    .no-img { padding: 40px; text-align: center; color: #8A93AC; font-size: 14px; }
    footer { text-align: center; padding: 32px; font-size: 13px; color: #8A93AC; }
    @media (max-width: 600px) { main { padding: 16px; } .summary-row { padding: 16px; } header { padding: 20px; } }
  </style>
</head>
<body>
  <header>
    <h1>📸 تقرير الاختبار البصري — شامل ERP</h1>
    <div class="meta">
      <span>🕐 ${date} UTC</span>
      <span>${backend_reachable ? '🟢 الخادم متصل' : '🟡 الخادم غير متاح'}</span>
      ${gofile_folder ? `<span>📂 <a href="${gofile_folder}" style="color:#fff" target="_blank">مجلد gofile.io</a></span>` : ''}
    </div>
  </header>

  <div class="summary-row">
    <div class="stat pass"><div class="val">${passed}</div><div class="key">✅ ناجحة</div></div>
    <div class="stat fail"><div class="val">${failed}</div><div class="key">❌ فاشلة</div></div>
    <div class="stat"><div class="val">${total}</div><div class="key">📊 المجموع</div></div>
    <div class="stat rate"><div class="val">${passRate}%</div><div class="key">📈 نسبة النجاح</div></div>
  </div>

  <main>
    <h2>الشاشات</h2>
    <div class="grid">
      ${cards}
    </div>
  </main>

  <footer>تم التوليد تلقائياً بواسطة Playwright Bot — شامل ERP UI Test</footer>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Write outputs
// ─────────────────────────────────────────────────────────────────────────────

const md   = buildMarkdown();
const html = buildHtml();

// GitHub Actions summary
const summaryFile = process.env.GITHUB_STEP_SUMMARY;
if (summaryFile) {
  fs.appendFileSync(summaryFile, md);
  log('📋', 'GitHub Actions summary written');
} else {
  log('📋', 'Not in GitHub Actions — printing summary to stdout:');
  console.log('\n' + md);
}

// HTML report
fs.writeFileSync(HTML, html);
log('🌐', `HTML report: ${HTML}`);
log('📊', `${passed}/${total} passed (${Math.round((passed / total) * 100)}%)`);

function log(emoji, msg) { console.log(`${emoji}  ${msg}`); }
