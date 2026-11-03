const {chromium}=require('playwright');
(async()=>{
  const [glb,out,...views]=process.argv.slice(2); // views: az,el
  const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const p=await b.newPage({viewport:{width:1200,height:700}});
  const http=require('http'),fs=require('fs'),path=require('path');
  const srv=http.createServer((q,s)=>{const f=path.join(__dirname,decodeURIComponent(q.url.split('?')[0]));fs.readFile(f,(e,d)=>{if(e){s.writeHead(404);s.end();return;}s.writeHead(200,{'Content-Type':f.endsWith('.js')?'text/javascript':f.endsWith('.html')?'text/html':'application/octet-stream'});s.end(d);});}).listen(8765);
  let i=0;
  for(const v of views){const [az,el]=v.split(',');
    await p.goto(`http://localhost:8765/render.html?m=${glb}&w=1200&h=700&az=${az}&el=${el}`);
    await p.waitForFunction('window.DONE===true',{timeout:120000});
    await p.screenshot({path:`${out}_${i++}.png`});}
  await b.close(); srv.close();
})();
