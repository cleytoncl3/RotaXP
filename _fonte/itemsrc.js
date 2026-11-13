// Gera Data/QuestItemSource.lua: de onde vem cada item pedido pelas quests dos guias.
// "m" = cai de mob, "o" = pega clicando em objeto (chão, baú, planta...), "mo" = os dois.
// Uso: node itemsrc.js <pasta RouteXP> <db.json>
const fs = require('fs'), path = require('path');
const RX = process.argv[2], DB = require(path.resolve(process.argv[3]));
const used = new Set();
for (const f of fs.readdirSync(path.join(RX, 'Guides')))
  for (const m of fs.readFileSync(path.join(RX, 'Guides', f), 'utf8').matchAll(/q=(\d+)/g)) used.add(+m[1]);
const src = {};
for (const q of used) {
  const d = DB.quests[q];
  const items = d && d['10'] && d['10']['3'];
  if (!items) continue;
  for (const it of items) {
    const id = it[0], info = DB.items[id];
    if (!info) continue;
    const mob = (info['2'] || []).length > 0, obj = (info['3'] || []).length > 0;
    const s = (mob ? 'm' : '') + (obj ? 'o' : '');
    if (s) src[id] = s;
  }
}
const ids = Object.keys(src).map(Number).sort((a, b) => a - b);
fs.writeFileSync(path.join(RX, 'Data/QuestItemSource.lua'),
  `-- GERADO por _fonte/itemsrc.js: de onde vem cada item de quest ("m" mob, "o" objeto, "mo" os dois).\nlocal _, RX = ...\n\nRX.ItemSource = {\n` +
  ids.map(id => `    [${id}] = "${src[id]}",`).join('\n') + '\n}\n');
const c = { m: 0, o: 0, mo: 0 }; for (const id of ids) c[src[id]]++;
console.log(ids.length, 'itens', JSON.stringify(c));
