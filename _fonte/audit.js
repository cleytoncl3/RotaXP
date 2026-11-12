// Auditoria dos guias contra o banco do Questie (db.json):
// - NPC/objeto de aceitar e entregar estão entre os starters/enders da quest?
// - pré-requisitos: o "Entregar" do pré-requisito vem antes do "Aceitar" no mesmo guia?
// - quest exclusiva com outra (exclusiveTo) aparecendo junto no guia?
// - raça/classe exclusiva de Aliança?
const fs = require('fs'), path = require('path');
const DB = require(path.resolve(process.argv[2]));
const GD = process.argv[3];
const only = process.argv[4];
function parseSteps(txt) {
  const steps = [];
  for (const line of txt.split('\n')) {
    const m = line.match(/^\s*\{t="([A-Z])", q=(\d+), n="((?:[^"\\]|\\.)*)"/);
    if (!m) continue;
    const npc = (line.match(/ npc="((?:[^"\\]|\\.)*)"/) || [])[1];
    steps.push({ t: m[1], q: +m[2], n: m[3], npc });
  }
  return steps;
}
const npcName = id => DB.npcs[id] && DB.npcs[id]['1'];
const objName = id => DB.objects[id] && DB.objects[id]['1'];
function who(field) {
  const out = [];
  if (!field) return out;
  for (const id of (field[0] || [])) out.push(npcName(id));
  for (const id of (field[1] || [])) out.push(objName(id));
  for (const id of (field[2] || [])) out.push('item:' + id);
  return out.filter(Boolean);
}
let issues = 0;
for (const f of fs.readdirSync(GD).filter(f => f.endsWith('.lua') && (!only || f.includes(only)))) {
  const steps = parseSteps(fs.readFileSync(path.join(GD, f), 'utf8'));
  const pos = {};
  steps.forEach((s, i) => { pos[s.t + s.q] = pos[s.t + s.q] ?? i; });
  const list = [];
  for (const [i, s] of steps.entries()) {
    const d = DB.quests[s.q];
    if (!d) { list.push(`  q${s.q} "${s.n}": NÃO existe no banco`); continue; }
    if (d['1'] !== s.n) list.push(`  q${s.q}: nome no guia "${s.n}" ≠ banco "${d['1']}"`);
    if (s.t === 'A' && s.npc) {
      const st = who(d['2']);
      if (st.length && !st.includes(s.npc) && s.npc !== 'WANTED!') list.push(`  A q${s.q} "${s.n}": guia diz NPC "${s.npc}", banco diz ${JSON.stringify(st)}`);
    }
    if (s.t === 'T' && s.npc) {
      const en = who(d['3']);
      if (en.length && !en.includes(s.npc)) list.push(`  T q${s.q} "${s.n}": guia diz NPC "${s.npc}", banco diz ${JSON.stringify(en)}`);
    }
    if (s.t === 'A') {
      const pre = [...(d['12'] || []), ...(d['13'] || [])];
      for (const p of pre) {
        const tp = pos['T' + p];
        if (tp !== undefined && tp > i) list.push(`  ORDEM: aceitar q${s.q} "${s.n}" (passo ${i + 1}) antes de entregar o pré-requisito q${p} "${DB.quests[p] ? DB.quests[p]['1'] : '?'}" (passo ${tp + 1})`);
      }
      for (const x of (d['16'] || [])) if (pos['A' + x] !== undefined) list.push(`  EXCLUSIVAS: q${s.q} "${s.n}" e q${x} "${DB.quests[x] ? DB.quests[x]['1'] : '?'}" (só dá para fazer uma)`);
      const races = d['6'];
      if (races && races !== 0 && (races & 434) === 0 && (races & 77) !== 0) list.push(`  RAÇA: q${s.q} "${s.n}" é só da Aliança (races=${races})`);
    }
  }
  if (list.length) { console.log(`== ${f} (${list.length})`); console.log(list.join('\n')); issues += list.length; }
}
console.log('total de problemas: ' + issues);
