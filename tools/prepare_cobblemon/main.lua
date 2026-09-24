-- Package-time build: love tools/prepare_cobblemon /absolute/path/to/mod
-- Runs the same data-only importer as optional downloaded content. No network.
function love.load(args)
 io.stdout:setvbuf('no')
 local ok,err=xpcall(function()
  local root=assert(args[1],'Pass the absolute mod directory')
  local function read(p)local f=io.open(root..'/'..p,'rb');if not f then return end;local b=f:read('*a');f:close();return b end
  local function write(p,b)local f=assert(io.open(root..'/'..p,'wb'));f:write(b);f:close()end
  local function sha(b)return love.data.encode('string','hex',love.data.hash('sha256',b))end
  local V={};local modules={}
  function V.require(n)if not modules[n]then modules[n]=assert(loadstring(assert(read('lib/'..n..'.lua')),'@'..n))(V)end;return modules[n]end
  local J=V.require('ContentJson');local encode=V.require('CobblemonJson').encode
  local raw=assert(read('assets/cobblemon-catalog.json'));local c=assert(J.decode(raw));local paths={}
  for _,f in ipairs(c.files)do
   assert(f.bundled,'Prepared base pack requires bundled inputs: '..f.path)
   local b=assert(read(f.bundled),f.bundled);assert(#b==f.bytes and sha(b)==f.sha256,'Invalid bundled input: '..f.bundled);paths[f.path]=f.bundled
  end
  local importer=V.require('CobblemonImport');local species={};local total,unique=0,{}
  local failures={};local dexes={};for d in pairs(c.species)do dexes[#dexes+1]=tonumber(d)end;table.sort(dexes)
  local defaults={{key='normal',aspects={}},{key='female',aspects={female=true}},{key='shiny',aspects={shiny=true}},{key='female_shiny',aspects={female=true,shiny=true}}}
  for i,dex in ipairs(dexes)do
   local row={}
   for _,variant in ipairs(c.variants and c.variants[tostring(dex)] or defaults)do
    local yes,m=pcall(importer.compile,c,dex,variant.aspects,function(p)return paths[p]and read(paths[p])end,J.decode)
    if yes then
     local b=encode(m);local h=sha(b);if not unique[h]then write('assets/cobblemon-prepared/models/'..h..'.json',b);unique[h]=true end
     row[variant.key]=h;total=total+1
    else failures[#failures+1]={dex=dex,variant=variant.key,error=tostring(m)}end
   end
   assert(row.normal,'No base model for #'..dex)
   species[tostring(dex)]=row
   if i%50==0 then print('Prepared',i,'/',#dexes)end
   collectgarbage('step',200)
  end
  local index={schema=1,commit=c.commit,catalogHash=sha(raw),importRevision=c.importRevision,speciesCount=#dexes,species=species,complete=#dexes==c.speciesCount}
  write('assets/cobblemon-prepared/index.json',encode(index))
  write('assets/cobblemon-prepared/build-report.json',encode{species=#dexes,variants=total,declined=failures})
  print('PREPARED',#dexes,'species',total,'variants',#failures,'unsupported variants')
 end,debug.traceback)
 if not ok then io.stderr:write(err..'\n')end
 love.event.quit(ok and 0 or 1)
end
