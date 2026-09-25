-- Authored portable diorama geometry. No map, battle, party or save mutations.
return function(api)
 local G,M=api.Voxel3D,api.Mat4
 local S={};local cache,order={},{};local brandTexture,brandMesh;local lightMesh,lightTexture,lightPixels
 local seenBattles=setmetatable({},{__mode='k'})
 local idleBattle,idleSince,lastCursor=nil,nil,nil;local idleAllowed=false;local lastImpact
 local palettes={
  forest={{.36,.60,.23},{.23,.42,.14}},grass={{.48,.66,.29},{.30,.47,.17}},
  cave={{.37,.34,.40},{.23,.21,.27}},gym={{.75,.67,.51},{.48,.44,.35}},
  coast={{.78,.71,.48},{.14,.49,.60}},ice={{.65,.80,.85},{.34,.56,.69}},
  city={{.58,.60,.57},{.35,.40,.38}},interior={{.63,.48,.33},{.38,.29,.22}},
  tower={{.38,.29,.44},{.23,.19,.30}},industrial={{.43,.49,.50},{.23,.29,.30}},
  ship={{.62,.41,.23},{.34,.22,.13}},safari={{.64,.62,.30},{.35,.47,.21}}
 }
 local gymThemes={PEWTER_GYM='rock',CERULEAN_GYM='water',VERMILION_GYM='electric',
 CELADON_GYM='garden',FUCHSIA_GYM='poison',SAFFRON_GYM='psychic',CINNABAR_GYM='fire',VIRIDIAN_GYM='earth',FIGHTING_DOJO='dojo'}
 local gymPalettes={water={{.62,.76,.78},{.15,.47,.66}},electric={{.55,.59,.57},{.77,.62,.20}},
 garden={{.47,.66,.31},{.21,.41,.16}},poison={{.47,.43,.52},{.40,.26,.47}},
 psychic={{.62,.48,.66},{.39,.29,.46}},fire={{.46,.36,.29},{.69,.22,.10}},
 earth={{.64,.53,.32},{.37,.31,.20}},dojo={{.72,.61,.43},{.40,.26,.14}} }
 local function hash(id)local n=17;for i=1,#id do n=(n*31+id:byte(i))%104729 end;return n end
 local function now()return api.clock and api.clock()or 0 end
 function S.activity(battle)
  local ready=battle and battle.phase=='menu' and not battle.current and not battle.sendingOut
   and not battle.enemySendingOut and not battle.animPlaying and not battle.showPlayerBack
  ready=ready and (not api.idleEnabled or api.idleEnabled())
  if battle then seenBattles[battle]=seenBattles[battle]or'active' end
  local input=battle and battle.game and battle.game.input
  if input and input.down and next(input.down)then ready=false end
  local cursor=battle and battle.menuIndex
  if battle~=idleBattle or cursor~=lastCursor or not ready then idleSince=now();if lastImpact and api.stopIdleSound then api.stopIdleSound()end;lastImpact=nil end
  idleBattle,lastCursor,idleAllowed=battle,cursor,ready==true
  if ready and not idleSince then idleSince=now();if lastImpact and api.stopIdleSound then api.stopIdleSound()end;lastImpact=nil end
 end
 function S.idleSample()
  if not idleAllowed or not idleSince then return 0,0 end
  local elapsed=now()-idleSince
  if elapsed<9 then return 0,0 end
  local t=elapsed-9
  local beat=math.floor(t/.56);local phase=(t/.56)-beat
  local envelope=math.sin(math.pi*phase)^2
  return (beat%2==0 and 1 or -1)*.075*envelope,envelope,t
 end
 function S.endBattle(battle,result)
  if not battle or seenBattles[battle]~='active'then return false end
  seenBattles[battle]='ended';idleAllowed=false;idleSince=nil;lastImpact=nil
  if api.stopIdleSound then api.stopIdleSound()end
  local won=(result or battle.result or battle.outcome)=='win'
  local versus=battle.kind=='trainer' or battle.kind=='link'
    or (battle.kind==nil and battle.wild==false)
  if won and versus and not battle.demo and api.playFanfare then api.playFanfare(battle)end
  return true
 end
 function S.cameraMode()return api.cameraMode and api.cameraMode()or "side"end
 function S.setup(map,cameraMode)
  local style=api.resolveStyle(map,nil);local family=style.id
  if family=='league_ice'or family=='johto_crystal'then family='ice'
  elseif family=='league_ghost'then family='tower'
  elseif family=='league_rock'or family=='moon_approach'or family=='moon_exit'then family='cave'
  elseif family=='route2_gate'then family='grass'
  elseif family=='rock_water'or family=='cape'or family=='cerulean_canal'then family='coast'
  elseif family=='rocket'then family='industrial'
  elseif family:find('league')or family:find('johto')then family='gym'
  elseif family=='mansion'then family='interior' end
  if not palettes[family]then family='grass'end
  local id=tostring(map and map.id or 'UNKNOWN');local design=api.gymDesign and api.gymDesign(id)
  if design then family=design.family or 'gym' end
  local behind=(cameraMode or S.cameraMode())=='behind'
  return {gymDesign=design,ballStyle=api.ballStyle and api.ballStyle(map)or'poke',id=id,family=family,theme=gymThemes[id],orientation='horizontal',cameraMode=behind and 'behind' or 'side',seed=hash(id),
   radius=74,actors=behind and {player={0,0,20},enemy={0,0,-20}}or{player={-25,0,0},enemy={25,0,0}},
   trainers=behind and {player={-19,2.4,46},enemy={19,2.4,-40}}or{player={-53,2.4,12},enemy={53,2.4,-12}}}
 end
 local function build(setup)
  local verts,indices,colors,colorIds={},{},{},{}
  local occluders={};local collect=false
  local function color(c)
   local key=string.format('%.3f:%.3f:%.3f',c[1],c[2],c[3]);local id=colorIds[key]
   if not id then id=#colors+1;assert(id<=256);colors[id]=c;colorIds[key]=id end
   return (id-.5)/256
  end
  local function quad(a,b,c,d,tone,shade)
   local u=color(tone);local n=#verts
   for _,p in ipairs({a,b,c,d})do verts[#verts+1]={p[1],p[2],p[3],u,.5/257,shade or 1}end
   for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=n+i end
  end
  local function box(x,y,z,w,h,d,c)
   if collect then occluders[#occluders+1]={x,y,z,w,h,d}end
   local a,b=x-w/2,x+w/2;local e,f=z-d/2,z+d/2;local t=y+h
   quad({a,t,e},{b,t,e},{b,t,f},{a,t,f},c,1)
   quad({a,y,f},{b,y,f},{b,t,f},{a,t,f},c,.83)
   quad({b,y,e},{a,y,e},{a,t,e},{b,t,e},c,.62)
   quad({b,y,f},{b,y,e},{b,t,e},{b,t,f},c,.9)
   quad({a,y,e},{a,y,f},{a,t,f},{a,t,e},c,.7)
  end
  local white,black,red={.93,.90,.83},{.075,.08,.09},{.68,.13,.12}
  local pal=gymPalettes[setup.theme] or palettes[setup.family];local top,alt=pal[1],pal[2]
  local appearance=api.ballAppearance and api.ballAppearance(setup.ballStyle)
  local accent=appearance and appearance.accent or (setup.ballStyle=='great'and{.94,.12,.085}or{1,.78,.035})
  local N=96
  local function ring(r0,y0,r1,y1,c,striped)
   for i=0,N-1 do local a,b=i*2*math.pi/N,(i+1)*2*math.pi/N
    quad({math.cos(a)*r0,y0,math.sin(a)*r0},{math.cos(b)*r0,y0,math.sin(b)*r0},
     {math.cos(b)*r1,y1,math.sin(b)*r1},{math.cos(a)*r1,y1,math.sin(a)*r1},(striped and setup.ballStyle~='poke' and math.abs(math.cos(a))>.83)and accent or c,.72+.24*(.5+.5*math.sin(a+.8)))
   end
  end
  -- Rounded porcelain body with bevelled lacquer rim and a recessed inner lip.
  for j=0,11 do local a,b=j*math.pi/24,(j+1)*math.pi/24
   local t=.80+j*.012;ring(77*math.sin(a),-72*math.cos(a)-5,77*math.sin(b),-72*math.cos(b)-5,{t,t*.985,t*.96})end
  ring(77,-5,77.5,-3,black);ring(77.5,-3,77.5,2.6,black)
  local rim=appearance and appearance.base or (setup.ballStyle=='great'and{.12,.34,.72}or setup.ballStyle=='ultra'and{.09,.10,.12}or red)
  ring(77.5,2.6,77,3.7,rim,true);ring(77,3.7,74.4,3.7,rim,true)
  ring(74.4,3.7,73.7,2.5,rim,true);ring(73.7,2.5,73.7,0,black)
  ring(76.9,3.72,76.55,3.72,{.89,.57,.38})
  ring(74.1,1.0,73.7,1.0,{.50,.43,.29})
  local shellVerts,shellIndices=verts,indices;verts,indices={},{};collect=true
  for i=0,N-1 do local a,b=i*2*math.pi/N,(i+1)*2*math.pi/N
   local n=#verts
   for _,p in ipairs({{0,0,0},{math.cos(a)*74,0,math.sin(a)*74},{math.cos(b)*74,0,math.sin(b)*74}})do
    verts[#verts+1]={p[1],p[2],p[3],math.max(.5/256,math.min(255.5/256,p[1]/148+.5)),(1.5+(p[3]/148+.5)*255)/257,1}
   end
   indices[#indices+1]=n+1;indices[#indices+1]=n+2;indices[#indices+1]=n+3
  end
  local stoneTones={{.43,.44,.43},{.50,.51,.49},{.57,.57,.53},{.64,.63,.58}}
  local scenery=setup.gymDesign
  if scenery then
   scenery.build({box=box,quad=quad},setup)
  else
  -- Ground flecks remain deterministic per map and never cover the actor feet.
  local n=setup.seed
  local function rand() n=(n*48271)%2147483647;return n/2147483647 end
  for i=1,240 do local x,z=(rand()*2-1)*71,(rand()*2-1)*71
   if x*x+z*z<70*70 and not(setup.family=='gym' and math.abs(x)<42 and math.abs(z)<26)then local w=rand()*.65+.25
    quad({x,.025,z},{x+w,.025,z},{x+w,.025,z+w},{x,.025,z+w},alt,.8)end
  end
  -- Pokeball inlay: a single continuous battlefield within the same bowl.
  for i=0,63 do local a,b=i*math.pi/32,(i+1)*math.pi/32
   quad({math.cos(a)*18,.07,math.sin(a)*18},{math.cos(b)*18,.07,math.sin(b)*18},
    {math.cos(b)*19,.07,math.sin(b)*19},{math.cos(a)*19,.07,math.sin(a)*19},white)
  end
  if setup.orientation=='horizontal' then box(0,.04,0,.65,.04,48,white) else box(0,.04,0,62,.04,.65,white) end;box(0,.045,0,5,.04,5,white)
  if setup.family=='gym' then
   for _,x in ipairs({-43,43})do for z=-26,26,4 do box(x,0,z,2,.45,3.8,{.48,.49,.48})end end
   for _,z in ipairs({-26,26})do for x=-40,40,4 do box(x,0,z,3.8,.45,2,{.57,.58,.56})end end
   for _,x in ipairs({-41,41})do box(x,.04,0,.7,.05,49,white)end
   for _,z in ipairs({-24,24})do box(0,.04,z,83,.05,.7,white)end
  end
  local function rock(x,z,scale,y)
   y=y or 0
   local unit=1.5*scale
   local function occupied(i,j,k)
    return j>=0 and j<=6 and (i/4.4)^2+((j-1.5)/4.8)^2+(k/3.6)^2<1
   end
   local shades={{.34,.35,.39},{.43,.44,.47},{.54,.55,.56},{.66,.67,.65}}
   for i=-4,4 do for j=0,6 do for k=-3,3 do
    if occupied(i,j,k)then
     local ax,bx=x+i*unit,x+(i+1)*unit;local ay,by=y+j*unit,y+(j+1)*unit;local az,bz=z+k*unit,z+(k+1)*unit
     local c=shades[(i*7+j*3+k*11+100)%4+1]
     if not occupied(i,j+1,k)then quad({ax,by,az},{bx,by,az},{bx,by,bz},{ax,by,bz},c)end
     if not occupied(i,j,k+1)then quad({ax,ay,bz},{bx,ay,bz},{bx,by,bz},{ax,by,bz},c,.82)end
     if not occupied(i,j,k-1)then quad({bx,ay,az},{ax,ay,az},{ax,by,az},{bx,by,az},c,.62)end
     if not occupied(i+1,j,k)then quad({bx,ay,bz},{bx,ay,az},{bx,by,az},{bx,by,bz},c,.9)end
     if not occupied(i-1,j,k)then quad({ax,ay,az},{ax,ay,bz},{ax,by,bz},{ax,by,az},c,.7)end
    end
   end end end
  end
  local greens={{.19,.40,.13},{.28,.53,.16},{.43,.68,.20},{.63,.81,.31}}
  local function bush(x,y,z,size)
   for i=-1,1 do for j=-1,1 do
    local h=(2+(i+j+4)%3)*size
    box(x+i*size*2,y,z+j*size*2,size*2.1,h,size*2.1,greens[(i-j+6)%4+1])
   end end
  end
  local function tree(x,z,scale,y)
   y=y or 0;local bark={.32,.20,.10};local lightBark={.47,.31,.15}
   box(x,y,z,3*scale,17*scale,3*scale,bark)
   for _,d in ipairs({-1,1})do
    box(x+d*2*scale,y,z,3*scale,2*scale,4*scale,bark)
    box(x+d*3*scale,y+10*scale,z,5*scale,2*scale,2*scale,lightBark)
   end
   box(x-.8*scale,y+2*scale,z+1.55*scale,.65*scale,10*scale,.12*scale,lightBark)
   -- Interlocking crowns, each with a stepped silhouette and small leaf clusters.
   for _,c in ipairs({{-5,14,-2,9},{4,15,-3,10},{-1,17,4,12},{0,23,-1,9}})do
    local cx,cy,cz,w=x+c[1]*scale,y+c[2]*scale,z+c[3]*scale,c[4]*scale
    box(cx,cy,cz,w,3*scale,w,greens[1]);box(cx,cy+3*scale,cz,w*.9,3*scale,w*.91,greens[2])
    box(cx-scale,cy+6*scale,cz-scale,w*.65,2*scale,w*.65,greens[3])
    for k=1,5 do local dx=(rand()-.5)*w*.8;local dz=(rand()-.5)*w*.8
     box(cx+dx,cy+7.5*scale,cz+dz,2.1*scale,scale,2.1*scale,greens[k%3+2])
    end
   end
  end
  local function terrace(x,z,w,d,h,grass)
   box(x,0,z,w,h,d,{.41,.30,.17})
   box(x,h-.2,z,w+.4,1,d+.4,grass or top)
   for i=1,5 do box(x-w*.4+i*w*.13,h*.45,z+d/2+.03,1.2,1.2,.15,{.65,.54,.35})end
  end
  local function stairs(x,z,w,stone)
   for k=0,3 do box(x,0,z-k*2,w,1.5+k*1.5,2,stone or {.60,.61,.60})end
  end
  local function crystal(x,z,y,col)
   y=y or 0;col=col or {.56,.77,.88}
   for k=-1,1 do
    local h=11-math.abs(k)*4
    box(x+k*3,y,z,2.8,h,3,col)
    box(x+k*3,y+h,z,1.4,2,1.5,{.81,.91,.95})
   end
  end
  local function flowers(x,z,col)
   for i=0,4 do local dx=(i%3)*2.3;local dz=math.floor(i/3)*3
    box(x+dx,0,z+dz,.5,2,.5,greens[2]);box(x+dx,2,z+dz,1.4,.65,1.4,col)
   end
  end
  local function bench(x,z)
   if setup.family=='gym'then
    -- Low three-row bleachers. No backrest wall or tall grandstand.
    local outward=z<0 and -1 or 1
    local seat=setup.theme=='water'and{.65,.81,.86}or setup.theme=='garden'and{.56,.41,.25}or{.62,.61,.56}
    for row=0,2 do
     box(x,0,z+outward*row*2.5,20,1.15+row*1.2,2.4,{.36,.38,.38})
     local tone={seat[1]+(.06-row*.04),seat[2]+(.06-row*.04),seat[3]+(.06-row*.04)}
     box(x,1.15+row*1.2,z+outward*row*2.5,20,.4,2.25,tone)
     for k=-4,4 do box(x+k*2,1.56+row*1.2,z+outward*row*2.5,.12,.025,2.1,{.40,.42,.41})end
    end
    return
   end
   for _,dx in ipairs({-5,5})do box(x+dx,0,z,1,3,4,{.20,.23,.23})end
   for k=0,2 do box(x,3,z-2+k*1.5,14,.6,1.2,{.55,.35,.16})end
   box(x,5,z-3,14,3,.8,{.62,.40,.20})
  end
  local function masonry(x,y,z,w,h,d)
   box(x,y,z,w,h,d,stoneTones[1])
   local courses=math.max(1,math.floor(h/2.6));local blocks=math.max(1,math.floor(w/4))
   for row=0,courses-1 do for col=0,blocks-1 do
    local bw=w/blocks;local ch=h/courses
    box(x-w/2+(col+.5)*bw,y+row*ch+.12,z+d/2+.09,bw-.23,ch-.22,.25,stoneTones[(row*3+col)%4+1])
   end end
   box(x,y+h,z,w+.7,.65,d+.7,stoneTones[4])
  end
  local function tuft(x,z,y,size)
   for k=-1,1 do box(x+k*size*.7,y,z+(k%2)*size*.4,.45*size,(1.1+(k%2)*.6)*size,.45*size,greens[k+3])end
  end
  local function pebbleBed(x,z,w,d)
   for k=1,18 do local px=x+(rand()-.5)*w;local pz=z+(rand()-.5)*d
    box(px,.08,pz,.5+rand()*.8,.2+rand()*.4,.6+rand()*.6,stoneTones[k%4+1])
   end
  end
  local wildGreen=setup.family=='forest'or setup.family=='grass'or setup.family=='safari'
  if wildGreen then
   -- Two raised banks frame the opening; every encounter shares clear feet.
   for _,x in ipairs({-40,40})do
    terrace(x,-41,24,22,7,top);tree(x,-43,1.05,8)
    terrace(x*1.60,-20,10,12,3,top);tree(x*1.60,-24,.62,4)
    stairs(x*.66,-28,9);bush(x,-0.2,-25,1.4)
    rock(x*1.3,24,.7);bush(x*1.55,0,12,.75)
    flowers(x*.8,35,{.89,.68,.30});bush(x*1.16,0,37,1)
   end
   for i=-2,2 do bush(i*10,0,-58,1.55);if i%2==0 then tree(i*10,-60,.8)end end
   for _,x in ipairs({-15,15})do bush(x,0,60,1);flowers(x-4,53,{.87,.56,.62})end
  elseif setup.family=='cave'or setup.family=='ice'or setup.family=='tower'then
   for i=-3,3 do
    local x=i*15;local z=-math.sqrt(61*61-x*x)
    local h=10+(3-math.abs(i))*4
    if i~=0 then
     box(x,0,z,16,h,13,alt);box(x-1,h,z,13,4,11,top)
     for k=0,3 do box(x-6+k*4,4+(k%2)*5,z+6.7,3,3,1,{.47,.45,.50})end
     if i%2==0 then crystal(x,z,h+4)end
    end
   end
   box(-10,0,-60,9,22,9,alt);box(10,0,-60,9,22,9,alt);box(0,20,-60,29,7,10,alt)
   box(0,0,-64,11,20,1,{.06,.06,.09})
   for _,x in ipairs({-53,53})do rock(x*1.18,8,.85);rock(x,30,.7);crystal(x*.40,48);stairs(x*.7,-25,9)end
   for _,x in ipairs({-22,22})do rock(x,55,.6);crystal(x,58)end
  elseif setup.family=='gym' and setup.theme=='rock'then
   -- A miniature stone amphitheatre: raised rear podium, paired stairs,
   -- stepped perimeter terraces and exhibits, composed around clear actor lanes.
   masonry(0,0,-51,48,8,19);masonry(0,8,-56,24,2.6,11)
   stairs(0,-34,13);stairs(-34,-34,9);stairs(34,-34,9)
   rock(0,-56,1.55,11.4)
   for _,side in ipairs({-1,1})do
    masonry(side*31,0,-47,13,5,17);rock(side*31,-48,.8,5.7)
    masonry(side*53,0,-32,13,5,16);rock(side*53,-33,.92,5.7)
    masonry(side*64,0,-8,9,3,12);pebbleBed(side*62,-8,8,11)
    masonry(side*54,0,34,14,4,14);rock(side*54,34,.88,4.7)
    masonry(side*31,0,54,13,3,9);rock(side*31,53,.62,3.7)
    bench(side*35,40);bench(side*41,-28)
    pebbleBed(side*47,-13,9,12);pebbleBed(side*46,18,8,12)
    for i=1,6 do local xx=side*(37+i*3);local zz=-math.sqrt(69^2-xx^2)
     masonry(xx,0,zz,4,2,5)
    end
    for _,z in ipairs({-23,27,46})do tuft(side*(z==46 and 42 or 57),z,0,.85)end
   end
   -- Warm inset tiles with actual fine grout, bounded by dressed stone.
   for x=-38,38,8 do for z=-20,20,8 do
    local c=((x+z)%3==0)and{.73,.63,.44}or{.76,.66,.48}
    quad({x-3.88,.028,z-3.88},{x+3.88,.028,z-3.88},{x+3.88,.028,z+3.88},{x-3.88,.028,z+3.88},c)
   end end
  elseif setup.family=='gym'then
   for _,x in ipairs({-29,29})do
    bench(x*1.2,-39);bench(x*1.2,40)
    box(x,0,-53,15,4,12,{.46,.47,.46});box(x,4,-53,14,1,11,{.67,.67,.64})
    if setup.theme=='garden'then tree(x,-53,.8,5)
    elseif setup.theme=='water'then crystal(x,-53,5)
    elseif setup.theme=='electric'then
     box(x,5,-53,4,14,4,{.24,.28,.29});for j=0,2 do box(x,8+j*4,-53,7,1.5,7,{.84,.68,.20})end
    elseif setup.theme=='fire'then
     rock(x,-53,.8,5);box(x,17,-53,3,5,3,{.95,.42,.08});box(x,19,-53,1.5,5,1.5,{1,.76,.16})
    elseif setup.theme=='psychic'or setup.theme=='poison'then crystal(x,-53,5,{.66,.43,.81})
    else rock(x,-53,1,5)end
   end
   box(0,0,-60,20,5,10,{.47,.47,.44});stairs(0,-47,10)
   if setup.theme=='water'or setup.theme=='fire'then
    local water=setup.theme=='water' and {.16,.51,.68}or setup.theme=='poison'and{.40,.24,.48}or{.79,.24,.07}
    for _,z in ipairs({-30,30})do box(0,.02,z,84,.08,6,water)
     for x=-36,36,9 do box(x,.12,z,4,.03,.35,setup.theme=='fire'and{1,.60,.07}or{.59,.78,.82})end end
   elseif setup.theme=='garden'then
    for _,z in ipairs({-31,31})do for x=-33,33,11 do bush(x,0,z,1.2);flowers(x+3,z,{.89,.54,.67})end end
   else for _,x in ipairs({-59,59})do rock(x,-32,.65);rock(x,31,.6)end end
  elseif setup.family=='coast'then
   for _,x in ipairs({-45,45})do
    terrace(x,-39,21,19,4,top);tree(x,-39,.95,5);rock(x,18,.9);rock(x*.8,49,.6)
   end
   for x=-45,45,3 do local z=-49-(math.abs(x)%9)
    box(x,.03,z,3,.06,10,alt);box(x,.1,z+4,2,.04,.65,{.81,.88,.83})end
   flowers(-35,32,{.91,.80,.53})
  elseif setup.family=='ship'then
   for x=-45,45,9 do box(x,.04,-40,8,.08,15,top);box(x,0,-53,1.5,8,1.5,alt)end
   box(0,7,-53,97,1.5,2,alt);bench(-42,20);bench(42,20)
   for _,x in ipairs({-38,38})do box(x,0,-36,10,9,10,alt);box(x,4,-36,10.4,1,10.4,white)end
  else
   for _,x in ipairs({-43,43})do
    terrace(x,-40,22,17,3,alt);box(x,3,-44,20,13,7,top)
    box(x,10,-39.9,12,5,.2,{.62,.77,.79});bench(x*.70,42)
    if setup.family=='city'then tree(x,-18,.8)else crystal(x,-22)end
   end
   stairs(0,-48,16);box(0,0,-58,28,8,10,alt)
  end
  if setup.family=='gym' then
   local theme=setup.theme
   if theme=='water'then
    -- Pool arena with pale floating platforms at the fixed battle feet.
    quad({-40,.035,-23},{40,.035,-23},{40,.035,23},{-40,.035,23},{.12,.49,.66})
    for x=-36,36,6 do for z=-20,20,8 do
     box(x,.045,z,2,.008,.25,{.42,.74,.83})
    end end
    for _,side in ipairs({'player','enemy'})do local p=setup.actors[side]
     box(p[1],.047,p[3],15,.018,13,{.87,.89,.81})
     box(p[1],.066,p[3],12,.006,10,{.72,.82,.80})
    end
    for _,x in ipairs({-39,39})do
     box(x,0,-50,2,17,2,white);box(x,16,-53,7,1,9,white)
    end
    box(0,0,-63,38,13,2,{.14,.39,.55});box(0,13,-63,40,1,3,white)
    for x=-18,18,6 do box(x,0,-61.7,.7,13,.7,white)end
   elseif theme=='garden'then
    -- Open greenhouse frame and densely planted rear flower beds.
    for x=-42,42,14 do
     local z=-math.sqrt(64^2-x*x)
     box(x,0,z,1.1,24,1.1,{.82,.86,.77});box(x,23,z,14,1,1,{.82,.86,.77})
     bush(x,0,z+7,1.2);flowers(x-3,z+10,{.93,.57,.70})
    end
    for _,x in ipairs({-52,52})do tree(x,-21,.65);flowers(x,27,{.91,.80,.31})end
   elseif theme=='electric'then
    -- Industrial hall fragments, metallic field edges and warning markings.
    for _,x in ipairs({-47,47})do for z=-24,24,6 do
     box(x,.1,z,4,.2,5,{.33,.37,.39});box(x,.31,z,3,.02,.5,{.90,.72,.18})
    end end
    for x=-18,18,12 do
     box(x,0,-61,9,17,5,{.24,.29,.33});box(x,5,-58.3,6,7,.3,{.47,.56,.57})
     for k=0,2 do box(x,7+k*1.8,-57.9,4,.5,.2,{.83,.72,.25})end
    end
    for _,x in ipairs({-45,45})do box(x,0,-43,2,25,2,{.31,.36,.37})end
   elseif theme=='poison' or theme=='dojo'then
    -- Koga's timber mansion/courtyard language, rather than a toxic pool.
    local wood={.35,.21,.15};local paper={.85,.78,.62}
    for x=-30,30,15 do
     box(x,0,-59,14,17,2,paper);box(x-7,0,-57.8,1,18,1,wood)
     for k=1,3 do box(x,k*4,-57.7,14,.55,.5,wood)end
     box(x,18,-59,17,1.2,9,{.28,.28,.31});box(x,19.2,-59,14,1,6,{.37,.36,.38})
    end
    for _,x in ipairs({-48,48})do tree(x,-36,.7);box(x,0,30,3,7,3,wood);box(x,5,30,5,4,5,{.89,.71,.43})end
   elseif theme=='psychic'then
    -- Sober, symmetrical psychic hall; recessed doorway and twin columns.
    box(0,0,-62,21,26,4,{.25,.22,.32});box(0,2,-59.8,12,20,.2,{.10,.12,.22})
    for _,x in ipairs({-41,41})do
     box(x,0,-47,7,3,7,{.62,.60,.68});box(x,3,-47,4,22,4,{.61,.58,.68});box(x,25,-47,7,2,7,{.74,.69,.78})
     box(x,9,-44.8,1,8,.3,{.88,.68,.87})
    end
   elseif theme=='fire'then
    -- Dark volcanic ledges and a luminous lava channel around the court.
    for i=-3,3 do local x=i*15;local z=-math.sqrt(64^2-x*x)
     box(x,0,z,13,9+(3-math.abs(i))*4,10,{.25,.23,.24})
     box(x+2,2,z+5.1,.8,6,.3,{.98,.41,.08})
    end
    for _,x in ipairs({-47,47})do box(x,.03,0,5,.02,46,{.85,.29,.05})end
   elseif theme=='earth'then
    -- Giovanni's Roman-inspired hall: columns, cornice and mural panel.
    for x=-42,42,21 do
     local z=-math.sqrt(62^2-x*x)
     box(x,0,z,8,3,8,{.58,.51,.39});box(x,3,z,5,20,5,{.78,.70,.55})
     box(x,23,z,9,2,8,{.84,.75,.59});box(x,25,z,20,2,7,{.63,.52,.37})
     for _,dx in ipairs({-1.5,1.5})do box(x+dx,4,z+2.55,.3,17,.2,{.53,.45,.32})end
    end
    box(0,0,-62,17,21,2,{.44,.31,.21});box(0,3,-60.7,12,14,.3,{.72,.54,.30})
    for i=-2,2 do box(i*2,7+math.abs(i)*2,-60.4,1.5,7-math.abs(i),.2,{.38,.30,.24})end
   end
  end
  if wildGreen then
   for i=0,28 do local a=math.pi*.10+i*math.pi*.80/28;local x,z=math.cos(a)*67,math.sin(a)*67
    bush(x,0,z,.55+(i%3)*.15);tuft(x*.91,z*.91,0,.8)
   end
   for _,side in ipairs({-1,1})do
    terrace(side*43,42,14,12,2.8,greens[2]);bush(side*43,3.5,42,1.1)
    for i=0,4 do tuft(side*(51+i),-35+i*3,0,.9)end
   end
  elseif setup.family=='cave' then
   for i=-4,4 do if i~=0 then
    local x=i*12;local z=-math.sqrt(67^2-x*x)
    masonry(x,0,z,12,9+(4-math.abs(i))*3,9)
    for k=0,2 do box(x-4+k*4,12+(4-math.abs(i))*3,z+4,2.4,3+(k%2)*2,2.4,alt)end
   end end
   for _,side in ipairs({-1,1})do pebbleBed(side*51,44,15,8);crystal(side*36,55,0,{.42,.66,.80})end
  end
  end -- supplied gym interior or existing portable scenery
  -- Two low stone trainer platforms, with steps facing the battlefield.
  for _,side in ipairs({'player','enemy'})do
   local p=setup.trainers[side];local x,z=p[1],p[3]
   box(x,0,z,13,1.3,13,{.34,.35,.36})
   box(x,1.3,z,12,1.1,12,{.72,.70,.63})
   box(x,2.4,z,10,.04,10,{.80,.77,.68})
   if setup.cameraMode=='behind'then
    local direction=z>0 and -1 or 1
    box(x,0,z+direction*8,8,.8,3,{.60,.59,.55})
    box(x,.8,z+direction*6.5,8,.8,2,{.67,.65,.59})
   else
    local direction=x>0 and -1 or 1
    box(x+direction*8,0,z,3,.8,8,{.60,.59,.55})
    box(x+direction*6.5,.8,z,2,.8,8,{.67,.65,.59})
   end
  end
  local terrainVerts,terrainIndices=verts,indices;verts,indices=shellVerts,shellIndices;collect=false
  -- Front button: shallow concentric vertical cylinders, facing the viewer.
  local function button(radius,z,c)
   for i=0,31 do local a,b=i*math.pi/16,(i+1)*math.pi/16
    quad({0,-7,z},{math.cos(a)*radius,-7+math.sin(a)*radius,z},
     {math.cos(b)*radius,-7+math.sin(b)*radius,z},{0,-7,z},c)end
  end
  button(12,77.2,black);button(10.8,77.4,setup.family=='gym' and {.79,.58,.16}or white)
  button(9.3,77.6,setup.family=='gym' and {.97,.80,.35}or{.79,.77,.72})
  button(8.1,77.8,setup.theme=='rock' and {.40,.43,.46}or white)
  if setup.gymDesign then setup.gymDesign.button({quad=quad})
  elseif setup.theme=='rock'then
   for i=0,5 do local a,b=i*math.pi/3,(i+1)*math.pi/3
    quad({0,-7,78},{math.cos(a)*7.5,-7+math.sin(a)*7.5,78},
     {math.cos(b)*7.5,-7+math.sin(b)*7.5,78},{0,-7,78},stoneTones[i%4+1],.9)
   end
  end
  local pixels=love.image.newImageData(256,257)
  local seed=setup.seed
  for z=0,255 do for x=0,255 do
   seed=(seed*48271)%2147483647;local noise=seed/2147483647
   local tile=(math.floor(x/7)*17+math.floor(z/7)*31+setup.seed)%9
   local factor=.95+tile*.006+(noise-.5)*.10
   if setup.family=='gym' and (x%28==0 or z%28==0)then factor=factor*.90 end
   if (setup.family=='forest'or setup.family=='grass')and noise<.055 then factor=factor*.67 end
   pixels:setPixel(x,z+1,math.min(1,top[1]*factor),math.min(1,top[2]*factor),math.min(1,top[3]*factor),1)
  end end
  for i,c in ipairs(colors)do pixels:setPixel(i-1,0,c[1],c[2],c[3],1)end
  local texture=love.graphics.newImage(pixels);pixels:release();texture:setFilter('nearest','nearest')
  local mesh,shell
  local ok,reason=pcall(function()
   mesh=assert(G.newMesh(terrainVerts,terrainIndices),'Terarrium mesh allocation failed')
   shell=assert(G.newMesh(shellVerts,shellIndices),'Terarrium shell allocation failed')
  end)
  if not ok then if mesh then mesh:release()end;if shell then shell:release()end;texture:release();error(reason)end
  return {mesh=mesh,shell=shell,texture=texture,occluders=occluders,vertices=#terrainVerts+#shellVerts,triangles=(#terrainIndices+#shellIndices)/3}
 end
 local function get(setup)
  if idleBattle and setup._ballBattle~=idleBattle then
   setup.ballStyle=api.ballStyle and api.ballStyle({id=setup.id})or'poke'
   setup._ballBattle=idleBattle
  end
  local key=setup.id..':'..setup.family..':'..tostring(setup.cameraMode)..':'..setup.ballStyle..':'..(setup.gymDesign and setup.gymDesign.revision or 'legacy')
  if not cache[key]then
   cache[key]=build(setup);order[#order+1]=key
   if #order>4 then local old=table.remove(order,1);if cache[old].lightmap then cache[old].lightmap:release()end;cache[old].mesh:release();cache[old].shell:release();cache[old].texture:release();cache[old]=nil end
  end
  return cache[key]
 end
 local function branding()
  if not api.branding then return end
  if not brandTexture then
   local texture=api.branding();local v,i={},{}
   -- Ink conforms to the porcelain shell; no plate or projecting backing.
   local cols,rows=32,12
   for row=0,rows do for col=0,cols do
    local u,t=col/cols,row/rows;local x=15+40*u;local y=-9-18*t
    local radius=77*math.sqrt(1-((y+5)/72)^2)
    local z=math.sqrt(radius*radius-x*x)+.38
    v[#v+1]={x,y,z,u,t,1}
   end end
   for row=0,rows-1 do for col=0,cols-1 do
    local n=row*(cols+1)+col+1
    for _,k in ipairs({n,n+1,n+cols+2,n,n+cols+2,n+cols+1})do i[#i+1]=k end
   end end
   local ok,result=pcall(G.newMesh,v,i)
   if not ok or not result then texture:release();error(result or 'Branding mesh allocation failed')end
   brandTexture,brandMesh=texture,result
  end
  return brandMesh,brandTexture
 end
 local function buttonLight(pulse,matrix)
  if pulse<.002 then return end
  if not lightMesh then
   lightPixels=love.image.newImageData(1,1);lightPixels:setPixel(0,0,1,1,1,1)
   lightTexture=love.graphics.newImage(lightPixels)
   local v,i={},{}
   for k=0,47 do local a,b=k*math.pi/24,(k+1)*math.pi/24;local n=#v
    v[#v+1]={0,-7,78.5,.5,.5,1}
    v[#v+1]={math.cos(a)*8,-7+math.sin(a)*8,78.5,.5,.5,1}
    v[#v+1]={math.cos(b)*8,-7+math.sin(b)*8,78.5,.5,.5,1}
    i[#i+1]=n+1;i[#i+1]=n+2;i[#i+1]=n+3
   end
   local ok,result=pcall(G.newMesh,v,i)
   if not ok or not result then
    lightTexture:release();lightPixels:release();lightTexture,lightPixels=nil,nil
    error(result or 'Idle button mesh allocation failed')
   end
   lightMesh=result
  end
  lightPixels:setPixel(0,0,.93-.82*pulse,.90-.38*pulse,.83+.17*pulse,1)
  lightTexture:replacePixels(lightPixels)
  G.draw(lightMesh,lightTexture,matrix)
 end
 function S.lightEnabled()return api.lighting and api.lighting.enabled()or false end
 function S.prepareLighting(arena,groundY)
  if not S.lightEnabled()then return api.lighting and api.lighting.prepare(arena,groundY)or false end
  local item=get(arena.terarrium)
  if not item.lightmap then item.lightmap=api.lighting.bake(item.occluders)end
  return api.lighting.prepare(arena,groundY,item.lightmap)
 end
 function S.lightingStatus()return api.lighting and api.lighting.last end
 function S.draw(arena,groundY)
  local item=get(arena.terarrium)
  if api.drawBackground then api.drawBackground(arena)end
  G.seams(false);G.glass(false)
  local matrix=M.translate(arena.mid[1],groundY,arena.mid[2])
  local ok,reason=pcall(function()
   G.shadowReception(false);G.draw(item.shell,item.texture,matrix)
   local bm,bt=branding();if bm then G.draw(bm,bt,matrix)end
   local _,pulse,t=S.idleSample();if not arena.terarrium.gymDesign then buttonLight(pulse,matrix)end
   if t then
    local beat=math.floor(t/.56);local phase=t/.56-beat
    local key=tostring(idleSince)..':'..beat
    if phase>=.42 and lastImpact~=key then
     lastImpact=key;if api.idleImpact then api.idleImpact()end
    end
   end
   G.shadowReception(true)
   G.draw(item.mesh,item.texture,matrix)
  end)
  G.shadowReception(true);G.glass(true);G.seams(true)
  if not ok then error(reason)end
 end
 function S.overlay(arena,groundY)
  if api.drawAtmosphere then api.drawAtmosphere(arena,groundY)end
  -- ODias gym designs are compact open bowls, even with a saved dome choice.
  if not arena.terarrium.gymDesign and api.drawDome then api.drawDome(arena,groundY)end
 end
 function S.cast(shadow,arena,groundY)
  if not shadow then return end;local item=get(arena.terarrium)
  shadow.draw(item.mesh,item.texture,M.translate(arena.mid[1],groundY,arena.mid[2]))
 end
 function S.camera(arena,groundY)
  local x,z=arena.mid[1],arena.mid[2]
  local eye={x,groundY+157,z+205};local focus={x,groundY-12,z}
  local d=math.sqrt(169^2+205^2)
  local roll=S.idleSample()
  -- Inverse rigid camera transform rotates the complete diorama, including
  -- actors, around its lower shell. HUD stays level and battle anchors stay fixed.
  local ny,nz=169/d,205/d;local pivot={x,groundY-64,z}
  local c,s=math.cos(roll),math.sin(roll)
  local function rotate(p,point)
   local px,py,pz=p[1],p[2],p[3]
   if point then px,py,pz=px-pivot[1],py-pivot[2],pz-pivot[3] end
   local dot=py*ny+pz*nz
   local q={px*c+(ny*pz-nz*py)*s,py*c+nz*px*s+ny*dot*(1-c),pz*c-ny*px*s+nz*dot*(1-c)}
   if point then for k=1,3 do q[k]=q[k]+pivot[k]end end
   return q
  end
  return {eye=rotate(eye,true),focus=rotate(focus,true),up=rotate({0,1,0},false),fov=2*math.atan(102/d),curve=0},math.atan2(205,169)
 end
 function S.trainerFoot(arena,side,groundY)
  local p=assert(arena.terarrium.trainers[side]);return {arena.mid[1]+p[1],groundY+p[2],arena.mid[2]+p[3]}
 end
 function S.release()
  if api.lighting then api.lighting.release()end
  if api.releaseAtmosphere then api.releaseAtmosphere()end
  if api.releaseBackground then api.releaseBackground()end
  if api.releaseDome then api.releaseDome()end
  if api.releaseIdleSound then api.releaseIdleSound()end
  idleBattle,idleSince,lastCursor,idleAllowed=nil,nil,nil,false
  if lightMesh then lightMesh:release();lightTexture:release();lightPixels:release();lightMesh,lightTexture,lightPixels=nil,nil,nil end
  if brandMesh then brandMesh:release();brandTexture:release();brandMesh,brandTexture=nil,nil end
  for _,item in pairs(cache)do if item.lightmap then item.lightmap:release()end;item.mesh:release();item.shell:release();item.texture:release()end;cache,order={},{}
 end
 return S
end
