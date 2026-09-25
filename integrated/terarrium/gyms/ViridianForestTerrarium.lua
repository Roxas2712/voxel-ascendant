-- Viridian Forest: compact open woodland diorama for integration by PANDY.
-- Visual direction: ODias, based on the three forest references supplied.
-- Reuse the host bowl, camera, participants, trainer plinths and branding.
local R={revision='viridian-forest-compact-v1'}
function R.appliesTo(mapId)return mapId=='VIRIDIAN_FOREST'end
local black={.10,.16,.09}
local wood={.31,.23,.12}
-- No badge: keep the host bowl's plain button.
function R.button(h)end
function R.build(h,setup)
 local box,quad=h.box,h.quad
 local function rect(x,z,w,d,y,c)
  quad({x-w/2,y,z-d/2},{x+w/2,y,z-d/2},{x+w/2,y,z+d/2},{x-w/2,y,z+d/2},c)
 end
 local function clear(x,z,w,d)
  for _,p in pairs(setup.trainers)do
   if math.abs(p[1]-x)<w/2+8 and math.abs(p[3]-z)<d/2+8 then return false end
  end
  for _,p in pairs(setup.actors)do
   if math.abs(p[1]-x)<w/2+11 and math.abs(p[3]-z)<d/2+10 then return false end
  end
  return true
 end
 local function disk(x,y,z,r,c,N)
  N=N or 16
  for i=0,N-1 do local a,b=i*2*math.pi/N,(i+1)*2*math.pi/N
   quad({x,y,z},{x+math.cos(a)*r,y,z+math.sin(a)*r},{x+math.cos(b)*r,y,z+math.sin(b)*r},{x,y,z},c)
  end
 end
 local grass={.31,.46,.16}
 local moss={.37,.49,.19}
 local leaf={.20,.36,.12}
 local litLeaf={.32,.47,.16}
 local earth={.45,.34,.19}
 local bark={.34,.25,.13}
 local cutWood={.65,.52,.29}
 local rock={.37,.42,.34}
 local function blob(x,y,z,rx,ry,rz,c,n,rings)
  n=n or 10;rings=rings or 5
  for j=0,rings-1 do local a,b=-math.pi/2+j*math.pi/rings,-math.pi/2+(j+1)*math.pi/rings
   for i=0,n-1 do local u,v=i*2*math.pi/n,(i+1)*2*math.pi/n
    local function p(t,s)return{x+rx*math.cos(s)*math.cos(t),y+ry*math.sin(s),z+rz*math.cos(s)*math.sin(t)}end
    quad(p(u,a),p(v,a),p(v,b),p(u,b),c,.79+.14*math.cos(u-.5)+.06*math.sin(a))
   end
  end
 end
 local function cylinder(x,y,z,r,height,c,n)
  n=n or 12
  disk(x,y+height,z,r,c,n)
  for i=0,n-1 do local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
   quad({x+r*math.cos(a),y,z+r*math.sin(a)},{x+r*math.cos(b),y,z+r*math.sin(b)},
    {x+r*math.cos(b),y+height,z+r*math.sin(b)},{x+r*math.cos(a),y+height,z+r*math.sin(a)},c,.8+.15*math.cos(a))
  end
 end
 local function patch(x,z,r,c,k,y)
  k=k or 8;y=y or .033
  local p={}
  for i=0,k-1 do local a=i*math.pi*2/k;local rr=r*(.80+((i*7+3)%5)*.05)
   p[#p+1]={x+math.cos(a)*rr,y,z+math.sin(a)*rr}
  end
  for i=1,k do quad({x,y,z},p[i],p[i%k+1],{x,y,z},c)end
 end
 disk(0,.02,0,73.5,grass,96)
 -- Irregular low colour patches produce grass variation without a tiled-room grid.
 for x=-63,63,9 do for z=-63,63,9 do
  if x*x+z*z<65^2 then
   local index=(math.floor(x/9)*3+math.floor(z/9)*7+200)%5
   local c=({{.30,.45,.15},{.32,.47,.17},{.33,.47,.17},{.30,.44,.15},{.32,.46,.16}})[index+1]
   patch(x+math.sin(x*3+z)*3,z+math.sin(z*2+x)*3,7.8,c,7,.031+index*.0005)
  end
 end end
 -- A winding central dirt trail broadens into a clearing and forks towards the rear.
 local function pathStrip(x1,z1,x2,z2,w1,w2)
  local dx,dz=x2-x1,z2-z1;local d=math.sqrt(dx*dx+dz*dz);local nx,nz=-dz/d,dx/d
  quad({x1+nx*w1,.043,z1+nz*w1},{x2+nx*w2,.043,z2+nz*w2},
   {x2-nx*w2,.043,z2-nz*w2},{x1-nx*w1,.043,z1-nz*w1},earth)
 end
 local path={{0,72,7.8},{-4,50,9},{-1,26,10.5},{4,3,12},{2,-20,11},{-3,-42,8.5},{0,-63,7}}
 for i=1,#path-1 do local a,b=path[i],path[i+1];pathStrip(a[1],a[2],b[1],b[2],a[3],b[3])end
 patch(1,-7,18,earth,11,.045)
 pathStrip(0,-23,-44,-39,7,5);pathStrip(0,-23,45,-42,7,5)
 for i=0,20 do local z=-60+i*6;local x=math.sin(i*2.4)*5
  patch(x,z,1.3+(i%3)*.45,({{.48,.38,.23},{.41,.31,.18},{.51,.40,.24}})[i%3+1],6,.048)
 end
 -- Layered rear trees frame the clearing, leaving the central sky open.
 local function tree(x,z,h,r,seed)
  cylinder(x,.04,z,2.5,h*.68,bark,10)
  for i=0,3 do local a=i*math.pi/2+seed*.3
   local dx,dz=math.cos(a),math.sin(a)
   quad({x-dz*.7,.07,z+dx*.7},{x+dz*.7,.07,z-dx*.7},{x+dx*6,.07,z+dz*6},{x,4.3,z},bark,.88)
  end
  for i=0,2 do local a=i*2*math.pi/3+seed
   local bx,bz=x+math.cos(a)*3,z+math.sin(a)*3
   box(bx,h*.46,bz,1.5,5,1.5,bark)
  end
  blob(x-r*.37,h*.67,z+1.2,r*.81,h*.22,r*.72,leaf,12,4)
  blob(x+r*.36,h*.75,z-.8,r*.77,h*.22,r*.73,litLeaf,12,4)
  blob(x,h*.86,z+.9,r*.74,h*.22,r*.77,{.29,.43,.14},12,4)
  for i=0,4 do local a=i*math.pi*2/5+seed
   blob(x+math.cos(a)*r*.65,h*.75+(i%2)*2,z+math.sin(a)*r*.65,r*.34,2.8,r*.33,(i%2==0)and litLeaf or leaf,8,3)
  end
 end
 tree(-12,-64,23,8,8);tree(12,-64,24,8,9)
 tree(-35,-53,22,8,10);tree(35,-53,23,8,11)
 tree(0,-64,32,10,1)
 tree(-24,-56,28,11,2);tree(24,-56,30,11,3)
 tree(-46,-42,26,10,4);tree(46,-42,25,10,5)
 tree(-67,-9,22,5.7,6);tree(67,-9,23,5.7,7)
 -- Bushes and rock groups are kept at the edge of the shared actor area.
 local function shrub(x,z,s)
  if not clear(x,z,8*s,8*s)then return end
  blob(x,2.2*s,z,4.3*s,2.7*s,3.8*s,leaf,10,4)
  blob(x-1.5*s,3.6*s,z-.5*s,3*s,2.5*s,3.1*s,litLeaf,10,4)
  blob(x+1.8*s,2.9*s,z+1.5*s,2.8*s,2*s,2.6*s,moss,10,4)
 end
 for _,p in ipairs({{-36,-56,1.2},{36,-56,1.2},{-58,-33,1.2},{58,-33,1.2},{-64,13,.8},{64,13,.8},
  {-12,-60,1.1},{12,-60,1.1},{-52,-25,1.0},{52,-25,1.0},
  {-56,43,1},{56,43,1},{-39,54,.8},{39,54,.8},{-22,62,.7},{22,62,.7}})do shrub(p[1],p[2],p[3])end
 local function boulder(x,z,s)
  if not clear(x,z,8*s,7*s)then return end
  blob(x,2.3*s,z,4*s,3*s,3.4*s,rock,7,3)
  blob(x-.5*s,4.2*s,z-.1*s,3.3*s,.8*s,2.8*s,moss,7,3)
 end
 boulder(-42,-36,1.3);boulder(-35,-40,.8);boulder(43,31,.7)
 boulder(54,3,.6);boulder(-37,28,.55);boulder(31,56,.65)
 -- Tall grass patches with folded blades, never over the participant anchors.
 local function grassPatch(x,z,cols,rows)
  for i=1,cols do for j=1,rows do
   local px=x+(i-(cols+1)/2)*2.9;local pz=z+(j-(rows+1)/2)*2.9
   if clear(px,pz,1.8,1.8)then
    local h=2.3+((i*7+j*3)%5)*.33
    for k=0,2 do local a=k*math.pi*2/3+(i+j)*.7;local dx,dz=math.cos(a),math.sin(a)
     local base1={px-dz*.52,.045,pz+dx*.52};local base2={px+dz*.52,.045,pz-dx*.52}
     local tip={px+dx*1.2,h,pz+dz*1.2}
     quad(base1,base2,tip,base1,({{.26,.48,.18},{.35,.56,.19},{.39,.57,.22}})[k+1])
    end
   end
  end end
 end
 grassPatch(-35,-18,7,6);grassPatch(35,-17,7,6)
 grassPatch(-48,29,7,7);grassPatch(48,28,7,7)
 grassPatch(-39,-50,6,3);grassPatch(39,-50,6,3)
 grassPatch(-22,-55,5,3);grassPatch(24,-55,5,3)
 grassPatch(-39,52,4,3);grassPatch(39,51,4,3)
 -- Wooden fences, low enough to keep the view into the clearing.
 local function fence(x,z1,z2)
  for z=z1,z2,8 do
   cylinder(x,.04,z,1.0,4.7,wood,8);disk(x,4.76,z,.95,cutWood,8)
  end
  box(x,2.4,(z1+z2)/2,1.2,1.0,z2-z1,wood)
 end
 fence(-27,23,47);fence(27,23,47)
 for _,s in ipairs({-1,1})do
  if clear(s*20,-39,12,2)then
   for _,x in ipairs({s*15,s*25})do cylinder(x,.04,-39,.8,3.8,wood,8)end
   box(s*20,2.4,-39,10,.65,.65,wood)
  end
 end
 -- A trail sign from the in-game reference; geometric marks avoid illegible text.
 cylinder(13,.04,-52,.7,6.1,wood,8)
 box(13,5.7,-52,7.7,4.7,1,wood)
 box(13,6.2,-51.4,6.5,3.6,.15,{.67,.57,.34})
 for y=6.9,8.7,.8 do box(13,y,-51.26,4.8,.13,.10,{.41,.34,.20})end
 -- Tree stumps and a fallen log retain the forest's cut-wood details.
 local function stump(x,z,r)
  if not clear(x,z,r*2,r*2)then return end
  cylinder(x,.04,z,r,3.5,bark,12);disk(x,3.56,z,r*.86,cutWood,12)
  for i=0,15 do local a,b=i*math.pi/8,(i+1)*math.pi/8
   local function p(rr,t)return{x+rr*math.cos(t),3.58,z+rr*math.sin(t)}end
   quad(p(r*.48,a),p(r*.48,b),p(r*.56,b),p(r*.56,a),{.45,.34,.18})
  end
 end
 stump(-57,29,2.5);stump(55,20,2.3);stump(-30,55,2)
 local lx,lz=48,41
 if clear(lx,lz,12,5)then
  for i=0,9 do local a,b=i*math.pi/5,(i+1)*math.pi/5
   local function p(xx,t)return{xx,2+1.9*math.cos(t),lz+1.9*math.sin(t)}end
   quad(p(lx-5,a),p(lx+5,a),p(lx+5,b),p(lx-5,b),bark,.82+.12*math.cos(a))
   quad({lx-5.03,2,lz},{lx-5.03,2+1.7*math.cos(a),lz+1.7*math.sin(a)},
    {lx-5.03,2+1.7*math.cos(b),lz+1.7*math.sin(b)},{lx-5.03,2,lz},cutWood)
  end
 end
 -- Fern silhouettes and leaf litter stay low, as surface details.
 for _,p in ipairs({{-58,7},{58,7},{-50,47},{50,47},{-19,-59},{18,-60}})do
  if clear(p[1],p[2],6,6)then
   for i=0,5 do local a=i*math.pi/3;local dx,dz=math.cos(a),math.sin(a)
    quad({p[1],.2,p[2]},{p[1]+dx*2-dz*.7,1.5,p[2]+dz*2+dx*.7},
     {p[1]+dx*4,.3,p[2]+dz*4},{p[1]+dx*2+dz*.7,1.5,p[2]+dz*2-dx*.7},{.24,.43,.17})
   end
  end
 end
 for i=0,31 do
  local a=i*2.39996;local r=32+(i%6)*5.5;local x,z=math.cos(a)*r,math.sin(a)*r
  patch(x,z,.7,({{.47,.47,.20},{.43,.37,.16},{.34,.42,.14}})[i%3+1],5,.052)
 end
end
return R
