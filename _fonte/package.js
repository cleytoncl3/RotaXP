// Monta o pacote do CurseForge: <saida>/RouteXP/ + <saida>/RouteXP-<versão>.zip
// Sem nada de GitHub nem do atualizador .bat (no CurseForge o app atualiza sozinho):
//  - fora: _fonte/, *.bat, README.md, RotaXP.toc + Legacy.lua (aviso do nome antigo), arquivos do git
//  - Dist.lua vira RX.DIST = "curseforge" (mensagens de atualização falam só do app)
//  - o RouteXP.toc perde a linha X-Website
// Uso (na pasta do addon): node _fonte/package.js <pasta de saída>
const fs = require('fs'), path = require('path'), { execSync } = require('child_process');
const OUT = path.resolve(process.argv[2] || 'dist');
const files = execSync('git ls-files', { encoding: 'utf8' }).split(/\r?\n/).filter(Boolean)
  .filter(f => !/^_fonte\//.test(f) && !/\.bat$/i.test(f) && !/^\.git/.test(f)
    && !['README.md', 'RotaXP.toc', 'Legacy.lua'].includes(f));
const dest = path.join(OUT, 'RouteXP');
fs.rmSync(dest, { recursive: true, force: true });
for (const f of files) {
  const to = path.join(dest, f);
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(f, to);
}
fs.writeFileSync(path.join(dest, 'Dist.lua'), [
  'local _, RX = ...',
  'RX.DIST = "curseforge"',
  'function RX:UpdateHow()',
  '    return RX.T("As atualizações chegam pelo app do CurseForge.", "Updates come through the CurseForge app.")',
  'end', ''].join('\n'));
const tocPath = path.join(dest, 'RouteXP.toc');
let toc = fs.readFileSync(tocPath, 'utf8').split(/\r?\n/).filter(l => !/^## X-Website:/.test(l)).join('\r\n');
fs.writeFileSync(tocPath, toc);
const version = (toc.match(/## Version: (\S+)/) || [])[1] || 'dev';
// nada de GitHub nem .bat no pacote
const bad = [];
for (const f of files) {
  const p = path.join(dest, f);
  if (!fs.existsSync(p) || /\.(tga|png|blp)$/i.test(f)) continue;
  const txt = fs.readFileSync(p, 'utf8');
  if (/github|Atualizar-RouteXP|\.bat\b/i.test(txt)) bad.push(f);
}
const zip = path.join(OUT, `RouteXP-${version}.zip`);
fs.rmSync(zip, { force: true });
execSync(`powershell -NoProfile -Command "Compress-Archive -Path '${dest}' -DestinationPath '${zip}'"`);
console.log(`${files.length} arquivos · ${zip}`);
if (bad.length) console.log('ATENÇÃO, citam GitHub/.bat fora do ramo do GitHub: ' + bad.join(', '));
