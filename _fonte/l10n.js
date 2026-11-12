// decode ptBR names (quests + npcs) and quest XP into separate json
const fs=require('fs'),zlib=require('zlib');
const toc=process.argv[2], xpdir=process.argv[3];
const meta=new Map();
for(const l of fs.readFileSync(toc,'utf8').split(/\r?\n/)){ if(!l.startsWith('## X-'))continue; const i=l.indexOf(':'); meta.set(l.slice(3,i).trim(), l.slice(i+1).trim()); }
function get(k){let v=meta.get(k); if(v===undefined)return; const m=/^~(\d+)~$/.exec(v); if(m){let s='';for(let i=1;i<=+m[1];i++)s+=meta.get(k+'-'+i);return s;} return v;}
eval(fs.readFileSync(__dirname+'/decode.js','utf8').match(/function cbor[\s\S]*?\n}\n/)[0]);
const inflate=b=>{try{return zlib.inflateSync(b)}catch(e){return zlib.inflateRawSync(b)}};
const blk=k=>cbor(inflate(Buffer.from(get(k),'base64')));
const at=(col,pos)=>Array.isArray(col)?col[pos-1]:col[pos];
const out={quest:{},npc:{},item:{},xp:{}};
for(const [type,key] of [['Quest','quest'],['Npc','npc'],['Item','item']]){
  const ids=blk('X-'+type+'-IDS'); const b=blk('X-l10n-ptBR-'+type);
  const c1=Array.isArray(b)?b[0]:b[1], c2=Array.isArray(b)?b[1]:b[2];
  ids.forEach((id,i)=>{ const n=c1&&at(c1,i+1); if(n){ out[key][id]= type==='Quest' ? [n, c2&&at(c2,i+1)] : n; } });
}
for(const f of fs.readdirSync(xpdir)) for(const m of fs.readFileSync(xpdir+'/'+f,'utf8').matchAll(/\[(\d+)\]\s*=\s*\{(\d+),\s*(\d+)\}/g)) out.xp[m[1]]=[+m[2],+m[3]];
fs.writeFileSync(__dirname+'/l10n.json',JSON.stringify(out));
console.log('ptBR quests',Object.keys(out.quest).length,'npcs',Object.keys(out.npc).length,'xp',Object.keys(out.xp).length);
for(const id of [568,95141,93786,2975]) console.log(id, JSON.stringify(out.quest[id]).slice(0,200), out.xp[id]);
console.log(out.npc[256418], out.npc[2491]);
