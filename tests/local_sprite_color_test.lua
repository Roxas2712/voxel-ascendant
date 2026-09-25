-- Run both generation-owned importers; exercise selection and decode caching,
-- not a copied implementation of the color classifier.
local root=(arg and arg[1]) or '.'
local function eq(a,b,label)assert(a==b,(label or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
for _,prefix in ipairs{'lib/','gen2/lib/'}do
 local files,decoded,released,reads={},0,0,0
 local function add(folder,name,pixels,meta)
  local path='user/sprites/pokemon/'..folder..'/'..name..'.png'
  files[path]={pixels=pixels,meta=meta or {type='file',size=100,modtime=1}}
  return path
 end
 local gray={{1,1,1,1},{.5,.5,.5,1},{0,0,0,1},{1,0,0,0}}
 local color={{1,1,1,0},{1,.7,0,1}}
 local front=add('front','CHARMANDER',color)
 add('back','CHARMANDER',color)
 add('dex','CHARMANDER',gray)
 add('overworld','CHARMANDER',color)
 add('front','CHARMANDER_SHINY',gray)
 add('front','CHARIZARD_MEGA_X',color)
 add('front','ALPHA_ONLY',{{1,0,0,0}})
 add('front','PARTIAL_ALPHA',{{1,0,0,.1}})
 local late={};for i=1,100 do late[i]={.5,.5,.5,1}end;late[100]={.5,.6,.5,1}
 add('front','LAST_PIXEL',late)
 local broken=add('front','BROKEN',color);files[broken].broken=true
 local badRead=add('front','BAD_READ',color);files[badRead].badRead=true
 local huge=add('front','HUGE',color);files[huge].width=4097
 love={image={newImageData=function(path)
  decoded=decoded+1;local f=assert(files[path]);if f.broken then error('bad PNG')end
  return {getDimensions=function()return f.width or #f.pixels,1 end,
   getPixel=function(_,x,y)reads=reads+1;if f.badRead then error('pixel access failed')end;return unpack(f.pixels[x+1])end,
   release=function()released=released+1 end}
 end}}
 local user={info=function(path)return files[path] and files[path].meta end,path=function(path)return path end}
 local V={mod={id='VOXEL_ASCENDANT'},require=function(name)assert(name=='UserFiles');return user end}
 local M=assert(loadfile(root..'/'..prefix..'LocalSprites.lua'))(V)
 local function resolve(species,side,kind,inherited,mon)
  local ctx={species=species,side=side or 'front',kind=kind or 'battle',trueColor=inherited,mon=mon}
  local path=M.resolve('pokemon','upstream',ctx)
  return path,ctx.trueColor
 end
 local path,tc=resolve('CHARMANDER','front','battle',false)
 eq(path,'upstream','disabled path');eq(tc,false,'disabled flag');eq(decoded,0,'disabled decoded PNG')
 M.setEnabled(nil,true)
 path,tc=resolve('CHARMANDER','front','battle',false)
 eq(path,front,'color path');eq(tc,true,'colored PNG lost source colors')
 local count,scan=decoded,reads
 path,tc=resolve('CHARMANDER','front','battle',false)
 eq(tc,true,'cached color flag');eq(decoded,count,'cache decoded twice');eq(reads,scan,'cache scanned twice')
 path,tc=resolve('CHARMANDER','back','battle',false);eq(tc,true,'rear color')
 path,tc=resolve('CHARMANDER','front','dex',true);eq(tc,false,'gray Dex inherited full color')
 path,tc=resolve('CHARMANDER','front','overworld',false);eq(tc,true,'overworld Pokemon color')
 path,tc=resolve('CHARMANDER','front','battle',true,{shiny=true});eq(tc,false,'shiny own grayscale')
 path,tc=resolve('CHARIZARD','front','battle',false,{_ascMegaForm='CHARIZARD_X'});eq(tc,true,'Mega alias color')
 path,tc=resolve('ALPHA_ONLY','front','battle',true);eq(tc,false,'hidden RGB counted as visible color')
 path,tc=resolve('PARTIAL_ALPHA','front','battle',false);eq(tc,true,'visible partial alpha ignored')
 path,tc=resolve('LAST_PIXEL','front','battle',false);eq(tc,true,'scan missed last pixel')
 for _,name in ipairs{'MISSING','BROKEN','BAD_READ','HUGE'}do
  path,tc=resolve(name,'front','battle',true);eq(path,'upstream',name..' path');eq(tc,true,name..' touched upstream flag')
 end
 files[front].pixels=gray;files[front].meta.modtime=2
 path,tc=resolve('CHARMANDER','front','battle',true);eq(tc,false,'modified file retained stale color')
 files[front].pixels=color;M.rescan()
 path,tc=resolve('CHARMANDER','front','battle',false);eq(tc,true,'explicit rescan retained stale classification')
 files[front]=nil
 path,tc=resolve('CHARMANDER','front','battle',false);eq(path,'upstream','removed file');eq(tc,false,'removed flag')
 add('front','CHARMANDER',gray)
 path,tc=resolve('CHARMANDER','front','battle',true);eq(tc,false,'readded file retained old signature cache')
 -- A host without pixel inspection keeps the previous path/flag contract.
 add('front','NO_PIXELS',gray)
 love.image.newImageData=function()decoded=decoded+1;return {getDimensions=function()return 2,2 end,release=function()released=released+1 end}end
 path,tc=resolve('NO_PIXELS','front','battle',true);assert(path~='upstream');eq(tc,true,'legacy no-pixel host flag')
 eq(released,decoded-1,'decoded images not released (one decode throws)')
 print('PASS '..prefix..'Pokemon PNG colors, grayscale, alpha, cache invalidation and fallback')
end
