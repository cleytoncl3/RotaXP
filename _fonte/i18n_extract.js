// Extrai os textos em inglês das chamadas T("pt", "en") do código Lua (para a tradução em espanhol).
// Uso: node _fonte/i18n_extract.js <saida.json>
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const files = fs.readdirSync(ROOT).filter(f => f.endsWith('.lua'));

// lê uma string Lua ("..." ou '...') a partir de i; devolve [valor, fim] ou null
function readStr(src, i) {
  const q = src[i];
  if (q !== '"' && q !== "'") return null;
  let j = i + 1, out = '';
  while (j < src.length && src[j] !== q) {
    if (src[j] === '\\') { out += src[j] + src[j + 1]; j += 2; continue; }
    if (src[j] === '\n') return null;
    out += src[j++];
  }
  return [out, j + 1];
}
function skipWs(src, i) { while (i < src.length && /\s/.test(src[i])) i++; return i; }

const all = new Map();
for (const f of files) {
  const src = fs.readFileSync(path.join(ROOT, f), 'utf8');
  const re = /(?:(?<![\w.:])|(?<=\bRX\.))T\(/g;   // T( e RX.T(
  let m;
  while ((m = re.exec(src))) {
    let i = skipWs(src, m.index + 2);
    const a = readStr(src, i); if (!a) continue;
    i = skipWs(src, a[1]);
    if (src[i] !== ',') continue;
    i = skipWs(src, i + 1);
    const b = readStr(src, i); if (!b) continue;
    i = skipWs(src, b[1]);
    if (src[i] !== ')') continue;
    const en = b[0];
    if (!all.has(en)) all.set(en, { pt: a[0], files: new Set() });
    all.get(en).files.add(f);
  }
}
const out = {};
for (const [en, v] of all) out[en] = v.pt;
fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 1));
console.log('textos únicos', all.size, 'caracteres', [...all.keys()].join('').length);
