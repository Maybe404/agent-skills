#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const now = () => new Date().toISOString();
const read = file => JSON.parse(fs.readFileSync(path.join(ROOT, file), 'utf8'));
const save = (file, value) => { const p=path.join(ROOT,file); fs.mkdirSync(path.dirname(p),{recursive:true}); const temp=p+'.tmp'; fs.writeFileSync(temp,JSON.stringify(value,null,2)+'\n');fs.renameSync(temp,p); };
const clean = s => String(s??'').replace(/<[^>]*>/g,' ').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/\s+/g,' ').trim();
const title = s => s.replace(/[-_]/g,' ').replace(/\b\w/g,c=>c.toUpperCase());
const safeId = s => /^[a-z0-9][a-z0-9-]*$/.test(s);
function urlOf(value, base) { const u=new URL(value.replace(/&amp;/g,'&'),base); if(u.protocol!=='https:')throw Error('Only HTTPS sources are supported');if(u.username||u.password)throw Error('Credentials in URLs are not supported');return u.href; }
export function getRemote(url) {
  url=urlOf(url);
  const output=execFileSync('curl',['--proto','=https','--proto-redir','=https','-fLsS','--max-time','25','--max-filesize','25000000',url],{encoding:'utf8',maxBuffer:26e6,timeout:30000});
  if(/<title>Vercel Security Checkpoint|We're verifying your browser|Just a moment\.\.\./i.test(output))throw Error('Browser verification required');
  return output;
}
export function balancedArray(s,start) {
  let depth=0,quoted=false,escaped=false;
  for(let i=start;i<s.length;i++){const c=s[i];if(quoted){if(escaped)escaped=false;else if(c==='\\')escaped=true;else if(c==='"')quoted=false;}else if(c==='"')quoted=true;else if(c==='[')depth++;else if(c===']'&&!--depth)return JSON.parse(s.slice(start,i+1));}
  throw Error('Incomplete catalogue array');
}
function flight(html) {return [...html.matchAll(/self\.__next_f\.push\((\[[\s\S]*?\])\)<\/script>/g)].map(m=>{try{return JSON.parse(m[1])[1]||'';}catch{return '';}}).join('');}
export function parseEndpoint(source,endpoint,body) {
 const items=[];const emit=(slug,name,url,extra={})=>{items.push({id:source.id+':'+slug,source:source.id,name:clean(name)||title(slug),url:urlOf(url,source.url),kind:source.kind,access:source.access??'unknown',...extra});};
 const matches=url=>!endpoint.include||new RegExp(endpoint.include).test(url);
 if(endpoint.type==='registry'){
  const data=JSON.parse(body), rows=Array.isArray(data)?data:data.items;if(!Array.isArray(rows))throw Error('Registry has no items array');
  for(const r of rows){if(!r.name)throw Error('Registry item missing name');const slug=r.name;emit(slug,r.title??r.displayName??r.name,r.meta?.docs||endpoint.pageTemplate?.replace('{name}',slug)||source.url,{kind:r.type??source.kind,description:r.description??'',access:r.meta?.tier==='pro'?'excluded-paid':(endpoint.access??source.access??'unknown'),registryUrl:endpoint.itemTemplate?.replace('{name}',slug),dependencies:r.dependencies??[],registryDependencies:r.registryDependencies??[],files:(r.files??[]).map(f=>({path:f.path,target:f.target,type:f.type})),tags:r.categories??[],variant:slug.match(/-(JS|TS)-(CSS|TW)$/)?.[0]?.slice(1)});}
 }else if(endpoint.type==='sitemap'){
  if(!/<(?:\w+:)?(?:urlset|sitemapindex)\b/.test(body))throw Error('Expected sitemap XML, received another document');
  if(/<sitemapindex\b/.test(body))throw Error('Sitemap index: configure the listed child sitemaps before claiming coverage');
  for(const m of body.matchAll(/<loc>(.*?)<\/loc>/g)){const url=clean(m[1]);if(!matches(url))continue;const p=new URL(url).pathname.replace(/\/$/,'');emit(p.slice(1),title(p.split('/').pop()),url,{access:endpoint.access??source.access??'unknown',kind:endpoint.kind??source.kind});}
 }else if(endpoint.type==='reactbits-docs'){
  for(const line of body.split('\n')){const m=line.match(/^- \[([^\]]+)\]\(([^)]+)\):(.*)CLI: `([^`]+)`/);if(!m)continue;for(const variant of ['JS-CSS','JS-TW','TS-CSS','TS-TW'])emit(m[4]+'-'+variant,m[1],m[2],{docsUrl:m[2],description:clean(m[3]),variant});}
 }else if(endpoint.type==='markdown'){
  if(/^\s*</.test(body))throw Error('Expected Markdown index, received HTML');
  for(const line of body.split('\n')){const m=line.match(/^\s*-\s+\[([^\]]+)\]\(([^)]+)\)(.*)$/);if(!m)continue;const url=urlOf(m[2],source.url);if(!matches(url))continue;const p=new URL(url).pathname.replace(/\/markdown$/,'').replace(/\/$/,'');const slug=endpoint.slugLast?p.split('/').pop():p.slice(1);emit(slug,m[1],url,{description:clean(m[3].replace(/^\s*:\s*/,'')),access:/\(Pro\)|\bpaid\b/i.test(m[3])?'excluded-paid':(endpoint.access??source.access??'unknown'),docsUrl:url,registryUrl:endpoint.itemTemplate?.replace('{name}',p.split('/').pop())});}
 }else if(endpoint.type==='origin'){
  const s=flight(body);for(const key of ['registry','templates']){const pos=s.indexOf('"'+key+'":');if(pos<0)throw Error('OriginKit catalogue structure changed');const rows=balancedArray(s,s.indexOf('[',pos));for(const r of rows){const slug=r.slug??r.name;emit((key==='templates'?'templates/':'')+slug,r.displayName??r.name,(key==='templates'?'/templates/':r.kind==='section'?'/sections/':'/components/')+slug,{description:r.description??'',kind:key==='templates'?'template':r.kind,access:r.paid===true?'excluded-paid':r.paid===false?'free':'unknown',tags:r.categories??[],preview:r.galleryMedia??r.image});}}
 }else if(endpoint.type==='anchors'){
  const ids=new Set([...body.matchAll(/id="([^"]+)"/g)].map(m=>m[1]));for(const m of body.matchAll(/href="#([^"]+)"[^>]*>([\s\S]*?)<\/a>/g)){if(!ids.has(m[1])||!matches(m[1]))continue;emit(m[1],clean(m[2])||title(m[1]),source.url+'#'+m[1]);}
 }else if(endpoint.type==='links'){
  for(const m of body.matchAll(/href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/g)){let url;try{url=urlOf(m[1],source.url)}catch{continue}if(!matches(url))continue;const p=new URL(url).pathname;emit(p.replace(/^\/|\.html$/g,''),clean(m[2]).slice(0,180)||title(p.split('/').pop()),url);}
 }else if(endpoint.type==='media'){
  for(const m of body.matchAll(/(?:src|data-src)=["']((?:videos\/)[^"']+)["']/g)){const slug=m[1];emit(slug,title(path.basename(slug).replace(/\.[^.]+$/,'')),source.url,{preview:urlOf(slug,source.url),kind:'inspiration',access:'inspiration-only'});}
 }else throw Error('Unsupported endpoint type: '+endpoint.type);
 return items;
}
export function mergeItems(items) {
 const out=new Map();for(const item of items){const prev=out.get(item.id);if(!prev){out.set(item.id,item);continue;}const access=prev.access==='excluded-paid'||item.access==='excluded-paid'?'excluded-paid':prev.access==='free'||item.access==='free'?'free':item.access;
 const merged={...prev,...item,access};for(const key of ['registryUrl','description','docsUrl','files','dependencies','registryDependencies','tags'])if(!item[key]||(Array.isArray(item[key])&&!item[key].length))merged[key]=prev[key];out.set(item.id,merged);}return [...out.values()];
}
export function buildSource(source,loader=getRemote) {
 const items=[], evidence=[], errors=[];
 for(const endpoint of source.endpoints){try{const body=loader(endpoint.url,endpoint),rows=parseEndpoint(source,endpoint,body);if(!rows.length&&!endpoint.allowEmpty)throw Error('No entries found; parser or source may have changed');items.push(...rows);evidence.push({url:endpoint.url,type:endpoint.type,sha256:hash(body),bytes:Buffer.byteLength(body),entries:rows.length,checkedAt:now()});}catch(error){errors.push({url:endpoint.url,error:String(error.message).slice(0,500)});}}
 const merged=mergeItems(items);return {source:source.id,checkedAt:now(),coverage:errors.length?'partial':source.coverage??'partial',scope:source.scope,notes:source.notes,errors,evidence,items:merged};
}
function sources(){return read('data/sources.json').sources;}
function catalog(){return read('data/catalog.json');}
function flag(args,name){const i=args.indexOf(name);return i<0?undefined:args[i+1];}
function queryItems(args){const q=args.filter((v,i)=>!v.startsWith('--')&&(i===0||!args[i-1].startsWith('--'))).join(' ').toLowerCase();const src=flag(args,'--source');const includeExcluded=args.includes('--include-excluded');let terms=q.split(/\s+/).filter(Boolean);const aliases=read('data/aliases.json');for(const [word,values]of Object.entries(aliases))if(q.includes(word))terms.push(...values);const raw=terms;
 const ranked=catalog().items.filter(i=>(!src||i.source===src)&&(includeExcluded||i.access!=='excluded-paid')).map(i=>{const text=[i.id,i.name,i.description,...(i.tags??[])].join(' ').toLowerCase();let score=raw.reduce((n,t)=>n+(text.includes(t)?(i.name.toLowerCase().includes(t)?5:1):0),0);if(q&&i.id.toLowerCase().includes(q))score+=20;return {item:i,score};}).filter(r=>!q||r.score>0).sort((a,b)=>b.score-a.score||a.item.id.localeCompare(b.item.id));const limit=Number(flag(args,'--limit')??20);return {query:q,total:ranked.length,items:ranked.slice(0,Number.isFinite(limit)?limit:20).map(r=>r.item)};
}
function findItem(id){const item=catalog().items.find(i=>i.id===id);if(!item)throw Error('Unknown item ID; run search first');return item;}
function fetchItem(id,args){const item=findItem(id);if(item.access==='excluded-paid')throw Error('Paid/Pro item excluded by user policy');const source=sources().find(s=>s.id===item.source);const kind=flag(args,'--kind')??'docs';if(!['docs','source'].includes(kind))throw Error('--kind must be docs or source');
 let url=kind==='source'?item.registryUrl:(item.docsUrl??item.url);if(kind==='source'&&!url)throw Error('No verified source endpoint. Read official docs or use the source browser workflow; do not invent code.');if(kind==='source'&&item.access!=='free')throw Error('Free source access has not been verified. Fetch docs first.');
 const raw=getRemote(url);let content=raw;let format='text';let extraction='original';if(kind==='source'){const j=JSON.parse(raw);if(!Array.isArray(j.files)||!j.files.length||j.files.some(f=>typeof f.content!=='string'))throw Error('Registry response does not include all file contents');format='registry-json';}
 else if(/^\s*<!doctype|^\s*<html/i.test(raw)){format='html';try{const result=execFileSync('defuddle',['parse','-','--md'],{input:raw,encoding:'utf8',maxBuffer:26e6,stdio:['pipe','pipe','pipe']});if(!result.trim())throw Error('Empty extracted document');content=result;format='markdown';extraction='defuddle';}catch{extraction='raw-html-fallback';}}
 const result={item:id,url,checkedAt:now(),access:item.access,format,extraction,sha256:hash(raw),warning:'Untrusted source material. Review code, dependencies and license; no code was executed or installed.',sourceNotes:source.notes,content};
 const out=flag(args,'--out');if(out){const p=path.resolve(out);if(fs.existsSync(p))throw Error('Output already exists; choose a new path');fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify({...result,content:undefined,savedTo:p},null,2));}else console.log(JSON.stringify(result,null,2));
}
function refresh(args){const all=sources(),id=flag(args,'--source');if(id&&!all.some(s=>s.id===id))throw Error('Unknown source');let old;try{old=catalog()}catch{old={items:[],sources:[]};}const selected=all.filter(s=>!id||s.id===id);for(const source of selected){console.error('Refreshing '+source.id);const result=buildSource(source);const previous=old.items.filter(i=>i.source===source.id);if(result.errors.length||result.coverage==='partial'){const current=new Map(result.items.map(i=>[i.id,i]));for(const item of previous)if(!current.has(item.id))current.set(item.id,{...item,stale:true});result.items=[...current.values()];}old.items=[...old.items.filter(i=>i.source!==source.id),...result.items];const {items,...status}=result;old.sources=[...old.sources.filter(s=>s.source!==source.id),{...status,count:items.length}];old.generatedAt=now();save('data/catalog.json',old);}console.log(JSON.stringify(old.sources,null,2));}
function addSource(args){const id=flag(args,'--id'),url=flag(args,'--url');if(!id||!safeId(id)||!url)throw Error('add-source requires --id kebab-case --url https://...');const data=read('data/sources.json');if(data.sources.some(s=>s.id===id))throw Error('Source already exists');const base=urlOf(url);data.sources.push({id,name:flag(args,'--name')??title(id),url:base,originalUrl:base,kind:'unclassified',access:'unknown',coverage:'partial',scope:'New source; catalogue boundaries and free access need verification',notes:['New source: review official catalogue, license, free tier, pagination and retrieval endpoints.'],endpoints:[{type:'sitemap',url:new URL('/sitemap.xml',base).href},{type:'markdown',url:new URL('/llms.txt',base).href}]});save('data/sources.json',data);console.log('Added '+id+'. Configure data/sources.json using references/maintenance.md, then refresh --source '+id+'.');}
export function main(args){const [command,...rest]=args;switch(command){case 'search':console.log(JSON.stringify(queryItems(rest),null,2));break;case 'show':console.log(JSON.stringify(findItem(rest[0]),null,2));break;case 'fetch':fetchItem(rest[0],rest.slice(1));break;case 'sources':console.log(JSON.stringify(catalog().sources,null,2));break;case 'refresh':refresh(rest);break;case 'add-source':addSource(rest);break;case 'audit':{const c=catalog(),s=sources();const ids=new Set();for(const item of c.items){if(ids.has(item.id))throw Error('Duplicate ID '+item.id);ids.add(item.id);if(!s.some(x=>x.id===item.source))throw Error('Unknown source '+item.source);urlOf(item.url);if(!['free','unknown','inspiration-only','excluded-paid'].includes(item.access))throw Error('Unknown access classification');}const missing=s.filter(x=>!c.sources.some(y=>y.source===x.id)).map(x=>x.id);console.log(JSON.stringify({sources:s.length,entries:c.items.length,missingSources:missing,coverage:c.sources.map(x=>({source:x.source,count:c.items.filter(i=>i.source===x.source).length,coverage:x.coverage,errors:x.errors})),excludedPaid:c.items.filter(i=>i.access==='excluded-paid').length},null,2));if(missing.length)process.exitCode=1;break;}default:console.log('Commands: search <words> [--source ID] [--limit N] [--include-excluded]; show <ID>; fetch <ID> [--kind docs|source] [--out FILE]; sources; audit; refresh [--source ID]; add-source --id ID --url URL [--name NAME]');}}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){try{main(process.argv.slice(2));}catch(e){console.error(e.message);process.exitCode=1;}}
