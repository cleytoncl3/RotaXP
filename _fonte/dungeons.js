// Gera Data/Dungeons.lua (mobs por nível de cada masmorra) e Data/Grind.lua (pontos de grind: grupos densos de mobs)
const fs = require('fs'); const d = require(__dirname + '/db.json'); const L = require(__dirname + '/l10n.json');
const a2u = {}; for (const m of fs.readFileSync(process.env.A2U, 'utf8').matchAll(/\[(\d+)\]\s*=\s*(\d+),/g)) if (!(m[1] in a2u)) a2u[m[1]] = +m[2];
const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
const src = fs.readFileSync(process.env.DUNG, 'utf8');
const RAIDS = /Molten Core|Onyxia|Blackwing|Zul'Gurub|Ahn'Qiraj|Naxxramas|Ruins of|Temple of|Utgarde|Nexus|Azjol|Drak|Gundrak|Halls|Violet|Oculus|Pinnacle|Culling|Trial|Forge|Pit of|Icecrown|Ulduar|Obsidian|Vault|Eye of|Karazhan|Gruul|Magtheridon|Serpentshrine|Tempest|Hyjal Summit|Black Temple|Sunwell|Scarlet Halls|Scholomance$|Scarlet Enclave|Deadmines|Stockade|Ragefire|Shadowfang|Blackfathom|Gnomeregan|Wailing|Razorfen Kraul|Hellfire|Blood Furnace|Shattered|Slave|Underbog|Steamvault|Mana-|Auchenai|Sethekk|Shadow Lab|Botanica|Mechanar|Arcatraz|Old Hillsbrad|Black Morass|Magisters|Ahn'kahet|Throne|Grim Batol|Lost City|Stonecore|Vortex|Bastion|Baradin|Firelands|End Time|Well of Eternity|Hour of Twilight|Dragon Soul|Zul'Aman|Blackrock Caverns/;
const dungeons = [];
for (const m of src.matchAll(/\[(\d+)\]\s*=\s*\{"([^"]+)",(\{[^}]*\}|nil),(\d+),\{\{(\d+),\s*([\d.]+),\s*([\d.]+)\}/g)) {
  const id = +m[1], name = m[2]; if (RAIDS.test(name)) continue;
  const alt = m[3] === 'nil' ? [] : m[3].replace(/[{}]/g, '').split(',').filter(Boolean).map(Number);
  dungeons.push({ id, name, areas: new Set([id, ...alt]), parent: +m[5], ex: +m[6], ey: +m[7] });
}
let out = '-- GERADO por dungeons.js (dados QuestieDB WoW Forever): mobs hostis por nível de cada masmorra\nlocal _, RX = ...\nRX.DungeonData = {\n';
const kept = [];
for (const dg of dungeons) {
  const by = {}; let total = 0; const lv = [];
  for (const [nid, n] of Object.entries(d.npcs)) {
    const fr = n[13] || ''; if (fr === 'H' || fr === 'AH' || fr === 'A') continue;
    const sp = n[7]; if (!sp) continue;
    let cnt = 0; for (const [z, pts] of Object.entries(sp)) if (dg.areas.has(+z)) cnt += pts.length;
    if (!cnt) continue;
    const lvl = Math.round(((n[4] || 0) + (n[5] || n[4] || 0)) / 2); if (lvl < 10 || lvl > 63) continue;
    const elite = [1, 2, 3].includes(n[6]);
    const k = lvl + (elite ? 'e' : 'n'); by[k] = (by[k] || 0) + cnt; total += cnt;
    for (let i = 0; i < cnt; i++) lv.push(lvl);
  }
  if (total < 15) continue;
  lv.sort((a, b) => a - b);
  const lo = lv[Math.floor(lv.length * 0.1)], hi = lv[Math.floor(lv.length * 0.9)];
  if (hi < 25) continue;
  const u = a2u[dg.parent];
  const mobs = Object.entries(by).map(([k, c]) => `{${parseInt(k)},${c},${k.endsWith('e') ? 1 : 0}}`).join(',');
  out += `  {id=${dg.id}, name=${lua(dg.name)}, map=${u || 0}, x=${dg.ex}, y=${dg.ey}, min=${lo}, max=${hi}, total=${total}, mobs={${mobs}}},\n`;
  kept.push(`${dg.name} ${lo}-${hi} (${total} mobs)`);
}
out += '}\n';
fs.writeFileSync(process.argv[2], out);
console.log('masmorras:', kept.length); console.log(kept.join('\n'));

// pontos de grind: para cada tipo de mob comum (não elite, hostil) nível 25-62 em zonas abertas, o grupo mais denso
let g = '-- GERADO por dungeons.js: pontos de grind (grupos densos de mobs comuns) por nível\nlocal _, RX = ...\nRX.GrindSpots = {\n'; let gn = 0;
for (const [nid, n] of Object.entries(d.npcs)) {
  const fr = n[13] || ''; if (fr === 'H' || fr === 'AH' || fr === 'A') continue;
  if (n[6] && n[6] !== 0) continue; // só comuns
  const lo = n[4] || 0, hi = n[5] || lo; if (lo < 25 || lo > 62) continue;
  if ((n[14] || '') !== '') continue; // NPCs com título geralmente não são mobs de grind
  const sp = n[7]; if (!sp) continue;
  for (const [z, pts] of Object.entries(sp)) {
    const u = a2u[z]; if (!u || !(u >= 1411 && u <= 1460 || u === 2548 || u === 2482 || u === 2652)) continue;
    if (pts.length < 8) continue;
    let best = null, bn = 0;
    for (const p of pts) { let c = 0; for (const q of pts) if (Math.hypot(p[0] - q[0], p[1] - q[1]) < 5) c++; if (c > bn) { bn = c; best = p; } }
    if (bn < 8) continue;
    const near = pts.filter(q => Math.hypot(best[0] - q[0], best[1] - q[1]) < 5);
    const cx = near.reduce((s, q) => s + q[0], 0) / near.length, cy = near.reduce((s, q) => s + q[1], 0) / near.length;
    g += `  {${u},${Math.round(cx * 10) / 10},${Math.round(cy * 10) / 10},${lo},${hi},${bn},${lua(n[1])}${L.npc[nid] ? ',' + lua(L.npc[nid]) : ''}},\n`; gn++;
  }
}
g += '}\n'; fs.writeFileSync(process.argv[3], g); console.log('pontos de grind:', gn);
