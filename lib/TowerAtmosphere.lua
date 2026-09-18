-- A small, optional lighting pass for the seven real Pokemon Tower floors.
-- Candle lighting stays on surfaces. IndoorMist renders the drifting air.
local V=...
local M={}
M.setting=V.require('ModSetting').new('towerAtmosphere','TOWER MOOD',{true,false},{'ON','OFF'},true)
local tint={.58,.56,.66}
local on,off={1,0},{0,0}
function M.active(map)
 local d=map and map.def
 local id=map and (map.id or d and d.id)
 return d and d.generation~=2 and d.tileset=='CEMETERY'
  and type(id)=='string' and id:match('^POKEMON_TOWER_[1-7]F$')~=nil
  and M.setting:get() or false
end
function M.tint(map,normal)return M.active(map) and tint or normal end
function M.uniforms(map)
 if not M.active(map)then return off end
 on[2]=V.require('Sky').clock or 0
 return on
end
function M.candleLight()
 local t=V.require('Sky').clock or 0
 return .70+.06*math.sin(t*7.3)+.025*math.sin(t*13.7)
end
-- One coarse, cached light field for all candles on a floor. Each candle
-- touches at most 64 samples; no loop over lights runs in the pixel shader.
function M.lightSamples(map,points)
 local w,h=map.def.width*8,map.def.height*8
 local values={}
 for _,p in ipairs(points)do
  for y=math.max(0,math.floor((p[2]-13)/4)),math.min(h-1,math.ceil((p[2]+13)/4))do
   for x=math.max(0,math.floor((p[1]-13)/4)),math.min(w-1,math.ceil((p[1]+13)/4))do
    local d=((x+.5)*4-p[1])^2+((y+.5)*4-p[2])^2
    if d<169 then
     local k=y*w+x;local v=(1-d/169)^2
     values[k]=math.min(1,(values[k]or 0)+v)
    end
   end
  end
 end
 return w,h,values
end
local fields=setmetatable({},{__mode='k'})
function M.lights(map,dark)
 -- Decorative torches never reveal an unlit FLASH map. The flame itself
 -- stays small and visible; no map palette, native darkness or save flag changes.
 if dark or not V.require('VoxelItems').setting:get()then return nil end
 local candles=M.active(map)
 local T=V.require('CaveTorches');local torches=T.eligible(map)and T.enabled()
 if not candles and not torches then return nil end
 local F=V.require('VoxelFurniture');local props=F.find(map)
 local cached=fields[map]
 if cached and cached.props==props and cached.candles==candles and cached.torches==torches then return cached.texture and cached or nil end
 if cached and cached.texture then cached.texture:release()end
 cached={props=props,candles=candles,torches=torches};fields[map]=cached
 local points={}
 for _,p in ipairs(props)do
  if p.claimed and F.enabled(p)then
   if candles and p.kind=='memorial_stone_2'then points[#points+1]={p.tx*8+12,p.ty*8+3}
   elseif torches and p.torchLight then points[#points+1]=p.torchLight end
  end
 end
 if #points==0 then return nil end
 local data
 local ok=pcall(function()
  local w,h,values=M.lightSamples(map,points)
  data=love.image.newImageData(w,h)
  for k,value in pairs(values)do data:setPixel(k%w,math.floor(k/w),value,0,0,1)end
  cached.texture=love.graphics.newImage(data)
  cached.texture:setFilter('linear','linear');cached.texture:setWrap('clamp','clamp')
  cached.size={w*4,h*4}
 end)
 if data then data:release()end
 return ok and cached.texture and cached or nil
end
function M.register(P)
 -- Variant 2 already has a wax candle. Place the flame on that candle,
 -- never on flowers or the stone inscriptions of the other two variants.
 local grave=P.models.memorial_stone_2
 if not grave then return end
 P.models.memorial_candle_flame={frameW=16,frameH=48,depth=16,offsetY=-32,
  boxes={{11,7,2,2,2,2,1},{11,9,2,1,2,1,11},{11,7,3,1,1,1,4}}}
 grave.glassKind='memorial_candle_flame'
 grave.glassVisible=function(map)return M.active(map)end
 grave.windowLight=M.candleLight
end
M.GLSL=[[
uniform vec2 towerMood;
uniform float towerBackdrop;
uniform Image towerLight;
uniform vec2 towerLightSize;
vec3 towerMist(vec3 rgb, vec3 world) {
 rgb*=mix(1.0,0.52,towerBackdrop);
 if(towerLightSize.x>0.0) {
   float pool=Texel(towerLight,world.xz/towerLightSize).r;
   float height=max(0.0,1.0-abs(world.y-7.0)/18.0);
   rgb+=vec3(0.24,0.12,0.035)*pool*height;
 }

 return rgb;
}
]]
return M
