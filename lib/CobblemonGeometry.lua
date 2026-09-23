-- Bedrock 1.12 cubes -> the existing skinned-mesh format. Data only.
local V=...;local E=V.require('CobblemonExpression');local M={}
local function vector(v,default)
 v=v or default or {0,0,0};assert(type(v)=='table' and #v==3,'invalid vector')
 for _,x in ipairs(v)do assert(type(x)=='number' and x==x and math.abs(x)<=4096,'invalid coordinate')end
 return v
end
local function append(t,v)for _,x in ipairs(v)do t[#t+1]=x end end
function M.build(raw,dex)
 local g=assert(raw['minecraft:geometry'] and raw['minecraft:geometry'][1],'Bedrock geometry missing')
 local desc=assert(g.description);local tw,th=desc.texture_width,desc.texture_height
 assert(type(tw)=='number' and tw>0 and tw<=4096 and type(th)=='number' and th>0 and th<=4096,'texture bounds')
 assert(g.bones and #g.bones<=384,'bone limit')
 local m={species=dex,source='cobblemon',parent={},restT={},restR={},restS={},nodeFlags={},useExactNodeFlags=true,rootScale=1,
  height=24,floor=0,radius=16,prims={},ctx={},anims={},moveAnim={},moveAux={},textures={},boneNames={}}
 local names,defs,pivots={},{},{};local function add(name,parent,pivot,rotation)
  local i=#m.parent+1;assert(i<=1024,'bone limit');m.parent[i]=parent or 0;m.nodeFlags[i]=0
  names[name]=i;pivots[i]=pivot;m.boneNames[i]=name
  local pp=pivots[parent] or {0,0,0};append(m.restT,{pivot[1]-pp[1],pivot[2]-pp[2],pivot[3]-pp[3]})
  local r=rotation or {0,0,0};append(m.restR,{-r[1]*32768/180,r[2]*32768/180,-r[3]*32768/180});append(m.restS,{1,1,1});return i
 end
 add('__vasc_root',0,{0,0,0},{0,180,0}) -- Bedrock faces -Z, VASC +Z.
 for _,b in ipairs(g.bones)do assert(type(b.name)=='string' and not defs[b.name] and b.name~='__vasc_root','duplicate bone');defs[b.name]=b end
 local visiting={};local function bone(name)
  if names[name]then return names[name]end
  assert(not visiting[name],'bone cycle');visiting[name]=true
  local b=assert(defs[name],'unknown parent');local p=b.parent and bone(b.parent) or 1
  local i=add(name,p,vector(b.pivot),vector(b.rotation));visiting[name]=nil;return i
 end
 for _,b in ipairs(g.bones)do bone(b.name)end
 local p={vertCount=0,bone={},px={},py={},pz={},nx={},ny={},nz={},uv={},index={},tex=1,wrapS=2,wrapT=2,tint={255,255,255,255}}
 m.prims[1]=p
 local faces={
  north={{1,2,3,4},{0,0,-1}},south={{6,5,8,7},{0,0,1}},
  west={{5,1,4,8},{-1,0,0}},east={{2,6,7,3},{1,0,0}},
  up={{4,3,7,8},{0,1,0}},down={{5,6,2,1},{0,-1,0}}}
 for _,b in ipairs(g.bones)do
  assert(not b.poly_mesh,'poly_mesh unsupported')
  for ci,c in ipairs(b.cubes or {})do
   local bi=names[b.name];local pivot=pivots[bi]
   if c.rotation then bi=add(b.name..'#cube'..ci,bi,vector(c.pivot),vector(c.rotation));pivot=pivots[bi]end
   local o,s=vector(c.origin),vector(c.size);local inflate=tonumber(c.inflate)or 0
   assert(math.abs(inflate)<=8,'invalid cube') -- signed extents are used by official inner shells
   local x,y,z=o[1]-pivot[1]-inflate,o[2]-pivot[2]-inflate,o[3]-pivot[3]-inflate
   local X,Y,Z=x+s[1]+2*inflate,y+s[2]+2*inflate,z+s[3]+2*inflate
   local points={{x,y,z},{X,y,z},{X,Y,z},{x,Y,z},{x,y,Z},{X,y,Z},{X,Y,Z},{x,Y,Z}}
   local uv=assert(c.uv,'UV missing');local box=type(uv[1])=='number';local rects
   if box then
    local u,v,w,h,d=uv[1],uv[2],s[1],s[2],s[3]
    rects={west={u,v+d,d,h},north={u+d,v+d,w,h},east={u+d+w,v+d,d,h},south={u+2*d+w,v+d,w,h},up={u+d,v,w,d},down={u+d+w,v,w,d}}
   end
   for _,name in ipairs{'north','south','west','east','up','down'}do
    local r=box and rects[name] or uv[name]
    if r then
     local u,v,w,h
     if box then u,v,w,h=unpack(r)else u,v=unpack(r.uv);w,h=unpack(r.uv_size or {s[1],s[2]});assert(not r.uv_rotation or r.uv_rotation==0,'rotated face UV unsupported')end
     if w~=0 and h~=0 then
      local us={u+w,u,u,u+w};local vs={v+h,v+h,v,v}
      if c.mirror or (c.mirror==nil and b.mirror)then us={u,u+w,u+w,u}end
      local f=faces[name];local first=p.vertCount
      for j=1,4 do
       local pos=points[f[1][j]];local k=first+j
       p.bone[k]=bi;p.px[k],p.py[k],p.pz[k]=unpack(pos);p.nx[k],p.ny[k],p.nz[k]=unpack(f[2]);append(p.uv,{us[j]/tw,vs[j]/th})
      end
      append(p.index,{first+1,first+2,first+3,first+1,first+3,first+4});p.vertCount=first+4
      assert(p.vertCount<=32768,'vertex limit')
     end
    end
   end
  end
 end
 assert(p.vertCount>0,'empty mesh');m.boneCount=#m.parent
 m.textureWidth,m.textureHeight=tw,th
 for i=1,20 do m.ctx[i]=65535 end
 for i=1,165 do m.moveAnim[i]=65535;m.moveAux[i]=65535 end
 return m,names
end
local function expressionVector(v,default)
 if type(v)=='number' or type(v)=='string'then v={v,v,v}end
 v=v or default;assert(type(v)=='table' and #v==3,'animation vector')
 return {E.compile(v[1]),E.compile(v[2]),E.compile(v[3])}
end
local function channel(raw,default)
 if raw==nil then return nil end
 if type(raw)~='table' or raw[1]~=nil then return {{t=0,pre=expressionVector(raw,default),post=expressionVector(raw,default)}}end
 local out={};for k,v in pairs(raw)do
  local time=tonumber(k);assert(time and time>=0 and time<=120,'keyframe time')
  local pre=type(v)=='table' and v.pre or v;local post=type(v)=='table' and v.post or v
  if type(v)=='table' and v.pre==nil and v.post then pre=v.post end
  if type(v)=='table' and v.post==nil and v.pre then post=v.pre end
  out[#out+1]={t=time,pre=expressionVector(pre,default),post=expressionVector(post,default),cat=type(v)=='table' and v.lerp_mode=='catmullrom' or nil}
 end
 assert(#out>0 and #out<=1024,'keyframe count');table.sort(out,function(a,b)return a.t<b.t end);return out
end
function M.clip(raw,names)
 local length=raw.animation_length or 2;assert(type(length)=='number' and length>0 and length<=120,'clip length')
 local c={seconds=length,frames=1,channels={},loop=raw.loop==true}
 for name,b in pairs(raw.bones or {})do
  local index=names[name]
  if index then c.channels[tostring(index)]={channel(b.position,{0,0,0}) or false,channel(b.rotation,{0,0,0}) or false,channel(b.scale,{1,1,1}) or false}end
 end
 return c
end
local function evaluate(c,t,axis)
 if t<=c[1].t then return E.value(c[1].pre[axis],t)end
 for i=2,#c do if t<=c[i].t then
  local a,b=c[i-1],c[i];local x=(t-a.t)/(b.t-a.t)
  local p1,p2=E.value(a.post[axis],t),E.value(b.pre[axis],t)
  if a.cat or b.cat then
   local p0=E.value((c[i-2] or a).post[axis],t);local p3=E.value((c[i+1] or b).pre[axis],t)
   return .5*((2*p1)+(-p0+p2)*x+(2*p0-5*p1+4*p2-p3)*x*x+(-p0+3*p1-3*p2+p3)*x*x*x)
  end
  return p1+(p2-p1)*x
 end end
 return E.value(c[#c].post[axis],t)
end
function M.sample(model,index,frame,wrap)
 local c=model.anims[index];if not c then return nil end
 local t=math.max(0,frame/30);t=wrap and t%c.seconds or math.min(t,c.seconds)
 local out=model._sample
 if not out then out={};for i=1,model.boneCount do out[i]={0,0,0,0,0,0,1,1,1}end;model._sample=out end
 for i=1,model.boneCount do
  local o=(i-1)*3;local row=out[i];local ch=c.channels[tostring(i)]
  for a=1,3 do
   row[a]=model.restT[o+a]+(ch and ch[1] and evaluate(ch[1],t,a) or 0)
   row[a+3]=model.restR[o+a]+(ch and ch[2] and evaluate(ch[2],t,a)*32768/180*(a==2 and 1 or -1) or 0)
   row[a+6]=model.restS[o+a]*(ch and ch[3] and evaluate(ch[3],t,a) or 1)
   assert(row[a]==row[a] and math.abs(row[a])<10000 and row[a+3]==row[a+3] and math.abs(row[a+3])<1e8 and row[a+6]==row[a+6] and math.abs(row[a+6])<100,'invalid animation sample')
  end
 end
 return out
end
return M
