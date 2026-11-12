// Decode QuestieDB baked TOC metadata -> JSON (quests + npcs + objects)
const fs = require('fs');
const zlib = require('zlib');
const toc = process.argv[2];
const out = process.argv[3];
const lines = fs.readFileSync(toc, 'utf8').split(/\r?\n/);
const meta = new Map();
for (const l of lines) {
  if (!l.startsWith('## X-')) continue;
  const i = l.indexOf(':');
  meta.set(l.slice(3, i).trim(), l.slice(i + 1).trim());
}
function get(key) {
  let v = meta.get(key);
  if (v === undefined) return undefined;
  const m = /^~(\d+)~$/.exec(v);
  if (m) { let s = ''; for (let i = 1; i <= +m[1]; i++) s += meta.get(key + '-' + i); return s; }
  return v;
}
function cbor(buf) {
  let p = 0;
  function rd() {
    const ib = buf[p++]; const mt = ib >> 5; let ai = ib & 31; let val;
    const len = () => {
      if (ai < 24) return ai;
      if (ai === 24) return buf[p++];
      if (ai === 25) { const v = buf.readUInt16BE(p); p += 2; return v; }
      if (ai === 26) { const v = buf.readUInt32BE(p); p += 4; return v; }
      if (ai === 27) { const v = Number(buf.readBigUInt64BE(p)); p += 8; return v; }
      throw new Error('ai ' + ai);
    };
    switch (mt) {
      case 0: return len();
      case 1: return -1 - len();
      case 2: { const n = len(); const b = buf.slice(p, p + n); p += n; return b.toString('utf8'); }
      case 3: { const n = len(); const s = buf.slice(p, p + n).toString('utf8'); p += n; return s; }
      case 4: { const n = len(); const a = []; for (let i = 0; i < n; i++) a.push(rd()); return a; }
      case 5: { const n = len(); const o = {}; for (let i = 0; i < n; i++) { const k = rd(); o[k] = rd(); } return o; }
      case 6: { len(); return rd(); }
      case 7: {
        if (ai === 20) return false; if (ai === 21) return true; if (ai === 22 || ai === 23) return null;
        if (ai === 25) { const h = buf.readUInt16BE(p); p += 2; const s = h & 0x8000 ? -1 : 1, e = (h >> 10) & 31, f = h & 1023; return s * (e === 0 ? f * 2 ** -24 : 2 ** (e - 15) * (1 + f / 1024)); }
        if (ai === 26) { const v = buf.readFloatBE(p); p += 4; return v; }
        if (ai === 27) { const v = buf.readDoubleBE(p); p += 8; return v; }
        throw new Error('simple ' + ai);
      }
    }
  }
  return rd();
}
const b64 = s => Buffer.from(s, 'base64');
function ids(prefix) {
  const raw = b64(get('X-' + prefix + 'IDS'));
  let dec; try { dec = zlib.inflateSync(raw); } catch (e) { dec = zlib.inflateRawSync(raw); }
  return cbor(dec);
}
// cbor arrays from lua are 1-based maps or arrays; normalize
function entity(prefix, fieldCount, types) {
  const res = {};
  for (const id of ids(prefix)) {
    const sRaw = get('X-' + prefix + id + '-S');
    const row = sRaw ? cbor(b64(sRaw)) : {};
    const o = {};
    for (let f = 1; f <= fieldCount; f++) {
      if (types[f] === 'table') {
        const t = get('X-' + prefix + id + '-' + f);
        if (t) o[f] = cbor(b64(t));
      } else if (row[f] !== undefined) o[f] = row[f];
    }
    res[id] = o;
  }
  return res;
}
const qT = {2:'table',3:'table',8:'table',9:'table',10:'table',12:'table',13:'table',14:'table',15:'table',16:'table',18:'table',19:'table',20:'table',21:'table',26:'table',28:'table',29:'table',35:'table'};
const nT = {7:'table',8:'table',10:'table',11:'table'};
const quests = entity('Quest-', 36, qT);
const npcs = entity('Npc-', 15, nT);
let objects = {};
try { objects = entity('Object-', 6, {2:'table',3:'table',4:'table'}); } catch (e) { console.error('obj', e.message); }
const items = entity('Item-', 16, {2:'table',3:'table',4:'table',6:'table',14:'table',15:'table'}); const slim={}; for(const [k,v] of Object.entries(items)){ if(v[2]||v[3]) slim[k]={1:v[1],2:v[2],3:v[3],12:v[12],7:v[7]}; } fs.writeFileSync(out, JSON.stringify({ quests, npcs, objects, items:slim }));
console.log('quests', Object.keys(quests).length, 'npcs', Object.keys(npcs).length, 'objects', Object.keys(objects).length);
