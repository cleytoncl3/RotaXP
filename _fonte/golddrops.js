// Gera Data/GoldDrops.lua: os drops mais valiosos dos mobs de cada local de farm de ouro (Data/GoldSpots.lua).
// Fonte: banco cmangos classic-db (creature_loot_template, reference_loot_template, item_template).
// Uso: node golddrops.js <pasta RouteXP> <classicdb.sql>
const fs = require('fs'), path = require('path');
const RX = process.argv[2], SQL = process.argv[3];
const sql = fs.readFileSync(SQL, 'utf8');

// --- leitor mínimo de INSERTs do mysqldump ---
function columns(tn) {
  const i = sql.indexOf('CREATE TABLE `' + tn + '`');
  const body = sql.slice(i, sql.indexOf(') ENGINE', i));
  return [...body.matchAll(/^\s+`(\w+)`/gm)].map(m => m[1]);
}
function* rows(tn, wanted) {
  const cols = columns(tn), idx = wanted.map(w => cols.indexOf(w));
  if (idx.some(i => i < 0)) throw tn + ': coluna faltando ' + wanted;
  const head = 'INSERT INTO `' + tn + '` VALUES ';
  let p = 0;
  while ((p = sql.indexOf(head, p)) >= 0) {
    let i = p + head.length;
    while (sql[i] === '(') {
      const vals = []; i++;
      while (true) {
        let v;
        if (sql[i] === "'") {
          let s = ''; i++;
          while (sql[i] !== "'") { if (sql[i] === '\\') { s += sql[i + 1]; i += 2; } else s += sql[i++]; }
          i++; v = s;
        } else { const j = i; while (sql[i] !== ',' && sql[i] !== ')') i++; v = sql.slice(j, i); }
        vals.push(v);
        if (sql[i] === ',') { i++; continue; }
        i++; break;
      }
      yield idx.map(k => vals[k]);
      if (sql[i] === ',') i++;
    }
    p = i;
  }
}

// --- locais de farm e nomes exatos dos mobs (Data/Grind.lua) ---
const spotsSrc = fs.readFileSync(path.join(RX, 'Data/GoldSpots.lua'), 'utf8');
const spots = [...spotsSrc.matchAll(/map = (\d+), mob = "([^"]+)"/g)].map(m => ({ map: +m[1], mob: m[2] }));
const grind = [...fs.readFileSync(path.join(RX, 'Data/Grind.lua'), 'utf8').matchAll(/\{(\d+),[\d.]+,[\d.]+,(\d+),(\d+),\d+,"([^"]+)"/g)]
  .map(m => ({ map: +m[1], lo: +m[2], hi: +m[3], name: m[4] }));

const wantNames = new Set();
for (const s of spots) for (const g of grind) if (g.map === s.map && g.name.includes(s.mob)) wantNames.add(g.name);

const creatures = {}; // nome -> [entry]
for (const [entry, name, lootId] of rows('creature_template', ['Entry', 'Name', 'LootId'])) {
  if (wantNames.has(name) && +lootId > 0) (creatures[name] = creatures[name] || []).push(+lootId);
}

// tabelas de loot
function loadLoot(tn) {
  const t = {};
  for (const [entry, item, chance, group, minRef] of rows(tn, ['entry', 'item', 'ChanceOrQuestChance', 'groupid', 'mincountOrRef'])) {
    (t[+entry] = t[+entry] || []).push({ item: +item, chance: +chance, group: +group, ref: +minRef < 0 ? -minRef : 0 });
  }
  return t;
}
const cLoot = loadLoot('creature_loot_template'), rLoot = loadLoot('reference_loot_template');

// chance (%) de cada item por abate, com grupos (chance 0 = divide o resto do grupo) e referências
function expand(list, mult, out, depth) {
  if (!list || depth > 3) return;
  const groups = {};
  for (const r of list) if (r.group > 0) (groups[r.group] = groups[r.group] || []).push(r);
  const eff = new Map();
  for (const r of list) {
    if (r.chance < 0) continue;                      // item de quest
    let c = r.chance;
    if (r.group > 0 && c === 0) {
      const g = groups[r.group];
      const fixed = g.reduce((a, x) => a + (x.chance > 0 ? x.chance : 0), 0);
      const zero = g.filter(x => x.chance === 0).length;
      c = Math.max(0, 100 - fixed) / zero;
    }
    eff.set(r, c);
  }
  for (const [r, c] of eff) {
    const p = mult * c / 100;
    if (r.ref) expand(rLoot[r.ref], p, out, depth + 1);
    else out[r.item] = (out[r.item] || 0) + p;
  }
}

const items = {};
for (const [entry, cls, name, quality, sell, bond] of rows('item_template', ['entry', 'class', 'name', 'Quality', 'SellPrice', 'bonding'])) {
  items[+entry] = { cls: +cls, name, q: +quality, sell: +sell, bond: +bond };
}

const out = [];
for (const s of spots) {
  const names = [...wantNames].filter(n => grind.some(g => g.map === s.map && g.name === n && n.includes(s.mob)));
  const acc = {}; let n = 0;
  for (const nm of names) for (const lootId of (creatures[nm] || [])) {
    const per = {}; expand(cLoot[lootId], 1, per, 0); n++;
    for (const k in per) acc[k] = (acc[k] || 0) + per[k];
  }
  if (!n) { out.push(`    -- ${s.mob} (${s.map}): sem dados de loot`); continue; }
  const list = Object.keys(acc).map(k => ({ id: +k, p: acc[k] / n, it: items[k] }))
    .filter(x => x.it && x.it.cls !== 12 && x.it.sell > 0);
  // valor esperado por abate (preço de vendedor; verde+ vale mais no leilão)
  for (const x of list) x.ev = x.p * x.it.sell * (x.it.q >= 3 ? 6 : x.it.q === 2 ? 3 : 1);
  const top = list.filter(x => x.p >= 0.005).sort((a, b) => b.ev - a.ev).slice(0, 4);
  // raros: azul/roxo vendável com chance de pelo menos 0,01% (o que mais vale x chance)
  const rare = list.filter(x => x.it.q >= 3 && x.it.bond !== 1 && x.p >= 0.0001 && !top.includes(x)).sort((a, b) => b.p * b.it.sell - a.p * a.it.sell).slice(0, 2);
  const fmt = x => `{ ${x.id}, ${(x.p * 100).toFixed(x.p * 100 < 0.1 ? 3 : 2)}, ${x.it.sell}, ${x.it.q}, "${x.it.name.replace(/"/g, '\\"')}" }`;
  out.push(`    ["${s.map}:${s.mob}"] = { top = { ${top.map(fmt).join(', ')} }, rare = { ${rare.map(fmt).join(', ')} } },`);
}
fs.writeFileSync(path.join(RX, 'Data/GoldDrops.lua'),
  '-- GERADO por _fonte/golddrops.js (dados: cmangos classic-db). Drops mais valiosos de cada local de farm de ouro.\n' +
  '-- { itemID, chance % por abate, preço de vendedor (cobre), qualidade, nome em inglês }\nlocal _, RX = ...\n\nRX.GoldDrops = {\n' + out.join('\n') + '\n}\n');
console.log(out.length + ' locais; sem dados: ' + out.filter(l => l.includes('sem dados')).length);
