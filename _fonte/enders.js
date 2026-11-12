// Gera Data/Enders.lua: NPC de entrega (nome, PT, mapa, x, y) de todas as quests da Horda
const fs = require('fs'); const d = require(__dirname + '/db.json'); const L = require(__dirname + '/l10n.json');
const a2u = {}; for (const m of fs.readFileSync(process.env.A2U, 'utf8').matchAll(/\[(\d+)\]\s*=\s*(\d+),/g)) if (!(m[1] in a2u)) a2u[m[1]] = +m[2];
const H = (2n | 16n | 32n | 128n | 512n | (1n << 33n));
const RE = {}; for (const [id, n] of Object.entries(d.npcs)) for (const q of (n[11] || [])) (RE[q] = RE[q] || []).push(['n', +id]);
for (const [id, o] of Object.entries(d.objects)) for (const q of (o[3] || [])) (RE[q] = RE[q] || []).push(['o', +id]);
const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
let out = '-- GERADO por enders.js: onde entregar cada quest (dados QuestieDB WoW Forever)\nlocal _, RX = ...\nRX.Enders = {\n'; let n = 0;
for (const [id, q] of Object.entries(d.quests)) {
  if (q[6] && (BigInt(q[6]) & H) === 0n) continue;
  let list = []; const f = q[3];
  if (f) { const a = Array.isArray(f) ? { 1: f[0], 2: f[1] } : f; for (const x of (a[1] || [])) list.push(['n', x]); for (const x of (a[2] || [])) list.push(['o', x]); }
  if (!list.length) list = RE[id] || [];
  let best = null;
  for (const [k, eid] of list) {
    const e = k === 'n' ? d.npcs[eid] : d.objects[eid]; if (!e) continue;
    const sp = (k === 'n' ? e[7] : e[4]) || {};
    for (const [z, pts] of Object.entries(sp)) { const u = a2u[z]; if (u && pts[0] && pts[0][0] > 0) { best = { u, x: pts[0][0], y: pts[0][1], name: e[1], pn: k === 'n' ? L.npc[eid] : null }; break; } }
    if (best) break;
  }
  if (!best) continue;
  out += `[${id}]={${best.u},${Math.round(best.x * 10) / 10},${Math.round(best.y * 10) / 10},${lua(best.name)}${',' + (best.pn ? lua(best.pn) : 'false')},${(L.xp[id]||[])[1]||0},${q[5]||0}},\n`; n++;
}
out += '}\n'; fs.writeFileSync(process.argv[2], out); console.log('enders', n, (out.length / 1024).toFixed(0) + 'KB');
