local V=...;local G=V.require('CobblemonGeometry');local M={}
local function resource(id)return type(id)=='string' and id:match('^cobblemon:([%w_%.%-/]+)$')end
local function reference(expr)
 if type(expr)~='string'then return nil end
 local group,name=expr:match("q%.bedrock[%w_]*%('%s*([%w_%-]+)'%s*,%s*'([%w_%-]+)'")
 return group,name
end
function M.compile(catalog,dex,aspects,read,decode)
 local rows={};for _,path in ipairs(catalog.species[tostring(dex)] or {})do
  local r=decode(assert(read(path),path));rows[#rows+1]=r
 end
 table.sort(rows,function(a,b)return (a.order or 0)<(b.order or 0)end)
 local variant={};local found=false;local shinyMatched=false;local matched={}
 for _,r in ipairs(rows)do for _,v in ipairs(r.variations or {})do
  local yes=true;for _,a in ipairs(v.aspects or {})do if not aspects[a]then yes=false end end
  if yes then for k,x in pairs(v)do variant[k]=x end;found=true;for _,a in ipairs(v.aspects or {})do matched[a]=true;if a=='shiny'then shinyMatched=true end end end
 end end
 for aspect in pairs(aspects)do if aspect~='female'then assert(matched[aspect],'requested form/colour unavailable: '..aspect)end end
 assert(found,'no matching resolver');assert(not aspects.shiny or shinyMatched,'shiny texture unavailable')
 local modelKey=resource(variant.model);local poserKey=resource(variant.poser)
 local modelPath=assert(catalog.index['model:'..tostring(modelKey)],'model missing')
 local texture='assets/cobblemon/'..assert(resource(variant.texture),'texture missing')
 assert(read(texture),'texture missing')
 local poserPath=catalog.index['poser:'..tostring(poserKey)]
 local poser=poserPath and decode(assert(read(poserPath))) or {poses={},animations={}}
 -- Older upstream species use Kotlin posers. Only recognize their standard
 -- authored Bedrock clips; never execute or pretend to support Kotlin logic.
 if not poserPath then
  local group=tostring(poserKey);local ap=catalog.index['animation:'..group]
  local a=ap and decode(assert(read(ap))).animations or {}
  local function pick(list)for _,n in ipairs(list)do if a['animation.'..group..'.'..n]then return "q.bedrock('"..group.."', '"..n.."')"end end end
  local idle=pick{'ground_idle','idle','air_idle','water_idle'}
  local walk=pick{'ground_walk','walk','air_fly','swim'}
  if idle then poser.poses.standing={poseTypes={'STAND'},animations={idle}}end
  local battle=pick{'battle_idle','battle_standing','battle'}
  if battle then poser.poses['battle-standing']={isBattle=true,poseTypes={'STAND'},animations={battle}}end
  if walk then poser.poses.walking={poseTypes={'WALK'},animations={walk}}end
  poser.animations={physical=pick{'physical','attack'},special=pick{'special'},status=pick{'status'},cry=pick{'cry'},recoil=pick{'recoil'},faint=pick{'faint'}}
 end
 local model,names=G.build(decode(assert(read(modelPath))),dex)
 model.texture=texture;model.actions={};model.warnings={};model.layers={}
 -- Texture layers are retained for compositing by the renderer. Animated
 -- and conditional layers are declined individually, never run as scripts.
 for _,l in ipairs(variant.layers or {})do
  local p=resource(l.texture)
  if p and read('assets/cobblemon/'..p)then model.layers[#model.layers+1]='assets/cobblemon/'..p
  else model.warnings[#model.warnings+1]='unsupported texture layer' end
 end
 local cache={};local function clip(expr)
  local group,name=reference(expr);if not group then return nil end
  local path=catalog.index['animation:'..group];if not path then return nil end
  if not cache[path]then cache[path]=decode(assert(read(path))).animations or {}end
  return cache[path]['animation.'..group..'.'..name]
 end
 local function expressions(pose)
  local out={}
  for _,expr in ipairs(pose and pose.animations or {})do local raw=clip(expr);if raw then out[#out+1]=raw end end
  if #out>0 then return out end
 end
 local poses=poser.poses or {};local chosen={}
 for _,name in ipairs{'standing','ground','idle','hover','flying','floating','swimming','walking','battle-standing','battle-hover','battle-flying'}do
  local p=poses[name]
  if p then
   local raw=expressions(p)
   if raw then
    if name=='walking'then chosen.walk=raw
    elseif p.isBattle==true then chosen.battle=raw
    elseif not p.isTouchingWater then chosen.idle=chosen.idle or raw end
   end
  end
 end
 for _,name in ipairs((function()local k={};for n in pairs(poses)do k[#k+1]=n end;table.sort(k);return k end)())do
  local p=poses[name];local raw=expressions(p)
  if raw then for _,pt in ipairs(p.poseTypes or {})do
   if (pt=='STAND' or pt=='HOVER' or pt=='FLOAT') and not p.isTouchingWater then
    if p.isBattle then chosen.battle=chosen.battle or raw else chosen.idle=chosen.idle or raw end
   elseif pt=='WALK' or pt=='FLY'then chosen.walk=chosen.walk or raw end
  end end
 end
 chosen.idle=chosen.idle or chosen.battle;chosen.battle=chosen.battle or chosen.idle
 local animations=poser.animations or {}
 -- Keep categories independent: a missing special clip must not silently
 -- replay a physical attack. CobblemonMotion supplies the VASC default.
 local function one(expr)local raw=clip(expr);return raw and {raw}end
 chosen.attack_physical=one(animations.physical)
 chosen.attack_special=one(animations.special)
 chosen.attack_status=one(animations.status)
 chosen.flinch=one(animations.recoil);chosen.entrance=one(animations.cry);chosen.faint=one(animations.faint)
 model.actionSources={}
 for _,action in ipairs{'idle','battle','walk','attack_physical','attack_special','attack_status','flinch','entrance','faint'}do
  local layers={}
  for _,raw in ipairs(chosen[action] or {})do
   local ok,c=pcall(G.clip,raw,names)
   if ok and next(c.channels)then layers[#layers+1]=c
   else model.warnings[#model.warnings+1]=action..': '..tostring(ok and 'no supported bone channels' or c)end
  end
  if #layers>0 then
   local c=layers[1]
   if #layers>1 then
    c={seconds=0,frames=1,channels={},layers=layers,loop=true}
    for _,layer in ipairs(layers)do c.seconds=math.max(c.seconds,layer.seconds)end
   end
   model.anims[#model.anims+1]=c;model.actions[action]=#model.anims;model.actionSources[action]=catalog.authored and catalog.authored[tostring(dex)] and 'vasc' or 'cobblemon'
  end
 end
 -- An unsupported battle-only clip must not hide a valid original idle.
 if not model.actions.battle and model.actions.idle then
  model.actions.battle=model.actions.idle;model.actionSources.battle=model.actionSources.idle
 end
 V.require('CobblemonMotion').complete(model,names,G)
 assert(model.actions.idle,'no supported idle animation: '..table.concat(model.warnings,'; '))
 model.ctx[1]=model.actions.idle-1
 model.ctx[2]=(model.actions.attack_default or model.actions.idle)-1
 model.ctx[3]=(model.actions.faint or model.actions.idle)-1
 model.ctx[4]=(model.actions.entrance or model.actions.idle)-1
 model.ctx[14]=(model.actions.flinch or model.actions.idle)-1
 -- Verify samples before activating content, including every clip's midpoint.
 for i,c in ipairs(model.anims)do G.sample(model,i,0,false);G.sample(model,i,c.seconds*15,false);G.sample(model,i,c.seconds*30,false)end
 model._sample=nil;return model
end
return M
