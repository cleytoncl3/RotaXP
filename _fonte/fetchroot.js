// baixa os ADT raiz (altura + água) de todos os tiles dos continentes
const fs = require('fs'), path = require('path');
const RAW = process.argv[2];
const V = '&version=1.60.1.70938';
const chunks = b => { const out = []; let o = 0; while (o + 8 <= b.length) { const n = b.slice(o, o + 4).toString('latin1').split('').reverse().join(''); const sz = b.readUInt32LE(o + 4); out.push([n, o + 8, sz]); o += 8 + sz; } return out; };
async function dl(id) {
  const f = path.join(RAW, id + '.bin');
  if (fs.existsSync(f) && fs.statSync(f).size > 0) return true;
  for (let t = 0; t < 5; t++) {
    try { const r = await fetch(`https://wago.tools/api/casc/${id}?download${V}`); if (r.status === 200) { fs.writeFileSync(f, Buffer.from(await r.arrayBuffer())); return true; } if (r.status === 404) return false; } catch (e) { }
    await new Promise(r => setTimeout(r, 2000 * (t + 1)));
  }
  return false;
}
(async () => {
  for (const [wdt, name] of [[782779, 'kalimdor'], [775971, 'azeroth']]) {
    const w = fs.readFileSync(path.join(RAW, wdt + '.bin'));
    if (!fs.existsSync(path.join(RAW, name + '_tiles.json'))) throw 'sem tiles ' + name;
    const mo = chunks(w).find(c => c[0] === 'MAID')[1];
    const list = []; for (let i = 0; i < 4096; i++) { const root = w.readUInt32LE(mo + i * 32), tex = w.readUInt32LE(mo + i * 32 + 12); if (root) list.push([i % 64, i >> 6, root, tex]); }
    fs.writeFileSync(path.join(RAW, name + '_full.json'), JSON.stringify(list));
    const q = list.map(x => x[2]).concat(list.map(x => x[3]));
    let done = 0, fail = 0;
    await Promise.all(Array.from({ length: 6 }, async () => { while (q.length) { const id = q.shift(); if (!(await dl(id))) fail++; if (++done % 200 === 0) console.log(name, done, '/', list.length * 2); } }));
    console.log(name, 'ok, falhas', fail);
  }
})();
