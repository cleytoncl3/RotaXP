const fs = require('fs'), path = require('path');
const AD = process.argv[2], RX = path.join(AD, 'RouteXP');
const ids = {};
const gq = fs.readFileSync(path.join(AD, 'GearQuestForever/Locales/Zones.lua'), 'utf8');
for (const m of gq.matchAll(/\["((?:[^"\\]|\\.)+)"\]\s*=\s*(-?\d+)/g)) ids[m[1]] = +m[2];
const qz = fs.readFileSync(path.join(AD, 'Questie/Localization/lookups/lookupZones.lua'), 'utf8');
for (const m of qz.matchAll(/\[(\d+)\]\s*=\s*"((?:[^"\\]|\\.)+)"/g)) {
  const n = m[2].trim();
  if (!(n in ids)) ids[n] = +m[1];
  // "The Shimmering Flats" também casa com "Shimmering Flats" (o jogo devolve o nome completo)
  if (n.startsWith('The ') && !(n.slice(4) in ids)) ids[n.slice(4)] = +m[1];
}
Object.assign(ids, { "Hinterlands": -1425, "Barrens": -1413, "Mount Hyjal": -2482, "Riverglades": -2548, "Shen'dralas": -2652,
  "Stranglethorn": -1434, "Dustwallow": -1445, "Un'Goro": -1449, "Arathi": -1417 });
let text = '';
const files = [...fs.readdirSync(path.join(RX, 'Guides')).map(f => 'Guides/' + f), 'Data/Routes.lua', 'Data/Zones.lua', 'Data/GoldSpots.lua',
  'Data/DungeonList.lua', 'Advisor.lua', 'Leveling.lua', 'Farm.lua', 'Talents.lua', 'Turnin.lua', 'Core.lua', 'UI.lua', 'Menu.lua', 'TravelPlan.lua', 'Data/Travel.lua'];
for (const f of files) {
  let s = fs.readFileSync(path.join(RX, f), 'utf8');
  if (f.startsWith('Guides/z_')) s = s.split('\n').filter(l => !/^\s*\{t="[ACT]"/.test(l)).join('\n');
  text += s + '\n';
}
const esc = x => x.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const found = {};
for (const [n, id] of Object.entries(ids)) {
  if (n.length < 5 || !/^[A-Z]/.test(n) || ["Docks","Dungeons"].includes(n)) continue;
  const re = new RegExp("(^|[^A-Za-z'])" + esc(n) + "(?![A-Za-z])");
  if (re.test(text)) found[n] = id;
}
const keys = Object.keys(found).sort();
let out = '-- GERADO por places.js: nome em inglês -> id de área (positivo) ou uiMapID (negativo).\n' +
  '-- O jogo devolve o nome no idioma do cliente; ver RX:Places() em Locale.lua.\nlocal _, RX = ...\n\nRX.PlaceIDs = {\n';
for (const k of keys) out += `    [${JSON.stringify(k)}] = ${found[k]},\n`;
out += '}\n';
fs.writeFileSync(path.join(RX, 'Data/PlaceNames.lua'), out);
console.log(keys.length + ' nomes'); console.log(keys.join(' | '));
