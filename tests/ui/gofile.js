/**
 * gofile.js — Upload all screenshots to gofile.io and update results.json
 *
 * gofile.io free API:
 *   GET  https://api.gofile.io/getServer          → { data: { server } }
 *   POST https://{server}.gofile.io/uploadFile    → multipart, field "file"
 *   Response: { data: { downloadPage, fileId, fileName, md5 } }
 *
 * Writes "gofile_url" and "gofile_folder" back into results.json for the report.
 */

'use strict';

const fs       = require('fs');
const path     = require('path');
const axios    = require('axios');
const FormData = require('form-data');

const OUT_DIR    = path.join(__dirname, 'screenshots');
const RESULTS    = path.join(OUT_DIR, 'results.json');
const LINKS_FILE = path.join(OUT_DIR, 'gofile_links.json');

const log = (emoji, msg) => console.log(`${emoji}  ${msg}`);

async function getUploadServer() {
  const res = await axios.get('https://api.gofile.io/getServer', { timeout: 15000 });
  if (res.data?.status !== 'ok') throw new Error('gofile getServer returned non-ok');
  return res.data.data.server;
}

async function uploadFile(server, filePath) {
  const form = new FormData();
  form.append('file', fs.createReadStream(filePath), {
    filename: path.basename(filePath),
    contentType: 'image/png',
  });

  const res = await axios.post(`https://${server}.gofile.io/uploadFile`, form, {
    headers: form.getHeaders(),
    timeout: 60000,
    maxBodyLength: Infinity,
  });

  if (res.data?.status !== 'ok') {
    throw new Error(`Upload failed: ${JSON.stringify(res.data)}`);
  }

  return {
    downloadPage: res.data.data.downloadPage,
    fileId:       res.data.data.fileId,
    directLink:   res.data.data.directLink || null,
  };
}

async function main() {
  if (!fs.existsSync(RESULTS)) {
    console.error('results.json not found — run flow.js first');
    process.exit(1);
  }

  const summary = JSON.parse(fs.readFileSync(RESULTS, 'utf8'));
  const links   = {};

  let server;
  try {
    log('🌐', 'Getting gofile.io upload server...');
    server = await getUploadServer();
    log('✅', `Upload server: ${server}`);
  } catch (err) {
    log('⚠️', `Could not reach gofile.io: ${err.message}`);
    log('ℹ️', 'Screenshots will only be available as GitHub artifact');
    process.exit(0); // non-fatal — CI should not fail if gofile is down
  }

  let folderUrl = null;

  for (const step of summary.steps) {
    const file = path.join(OUT_DIR, step.file);
    if (!fs.existsSync(file)) {
      log('⏭️', `Skipping missing file: ${step.file}`);
      continue;
    }

    try {
      log('⬆️', `Uploading ${step.file}...`);
      const result = await uploadFile(server, file);
      links[step.id] = result.downloadPage;
      step.gofile_url = result.downloadPage;
      if (!folderUrl && result.downloadPage) {
        // All files go to the same folder if uploaded without auth
        folderUrl = result.downloadPage.replace(/\/[^/]+$/, '');
      }
      log('🔗', `  ${step.label} → ${result.downloadPage}`);
    } catch (err) {
      log('❌', `  Failed to upload ${step.file}: ${err.message}`);
      step.gofile_url = null;
    }

    // Small delay between uploads to be polite
    await new Promise(r => setTimeout(r, 500));
  }

  if (folderUrl) {
    summary.gofile_folder = folderUrl;
    log('📂', `Folder URL: ${folderUrl}`);
  }

  fs.writeFileSync(RESULTS, JSON.stringify(summary, null, 2));
  fs.writeFileSync(LINKS_FILE, JSON.stringify(links, null, 2));

  const uploaded = Object.keys(links).length;
  log('📊', `Uploaded ${uploaded}/${summary.steps.length} screenshots to gofile.io`);
}

main().catch(e => { console.error(e); process.exit(1); });
