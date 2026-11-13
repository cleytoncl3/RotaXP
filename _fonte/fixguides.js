// Correções cirúrgicas nos guias de rota (Guides/h*.lua), sem reconstruir:
//  1) cc = total de itens de DROP que a quest pede (o build antigo contava só os TIPOS de item, por um erro de regex)
//  2) ordem: o "Aceitar" de uma continuação vai para logo depois do "Entregar" da quest anterior
// Uso: node fixguides.js <pasta RotaXP> <db.json>
const fs = require('fs'), path = require('path');
const RX = process.argv[2], d = require(path.resolve(process.argv[3]));

function collectCount(q) {
  let o = q[10]; if (!o) return 0;
  if (Array.isArray(o)) o = { 3: o[2] };
  let drops = 0;
  for (const c of (o[3] || [])) { const it = d.items[c[0]]; if (it && it[2] && it[2].length && !(it[3] && it[3].length)) drops++; }
  if (!drops) return 0;
  const nums = ((q[8] || []).join(' ').match(/\d+/g) || []).map(Number).filter(n => n > 1 && n < 100);
  return nums.length ? nums.reduce((a, b) => a + b, 0) : drops;
}
const prereqs = q => { const e = d.quests[q]; if (!e) return []; return [...(e[12] || []), ...(e[13] || [])].map(Math.abs); };

let ccFix = 0, moved = 0, skipped = [];
for (const f of fs.readdirSync(path.join(RX, 'Guides')).filter(f => /^h\d/.test(f))) {
  const file = path.join(RX, 'Guides', f);
  const nl = fs.readFileSync(file, 'utf8').includes('\r\n') ? '\r\n' : '\n';
  let lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  // 1) cc
  lines = lines.map(l => {
    const m = l.match(/\bq=(\d+)\b/);
    if (!m || !/\bcc=\d+/.test(l)) return l;
    const q = d.quests[m[1]]; if (!q) return l;
    const n = collectCount(q);
    if (n > 0 && !l.includes('cc=' + n + ',')) { ccFix++; return l.replace(/\bcc=\d+/, 'cc=' + n); }
    return l;
  });
  // 2) ordem
  const stepOf = (l) => { const m = l.match(/\{t="([A-Z])", q=(\d+)\b/); return m ? { t: m[1], q: +m[2] } : null; };
  let changed = true, guard = 0;
  while (changed && guard++ < 50) {
    changed = false;
    for (let i = 0; i < lines.length; i++) {
      const s = stepOf(lines[i]); if (!s || s.t !== 'A') continue;
      for (const p of prereqs(s.q)) {
        const ti = lines.findIndex(l => { const x = stepOf(l); return x && x.t === 'T' && x.q === p; });
        if (ti > i) {
          // C/T da própria quest antes do novo lugar? então não dá para mover só o "Aceitar"
          const own = lines.slice(i + 1, ti + 1).some(l => { const x = stepOf(l); return x && x.q === s.q; });
          if (own) { skipped.push(`${f}: q${s.q} depende de q${p}`); continue; }
          const [line] = lines.splice(i, 1);
          lines.splice(ti, 0, line);          // ti já desceu uma posição: fica logo depois do "Entregar"
          moved++; changed = true; break;
        }
      }
      if (changed) break;
    }
  }
  fs.writeFileSync(file, lines.join(nl));
}
console.log(`cc corrigido: ${ccFix} linhas · "Aceitar" movidos: ${moved}`);
if (skipped.length) console.log('não movidos (a quest já é feita antes da anterior no guia):\n  ' + [...new Set(skipped)].join('\n  '));
