// Gera Data/QuestFix.lua a partir do banco do Questie (db.json):
// - RX.QuestStart[q] = itemID (quest começa com um item) ou 0 (início desconhecido no banco: não mandar para um ponto falso)
// - RX.QuestPvP[q]  = true (quests de campo de batalha: não são de leveling)
// Uso: node questfix.js <pasta RotaXP> <db.json>
const fs = require('fs'), path = require('path');
const RX = process.argv[2], DB = require(path.resolve(process.argv[3]));
const BG = new Set([3358, 3277, 2597, 3820]); // Bacia Arathi, Ravina Brado Guerreiro, Vale Alterac, Olho da Tormenta
const start = {}, pvp = {};
for (const f of fs.readdirSync(path.join(RX, 'Guides'))) {
  for (const line of fs.readFileSync(path.join(RX, 'Guides', f), 'utf8').split('\n')) {
    const m = line.match(/\{t="([ACT])", q=(\d+)/);
    if (!m) continue;
    const q = +m[2], d = DB.quests[q];
    if (!d) continue;
    if (BG.has(d['17'])) pvp[q] = true;
    if (m[1] !== 'A') continue;
    const st = d['2'] || [];
    const hasNpc = (st[0] || []).length + (st[1] || []).length > 0;
    const item = (st[2] || [])[0] || d['11'];
    if (!hasNpc && item) start[q] = item;
    else if (!hasNpc && /approx=1/.test(line)) start[q] = start[q] ?? 0;
  }
}
const lines = ['-- GERADO por _fonte/questfix.js (dados do Questie). Não editar à mão.', 'local _, RX = ...', '',
  '-- quest que começa com um item (itemID) ou com início desconhecido no banco (0)', 'RX.QuestStart = {'];
for (const q of Object.keys(start).sort((a, b) => a - b)) lines.push(`    [${q}] = ${start[q]},`);
lines.push('}', '', '-- quests de campo de batalha (fora do leveling)', 'RX.QuestPvP = {');
for (const q of Object.keys(pvp).sort((a, b) => a - b)) lines.push(`    [${q}] = true,`);
lines.push('}', '');
fs.writeFileSync(path.join(RX, 'Data/QuestFix.lua'), lines.join('\n'));
console.log('início por item/desconhecido: ' + Object.keys(start).length + ' · pvp: ' + Object.keys(pvp).length);
