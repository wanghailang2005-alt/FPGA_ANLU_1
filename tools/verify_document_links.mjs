import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
function git(args){const r=spawnSync('git',args,{cwd:repo,encoding:'utf8'});if(r.status)throw Error(r.stderr);return r.stdout.trim().split(/\r?\n/).filter(Boolean);}
const files=[...new Set([...git(['diff','--name-only','HEAD']),...git(['ls-files','--others','--exclude-standard'])])].filter(f=>f.endsWith('.md'));
const bad=[];let checked=0;
for(const file of files){
 const full=path.join(repo,file);if(!fs.existsSync(full))continue;
 for(const match of fs.readFileSync(full,'utf8').matchAll(/!?\[[^\]]*\]\(([^\s)]+)\)/g)){
  const target=match[1];if(/^(?:[a-zA-Z][\w+.-]*:|\/|#)/.test(target))continue;
  const resolved=path.resolve(path.dirname(full),decodeURIComponent(target.split('#')[0]));
  checked++;if(!fs.existsSync(resolved))bad.push({file,target});
 }
}
if(bad.length){console.error(JSON.stringify(bad,null,2));process.exit(1);}
console.log(`PASS: ${checked} relative links in ${files.length} changed/new Markdown files`);
