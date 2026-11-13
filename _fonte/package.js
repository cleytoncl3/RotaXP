// Monta o pacote do addon: <saida>/RouteXP/ + <saida>/RouteXP-<versão>[-github].zip
// O zip tem sempre a pasta RouteXP na raiz (o jogo exige que a pasta tenha o nome do .toc)
// e caminhos com "/" (o Compress-Archive do Windows grava "\", que outros programas leem errado).
//
//  node _fonte/package.js <saída>            -> CurseForge: sem nada de GitHub nem do .bat
//      fora: _fonte/, *.bat, README.md, RotaXP.toc + Legacy.lua, arquivos do git
//      Dist.lua vira RX.DIST = "curseforge"; o RouteXP.toc perde a linha X-Website
//  node _fonte/package.js <saída> --github   -> RouteXP.zip para a página de Releases do GitHub
//      leva o README e o Atualizar-RouteXP.bat; fora: _fonte/, RotaXP.toc + Legacy.lua
// Uso: na pasta do addon.
const fs = require('fs'), path = require('path'), { execSync } = require('child_process');
const OUT = path.resolve(process.argv[2] || 'dist');
const GITHUB = process.argv.includes('--github');
const files = execSync('git ls-files', { encoding: 'utf8' }).split(/\r?\n/).filter(Boolean)
  .filter(f => !/^_fonte\//.test(f) && !/^\.git/.test(f) && !['RotaXP.toc', 'Legacy.lua'].includes(f))
  .filter(f => GITHUB || (!/\.bat$/i.test(f) && f !== 'README.md'));
const dest = path.join(OUT, 'RouteXP');
fs.rmSync(dest, { recursive: true, force: true });
for (const f of files) {
  const to = path.join(dest, f);
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(f, to);
}
const tocPath = path.join(dest, 'RouteXP.toc');
let toc = fs.readFileSync(tocPath, 'utf8');
if (!GITHUB) {
  fs.writeFileSync(path.join(dest, 'Dist.lua'), [
    'local _, RX = ...',
    'RX.DIST = "curseforge"',
    'function RX:UpdateHow()',
    '    return RX.T("As atualizações chegam pelo app do CurseForge.", "Updates come through the CurseForge app.")',
    'end', ''].join('\n'));
  toc = toc.split(/\r?\n/).filter(l => !/^## X-Website:/.test(l)).join('\r\n');
  fs.writeFileSync(tocPath, toc);
}
const version = (toc.match(/## Version: (\S+)/) || [])[1] || 'dev';
// CurseForge: nada de GitHub nem .bat no pacote
const bad = [];
if (!GITHUB) for (const f of files) {
  const p = path.join(dest, f);
  if (!fs.existsSync(p) || /\.(tga|png|blp)$/i.test(f)) continue;
  if (/github|Atualizar-RouteXP|\.bat\b/i.test(fs.readFileSync(p, 'utf8'))) bad.push(f);
}
// zip com "/" nos caminhos e a pasta RouteXP na raiz
const zip = path.join(OUT, GITHUB ? 'RouteXP.zip' : `RouteXP-${version}.zip`);   // GitHub: sempre RouteXP.zip (link direto ./releases/latest/download/RouteXP.zip)
fs.rmSync(zip, { force: true });
const ps1 = path.join(OUT, 'make-zip.ps1');
fs.writeFileSync(ps1, [
  'param([string]$src, [string]$out)',
  'Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem',
  "$zip = [System.IO.Compression.ZipFile]::Open($out, 'Create')",
  'Get-ChildItem -LiteralPath $src -Recurse -File | ForEach-Object {',
  "  $rel = 'RouteXP/' + $_.FullName.Substring($src.Length + 1).Replace([string][char]92, '/')",
  '  [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel)',
  '}',
  '$zip.Dispose()', ''].join('\r\n'));
execSync(`powershell -NoProfile -ExecutionPolicy Bypass -File "${ps1}" -src "${dest}" -out "${zip}"`);
fs.rmSync(ps1, { force: true });
console.log(`${files.length} arquivos · ${zip}`);
if (bad.length) console.log('ATENÇÃO, citam GitHub/.bat: ' + bad.join(', '));
