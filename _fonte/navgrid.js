// Gera a malha de navegação (Data/NavGrid_*.lua) a partir do terreno do WoW: Forever.
// Célula = meio chunk (16,67 jardas). Valor por célula (0..63):
//   1 = dá para ir para LESTE, 2 = SUL, 4 = SUDESTE, 8 = SUDOESTE (sem penhasco/rampa íngreme no caminho)
//   16 = estrada (textura de estrada/calçamento/trilha), 32 = água funda (nado)
// Uso: node navgrid.js <raw> <outDir> <kalimdor|azeroth> <contId>
const fs = require('fs'), path = require('path');
const [RAW, OUT, NAME, CONT] = process.argv.slice(2);
const TILE = 1600 / 3, CHUNK = TILE / 16, VSTEP = CHUNK / 8;
const MAXS = 1.1;        // inclinação máxima andável (dh / distância)
const DEEP = 1.6;        // água mais funda que isso = nado
const list = JSON.parse(fs.readFileSync(path.join(RAW, NAME + '_full.json'), 'utf8'));
const names = {};
for (const l of fs.readFileSync(path.join(RAW, 'tileset.csv'), 'utf8').split('\n')) { const i = l.indexOf(';'); names[+l.slice(0, i)] = l.slice(i + 1); }
const isRoad = n => { if (!n) return false; const b = n.split('/').pop(); return /road|cobble|street|flagstone|footprint|plaza/i.test(b) && !/roadside/i.test(b); };
function chunks(b, s = 0, e = b.length) { const out = []; let o = s; while (o + 8 <= e) { const n = b.slice(o, o + 4).toString('latin1').split('').reverse().join(''); const sz = b.readUInt32LE(o + 4); out.push([n, o + 8, sz]); o += 8 + sz; } return out; }

const H = new Map(), W = new Map(), R = new Map();
for (const [tx, ty, rootId, texId] of list) {
  const fr = path.join(RAW, rootId + '.bin');
  if (!fs.existsSync(fr)) continue;
  const b = fs.readFileSync(fr);
  const top = chunks(b);
  const h = new Float32Array(128 * 128).fill(NaN), w = new Float32Array(128 * 128).fill(NaN);
  const mcnks = top.filter(c => c[0] === 'MCNK');
  for (const mc of mcnks) {
    const hd = mc[1];
    const cx = b.readUInt32LE(hd + 4), cy = b.readUInt32LE(hd + 8), z = b.readFloatLE(hd + 0x70);
    const sub = chunks(b, hd + 128, mc[1] + mc[2]);
    const vt = sub.find(c => c[0] === 'MCVT'); if (!vt) continue;
    for (let r = 0; r < 8; r++) for (let c = 0; c < 8; c++) h[(cy * 8 + r) * 128 + cx * 8 + c] = z + b.readFloatLE(vt[1] + (r * 17 + c) * 4);
  }
  const mh = top.find(c => c[0] === 'MH2O');
  if (mh) {
    const base = mh[1];
    for (let ci = 0; ci < 256; ci++) {
      const oi = b.readUInt32LE(base + ci * 12), nl = b.readUInt32LE(base + ci * 12 + 4);
      if (!oi || !nl) continue;
      const cx = ci % 16, cy = Math.floor(ci / 16);
      for (let l = 0; l < nl; l++) {
        const o = base + oi + l * 24;
        if (o + 24 > b.length) break;
        const maxH = b.readFloatLE(o + 8), xo = b[o + 12], yo = b[o + 13], ww = b[o + 14], hh = b[o + 15], ob = b.readUInt32LE(o + 16);
        for (let yy = 0; yy < hh; yy++) for (let xx = 0; xx < ww; xx++) {
          if (ob) { const bit = yy * ww + xx; if (!(b[base + ob + (bit >> 3)] & (1 << (bit & 7)))) continue; }
          const qx = xo + xx, qy = yo + yy; if (qx > 7 || qy > 7) continue;
          const k = (cy * 8 + qy) * 128 + cx * 8 + qx;
          if (!(w[k] >= maxH)) w[k] = maxH;
        }
      }
    }
  }
  H.set(ty * 64 + tx, h); W.set(ty * 64 + tx, w);
  // estrada (tex0)
  const ft = path.join(RAW, texId + '.bin');
  const road = new Uint8Array(32 * 32);
  if (fs.existsSync(ft)) {
    const t = fs.readFileSync(ft), tt = chunks(t);
    const md = tt.find(c => c[0] === 'MDID');
    if (md) {
      const ids = []; for (let o = md[1]; o < md[1] + md[2]; o += 4) ids.push(t.readUInt32LE(o));
      const rset = new Set(); ids.forEach((id, i) => { if (isRoad(names[id])) rset.add(i); });
      if (rset.size) {
        tt.filter(c => c[0] === 'MCNK').forEach((mc, ci) => {
          const cx = ci % 16, cy = Math.floor(ci / 16);
          const sub = chunks(t, mc[1], mc[1] + mc[2]);
          const ly = sub.find(c => c[0] === 'MCLY'), al = sub.find(c => c[0] === 'MCAL');
          if (!ly) return;
          const cnt = new Uint16Array(4);       // 2x2 células por chunk: pixels de estrada
          for (let l = 0; l < ly[2] / 16; l++) {
            const o = ly[1] + l * 16, tid = t.readUInt32LE(o), fl = t.readUInt32LE(o + 4), ao = t.readUInt32LE(o + 8);
            if (!rset.has(tid)) continue;
            if (l === 0) { cnt.fill(1024); break; }
            if (!(fl & 0x100) || !al) continue;
            const a = new Uint8Array(4096);
            if (fl & 0x200) { let p = al[1] + ao, i = 0; while (i < 4096) { const c = t[p++]; const n = c & 0x7f; if (c & 0x80) { const v = t[p++]; for (let k = 0; k < n && i < 4096; k++) a[i++] = v; } else for (let k = 0; k < n && i < 4096; k++) a[i++] = t[p++]; } }
            else for (let i = 0; i < 4096; i++) a[i] = t[al[1] + ao + i];
            for (let py = 0; py < 64; py++) for (let px = 0; px < 64; px++) if (a[py * 64 + px] > 80) cnt[(py >> 5) * 2 + (px >> 5)]++;
          }
          for (let q = 0; q < 4; q++) if (cnt[q] >= 110) road[(cy * 2 + (q >> 1)) * 32 + cx * 2 + (q & 1)] = 1;   // >= 25% da célula
        });
      }
    }
  }
  R.set(ty * 64 + tx, road);
}
console.error(NAME, 'tiles com altura', H.size);

// altura e água em coordenadas globais de vértice (u = leste, v = sul)
function hAt(u, v) { const t = H.get((v >> 7) * 64 + (u >> 7)); return t ? t[(v & 127) * 128 + (u & 127)] : NaN; }
function wAt(u, v) { const t = W.get((v >> 7) * 64 + (u >> 7)); return t ? t[(v & 127) * 128 + (u & 127)] : NaN; }
function bil(fu, fv) {
  const u = Math.floor(fu), v = Math.floor(fv), a = fu - u, c = fv - v;
  const h00 = hAt(u, v), h10 = hAt(u + 1, v), h01 = hAt(u, v + 1), h11 = hAt(u + 1, v + 1);
  return (h00 * (1 - a) + h10 * a) * (1 - c) + (h01 * (1 - a) + h11 * a) * c;
}
function wet(fu, fv, h) { const s = wAt(Math.floor(fu), Math.floor(fv)); return s === s && s - h > DEEP; }
function canGo(gx, gy, dx, dy) {
  const u0 = gx * 4 + 2, v0 = gy * 4 + 2, u1 = u0 + dx * 4, v1 = v0 + dy * 4;
  const len = Math.hypot(dx, dy) * 4, n = Math.ceil(len * 2), step = len / n * VSTEP;
  let ph = bil(u0, v0); if (ph !== ph) return false;
  let pw = wet(u0, v0, ph);
  for (let k = 1; k <= n; k++) {
    const fu = u0 + (u1 - u0) * k / n, fv = v0 + (v1 - v0) * k / n;
    const h = bil(fu, fv); if (h !== h) return false;
    const ww = wet(fu, fv, h);
    if (!(pw && ww) && Math.abs(h - ph) / step > MAXS) return false;
    ph = h; pw = ww;
  }
  return true;
}
const ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&\'()*+,-';
const out = []; let cells = 0, roads = 0, blockedAll = 0, wetc = 0;
for (const key of [...H.keys()].sort((a, b) => a - b)) {
  const tx = key % 64, ty = Math.floor(key / 64), road = R.get(key);
  let s = '', run = 0, last = '';
  const flush = () => { if (run) { s += last + (run > 2 ? String(run) : (run === 2 ? last : '')); } };
  for (let cy = 0; cy < 32; cy++) for (let cx = 0; cx < 32; cx++) {
    const gx = tx * 32 + cx, gy = ty * 32 + cy;
    let v = 0;
    if (canGo(gx, gy, 1, 0)) v |= 1;
    if (canGo(gx, gy, 0, 1)) v |= 2;
    if (canGo(gx, gy, 1, 1)) v |= 4;
    if (canGo(gx, gy, -1, 1)) v |= 8;
    if (road[cy * 32 + cx]) { v |= 16; roads++; }
    const ch = bil(gx * 4 + 2, gy * 4 + 2); if (ch === ch && wet(gx * 4 + 2, gy * 4 + 2, ch)) { v |= 32; wetc++; }
    if (!(v & 15)) blockedAll++;
    cells++;
    const c = ALPHA[v];
    if (c === last) run++; else { flush(); last = c; run = 1; }
  }
  flush();
  out.push(`[${key}]="${s}"`);
}
const lua = `-- Malha de navegação gerada do terreno do WoW: Forever (_fonte/navgrid.js). Não editar.\nlocal _, RX = ...\nRX.NavData = RX.NavData or {}\nRX.NavData[${CONT}] = {\n${out.join(',\n')}\n}\n`;
fs.writeFileSync(path.join(OUT, `NavGrid_${NAME}.lua`), lua);
console.log(NAME, 'células', cells, 'estrada', roads, 'água', wetc, 'sem saída', blockedAll, 'KB', (lua.length / 1024).toFixed(0));
