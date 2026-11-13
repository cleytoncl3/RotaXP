// Gera Data/QuestChains.lua: as quests PRÉ-REQUISITO (e os pré-requisitos delas, em cadeia) das quests dos guias
// que NÃO aparecem em nenhum guia. Sem isto a quest seguinte fica escondida e você não sabe o que falta fazer.
// Uso: A2U=<zoneDB.lua do Questie> node chains.js <pasta RouteXP> <db.json> <l10n.json>
const fs = require('fs'), path = require('path');
const RX = process.argv[2], d = require(path.resolve(process.argv[3])), L = require(path.resolve(process.argv[4]));
const a2u = {};
for (const m of fs.readFileSync(process.env.A2U, 'utf8').matchAll(/\[(\d+)\]\s*=\s*(\d+),/g)) if (!(m[1] in a2u)) a2u[m[1]] = +m[2];
const H = (2n | 16n | 32n | 128n | 512n | (1n << 33n));
const horde = q => !q[6] || (BigInt(q[6]) & H) !== 0n;

// quests com passo "Aceitar" em algum guia
const inGuide = new Set();
for (const f of fs.readdirSync(path.join(RX, 'Guides')))
  for (const m of fs.readFileSync(path.join(RX, 'Guides', f), 'utf8').matchAll(/\{t="A", q=(\d+)/g)) inGuide.add(+m[1]);

const pres = q => { const e = d.quests[q]; return e ? { any: (e[13] || []).filter(x => x > 0), all: (e[12] || []).filter(x => x > 0) } : { any: [], all: [] }; };

// fecho dos pré-requisitos
const need = new Set(), seen = new Set();
const stack = [...inGuide];
while (stack.length) {
  const q = stack.pop();
  if (seen.has(q)) continue; seen.add(q);
  const p = pres(q);
  for (const x of [...p.any, ...p.all]) {
    if (!d.quests[x] || !horde(d.quests[x])) continue;
    if (!inGuide.has(x)) need.add(x);
    stack.push(x);
  }
}

const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
function pos(list, kind) {
  for (const id of list || []) {
    const e = kind === 'n' ? d.npcs[id] : d.objects[id]; if (!e) continue;
    const sp = (kind === 'n' ? e[7] : e[4]) || {};
    for (const [z, pts] of Object.entries(sp)) {
      const u = a2u[z];
      if (u && pts[0] && pts[0][0] > 0) return { u, x: Math.round(pts[0][0] * 10) / 10, y: Math.round(pts[0][1] * 10) / 10, name: e[1], pn: kind === 'n' ? L.npc[id] : null };
    }
  }
  return null;
}
const out = []; let noStart = 0;
for (const q of [...need].sort((a, b) => a - b)) {
  const e = d.quests[q];
  const st = Array.isArray(e[2]) ? { n: e[2][0], o: e[2][1], i: e[2][2] } : { n: (e[2] || {})[1], o: (e[2] || {})[2], i: (e[2] || {})[3] };
  const s = pos(st.n, 'n') || pos(st.o, 'o');
  const item = (st.i && st.i[0]) || 0;
  if (!s && !item) noStart++;
  const p = pres(q);
  const names = L.quest[q] || [];
  const xp = (L.xp[q] || [])[1] || 0;
  const f = [
    `lvl=${e[5] || 0}`, `xp=${xp}`, `n=${lua(e[1])}`, names[0] ? `pn=${lua(names[0])}` : null,
    p.any.length ? `pre={${p.any.join(',')}}` : null, p.all.length ? `preAll={${p.all.join(',')}}` : null,
    s ? `m=${s.u}, x=${s.x}, y=${s.y}, npc=${lua(s.name)}` + (s.pn ? `, pnpc=${lua(s.pn)}` : '') : null,
    item ? `startItem=${item}` : null,
  ].filter(Boolean);
  out.push(`    [${q}] = { ${f.join(', ')} },`);
}
fs.writeFileSync(path.join(RX, 'Data/QuestChains.lua'),
  '-- GERADO por _fonte/chains.js: quests pré-requisito que não estão em nenhum guia (onde pegar e o que exigem).\n' +
  'local _, RX = ...\n\nRX.QuestChains = {\n' + out.join('\n') + '\n}\n');
console.log(`${out.length} quests de cadeia (sem local de início: ${noStart})`);
