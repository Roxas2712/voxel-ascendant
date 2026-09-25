local Bundle=dofile('lib/SpriteBundleInstaller.lua');local Import=dofile('lib/SpritePackageImport.lua')
local function hash(s)local n=0;for i=1,#s do n=(n*31+s:byte(i))%2147483647 end;return string.format('%064x',n)end
local manifest='meta';local p={id='one',published=true,manifestSha256=hash(manifest),manifestBytes=#manifest}
local archive=Import.MAGIC..p.manifestSha256..'\n'..string.format('%08x',#manifest)..'\n'..manifest..'abc'
local bodies={archive:sub(1,50),archive:sub(51)};local chunks={};for i,raw in ipairs(bodies)do chunks[i]={bytes=#raw,sha256=hash(raw)}end
for _,corrupt in ipairs({false,true})do
 local disk,requests,activated,stored={},{0,0},0,false
 local cache={info=function(_,k)return disk[k]and{type='file',size=#disk[k]}end,read=function(_,k)return disk[k]end,
  write=function(_,k,v)disk[k]=v;return true end,remove=function(_,k)disk[k]=nil;return true end}
 local fetch={state='idle',attempt=0,receivedBytes=0}
 function fetch:start(path,bytes,sha)local i=tonumber(path:match('/(%d+)$'))+1;requests[i]=requests[i]+1;self.next=i;self.state='fetching';return true end
 function fetch:update()self.body=bodies[self.next];self.state='ready'end
 function fetch:cancel()self.state='cancelled';self.body=nil end
 local store={inspect=function(_,raw)assert(raw==manifest);return{files={{chunks={{sha256=hash('abc'),bytes=3}}}}}end,
  putChunk=function(_,sha,raw)assert(sha==hash(raw)and raw=='abc');stored=true;return true end,
  activate=function(_,raw)assert(stored and raw==manifest);activated=activated+1;return true end}
 local deps={cache=cache,fetch=fetch,store=store,Importer=Import,sha256=hash,now=function()return 1 end,catalog={packages={one=p}},
  bundles={one={sha256=hash(archive),bytes=#archive,chunks=chunks}}}
 local a=Bundle.new(deps);assert(not a:start({missing={'one'}},false));assert(a:start({missing={'one'}},true))
 a:update();a:update();assert(disk[Bundle.ROOT..chunks[1].sha256]);a:update();assert(requests[2]==1)
 a:cancel();assert(a.state=='cancelled'and activated==0)
 if corrupt then disk[Bundle.ROOT..chunks[1].sha256]='damaged'end
 -- Recreate the installer to simulate restart: only verified cache bytes count.
 local b=Bundle.new(deps);assert(b:start({missing={'one'}},true))
 for i=1,20 do b:update();local progress=b:progress();assert(progress.doneBytes<=progress.totalBytes);if b.state=='ready'then break end end
 assert(b.state=='ready'and activated==1 and stored)
 assert(requests[1]==(corrupt and 2 or 1)and requests[2]==2,'resume did not reuse/reject cache correctly')
 assert(not disk['sprite-content/archive-pending/one']and not disk[Bundle.ROOT..chunks[1].sha256])
 for i=1,10 do b:update()end;assert(activated==1)
end
print('PASS actual bundle installer + package importer: consent, pause, process restart, verified reuse, corrupt-cache retry, single activation and cleanup')
