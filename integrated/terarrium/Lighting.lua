-- Bounded local light rig and cached 64x64 soft contact lightmap.
return function(api)
 local S={bakes=0};local L=api.lights
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
 function S.enabled()return L.available() and api.enabled()~=false end
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
  local p=palettes[id]or(id:match('^POKEMON_TOWER_')and{{.59,.49,.80},{.66,.74,.94}})or{{1,.84,.66},{.63,.81,1}}
  local t=api.clock();local pulse=p[3]=='lava' and (1+.035*math.sin(t*2.1)+.018*math.sin(t*4.7))or 1
  local lamps={};local x,z=arena.mid[1],arena.mid[2];local lava=p[3]=='lava'
  for i,side in ipairs({-1,1})do
   lamps[#lamps+1]={x=x+side*(lava and 57 or 44),y=ground+(lava and 9 or 32),z=z-17,
    radius=112,power=(lava and .92 or .68)*pulse,weight=1,normal={0,0,0},owner={},color=p[i]}
  end
  if not L.mobile then lamps[3]={x=x,y=ground+38,z=z+49,radius=130,power=.27,weight=1,normal={0,0,0},owner={},color={1,.95,.87}}end
  local tint={.80,.81,.84};if lava then tint={.77,.74,.76}end
  api.graphics.tint=tint
  local f=L.stage(nil,tint,lamps)
  f.terrarium=true;f.stageAO=lightmap;f.stageOrigin={x,ground,z,152}
  -- Contact shadows are baked; no world visibility prepass for these fills.
  f.unoccluded=true
  S.last={id=id,count=#lamps,bakes=S.bakes}
  return true
 end
 function S.release()L.clear(true);S.last=nil end
 return S
end
