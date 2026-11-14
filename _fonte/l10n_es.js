// Nomes em espanhol (esES; esMX quando faltar) das quests e NPCs usados pelos guias, do QuestieDB.
// Gera Data/Names_esES.lua: RX.ESQuest[questID] = nome; RX.ESNpc["English NPC name"] = nome.
// Uso: node _fonte/l10n_es.js <QuestieDB_Forever.toc> <db.json>
const fs = require('fs'), zlib = require('zlib'), path = require('path');
const [toc, dbFile] = process.argv.slice(2);
const ROOT = path.join(__dirname, '..');
const meta = new Map();
for (const l of fs.readFileSync(toc, 'utf8').split(/\r?\n/)) { if (!l.startsWith('## X-')) continue; const i = l.indexOf(':'); meta.set(l.slice(3, i).trim(), l.slice(i + 1).trim()); }
function get(k) { let v = meta.get(k); if (v === undefined) return; const m = /^~(\d+)~$/.exec(v); if (m) { let s = ''; for (let i = 1; i <= +m[1]; i++) s += meta.get(k + '-' + i); return s; } return v; }
eval(fs.readFileSync(__dirname + '/decode.js', 'utf8').match(/function cbor[\s\S]*?\n}\n/)[0]);
const inflate = b => { try { return zlib.inflateSync(b) } catch (e) { return zlib.inflateRawSync(b) } };
const blk = k => { const v = get(k); return v ? cbor(inflate(Buffer.from(v, 'base64'))) : null; };
const at = (col, pos) => Array.isArray(col) ? col[pos - 1] : col[pos];
function names(type, loc) {
  const ids = blk('X-' + type + '-IDS'), b = blk('X-l10n-' + loc + '-' + type);
  const out = {};
  if (!ids || !b) return out;
  const c1 = Array.isArray(b) ? b[0] : b[1];
  ids.forEach((id, i) => { const n = c1 && at(c1, i + 1); if (n) out[id] = n; });
  return out;
}
const q = Object.assign(names('Quest', 'esMX'), names('Quest', 'esES'));
const n = Object.assign(names('Npc', 'esMX'), names('Npc', 'esES'));
const db = JSON.parse(fs.readFileSync(dbFile, 'utf8'));

// o que os guias usam
const usedQ = new Set(), usedN = new Set();
for (const d of ['Guides', 'Data']) for (const f of fs.readdirSync(path.join(ROOT, d))) {
  if (!f.endsWith('.lua') || f.startsWith('NavGrid') || f.startsWith('Locale') || f.startsWith('Names')) continue;
  const t = fs.readFileSync(path.join(ROOT, d, f), 'utf8');
  for (const m of t.matchAll(/\bq=(\d+)/g)) usedQ.add(+m[1]);
  for (const m of t.matchAll(/\[(\d+)\]\s*=\s*\{/g)) usedQ.add(+m[1]);
  for (const m of t.matchAll(/\b(?:npc|pnpc)\s*=\s*"((?:[^"\\]|\\.)*)"/g)) usedN.add(m[1]);
}
const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"';
const outQ = [], outN = [];
for (const id of [...usedQ].sort((a, b) => a - b)) if (q[id]) outQ.push(`[${id}]=${lua(q[id])}`);
const enName = {};
for (const [id, e] of Object.entries(db.npcs || {})) { const nm = Array.isArray(e) ? e[0] : e && (e['1'] || e.name); if (nm && n[id] && !enName[nm]) enName[nm] = n[id]; }
for (const nm of [...usedN].sort()) if (enName[nm] && enName[nm] !== nm) outN.push(`[${lua(nm)}]=${lua(enName[nm])}`);
fs.writeFileSync(path.join(ROOT, 'Data', 'Names_esES.lua'),
  `-- Nombres en español de misiones y PNJ (QuestieDB, esES/esMX). Generado por _fonte/l10n_es.js.\nlocal _, RX = ...\nRX.ESQuest = {\n${outQ.join(',\n')}\n}\nRX.ESNpc = {\n${outN.join(',\n')}\n}\n`);
console.log('quests ES', outQ.length, 'de', usedQ.size, '| npcs ES', outN.length, 'de', usedN.size);
