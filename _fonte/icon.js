// Gera Media/icon.tga (64x64, 32 bits): ícone do addon.
// Disco azul-escuro, anel laranja, rota pontilhada subindo e seta dourada (subir de nível).
// Uso: node icon.js <pasta do addon>
const fs = require('fs'), path = require('path');
const OUT = path.join(process.argv[2] || '.', 'Media');
const N = 64, SS = 4;                      // tamanho e supersampling (bordas suaves)
const C = (N - 1) / 2;

function mix(a, b, t) { return a + (b - a) * t; }
function distSeg(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)));
  const x = ax + t * dx, y = ay + t * dy;
  return Math.hypot(px - x, py - y);
}
function inTri(px, py, a, b, c) {
  const s = (p, q, r) => (p[0] - r[0]) * (q[1] - r[1]) - (q[0] - r[0]) * (p[1] - r[1]);
  const P = [px, py], d1 = s(P, a, b), d2 = s(P, b, c), d3 = s(P, c, a);
  return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0));
}

// rota: curva de baixo-esquerda até a seta (pontos ao longo de uma bezier)
const P0 = [14, 50], P1 = [10, 30], P2 = [36, 48], P3 = [35, 29];
function bez(t) {
  const u = 1 - t;
  return [0, 1].map(i => u * u * u * P0[i] + 3 * u * u * t * P1[i] + 3 * u * t * t * P2[i] + t * t * t * P3[i]);
}
const dots = [];
for (const k of [0.3, 0.55, 0.8]) dots.push(bez(k));
// seta: corpo + ponta, apontando para cima-direita
const tip = [52, 11], A = [37.5, 14.5], B = [48.5, 25.5];          // triângulo da ponta
const shaftA = [44, 19], shaftB = [35.5, 27.5];

function sample(x, y) {
  const r = Math.hypot(x - C, y - C);
  let col = [0, 0, 0, 0];
  const over = (c) => { const a = c[3]; col = [mix(col[0], c[0], a), mix(col[1], c[1], a), mix(col[2], c[2], a), col[3] + a * (1 - col[3])]; };
  if (r <= 31) {
    // disco com gradiente (mais claro em cima)
    const g = Math.max(0, Math.min(1, (y + (C - r) * 0.2) / N));
    over([mix(0.13, 0.04, g), mix(0.20, 0.07, g), mix(0.34, 0.14, g), 1]);
  }
  if (r <= 31 && r >= 27) over([1.0, 0.50, 0.05, 1]);                 // anel laranja
  if (r <= 27 && r >= 25.8) over([0.55, 0.25, 0.02, 0.9]);            // sombra interna do anel
  if (r < 26) {
    for (const d of dots) if (Math.hypot(x - d[0], y - d[1]) <= 2.9) over([1.0, 0.86, 0.45, 1]);
    if (Math.hypot(x - P0[0], y - P0[1]) <= 4.3) over([0.35, 0.95, 0.35, 1]);   // ponto de partida (verde)
    if (distSeg(x, y, shaftA[0], shaftA[1], shaftB[0], shaftB[1]) <= 3.8) over([1.0, 0.78, 0.15, 1]);
    if (inTri(x, y, tip, A, B)) over([1.0, 0.78, 0.15, 1]);
  }
  return col;
}

const px = Buffer.alloc(N * N * 4);
for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
  let acc = [0, 0, 0, 0];
  for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
    const c = sample(x + (sx + 0.5) / SS - 0.5, y + (sy + 0.5) / SS - 0.5);
    acc = [acc[0] + c[0] * c[3], acc[1] + c[1] * c[3], acc[2] + c[2] * c[3], acc[3] + c[3]];
  }
  const a = acc[3] / (SS * SS);
  const i = (y * N + x) * 4;
  const div = acc[3] || 1;
  px[i] = Math.round(acc[2] / div * 255);      // B
  px[i + 1] = Math.round(acc[1] / div * 255);  // G
  px[i + 2] = Math.round(acc[0] / div * 255);  // R
  px[i + 3] = Math.round(a * 255);             // A
}
const head = Buffer.alloc(18);
head[2] = 2;                       // true-color, sem compressão
head.writeUInt16LE(N, 12); head.writeUInt16LE(N, 14);
head[16] = 32; head[17] = 0x28;    // 32 bits, 8 de alfa, origem no topo
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'icon.tga'), Buffer.concat([head, px]));
console.log('Media/icon.tga gerado');
