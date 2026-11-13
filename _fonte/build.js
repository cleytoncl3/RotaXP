// Build RotaXP guide Lua files from DSL route files, resolving quest IDs and coordinates from QuestieDB data.
const fs = require('fs');
const path = require('path');
const S = __dirname;
const d = require(S + '/db.json');
const L10N = require(S + '/l10n.json');
const EN = require(S + '/en.js');
// quantos itens de DROP de mob a quest pede (0 = nenhum)
function collectCount(q) {
  let o = q[10]; if (!o) return 0;
  if (Array.isArray(o)) o = { 3: o[2] };
  let drops = 0;
  for (const c of (o[3] || [])) { const it = d.items[c[0]]; if (it && it[2] && it[2].length && !(it[3] && it[3].length)) drops++; }
  if (!drops) return 0;
  const nums = ((q[8] || []).join(' ').match(/\b\d+\b/g) || []).map(Number).filter(n => n > 1 && n < 100);
  return nums.length ? nums.reduce((a, b) => a + b, 0) : drops;
}
const OUT = process.argv[2];
const files = process.argv.slice(3);

const ZONES = {Orgrimmar:1637,ThousandNeedles:400,Ashenvale:331,Desolace:405,STV:33,Badlands:3,Swamp:8,Dustwallow:15,Hinterlands:47,Arathi:45,Tanaris:440,Feralas:357,Azshara:16,SearingGorge:51,BurningSteppes:46,BlastedLands:4,UnGoro:490,Felwood:361,Winterspring:618,Silithus:1377,WPL:28,EPL:139,Deadwind:41,Tirisfal:85,Undercity:1497,Hillsbrad:267,Alterac:36,Barrens:17,Stonetalon:406,Mulgore:215,ThunderBluff:1638,Durotar:14,Moonglade:493,Riverglades:16591,Hyjal:616,ShenDralas:16651,Duskwood:10,Wetlands:11};
// areaId -> uiMapId
const a2u = {};
const auSrc = fs.readFileSync(process.env.A2U, 'utf8');
for (const m of auSrc.matchAll(/\[(\d+)\]\s*=\s*(\d+),/g)) if (!(m[1] in a2u)) a2u[m[1]] = +m[2];

const H = (2n | 16n | 32n | 128n | 512n | (1n << 33n));
const horde = q => !q[6] || (BigInt(q[6]) & H) !== 0n;
const RS = {}, RE = {};
const push = (M, q, v) => (M[q] = M[q] || []).push(v);
for (const [id, n] of Object.entries(d.npcs)) { for (const q of (n[10] || [])) push(RS, q, ['n', +id]); for (const q of (n[11] || [])) push(RE, q, ['n', +id]); }
for (const [id, o] of Object.entries(d.objects)) { for (const q of (o[2] || [])) push(RS, q, ['o', +id]); for (const q of (o[3] || [])) push(RE, q, ['o', +id]); }
function givers(field, rev) {
  const res = [];
  if (field) {
    const a = Array.isArray(field) ? { 1: field[0], 2: field[1], 3: field[2] } : field;
    for (const id of (a[1] || [])) res.push(['n', id]);
    for (const id of (a[2] || [])) res.push(['o', id]);
    for (const id of (a[3] || [])) res.push(['i', id]);
  }
  if (!res.length && rev) res.push(...rev);
  return res;
}
function spawnsOf(kind, id) {
  const e = kind === 'n' ? d.npcs[id] : d.objects[id];
  if (!e) return null;
  return { name: e[1], sp: (kind === 'n' ? e[7] : e[4]) || {} };
}
function giverLoc(list, zoneHint) {
  let best = null;
  for (const [k, id] of list) {
    if (k === 'i') { const it = d.items[id]; best = best || { name: (it && it[1]) || ('item ' + id), item: id }; continue; }
    const s = spawnsOf(k, id); if (!s) continue;
    const zs = Object.keys(s.sp);
    let z = zs.find(z => +z === zoneHint) || zs[0];
    if (!z) { best = best || { name: s.name }; continue; }
    const c = s.sp[z][0];
    const cand = { name: s.name, z: +z, x: c[0], y: c[1], id };
    if (+z === zoneHint) return cand;
    if (!best || !best.z) best = cand;
  }
  return best;
}
function cluster(points) {
  if (!points.length) return null;
  let best = null, bestN = -1;
  for (const p of points) {
    let n = 0; for (const q of points) if (Math.hypot(p[0] - q[0], p[1] - q[1]) < 6) n++;
    if (n > bestN) { bestN = n; best = p; }
  }
  const near = points.filter(q => Math.hypot(best[0] - q[0], best[1] - q[1]) < 6);
  const x = near.reduce((s, q) => s + q[0], 0) / near.length, y = near.reduce((s, q) => s + q[1], 0) / near.length;
  // snap to nearest actual spawn so the arrow never points into a wall
  let snap = near[0], dmin = 1e9; for (const q of near) { const dd = Math.hypot(q[0] - x, q[1] - y); if (dd < dmin) { dmin = dd; snap = q; } }
  return [snap[0], snap[1]];
}
function objectiveLoc(q, zoneHint) {
  let o = q[10]; if (!o) return null;
  if (Array.isArray(o)) o = { 1: o[0], 2: o[1], 3: o[2], 4: o[3], 5: o[4], 6: o[5] };
  const ents = [];
  for (const c of (o[1] || [])) ents.push(['n', c[0]]);
  for (const c of (o[2] || [])) ents.push(['o', c[0]]);
  for (const c of (o[5] || [])) { if (Array.isArray(c[1])) for (const id of c[1]) ents.push(['n', id]); else ents.push(['n', c[0]]); }
  let dropItems = 0;
  for (const c of (o[3] || [])) {
    const it = d.items[c[0]]; if (!it) continue;
    if (it[2] && it[2].length) { dropItems++; for (const id of it[2].slice(0, 30)) ents.push(['n', id]); }
    for (const id of (it[3] || []).slice(0, 30)) ents.push(['o', id]);
  }
  const byZone = {};
  for (const [k, id] of ents) { const s = spawnsOf(k, id); if (!s) continue; for (const [z, pts] of Object.entries(s.sp)) for (const p of pts) if (p[0] > 0) (byZone[z] = byZone[z] || []).push(p); }
  let z = byZone[zoneHint] ? zoneHint : null;
  if (!z) { let m = 0; for (const [zz, pts] of Object.entries(byZone)) if (pts.length > m) { m = pts.length; z = +zz; } }
  if (!z) return { dropItems };
  const c = cluster(byZone[z]);
  return { z: +z, x: c[0], y: c[1], dropItems };
}
const byName = {};
for (const [id, q] of Object.entries(d.quests)) { const k = (q[1] || '').toLowerCase(); (byName[k] = byName[k] || []).push(+id); }

function resolve(name, forced, zoneHint, lo, hi, kind) {
  if (forced) return forced;
  const c = (byName[name.toLowerCase()] || []).filter(id => { const q = d.quests[id]; return horde(q) && !q[7] && !q[18]; });
  if (!c.length) return null;
  const inLvl = c.filter(id => { const l = d.quests[id][5] || 0; return l >= lo - 12 && l <= hi + 12; });
  const pool = inLvl.length ? inLvl : c;
  const zoneOf = id => { const q = d.quests[id]; const s = giverLoc(givers(q[2], RS[id]), zoneHint); const e = giverLoc(givers(q[3], RE[id]), zoneHint); return [s && s.z, e && e.z, q[17]]; };
  const zm = pool.filter(id => zoneOf(id).includes(zoneHint));
  const final = zm.length ? zm : pool;
  if (final.length > 1) warn(`ambiguous "${name}" -> ${final.join(',')} (using ${final[0]})`);
  return final[0];
}
let warnings = []; const REPORT = [];
const warn = m => warnings.push(m);
const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
const r2 = n => Math.round(n * 100) / 100;

for (const file of files) {
  let src = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  src = src.flatMap(l => {
    const m = /^#include\s+(\S+)/.exec(l.trim()); if (!m) return [l];
    return fs.readFileSync(path.join(path.dirname(file), m[1]), 'utf8').split(/\r?\n/).filter(x => !/^#(guide|desc|tag|route|source)\b/.test(x.trim()));
  });
  let g = { steps: [] }, zoneHint = 0, lo = 1, hi = 60, hub = null;
  for (let raw of src) {
    const line = raw.trim(); if (!line || line.startsWith('//')) continue;
    if (line.startsWith('#guide ')) { const [id, name, mn, mx, next] = line.slice(7).split('|').map(s => s.trim()); Object.assign(g, { id, name, min: +mn, max: +mx, next }); lo = +mn; hi = +mx; continue; }
    if (line.startsWith('#desc ')) { g.desc = line.slice(6); continue; }
    if (line.startsWith('#tag ')) { g.tag = line.slice(5); continue; }
    if (line.startsWith('#route ')) { g.route = line.slice(7); continue; }
    if (line.startsWith('#source ')) { g.source = line.slice(8); continue; }
    if (line.startsWith('#hub')) { const m = /([d.]+)s*,s*([d.]+)/.exec(line); hub = m ? [+m[1], +m[2]] : null; continue; }
    if (line.startsWith('@')) { hub = null; const z = line.slice(1).trim(); zoneHint = ZONES[z]; if (!zoneHint) warn('unknown zone ' + z); continue; }
    let note = ''; let body = line;
    const ni = body.indexOf(' -- '); if (ni >= 0) { note = body.slice(ni + 4).trim(); body = body.slice(0, ni).trim(); }
    const flags = []; body = body.replace(/\[(\w+)\]/g, (_, f) => { flags.push(f); return ''; }).trim();
    const t = body[0]; let arg = body.slice(1).trim();
    const step = { t };
    if ('ATC'.includes(t)) {
      let forced = null; const m = /#(\d+)$/.exec(arg); if (m) { forced = +m[1]; arg = arg.slice(0, m.index).trim(); }
      const id = resolve(arg, forced, zoneHint, lo, hi, t);
      if (!id) { warn(`${path.basename(file)}: quest not found "${arg}"`); step.n = arg; }
      else {
        const q = d.quests[id];
        if (q[1].toLowerCase() !== arg.toLowerCase()) warn(`name mismatch ${id}: "${arg}" vs "${q[1]}"`);
        step.q = id; step.n = q[1]; step.lvl = q[5];
        const pt = L10N.quest[id]; if (pt && pt[0]) step.pn = pt[0];
        const xp = L10N.xp[id]; if (xp) step.xp = xp[1];
        const cc = collectCount(q);
        if (cc >= 5 && !flags.includes('coleta')) flags.push('coleta');
        if (cc >= 10 && !flags.includes('drop')) flags.push('drop');
        if (cc) step.cc = cc;
        let loc = null;
        if (t === 'A') { loc = giverLoc(givers(q[2], RS[id]), zoneHint); if (loc && loc.item) { step.item = loc.item; note = note || 'Esta quest começa a partir de um item (drop).'; } }
        else if (t === 'T') loc = giverLoc(givers(q[3], RE[id]), zoneHint);
        else { loc = objectiveLoc(q, zoneHint); if (loc && loc.dropItems && /\b(\d+)\b/.test((q[8] || []).join(' '))) { const cnt = Math.max(...((q[8] || []).join(' ').match(/\b\d+\b/g) || ['0']).map(Number));  } }
        if (loc && loc.name && t !== 'C') { step.npc = loc.name; if (loc.id && L10N.npc[loc.id]) step.pnpc = L10N.npc[loc.id]; }
        if (t === 'C' && pt && pt[1]) step.pobj = [].concat(pt[1]).join(' ');
        if (loc && loc.z && a2u[loc.z]) { step.m = a2u[loc.z]; step.x = r2(loc.x); step.y = r2(loc.y); }
        else if (hub && t !== 'C' && a2u[zoneHint]) { step.m = a2u[zoneHint]; step.x = hub[0]; step.y = hub[1]; step.approx = 1; }
        else if (t !== 'A' || !step.item) warn(`no coords for ${t} ${id} ${q[1]}`);
        if (t === 'C' && q[8]) step.obj = q[8].join(' ');
      }
    } else if (t === 'G') {
      const m = /^([\d.]+)\s*,\s*([\d.]+)\s*(.*)$/.exec(arg);
      if (m) { step.m = a2u[zoneHint]; step.x = +m[1]; step.y = +m[2]; note = note || m[3]; } else note = note || arg;
    } else if (t === 'L') { const m = /^(\d+)\s*(.*)$/.exec(arg); step.lv = +m[1]; note = note || m[2]; }
    else if ('FHRNB'.includes(t)) { step.d = arg; }
    else { warn('bad line: ' + line); continue; }
    if (note) step.note = note;
    if (flags.length) step.f = flags;
    g.steps.push(step);
  }
  // emit
  let o = `-- GERADO por build.js a partir de ${path.basename(file)} (dados: QuestieDB WoW Forever). Pode editar à mão.\nlocal _, RX = ...\nRX:RegisterGuide({\n  id=${lua(g.id)}, name=${lua(g.name)}, min=${g.min}, max=${g.max}${g.next ? ', next=' + lua(g.next) : ''}${g.tag ? ', tag=' + lua(g.tag) : ''}${g.route ? ', route=' + lua(g.route) : ''}${g.source ? ', source=' + lua(g.source) : ''},\n  desc=${lua(g.desc || '')}, nameEn=${lua(EN.NAME(g.name))}${EN.en(g.desc) ? ', descEn=' + lua(EN.en(g.desc)) : ''},\n  steps={\n`;
  for (const s of g.steps) {
    if (s.note) s.noteEn = EN.en(s.note);
    if (s.t === 'N' && s.d) s.dEn = EN.en(s.d);
    const parts = [];
    for (const k of ['t', 'q', 'n', 'pn', 'lvl', 'xp', 'cc', 'npc', 'pnpc', 'item', 'm', 'x', 'y', 'approx', 'lv', 'd', 'dEn', 'note', 'noteEn', 'obj', 'pobj']) if (s[k] !== undefined) parts.push(`${k}=${typeof s[k] === 'number' ? s[k] : lua(s[k])}`);
    if (s.f) parts.push(`f={${s.f.map(lua).join(',')}}`);
    o += `    {${parts.join(', ')}},\n`;
  }
  o += '  },\n})\n';
  fs.writeFileSync(path.join(OUT, path.basename(file).replace(/\.txt$/, '.lua')), o);
  {
    const T = g.steps.filter(x => x.t === 'T' && x.q);
    const has = (x, f) => x.f && x.f.includes(f);
    const bColeta = new Set(g.steps.filter(x => x.q && (has(x, 'coleta') || has(x, 'drop'))).map(x => x.q));
    const bDrop = new Set(g.steps.filter(x => x.q && has(x, 'drop')).map(x => x.q));
    const sum = f => T.filter(f).reduce((a, x) => a + (x.xp || 0), 0);
    REPORT.push(`${g.id.padEnd(26)} passos=${String(g.steps.length).padStart(3)} entregas=${String(T.length).padStart(3)} xp=${String(sum(() => 1)).padStart(6)} (sem dado: ${T.filter(x => !x.xp).length}) | duo=${sum(x => !bDrop.has(x.q))} | semColeta=${sum(x => !bColeta.has(x.q))}`);
  }
}
console.log(REPORT.join('\n'));
if (EN.missing.size) console.log('SEM TRADUCAO:\n' + [...EN.missing].join('\n'));
if (warnings.length && process.env.WARN) console.log('WARNINGS:\n' + warnings.join('\n'));
