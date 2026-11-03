const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),e=path.join(root,'ui_evidence');
const probe=path.join(e,'rom_init_probe/font_gate_probe.v');
const text=fs.readFileSync(probe,'utf8'),rtl=fs.readFileSync(path.join(root,'src/user_source/hdl_source/OSD/osd_overlay.v'),'utf8');
const glyphs={};for(const m of rtl.matchAll(/7'd(\d+)\s*:\s*bmp\s*=\s*256'h([0-9a-f]+)/gi))glyphs[+m[1]]=BigInt('0x'+m[2]);
const zh=Array.from({length:2048},(_,i)=>Number(((glyphs[i>>4]||0n)>>BigInt((15-(i&15))*16))&65535n));
const sidebar=fs.readFileSync(path.join(e,'sidebar_font.hex'),'utf8').trim().split(/\s+/).map(x=>parseInt(x,16));
const result={status:'PASS',fonts:{}};
for(const [name,rows] of [['u_osd_overlay/zh_row',zh],['u_osd_overlay/sidebar/bits',sidebar]]){
 let mask=0,instances=0;const reconstructed=Array(2048).fill(0);
 for(const m of text.matchAll(/EG_PHY_BRAM\s*#\((.*?)\)\s*(\\[^\s]+)\s*\((.*?)\);/gs)){
 const [_,parameters,instance,ports]=m;if(!ports.includes(name))continue;
 const r=new RegExp(name.replaceAll('/','\\/')+'\\s*\\[(\\d+):(\\d+)\\]');const slice=ports.match(r);
 if(!slice)throw Error('No output slice '+instance);const hi=+slice[1],lo=+slice[2];
 if(hi-lo!==3 || ![0,4,8,12].includes(lo))throw Error('Unexpected output slice');
 if(!parameters.includes('.MODE("SP8K")') || !parameters.includes('.WEAMUX("0")'))throw Error('Unexpected ROM configuration');
 const init=[...parameters.matchAll(/\.INIT_([0-9a-f]{2})\(256'h([0-9a-f]+)\)/gi)];
 if(init.length!==32)throw Error('Incomplete init');let image=0n;
 for(const a of init)image|=BigInt('0x'+a[2])<<BigInt(parseInt(a[1],16)*256);
 if(mask&(15<<lo))throw Error('Duplicate slice');mask|=15<<lo;
 for(let i=0;i<2048;i++){
 const value=Number((image>>BigInt(i*4))&15n);
 if(value!==((rows[i]>>lo)&15))throw Error(`Font initialization mismatch ${name} at ${i}`);
 reconstructed[i]|=value<<lo;
 }instances++;
 }
 if(mask!==65535 || instances!==4)throw Error('Missing font slices '+name);
 const b=Buffer.alloc(4096);reconstructed.forEach((x,i)=>b.writeUInt16LE(x,i*2));
 result.fonts[name]={bram_instances:instances,matched_rows:2048,matched_bits:32768,sha256:crypto.createHash('sha256').update(b).digest('hex')};
}
fs.writeFileSync(path.join(e,'font_init_verified.json'),JSON.stringify(result,null,2));
fs.unlinkSync(probe);console.log(JSON.stringify(result,null,2));
