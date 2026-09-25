-- Bounded local light rig and cached 64x64 soft contact lightmap.
return function(api)
 local S={bakes=0};local L=api.lights
 local rigs=setmetatable({},{__mode='k'})
 local defaultPalette={{1,.84,.66},{.63,.81,1}}
 local towerPalette={{.59,.49,.80},{.66,.74,.94}}
 local palettes={
  ROCKET_HIDEOUT_B4F={{1,.61,.53},{.60,.79,.96}},
  CINNABAR_GYM={{1,.43,.12},{1,.70,.27},'lava'},
  FUCHSIA_GYM={{.68,.55,.88},{.52,.77,.62}},
  CERULEAN_GYM={{.40,.78,1},{.75,.92,1}},
  VERMILION_GYM={{1,.81,.34},{.70,.85,1}},
  CELADON_GYM={{.81,.95,.58},{1,.79,.51}},
  SAFFRON_GYM={{.84,.58,1},{.55,.76,1}},
  VIRIDIAN_GYM={{1,.78,.46},{.82,.91,.71}},
  LORELEIS_ROOM={{.38,.76,1},{.71,.90,1}},
  BRUNOS_ROOM={{1,.65,.31},{1,.86,.61}},
  AGATHAS_ROOM={{.68,.44,.95},{.52,.67,.93}},
  LANCES_ROOM={{1,.63,.35},{1,.86,.57}},
  CHAMPIONS_ROOM={{1,.88,.66},{.52,.84,1}},
 }
 local function rigFor(arena)
  local rig=rigs[arena]
  if not rig then
   local lamps={}
   for i=1,3 do lamps[i]={weight=1,normal={0,0,0},owner={}}end
   lamps[3].radius=130;lamps[3].power=.27;lamps[3].color={1,.95,.87}
   rig={lamps=lamps,fill=lamps[3],tint={.80,.81,.84}}
   rigs[arena]=rig
  end
  return rig
 end
 function S.enabled()return not S.failure and L.available() and api.enabled()~=false end
 function S.fail(reason)
  if not S.failure then
   S.failure=tostring(reason)
   if api.reportEffectFailure then pcall(api.reportEffectFailure,'lighting',S.failure)end
  end
  L.clear(true);S.last=nil
 end
 -- Grounded vertical props only; the bowl/floor cannot darken the whole map.
 function S.bake(boxes)
  local n,span=64,152;local cells={}
  for i=1,n*n do cells[i]=0 end
  for _,b in ipairs(boxes)do
   local x,y,z,w,h,d=unpack(b)
   if y<=3.1 and y+h>=1.4 and w*d<1600 then
    local x0=math.max(0,math.floor((x-w/2+76)/span*n)-1)
    local x1=math.min(n-1,math.ceil((x+w/2+76)/span*n)+1)
    local z0=math.max(0,math.floor((z-d/2+76)/span*n)-1)
    local z1=math.min(n-1,math.ceil((z+d/2+76)/span*n)+1)
    local strength=math.min(.30,.10+h*.009)
    for iz=z0,z1 do for ix=x0,x1 do
     local px,pz=(ix+.5)*span/n-76,(iz+.5)*span/n-76
     local dx=math.max(0,math.abs(px-x)-w/2);local dz=math.max(0,math.abs(pz-z)-d/2)
     local shade=strength*math.max(0,1-math.sqrt(dx*dx+dz*dz)/5)
     local k=iz*n+ix+1;cells[k]=math.max(cells[k],shade)
    end end
   end
  end
  for pass=1,2 do
   local smooth={}
   for z=0,n-1 do for x=0,n-1 do
    local sum=0
    for dz=-1,1 do for dx=-1,1 do sum=sum+cells[math.max(0,math.min(n-1,z+dz))*n+math.max(0,math.min(n-1,x+dx))+1]end end
    smooth[z*n+x+1]=sum/9
   end end
   cells=smooth
  end
  local data=love.image.newImageData(n,n)
  for z=0,n-1 do for x=0,n-1 do local v=1-cells[z*n+x+1];data:setPixel(x,z,v,v,v,1)end end
  local ok,texture=pcall(love.graphics.newImage,data);data:release();if not ok then error(texture)end
  texture:setFilter('linear','linear');texture:setWrap('clamp','clamp');S.bakes=S.bakes+1
  return texture
 end
 function S.prepare(arena,ground,lightmap)
  if not S.enabled()then L.clear(true);return false end
  local id=arena.terarrium.id
  local p=palettes[id]or(id:match('^POKEMON_TOWER_')and towerPalette)or defaultPalette
  local lava=p[3]=='lava';local pulse=1
  if lava then local t=api.clock();pulse=1+.035*math.sin(t*2.1)+.018*math.sin(t*4.7)end
  local rig=rigFor(arena);local lamps=rig.lamps;local x,z=arena.mid[1],arena.mid[2]
  for i=1,2 do
   local lamp=lamps[i];local side=i==1 and -1 or 1
   lamp.x=x+side*(lava and 57 or 44);lamp.y=ground+(lava and 9 or 32);lamp.z=z-17
   lamp.radius=112;lamp.power=(lava and .92 or .68)*pulse;lamp.color=p[i]
  end
  if L.mobile or L.handheld then lamps[3]=nil
  else lamps[3]=rig.fill;rig.fill.x=x;rig.fill.y=ground+38;rig.fill.z=z+49 end
  local tint=rig.tint
  tint[1],tint[2],tint[3]=lava and .77 or .80,lava and .74 or .81,lava and .76 or .84
  api.graphics.tint=tint
  local f=L.stage(nil,tint,lamps)
  f.terrarium=true;f.stageAO=lightmap;f.stageOrigin={x,ground,z,152}
  -- Contact shadows are baked; no world visibility prepass for these fills.
  f.unoccluded=true
  S.last={id=id,count=#lamps,bakes=S.bakes}
  return true
 end
 function S.release()L.clear(true);S.last=nil;S.failure=nil;rigs=setmetatable({},{__mode='k'}) end
 return S
end
