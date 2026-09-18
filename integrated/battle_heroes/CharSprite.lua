-- Public character art registry. Frame indices and atlas rows are zero-based.
local load=...
local defaults=load('Trainers.lua')
local rigs=load('data/rigs.lua')
local C={schema='ascendant.charsprite/v1',revision=0,characters={},trainers={}}
for k,v in pairs(defaults) do C.trainers[k]=v end
local function validNumber(n) return type(n)=='number' and n==n and n>=0 and n<10000 end
function C.register(id,spec)
 assert(type(id)=='string' and #id>0,'charsprite id required')
 assert(type(spec)=='table' and type(spec.path)=='string','charsprite path required')
 local out={}
 for k,v in pairs(spec) do out[k]=v end
 out.columns,out.rows=out.columns or 3,out.rows or 4
 assert(validNumber(out.columns) and out.columns>=1 and out.columns%1==0,'invalid columns')
 assert(validNumber(out.rows) and out.rows>=1 and out.rows%1==0,'invalid rows')
 out.leftRow,out.rightRow=out.leftRow or 1,out.rightRow or 3
 assert(validNumber(out.leftRow) and out.leftRow%1==0 and out.leftRow<out.rows and validNumber(out.rightRow) and out.rightRow%1==0 and out.rightRow<out.rows,'direction row outside atlas')
 for _,key in ipairs({'frontRow','backRow'})do
  if out[key]~=nil then assert(validNumber(out[key]) and out[key]%1==0 and out[key]<out.rows,'view row outside atlas')end
 end
 out.idleColumn=out.idleColumn or 0
 assert(validNumber(out.idleColumn) and out.idleColumn%1==0 and out.idleColumn<out.columns,'idle column outside atlas')
 if out.width then assert(validNumber(out.width) and out.width>0,'invalid character width')end
 out.height=out.height or 18
 assert(validNumber(out.height) and out.height>0,'invalid character height')
 -- Authored full-body clips take precedence over the generated arm rig.
 -- Each clip entry is {column,row,ticks}; throw release remains tick 18.
 for _,clip in pairs(out.clips or {}) do
  assert(type(clip)=='table' and #clip>0,'empty animation clip')
  for _,f in ipairs(clip) do
   assert(validNumber(f[1]) and f[1]%1==0 and f[1]<out.columns and validNumber(f[2]) and f[2]%1==0 and f[2]<out.rows and validNumber(f[3]) and f[3]>=1,'invalid clip frame')
  end
 end
 C.characters[id]=out;C.revision=C.revision+1
 return out
end
function C.bindTrainer(class,id)
 assert(C.characters[id],'unknown charsprite '..tostring(id))
 C.trainers[class]=id;C.revision=C.revision+1
end
function C.setResolver(fn)
 assert(fn==nil or type(fn)=='function','charsprite resolver must be a function')
 C.resolver=fn;C.revision=C.revision+1
end
function C.resolve(battle,side,fallback)
 if C.resolver then
  local ok,id=pcall(C.resolver,battle,side,fallback)
  if ok and C.characters[id] then return id end
 end
 return fallback
end
function C.get(id)
 return C.characters[id] or C.characters['trainers/youngster']
end
function C.cellBounds(spec,pixels,row,column)
 local iw,ih=pixels:getDimensions()
 assert(iw%spec.columns==0 and ih%spec.rows==0,'charsprite atlas dimensions do not match grid')
 local w,h=iw/spec.columns,ih/spec.rows
 local l,t,r,b=w,h,-1,-1
 local x0,y0,x1,y1=(column or 0)*w,(row or 0)*h,(column or 0)*w+w-1,(row or 0)*h+h-1
 -- A common cell-space box prevents authored wind-up frames from shrinking
 -- the entire character when a raised hand extends above the idle head.
 if spec.clips then x0,y0,x1,y1=0,0,iw-1,ih-1 end
 for y=y0,y1 do for x=x0,x1 do
  local _,_,_,alpha=pixels:getPixel(x,y)
  if alpha>.1 then
   local u,v=x%w,y%h
   l,t,r,b=math.min(l,u),math.min(t,v),math.max(r,u),math.max(b,v)
  end
 end end
 assert(r>=l and b>=t,'empty charsprite cell')
 return {l,t,r+1,b+1,w,h}
end
function C.frame(spec,action,age,side,view)
 if view=='terarrium-front' or view=='terarrium-back' then
  local row=view=='terarrium-front' and spec.frontRow or spec.backRow
  if row~=nil and row~=false then return spec.idleColumn or 0,row,not action or action=='idle' end
 end
 -- Full-body camera views are opt-in for custom packs. Native throw/command
 -- clips and their hand/release geometry keep their established side view.
 if not action or action=='idle' then
  local row=view=='front' and spec.frontRow or view=='back' and spec.backRow
  if row~=nil and row~=false then return spec.idleColumn or 0,row,true end
 end
 local clips=spec.clips or {}
 local clip=clips[(action or 'idle')..'_'..side] or clips[action or 'idle']
 if clip then
  local elapsed=math.max(0,age or 0)
  if not action or action=='idle' then
   local total=0;for _,f in ipairs(clip)do total=total+f[3]end
   elapsed=elapsed%total
  end
  for _,f in ipairs(clip) do
   if elapsed<f[3] then return f[1],f[2],true end
   elapsed=elapsed-f[3]
  end
 end
 return spec.idleColumn or 0,side=='enemy' and spec.leftRow or spec.rightRow,false
end
for _,id in ipairs({'red','blue','green','gold','silver','kris'}) do
 C.register(id,{path='assets/heroes/'..id..'.png',frontRow=0,backRow=2,rig=rigs[id]})
end
for _,id in pairs(defaults) do
 if not C.characters[id] then
  C.register(id,{path='assets/'..id..'.png',frontRow=0,backRow=2,rig=rigs[id:gsub('trainers/','')]})
 end
end
C.register('trainers/jessie-james',{
 path='assets/trainers/jessie-james.png',columns=1,rows=1,leftRow=0,rightRow=0,
 height=18,width=17,
 rig={[0]={centers={.77},radius={.105},window={.24,.34,.47,.53}}},
 fallbackView='existing front portrait; replacement side-view pack supported',
})
C.trainers.KA_JOHTO_GOLD='gold'
C.trainers.KA_JOHTO_SILVER='silver'
C.trainers.KA_JOHTO_KRIS='kris'
C.trainers.KA_OAK_BETA='trainers/professor-oak'
function C.enemyDefault(battle)
 local trainer=battle.trainer
 if battle.oppClass=='OPP_ROCKET' and (battle.partyIndex or 0)>=42
     and trainer and trainer.picJessieJames then return 'trainers/jessie-james' end
 return C.trainers[battle.oppClass] or 'trainers/youngster'
end
return C
