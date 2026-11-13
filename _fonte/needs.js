// Gera Data/QuestNeeds.lua: itens que cada quest dos guias pede (objetivos de item), com a quantidade.
// Uso: node needs.js <pasta RouteXP> <db.json>
const fs = require('fs'), path = require('path');
const RX = process.argv[2], DB = require(path.resolve(process.argv[3]));
const used = new Set();
for (const f of fs.readdirSync(path.join(RX, 'Guides')))
  for (const m of fs.readFileSync(path.join(RX, 'Guides', f), 'utf8').matchAll(/q=(\d+)/g)) used.add(+m[1]);
const out = [];
for (const q of [...used].sort((a, b) => a - b)) {
  const d = DB.quests[q];
  const items = d && d['10'] && d['10']['3'];
  if (!items || !items.length) continue;
  const text = (d['8'] || []).join(' ');
  const nums = [...text.matchAll(/(\d+)\s+(?!yards|minutes|seconds)[A-Z'a-z]/g)].map(m => +m[1]);
  const parts = items.map((it, i) => `{ ${it[0]}, ${nums[i] || (items.length === 1 && nums[0]) || 1} }`);
  out.push(`    [${q}] = { ${parts.join(', ')} },`);
}
fs.writeFileSync(path.join(RX, 'Data/QuestNeeds.lua'),
  `-- GERADO por _fonte/needs.js: itens pedidos por cada quest dos guias { itemID, quantidade }.\nlocal _, RX = ...\n\nRX.QuestNeeds = {\n${out.join('\n')}\n}\n`);
console.log(out.length + ' quests com itens');
