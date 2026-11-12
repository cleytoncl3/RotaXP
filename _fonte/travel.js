// Gera Data/Travel.lua: mestres de voo da Horda/neutros e transportes (zepelins/barcos)
const fs = require('fs'); const d = require(__dirname + '/db.json'); const L = require(__dirname + '/l10n.json');
const a2u = {}; for (const m of fs.readFileSync(process.env.A2U, 'utf8').matchAll(/\[(\d+)\]\s*=\s*(\d+),/g)) if (!(m[1] in a2u)) a2u[m[1]] = +m[2];
const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
let out = '-- GERADO por travel.js (dados QuestieDB WoW Forever) + transportes conhecidos\nlocal _, RX = ...\nRX.FlightMasters = {\n';
let n = 0;
for (const [id, e] of Object.entries(d.npcs)) {
  const sub = e[14] || '';
  if (!/^(Wind Rider Master|Bat Handler|Flight Master|Thunder Bluff Flight Master)$/.test(sub)) continue;
  const fac = e[13] || '';
  if (fac !== 'H' && fac !== 'AH') continue;
  const sp = e[7] || {};
  for (const [z, pts] of Object.entries(sp)) {
    const u = a2u[z]; const c = pts[0];
    if (!u || !c || c[0] <= 0) continue;
    out += `  {${u},${c[0]},${c[1]},${lua(e[1])}${L.npc[id] ? ',' + lua(L.npc[id]) : ''}},\n`; n++;
    break;
  }
}
out += '}\n';
// transportes: {nome PT, nome EN, mapa A, x, y, mapa B, x, y, aprox}
const T = [
  ['Zepelim Orgrimmar <-> Undercity', 'Zeppelin Orgrimmar <-> Undercity', 14, 50.82, 13.54, 85, 60.74, 58.87],
  ['Zepelim Orgrimmar <-> Grom\'gol', 'Zeppelin Orgrimmar <-> Grom\'gol', 14, 50.69, 12.89, 33, 31.43, 29.91],
  ['Zepelim Undercity <-> Grom\'gol', 'Zeppelin Undercity <-> Grom\'gol', 85, 61.78, 59.18, 33, 31.54, 29.36],
  ['Barco Ratchet <-> Booty Bay', 'Boat Ratchet <-> Booty Bay', 17, 63.54, 38.61, 33, 26.08, 73.35],
  ['Navio Steamwheedle Port <-> Powderfuse Port', 'Ship Steamwheedle Port <-> Powderfuse Port', 440, 67.6, 23.6, 16591, 79.34, 52.75, 1],
];
out += 'RX.Transports = {\n';
for (const t of T) out += `  {${lua(t[0])},${lua(t[1])},${a2u[t[2]]},${t[3]},${t[4]},${a2u[t[5]]},${t[6]},${t[7]}${t[8] ? ',true' : ''}},\n`;
out += '}\n';
fs.writeFileSync(process.argv[2], out);
console.log('flight masters', n, 'transports', T.length, T.map(t => a2u[t[2]] + '/' + a2u[t[5]]).join(' '));
