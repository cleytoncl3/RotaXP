// Gera guias COMPLETOS por zona a partir do QuestieDB (todas as quests da Horda do mapa),
// ordenados em "rodadas" (aceitar -> fazer -> entregar) respeitando cadeias de quests.
const fs = require('fs'); const path = require('path');
const S = __dirname;
const d = require(S + '/db.json');
const L10N = require(S + '/l10n.json');
const EN = require(S + '/en.js');
const den = s => { const e = EN.en(s); return e ? `, dEn=${lua(e)}` : ''; };
const OUT = process.argv[2];
const a2u = {};
for (const m of fs.readFileSync(process.env.A2U, 'utf8').matchAll(/\[(\d+)\]\s*=\s*(\d+),/g)) if (!(m[1] in a2u)) a2u[m[1]] = +m[2];

const H = (2n | 16n | 32n | 128n | 512n | (1n << 33n));
const horde = q => !q[6] || (BigInt(q[6]) & H) !== 0n;
const arr3 = f => !f ? {} : Array.isArray(f) ? { 1: f[0], 2: f[1], 3: f[2], 4: f[3], 5: f[4], 6: f[5] } : f;
const RS = {}, RE = {};
const push = (M, q, v) => (M[q] = M[q] || []).push(v);
for (const [id, n] of Object.entries(d.npcs)) { for (const q of (n[10] || [])) push(RS, q, ['n', +id]); for (const q of (n[11] || [])) push(RE, q, ['n', +id]); }
for (const [id, o] of Object.entries(d.objects)) { for (const q of (o[2] || [])) push(RS, q, ['o', +id]); for (const q of (o[3] || [])) push(RE, q, ['o', +id]); }
function givers(field, rev) {
  const a = arr3(field); const res = [];
  for (const id of (a[1] || [])) res.push(['n', id]);
  for (const id of (a[2] || [])) res.push(['o', id]);
  for (const id of (a[3] || [])) res.push(['i', id]);
  if (!res.length && rev) res.push(...rev);
  return res;
}
const ent = (k, id) => k === 'n' ? d.npcs[id] : d.objects[id];
const spawns = (k, id) => { const e = ent(k, id); return e ? ((k === 'n' ? e[7] : e[4]) || {}) : {}; };
function locIn(list, zone) {
  for (const [k, id] of list) {
    if (k === 'i') continue;
    const sp = spawns(k, id)[zone];
    if (sp && sp.length && sp[0][0] > 0) return { z: zone, x: sp[0][0], y: sp[0][1], id, k, name: ent(k, id)[1] };
  }
  return null;
}
function anyLoc(list) {
  for (const [k, id] of list) {
    if (k === 'i') continue;
    const sp = spawns(k, id); const z = Object.keys(sp)[0];
    if (z && sp[z][0] && sp[z][0][0] > 0) return { z: +z, x: sp[z][0][0], y: sp[z][0][1], id, k, name: ent(k, id)[1] };
  }
  return null;
}
function cluster(points, r = 6) {
  let best = null, bestN = -1;
  for (const p of points) { let n = 0; for (const q of points) if (Math.hypot(p[0] - q[0], p[1] - q[1]) < r) n++; if (n > bestN) { bestN = n; best = p; } }
  return best;
}
function objective(q, zone) {
  const o = arr3(q[10]);
  const ents = []; let elite = false, drops = 0, objOutside = false;
  const addN = id => { ents.push(['n', id]); const n = d.npcs[id]; if (n && [1, 2, 3].includes(n[6])) elite = true; };
  for (const c of (o[1] || [])) addN(c[0]);
  for (const c of (o[2] || [])) ents.push(['o', c[0]]);
  for (const c of (o[5] || [])) { if (Array.isArray(c[1])) c[1].forEach(addN); else addN(c[0]); }
  for (const c of (o[3] || [])) {
    const it = d.items[c[0]]; if (!it) continue;
    if (it[2] && it[2].length) { if (!(it[3] && it[3].length)) drops++; it[2].slice(0, 40).forEach(id => ents.push(['n', id])); }
    for (const id of (it[3] || []).slice(0, 40)) ents.push(['o', id]);
  }
  const inZone = [], other = {};
  for (const [k, id] of ents) for (const [z, pts] of Object.entries(spawns(k, id))) for (const p of pts) if (p[0] > 0) (+z === zone ? inZone : (other[z] = other[z] || [])).push(p);
  let loc = null;
  if (inZone.length) { const c = cluster(inZone); loc = { z: zone, x: c[0], y: c[1] }; }
  else if (ents.length) { let m = 0, zz = null; for (const [z, p] of Object.entries(other)) if (p.length > m) { m = p.length; zz = z; } if (zz) { const c = cluster(other[zz]); loc = { z: +zz, x: c[0], y: c[1] }; objOutside = true; } }
  return { loc, elite, drops, hasObj: ents.length > 0 };
}
// Um local por objetivo (cada mob/item/objeto), para a seta ir ao objetivo que ainda falta
function objectiveParts(q, zone) {
  const o = arr3(q[10]);
  const parts = [];
  const place = (ents) => {
    const inZone = [], other = {};
    for (const [k, id] of ents) for (const [z, pts] of Object.entries(spawns(k, id))) for (const p of pts) if (p[0] > 0) (+z === zone ? inZone : (other[z] = other[z] || [])).push(p);
    if (inZone.length) { const c = cluster(inZone); return { z: zone, x: c[0], y: c[1] }; }
    let m = 0, zz = null; for (const [z, p] of Object.entries(other)) if (p.length > m) { m = p.length; zz = z; }
    if (zz) { const c = cluster(other[zz]); return { z: +zz, x: c[0], y: c[1] }; }
    return null;
  };
  for (const c of (o[1] || [])) { const n = d.npcs[c[0]]; const l = place([['n', c[0]]]); if (n && l) parts.push({ n: n[1], p: L10N.npc[c[0]], ...l }); }
  for (const c of (o[5] || [])) { const ids = Array.isArray(c[1]) ? c[1] : [c[0]]; const n = d.npcs[ids[0]]; const l = place(ids.map(i => ['n', i])); if (n && l) parts.push({ n: n[1], p: L10N.npc[ids[0]], ...l }); }
  for (const c of (o[2] || [])) { const ob = d.objects[c[0]]; const l = place([['o', c[0]]]); if (ob && l) parts.push({ n: ob[1], ...l }); }
  for (const c of (o[3] || [])) {
    const it = d.items[c[0]]; if (!it) continue;
    const ents = (it[2] || []).slice(0, 40).map(i => ['n', i]).concat((it[3] || []).slice(0, 40).map(i => ['o', i]));
    const l = place(ents); if (l) parts.push({ n: it[1], p: L10N.item && L10N.item[c[0]], ...l });
  }
  return parts;
}

function collectCount(q, drops) {
  if (!drops) return 0;
  const nums = ((q[8] || []).join(' ').match(/\b\d+\b/g) || []).map(Number).filter(n => n > 1 && n < 100);
  return nums.length ? nums.reduce((a, b) => a + b, 0) : drops;
}
const BAD = /Writ|Legacy Reward|Conflict at|Battle for|the Elder$|Donation of|Tip the Scales|Commission|Scourgestones|Basic Care Package|Darkmoon|Sealed Crate|Sign Me Up|Learning to Ride|Your First Riding|Swift as the Wind|Library|Almanac|Mantle|Catalogue|Cryptstalker|Dread Citadel|Bone Fragments|Crypt Fiend|Dark Iron Scraps|Elemental Equation|Core of Elements|Binding the Dreadnaught|Bonescythe|Libram|Corrupted (Songflower|Windblossom|Whipper Root|Night Dragon)|Shipping Label|Economic Warfare|E'ko|Breastplate|Leggings|Legplates|Cap of the|Unstable Magic|Craftsman/;
const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ') + '"';
const r2 = n => Math.round(n * 100) / 100;

function buildZone(cfg) {
  const zone = cfg.area;
  const set = {};
  for (const [sid, q] of Object.entries(d.quests)) {
    const id = +sid;
    if (!horde(q) || q[7] || q[18] || q[31]) continue;
    if (q[24] && (q[24] & 1)) continue; // repetível
    if (BAD.test(q[1] || '')) continue;
    const lvl = q[5] || 0; if (lvl < cfg.lo || lvl > cfg.hi) continue;
    if ((q[4] || 0) > cfg.hi) continue;
    const gs = givers(q[2], RS[id]);
    let s = locIn(gs, zone); let approx = false;
    if (!s) { if (q[17] !== zone || gs.some(g => g[0] === 'i')) continue; approx = true; s = null; }
    const es = givers(q[3], RE[id]);
    const e = locIn(es, zone) || anyLoc(es);
    const ob = objective(q, zone);
    const flags = [];
    const cc = collectCount(q, ob.drops);
    if (cc >= 5) flags.push('coleta');
    if (cc >= 10) flags.push('drop');
    if (ob.elite) flags.push('elite');
    const txt = (q[8] || []).join(' ');
    if (/escort|Escolt|Lead .* (to|out)|Protect/i.test(txt)) flags.push('long', 'escolta');
    if (e && e.z !== zone) flags.push('long');
    if (ob.loc && ob.loc.z !== zone) { const dz = ob.loc.z; if (!a2u[dz] || a2u[dz] < 1400 || a2u[dz] > 1460) flags.push('dungeon'); else flags.push('long'); }
    set[id] = { approx, id, q, lvl, req: q[4] || 1, s, e, ob, flags: [...new Set(flags)], cc, xp: (L10N.xp[id] || [])[1] || 0 };
  }
  // pré-requisitos
  for (const x of Object.values(set)) {
    x.pre = (x.q[13] || []).filter(Boolean); x.preAll = (x.q[12] || []).filter(Boolean);
    x.ex = (x.q[16] || []).filter(Boolean);
  }
  const ids = Object.values(set);
  // "adiantar": outra quest da zona pede itens que caem dos MESMOS mobs desta
  const mobsOf = x => {
    const o = arr3(x.q[10]); const s = new Set();
    for (const c of (o[1] || [])) s.add(c[0]);
    for (const c of (o[5] || [])) (Array.isArray(c[1]) ? c[1] : [c[0]]).forEach(i => s.add(i));
    for (const c of (o[3] || [])) { const it = d.items[c[0]]; if (it && it[2]) it[2].forEach(i => s.add(i)); }
    return s;
  };
  for (const x of ids) {
    const mine = mobsOf(x); if (!mine.size) continue;
    x.ahead = [];
    for (const y of ids) {
      if (y === x || x.ahead.length >= 2 || Math.abs(y.lvl - x.lvl) > 4 || (x.ex || []).includes(y.id)) continue;
      const oy = arr3(y.q[10]);
      for (const c of (oy[3] || [])) {
        const it = d.items[c[0]]; if (!it || !it[2]) continue;
        if (it[2].some(n => mine.has(n))) {
          const nums = ((y.q[8] || []).join(' ').match(/\b\d+\b/g) || []).map(Number).filter(n => n > 0 && n < 100);
          x.ahead.push({ q: y.id, n: y.q[1], pn: (L10N.quest[y.id] || [])[0], i: it[1], ip: L10N.item && L10N.item[c[0]], c: nums[0] || 1, qi: it[12] === 12 });
          break;
        }
      }
    }
  }
  // quests de XP muito baixo comparado ao resto => opcional no speedrun
  const xps = ids.map(x => x.xp).filter(Boolean).sort((a, b) => a - b);
  const median = xps[Math.floor(xps.length / 2)] || 0;
  const hubPt = cfg.hub || cluster(ids.filter(x => x.s).map(x => [x.s.x, x.s.y]), 8) || [50, 50];
  for (const x of ids) if (!x.s) x.s = { z: zone, x: hubPt[0], y: hubPt[1] };
  for (const x of ids) if (!x.e && x.approx) x.e = { z: zone, x: hubPt[0], y: hubPt[1], approx: true };
  for (const x of ids) {
    if (x.xp && x.xp < median * 0.35) x.flags.push('opt');
    const far = x.ob.loc && x.ob.loc.z === zone ? Math.hypot(x.ob.loc.x - hubPt[0], x.ob.loc.y - hubPt[1]) : 0;
    if (far > 45 && x.xp < median) x.flags.push('opt');
  }
  // rodadas
  const done = new Set(); let pending = new Set(ids.map(x => x.id));
  const steps = []; let pos = hubPt;
  const tour = (items, getLoc) => {
    const left = items.slice(); const out = [];
    while (left.length) {
      let bi = 0, bd = 1e9;
      left.forEach((it, i) => { const l = getLoc(it); const dd = l ? Math.hypot(l.x - pos[0], l.y - pos[1]) : 500; if (dd < bd) { bd = dd; bi = i; } });
      const it = left.splice(bi, 1)[0]; const l = getLoc(it); if (l && l.z === undefined || (l && l.z === zone)) pos = [l.x, l.y];
      out.push(it);
    }
    return out;
  };
  const okPre = x => {
    const inSet = p => set[p] !== undefined;
    const single = x.pre.filter(inSet); const all = x.preAll.filter(inSet);
    if (single.length && !single.some(p => done.has(p))) return false;
    if (all.length && !all.every(p => done.has(p))) return false;
    return true;
  };
  let round = 0;
  while (pending.size && round < 80) {
    round++;
    let avail = [...pending].map(i => set[i]).filter(okPre);
    if (!avail.length) break;
    // progride por faixas de nível: só pega quests até 2 níveis acima da mais baixa disponível
    const tier = Math.min(...avail.map(x => Math.max(x.lvl, x.req)));
    avail = avail.filter(x => Math.max(x.lvl, x.req) <= tier + 2);
    // exclusivas: mantenha só a primeira de cada grupo
    for (const a of avail) for (const e of a.ex) if (pending.has(e) && avail.find(b => b.id === e)) { pending.delete(e); }
    const av = avail.filter(a => pending.has(a.id));
    for (const x of tour(av, x => x.s)) steps.push({ t: 'A', x });
    for (const x of tour(av.filter(x => x.ob.hasObj), x => x.ob.loc)) steps.push({ t: 'C', x });
    for (const x of tour(av, x => x.e && x.e.z === zone ? x.e : null)) steps.push({ t: 'T', x });
    av.forEach(x => { done.add(x.id); pending.delete(x.id); });
  }
  return { steps, set, hubPt, unreachable: pending.size };
}

const ZONES = JSON.parse(fs.readFileSync(S + '/zones.json', 'utf8'));
const REPORT = [];
const XPNEED = { 30: 47400, 31: 50800, 32: 54500, 33: 58600, 34: 62800, 35: 67100, 36: 71600, 37: 76100, 38: 80800, 39: 85700, 40: 90700, 41: 95800, 42: 101000, 43: 106300, 44: 111800, 45: 117500, 46: 123200, 47: 129100, 48: 135100, 49: 141200, 50: 147500, 51: 153900, 52: 160400, 53: 167100, 54: 173900, 55: 180800, 56: 187900, 57: 195000, 58: 202300, 59: 209800 };
for (const cfg of ZONES) {
  const { steps, set, unreachable } = buildZone(cfg);
  const mapId = a2u[cfg.area];
  let o = `-- GERADO por auto.js (todas as quests da Horda da zona, dados QuestieDB WoW Forever)\nlocal _, RX = ...\nRX:RegisterGuide({\n  id=${lua(cfg.id)}, name=${lua(cfg.name)}, min=${cfg.min}, max=${cfg.max}, kind="zona", map=${mapId || 0}, zone=${lua(cfg.zoneName)}${cfg.forever ? ', tag="forever"' : ''},\n  desc=${lua(cfg.desc)}, nameEn=${lua(EN.NAME(cfg.name))}${EN.en(cfg.desc) ? ', descEn=' + lua(EN.en(cfg.desc)) : ''},\n  steps={\n`;
  const pre = (cfg.intro || []).map(n => ({ raw: n }));
  for (const p of pre) o += `    {t="N", d=${lua(p.raw)}${den(p.raw)}},\n`;
  if (cfg.hubName) {
    const fp = 'Fale com o mestre de voo de ' + cfg.hubName + ' para liberar o voo.';
    o += `    {t="R", d=${lua(cfg.hubName)}},\n    {t="N", d=${lua(fp)}${den(fp)}},\n`;
  }
  let xpTotal = 0;
  for (const st of steps) {
    const x = st.x, q = x.q;
    const p = [`t="${st.t}"`, `q=${x.id}`, `n=${lua(q[1])}`];
    const pt = L10N.quest[x.id]; if (pt && pt[0]) p.push(`pn=${lua(pt[0])}`);
    p.push(`lvl=${x.lvl}`); if (x.req > 1) p.push(`req=${x.req}`);
    if (x.xp) p.push(`xp=${x.xp}`); if (x.cc) p.push(`cc=${x.cc}`);
    let loc = null;
    if (st.t === 'A') loc = { z: cfg.area, ...x.s };
    else if (st.t === 'T') loc = x.e;
    else loc = x.ob.loc;
    if (st.t !== 'C' && loc && loc.name) { p.push(`npc=${lua(loc.name)}`); const pn = loc.k === 'n' && L10N.npc[loc.id]; if (pn) p.push(`pnpc=${lua(pn)}`); }
    if (loc && loc.x !== undefined && a2u[loc.z]) { p.push(`m=${a2u[loc.z]}`, `x=${r2(loc.x)}`, `y=${r2(loc.y)}`); if ((st.t === 'A' && x.approx) || loc.approx) p.push('approx=1'); }
    if (st.t === 'C') {
      const ob = arr3(q[10]);
      const ot = (ob[3] && ob[3].length) ? 'i' : ((ob[1] && ob[1].length) || (ob[5] && ob[5].length)) ? 'k' : (ob[2] && ob[2].length) ? 'o' : 'e';
      p.push(`ot="${ot}"`);
      const parts = objectiveParts(q, cfg.area).filter(pp => a2u[pp.z]);
      if (x.ahead && x.ahead.length) p.push(`ahead={${x.ahead.map(a => `{q=${a.q}, n=${lua(a.n)}${a.pn ? ', pn=' + lua(a.pn) : ''}, i=${lua(a.i)}${a.ip ? ', ip=' + lua(a.ip) : ''}, c=${a.c}${a.qi ? ', qi=true' : ''}}`).join(',')}}`);
      if (parts.length > 1) p.push(`objs={${parts.map(pp => `{n=${lua(pp.n)}${pp.p ? ', p=' + lua(pp.p) : ''}, m=${a2u[pp.z]}, x=${r2(pp.x)}, y=${r2(pp.y)}}`).join(',')}}`);
    }
    if (st.t === 'C') { if (q[8]) p.push(`obj=${lua(q[8].join(' '))}`); if (pt && pt[1]) p.push(`pobj=${lua([].concat(pt[1]).join(' '))}`); }
    if (st.t === 'A') {
      if (x.pre.length) p.push(`pre={${x.pre.join(',')}}`);
      if (x.preAll.length) p.push(`preAll={${x.preAll.join(',')}}`);
      if (x.ex.length) p.push(`ex={${x.ex.join(',')}}`);
    }
    if (st.t === 'T') xpTotal += x.xp;
    if (x.flags.length) p.push(`f={${x.flags.map(lua).join(',')}}`);
    o += `    {${p.join(', ')}},\n`;
  }
  o += `    {t="L", lv=${cfg.max}, note=${lua('Se ainda não chegou no nível, mate mobs da zona ou faça a masmorra do seu nível.')}${EN.en('Se ainda não chegou no nível, mate mobs da zona ou faça a masmorra do seu nível.') ? ', noteEn=' + lua(EN.en('Se ainda não chegou no nível, mate mobs da zona ou faça a masmorra do seu nível.')) : ''}},\n  },\n})\n`;
  fs.writeFileSync(path.join(OUT, cfg.id + '.lua'), o);
  const tq = Object.values(set);
  const sumF = f => tq.filter(f).reduce((a, x) => a + x.xp, 0);
  let need = 0; for (let l = cfg.min; l < cfg.max; l++) need += XPNEED[l] || 0;
  REPORT.push(`${cfg.id.padEnd(22)} quests=${String(tq.length).padStart(3)} xp=${String(xpTotal).padStart(7)} duo=${String(sumF(x => !x.flags.includes('drop'))).padStart(7)} semColeta=${String(sumF(x => !x.flags.includes('coleta') && !x.flags.includes('drop'))).padStart(7)} speed=${String(sumF(x => !x.flags.includes('opt') && !x.flags.includes('long'))).padStart(7)} | XP p/ ${cfg.min}->${cfg.max}=${need} | inacess=${unreachable}`);
}
console.log(REPORT.join('\n'));
