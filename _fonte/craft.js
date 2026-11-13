// Gera Data/Crafted.lua: quests cujo objetivo é um item FABRICADO por profissão (ex.: Culinária).
// Fonte: AtlasLootClassic/Data/Profession.lua (receitas) + db.json (objetivos das quests, do QuestieDB).
// Uso: node craft.js <pasta AddOns> <db.json>
const fs = require('fs'), path = require('path');
const AD = process.argv[2], DB = require(path.resolve(process.argv[3]));
const RX = path.join(AD, 'RouteXP');
const prof = fs.readFileSync(path.join(AD, 'AtlasLootClassic/Data/Profession.lua'), 'utf8');
const start = prof.indexOf('PROFESSION_DATA.CLASSIC = {'), end = prof.indexOf('PROFESSION_DATA.BCC = {');
const block = prof.slice(start, end);
const recipes = {};   // itemCriado -> receita
const re = /\[(\d+)\]\s*=\s*\{\s*(\d+|nil),\s*(\d+),\s*(\d+),[^{]*\{([^}]*)\},\s*\{([^}]*)\}/g;
for (const m of block.matchAll(re)) {
  if (m[2] === 'nil') continue;
  const item = +m[2], p = +m[3], skill = +m[4];
  const r = m[5].split(',').map(s => +s.trim()).filter(Boolean);
  const c = m[6].split(',').map(s => +s.trim()).filter(Boolean);
  if (!recipes[item] || recipes[item].s > skill) recipes[item] = { p, s: skill, r: r.map((id, i) => [id, c[i] || 1]) };
}
// quests usadas nos guias
const used = new Set();
for (const f of fs.readdirSync(path.join(RX, 'Guides'))) {
  const s = fs.readFileSync(path.join(RX, 'Guides', f), 'utf8');
  for (const m of s.matchAll(/q=(\d+)/g)) used.add(+m[1]);
}
const out = [];
for (const q of [...used].sort((a, b) => a - b)) {
  const d = DB.quests[q];
  if (!d || !d['10'] || !d['10']['3']) continue;
  const text = (d['8'] || []).join(' ');
  for (const it of d['10']['3']) {
    const id = it[0], rc = recipes[id];
    if (!rc) continue;
    const m = text.match(/(\d+)\s/);
    const n = m ? +m[1] : 1;
    out.push(`    [${q}] = { i = ${id}, n = ${n}, p = ${rc.p}, s = ${rc.s}, r = { ${rc.r.map(([a, b]) => `{ ${a}, ${b} }`).join(', ')} } },`);
    break;
  }
}
const lua = `-- GERADO por _fonte/craft.js: quests que pedem um item FABRICADO por profissão.
-- i = item pedido, n = quantidade, p = profissão (ids do AtlasLoot: 1 Primeiros Socorros, 2 Ferraria, 3 Couraria,
-- 4 Alquimia, 6 Culinária, 8 Alfaiataria, 9 Engenharia, 10 Encantamento), s = perícia mínima, r = {reagente, qtd por unidade}
local _, RX = ...

RX.QuestCraft = {
${out.join('\n')}
}
`;
fs.writeFileSync(path.join(RX, 'Data/Crafted.lua'), lua);
console.log(Object.keys(recipes).length + ' receitas; ' + out.length + ' quests de profissão nos guias');
console.log(out.join('\n'));
