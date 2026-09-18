-- Repeat only undecorated material strips from the room's existing artwork.
-- Motifs remain unique; material colours, dado and cornice line up exactly.
local F={}
local quietColumn={stone_hall=.0203,underground=.442,mart=.488,casino=.7375,
 hotel=.7937,traditional_home=.5138,lab=.335,gate=.9926,spirit_hall=.1238,
 diner=.413,ruined_mansion=.6538,home=.8416,workshop=.3886,ice_hall=.8858,
 corporate=.7462,coastal_home=.4033,rocket=.0055,center=.856,daycare=.0681,
 power_plant=.5322,dragon_hall=.198,champion_hall=.9742,museum=.4586,elevator=.20}
-- Reviewed boundaries in the existing artwork, between complete motifs.
-- Equal thirds cut shelves, wheels, windows and Lance's dragon in half.
-- Lab boundaries retain one different starter poster on each bearing.
F.seams={lab={704/2172,1534/2172},home={.337,.667},
 traditional_home={.250,.653},coastal_home={.404,.649},
 hotel={.341,.663},daycare={.452,.692},diner={.413,.695},
 mart={.337,.754},center={.350,.664},workshop={.388,.731},
 museum={.300,.700},corporate={.280,.606},casino={.310,.676},
 rocket={.399,.631},power_plant={.207,.797},gate={.328,.638},
 ruined_mansion={.415,.638},ice_hall={.338,.658},
 stone_hall={.351,.642},spirit_hall={1/3,2/3},
 dragon_hall={.229,.771},champion_hall={.380,.620},
 underground={.256,.738},elevator={1/3,2/3}}
function F.placement(panel,theme,height)
 if panel.endcap then return nil end
 local section=({west=0,north=1,east=2})[panel.edge]
 if section==nil then return nil end
 local cuts=F.seams[theme] or {1/3,2/3}
 -- The champion image starts/ends in the middle of ornamental pillars.
 -- Exclude those incomplete outer caps; all banners and medals remain whole.
 local trim=theme=='champion_hall' and .0225 or 0
 local limits={trim,cuts[1],cuts[2],1-trim}
 local sourceFrom,sourceTo=limits[section+1],limits[section+2]
 local ideal=height*3*(sourceTo-sourceFrom)
 local doors={};for _,door in ipairs(panel.openings or{})do doors[#doors+1]=door end
 table.sort(doors,function(a,b)return a.from<b.from end)
 local cursor,last=panel.from+4,panel.upto-4
 local center=(panel.from+panel.upto)/2
 local best
 local function consider(a,b)
  local width=math.min(ideal,b-a)
  if width<24 then return end
  local left=math.max(a,math.min(center-width/2,b-width))
  local distance=math.abs(left+width/2-center)
  if not best or width>best.width+1e-6 or
     (math.abs(width-best.width)<1e-6 and distance<best.distance) then
   best={left=left,right=left+width,width=width,distance=distance,
     sourceFrom=sourceFrom,sourceTo=sourceTo}
  end
 end
 for _,door in ipairs(doors)do
  consider(cursor,math.min(last,door.from-2))
  cursor=math.max(cursor,door.upto+2)
 end
 consider(cursor,last)
 return best
end
function F.paint(g,w,h,theme,source)
 local sw,sh=source:getDimensions()
 -- The champion mural has no undecorated full-height column. Sampling one
 -- repeats banner tips, flames or cropped pillars. Reuse genuinely plain
 -- fabric/marble patches, with uninterrupted horizontal cornice/dado rails.
 if theme=='champion_hall' then
  local function patch(sx,sy,swid,shgt,y,height,tiled)
   local q=g.newQuad(sx*sw,sy*sh,swid*sw,shgt*sh,sw,sh)
   local step=tiled and 32 or w
   for at=0,w-1,step do
    local width=math.min(step,w-at)
    g.draw(source,q,at,y,0,width/(swid*sw),height/(shgt*sh))
   end
   q:release()
  end
  g.setColor(1,1,1,1)
  patch(.15,.79,.08,.11,0,h,true)
  patch(.31,.10,.028,.075,h*.072,h*(.715-.072),true)
  patch(.31,0,.045,.072,0,h*.072,false)
  patch(.31,.715,.045,.035,h*.715,h*.035,false)
  patch(.31,.925,.045,.075,h*.925,h*.075,false)
  return
 end
 local strip=math.max(1,math.floor(sw*.007))
 local x=math.min(sw-strip,math.max(0,math.floor((quietColumn[theme] or .5)*sw-strip/2)))
 local quad=g.newQuad(x,0,strip,sh,sw,sh)
 g.setColor(1,1,1,1)
 for at=0,w-1,8 do g.draw(source,quad,at,0,0,8/strip,h/sh)end
 quad:release()
 -- Keep the full material grain of the dado, rather than stretching one
 -- column of wood. The upper decorative motifs are never sampled here.
 -- Start at the material's real cap rail. A later crop splices independently
 -- scaled vertical joints into their middles, leaving chopped plank/tile ends.
 local base=({home=.69,lab=.77,traditional_home=.68,coastal_home=.657,
  mart=.688,center=.683,diner=.648,daycare=.675,casino=.675,hotel=.705,
  workshop=.765,museum=.73,corporate=.675,rocket=.70,power_plant=.755,
  gate=.66,ruined_mansion=.735,ice_hall=.745,stone_hall=.625,
  spirit_hall=.71,dragon_hall=.715,underground=.88,elevator=.86})[theme] or .82
 local y=math.floor(sh*base)
 local dado=g.newQuad(0,y,sw,sh-y,sw,sh)
 g.draw(source,dado,0,h*base,0,w/sw,h*(1-base)/(sh-y));dado:release()
end
function F.door(g,w,h)
 local function rect(c,x,y,r,b)
  g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',x*w,y*h,r*w,b*h)
 end
 rect({.32,.19,.09},0,0,1,1)
 rect({.55,.35,.17},.045,.025,.91,.95)
 -- Two recessed panels with continuous stiles rather than wall strips.
 for _,p in ipairs({{.12,.08,.76,.43},{.12,.58,.76,.34}})do
  rect({.30,.17,.075},p[1],p[2],p[3],p[4])
  rect({.62,.41,.22},p[1]+.018,p[2]+.012,p[3]-.036,p[4]-.024)
  rect({.49,.30,.14},p[1]+.045,p[2]+.03,p[3]-.09,p[4]-.06)
 end
 rect({.23,.17,.09},.78,.51,.065,.085)
 rect({.88,.69,.28},.76,.54,.15,.018)
 g.setColor(1,1,1,1)
end
function F.securityDoor(g,w,h)
 local function rect(c,x,y,a,b)
  g.setColor(c[1],c[2],c[3],1);g.rectangle('fill',x*w,y*h,a*w,b*h)
 end
 rect({.13,.19,.23},0,0,1,1)
 rect({.64,.71,.73},.04,.025,.92,.95)
 for _,x in ipairs({.075,.515})do
  rect({.34,.43,.47},x,.06,.41,.88)
  rect({.48,.57,.59},x+.012,.073,.386,.854)
  rect({.12,.22,.27},x+.04,.14,.33,.18)
  rect({.29,.65,.70},x+.053,.153,.304,.155)
  rect({.61,.84,.83},x+.07,.16,.265,.02)
  for y=.39,.85,.075 do
   rect({.31,.40,.44},x+.035,y,.34,.012)
   rect({.64,.70,.71},x+.035,y+.012,.34,.008)
  end
 end
 rect({.08,.13,.16},.488,.045,.024,.91)
 -- Card reader on the right, with a red locked lamp and a narrow card slot.
 rect({.12,.19,.22},.84,.35,.095,.19)
 rect({.81,.20,.13},.863,.378,.05,.035)
 rect({.67,.75,.75},.851,.462,.07,.015)
 rect({.86,.64,.18},.06,.965,.88,.017)
 g.setColor(1,1,1,1)
end

-- A small raised wall plaque, styled like the native cream/dark sign.
-- Its neutral text strokes remain language independent: the real localized
-- wording is read through the unchanged native interaction.
function F.sign(g,W,H)
 g.setColor(.20,.13,.075,1);g.rectangle('fill',0,0,W,H)
 g.setColor(.74,.60,.33,1);g.rectangle('fill',W*.045,H*.08,W*.91,H*.84)
 g.setColor(.96,.91,.77,1);g.rectangle('fill',W*.085,H*.15,W*.83,H*.70)
 g.setColor(.20,.17,.12,1)
 g.rectangle('fill',W*.19,H*.30,W*.62,H*.09)
 g.rectangle('fill',W*.19,H*.49,W*.47,H*.07)
 g.rectangle('fill',W*.19,H*.66,W*.58,H*.07)
end
return F
