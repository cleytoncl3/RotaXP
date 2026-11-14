// node viz.js <NavGrid.lua> <out.png> ax ay bx by [pad]
// desenha a malha (verde = andável, preto = penhasco, amarelo = estrada, azul = água) e a rota A* (vermelho)
const fs = require('fs'), zlib = require('zlib');
const [file, outPng, ...nums] = process.argv.slice(2);
const [ax, ay, bx, by, padArg] = nums.map(Number);
const TILE = 1600 / 3, CELL = TILE / 32, ORIG = 32 * TILE;
const ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&'()*+,-";
const src = fs.readFileSync(file, 'utf8');
const tiles = {};
for (const m of src.matchAll(/\[(\d+)\]="([^"]*)"/g)) tiles[+m[1]] = m[2];
const dec = {};
function decode(s) { const t = []; let i = 0; while (i < s.length) { const v = ALPHA.indexOf(s[i++]); let j = i; while (j < s.length && s[j] >= '0' && s[j] <= '9') j++; const run = j > i ? +s.slice(i, j) : 1; i = j; for (let k = 0; k < run; k++) t.push(v); } return t; }
function val(gx, gy) { if (gx < 0 || gy < 0 || gx >= 2048 || gy >= 2048) return null; const tk = (gy >> 5) * 64 + (gx >> 5); if (!(tk in dec)) dec[tk] = tiles[tk] ? decode(tiles[tk]) : null; const t = dec[tk]; return t ? t[(gy & 31) * 32 + (gx & 31)] : null; }
const has = (v, b) => v != null && (v & b) !== 0;
function can(gx, gy, dx, dy) {
  if (dy === 0) return dx === 1 ? has(val(gx, gy), 1) : has(val(gx - 1, gy), 1);
  if (dx === 0) return dy === 1 ? has(val(gx, gy), 2) : has(val(gx, gy - 1), 2);
  if (dx === dy) return dx === 1 ? has(val(gx, gy), 4) : has(val(gx - 1, gy - 1), 4);
  return dx === -1 ? has(val(gx, gy), 8) : has(val(gx + 1, gy - 1), 8);
}
const cost = v => v == null ? 1 : (v & 32) ? 5 : (v & 16) ? 0.5 : 1;
const toCell = (wx, wy) => [Math.floor((ORIG - wy) / CELL), Math.floor((ORIG - wx) / CELL)];
const [sx, sy] = toCell(ax, ay), [ex, ey] = toCell(bx, by);
// A* (mesmo do addon)
const DIRS = [[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [1, 1, 1.4142], [-1, -1, 1.4142], [-1, 1, 1.4142], [1, -1, 1.4142]];
const oct = (x, y) => { const dx = Math.abs(x - ex), dy = Math.abs(y - ey); return dx > dy ? dx + 0.4142 * dy : dy + 0.4142 * dx; };
const g = new Map(), came = new Map(), closed = new Set(); const heap = [];
const push = (k, f) => { heap.push([f, k]); let i = heap.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (heap[p][0] <= heap[i][0]) break; [heap[p], heap[i]] = [heap[i], heap[p]]; i = p; } };
const pop = () => { const top = heap[0]; const last = heap.pop(); if (heap.length) { heap[0] = last; let i = 0; for (;;) { let c = 2 * i + 1; if (c >= heap.length) break; if (c + 1 < heap.length && heap[c + 1][0] < heap[c][0]) c++; if (heap[c][0] >= heap[i][0]) break; [heap[c], heap[i]] = [heap[i], heap[c]]; i = c; } } return top; };
const K = (x, y) => y * 4096 + x;
g.set(K(sx, sy), 0); push(K(sx, sy), 0);
let exp = 0, found = false;
while (heap.length && exp < 70000) {
  const [, cur] = pop(); if (cur === K(ex, ey)) { found = true; break; }
  if (closed.has(cur)) continue; closed.add(cur); exp++;
  const cx = cur % 4096, cy = Math.floor(cur / 4096), gc = g.get(cur), cc = cost(val(cx, cy));
  for (const [dx, dy, l] of DIRS) { const nx = cx + dx, ny = cy + dy, nk = K(nx, ny); if (closed.has(nk) || !can(cx, cy, dx, dy)) continue; const ng = gc + l * (cc + cost(val(nx, ny))) / 2; if (!g.has(nk) || ng < g.get(nk)) { g.set(nk, ng); came.set(nk, cur); push(nk, ng + oct(nx, ny) * 0.75); } }
}
const path = []; if (found) { let k = K(ex, ey); while (k !== undefined) { path.push([k % 4096, Math.floor(k / 4096)]); k = came.get(k); } }
const direct = Math.hypot(ax - bx, ay - by);
let plen = 0; for (let i = 1; i < path.length; i++) plen += Math.hypot(path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]) * CELL;
let onRoad = 0; for (const [x, y] of path) if (has(val(x, y), 16)) onRoad++;
console.log(JSON.stringify({ found, expanded: exp, cells: path.length, direto_jd: Math.round(direct), caminho_jd: Math.round(plen), naEstrada: path.length ? Math.round(100 * onRoad / path.length) + '%' : '-' }));
// imagem
const pad = padArg || 25;
const x0 = Math.min(sx, ex) - pad, x1 = Math.max(sx, ex) + pad, y0 = Math.min(sy, ey) - pad, y1 = Math.max(sy, ey) + pad;
const S = Math.max(1, Math.floor(900 / Math.max(x1 - x0, y1 - y0)));
const Wd = (x1 - x0 + 1) * S, Ht = (y1 - y0 + 1) * S;
const px = Buffer.alloc(Wd * Ht * 3);
const put = (x, y, c) => { for (let a = 0; a < S; a++) for (let b = 0; b < S; b++) { const o = (((y - y0) * S + a) * Wd + (x - x0) * S + b) * 3; px[o] = c[0]; px[o + 1] = c[1]; px[o + 2] = c[2]; } };
for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
  const v = val(x, y);
  let c;
  if (v == null) c = [40, 40, 60];
  else {
    let open = 0; for (const [dx, dy] of DIRS) if (can(x, y, dx, dy)) open++;
    if (v & 32) c = [60, 110, 200];
    else if (v & 16) c = [230, 200, 90];
    else c = [30 + open * 18, 70 + open * 18, 30 + open * 6];
    if (open <= 2) c = [15, 15, 15];
  }
  put(x, y, c);
}
for (const [x, y] of path) put(x, y, [255, 30, 30]);
put(sx, sy, [255, 255, 255]); put(ex, ey, [255, 0, 255]);
// PNG
const raw = Buffer.alloc((Wd * 3 + 1) * Ht); for (let y = 0; y < Ht; y++) { raw[y * (Wd * 3 + 1)] = 0; px.copy(raw, y * (Wd * 3 + 1) + 1, y * Wd * 3, (y + 1) * Wd * 3); }
const crcT = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crcT[n] = c >>> 0; }
const crc = b => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
const ih = Buffer.alloc(13); ih.writeUInt32BE(Wd, 0); ih.writeUInt32BE(Ht, 4); ih[8] = 8; ih[9] = 2;
fs.writeFileSync(outPng, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
