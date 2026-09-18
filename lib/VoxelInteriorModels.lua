-- Authored retail, research and exhibit furniture. All dimensions are world
-- pixels; footprints correspond to the exact native masks in the companion file.
return function(P,F)
  local C=P.decorColors
  local function model(name,w,d)
    local m={boxes={},frameW=w,frameH=d+32,depth=d,offsetY=-32}
    P.models[name]=m
    return function(x,y,z,a,b,c,color)m.boxes[#m.boxes+1]={x,y,z,a,b,c,color}end
  end
  local function ball(b,x,y,z,kind)
    for i=0,4 do for j=0,4 do for k=0,4 do
      if (i-2)^2+(j-2)^2+(k-2)^2<=6 then
        local top=({1,19,3,4})[kind%4+1]
        local color=j<2 and 4 or j==2 and 3 or top
        if kind%4==1 and j>2 and (i==0 or i==4)then color=1 end
        if kind%4==2 and j>2 and (i==1 or i==3)then color=11 end
        b(x+i,y+j,z+k,1,1,1,color)
      end
    end end end
    b(x+2,y+2,z+4,1,1,1,4)
  end
  local function product(b,x,y,z,kind,color)
    if kind=='ball' then ball(b,x,y,z,color);return end
    if kind=='stone' then
      b(x+1,y,z,3,1,4,3);b(x,y+1,z+1,5,2,3,color)
      b(x+1,y+3,z+1,3,1,2,9);b(x+2,y+4,z+2,1,1,1,4)
    elseif kind=='box' then
      b(x,y,z,4,5,3,color);b(x+1,y+1,z+3,2,3,1,4)
      b(x,y+5,z,4,1,3,2);b(x+1,y+2,z+4,2,1,1,3)
    elseif kind=='disc' then
      b(x,y,z,5,5,2,3);b(x+1,y+1,z+2,3,3,1,color);b(x+2,y+2,z+3,1,1,1,4)
    else
      b(x+1,y,z,3,1,3,3);b(x,y+1,z,4,3,3,color)
      b(x+1,y+4,z+1,2,1,2,14);b(x+1,y+5,z+1,3,1,1,3)
      b(x+1,y+2,z+3,2,2,1,4)
    end
  end
  local function monitor(b,x,y,z,w,h,theme)
    b(x,y,z,w,h,2,3);b(x+1,y+1,z+2,w-2,h-2,1,C.navy)
    -- A tiny landscape, with a sun and stepped hills rather than blank bars.
    b(x+2,y+h-4,z+3,2,2,1,11)
    for i=0,w-5 do
      local h0=1+(i+theme)%4
      b(x+2+i,y+2,z+3,1,h0,1,theme%2==0 and 12 or 7)
    end
    b(x+w-3,y,z+2,1,1,1,12)
  end
  local function counter(b,x,z,w,d,h,accent)
    b(x+1,0,z+1,w-2,1,d-2,3);b(x,1,z,w,h-3,d,C.walnut)
    b(x,h-2,z,w,1,d,C.oak);b(x,h-1,z,w,1,d,4)
    b(x,2,z+d-1,w,1,1,accent)
    for i=3,w-2,8 do b(x+i,3,z+d-1,1,math.max(1,h-6),1,C.oak)end
  end
  local function terminal(b,x,y,z)
    b(x,y,z,9,1,7,14);b(x+3,y+1,z+1,2,2,2,3)
    monitor(b,x+1,y+3,z,8,6,1)
    b(x+1,y+1,z+5,5,1,2,3);b(x+2,y+2,z+5,3,1,1,14)
  end
  local function sample(b,source,x,y,z)
    for _,v in ipairs(P.models[source].boxes)do b(x+v[1],y+v[2],z+v[3],v[4],v[5],v[6],v[7])end
  end
  local themes={balls=1,medicine=7,stones=12,tech=C.purple,mixed=11}
  -- Different rows and silhouettes are deliberately authored for each department.
  for theme,accent in pairs(themes)do for _,half in ipairs({false,true})do for phase=0,2 do
    local name='retail_'..theme..(half and '_half' or '')..(phase>0 and '_v'..phase or '')
    local b=model(name,32,half and 16 or 32)
    local d=half and 14 or 28
    b(1,0,1,30,2,d,3);b(1,2,1,2,24,d,14);b(29,2,1,2,24,d,14)
    b(3,2,half and 1 or 13,26,23,2,C.walnut)
    b(3,25,half and 1 or 13,26,2,3,accent)
    for row,y in ipairs({2,10,18})do
      b(3,y,1,26,1,d,2);b(3,y,half and 14 or 28,26,1,1,accent)
      for col=0,3 do
        local kind=theme=='balls' and (row==3 and 'box' or 'ball')
          or theme=='stones' and (row==1 and 'box' or 'stone')
          or theme=='tech' and (row==2 and 'box' or 'disc')
          or theme=='medicine' and (row==1 and 'box' or 'bottle')
          or ({'ball','bottle','stone','box'})[(col+row+phase)%4+1]
        local color=kind=='ball' and (col+row+phase)%4 or ({7,15,12,11})[(col+row+phase)%4+1]
        if not (phase==1 and row==2 and col==3)then product(b,4+col*6,y+1,half and 10 or 24,kind,color)end
        if not half and not (phase==2 and row==3 and col==0)then product(b,4+col*6,y+1,3,kind,color)end
        b(5+col*6,y,half and 15 or 29,3,1,1,4)
      end
    end
  end end end
  -- Replace the complete old checkout booth; the clerk's open bay stays open.
  local b=model('retail_checkout',32,48)
  counter(b,0,0,32,12,8,7);counter(b,16,12,16,20,8,7);counter(b,0,32,32,16,8,7)
  terminal(b,19,8,18);b(2,8,35,11,1,9,C.navy)
  ball(b,4,9,36,0);product(b,23,8,35,'box',11)
  for _,spec in ipairs({{'counter_front',8,16},{'counter_side',16,8},{'counter_cap',16,8},{'counter_corner',16,16}})do
    b=model(spec[1],spec[2],spec[3]);counter(b,0,0,spec[2],spec[3],8,7)
  end
  b=model('reception_directory',16,16);counter(b,0,0,16,16,8,7)
  monitor(b,3,8,4,10,12,1)
  for i=0,3 do b(5,10+i*2,7,5,1,1,({7,11,12,C.purple})[i+1])end
  b=model('payphone',16,32)
  counter(b,1,17,14,13,10,7);b(2,10,18,12,15,5,14)
  b(3,13,23,4,10,1,3);b(3,13,24,2,3,2,8);b(3,20,24,2,3,2,8)
  b(3,16,25,1,4,1,3);b(9,19,23,4,4,1,7)
  for x=9,12,2 do for y=13,17,2 do b(x,y,23,1,1,1,3)end end
  b=model('tv_showcase',16,32)
  counter(b,0,17,16,14,8,C.purple);b(6,8,22,4,2,3,3);monitor(b,1,10,19,14,12,2)
  b(2,8,27,8,1,2,14);b(12,8,27,2,1,2,11)
  b=model('tv_wall',16,16);b(0,0,1,16,16,3,14);monitor(b,1,5,4,14,10,3)
  b=model('demo_counter',80,24)
  counter(b,0,0,80,24,8,C.purple)
  for _,x in ipairs({4,50})do
    monitor(b,x+8,10,4,20,13,2);b(x+15,8,8,5,2,4,3)
    b(x+9,8,14,18,2,7,3);b(x+9,10,14,3,1,7,7);b(x+24,10,14,3,1,7,1)
    b(x+13,10,15,10,1,5,8);b(x+15,11,17,6,1,1,9)
    product(b,x,8,10,'disc',11)
  end
  -- Drink machines, prize cabinets and laboratory storage share a frame only.
  for _,kind in ipairs({'vending','prize_case','specimen_cabinet','lab_storage','lab_server'})do
    b=model(kind,16,32)
    local accent=kind=='vending' and 1 or kind=='prize_case' and 11 or 7
    b(1,0,14,14,2,17,3);b(0,2,14,16,25,16,14)
    b(2,4,29,12,20,1,8);b(1,26,14,14,2,16,accent)
    if kind=='lab_server' then
      for y=5,22,4 do
        b(2,y,30,12,3,1,C.navy);b(3,y+1,31,5,1,1,7);b(11,y+1,31,1,1,1,12)
      end
    else
      for row,y in ipairs({5,12,19})do
        b(2,y,26,10,1,4,2)
        for col=0,1 do
          local k=kind=='prize_case' and 'ball' or kind=='specimen_cabinet' and 'stone'
            or kind=='lab_storage' and 'box' or 'bottle'
          product(b,2+col*6,y+1,27,k,k=='ball' and row+col or ({7,11,12})[row])
        end
      end
    end
    if kind=='vending' then
      b(12,8,30,3,15,1,3);b(13,18,31,1,3,1,7);b(13,12,31,1,1,1,11)
      b(3,2,30,9,3,2,3);b(4,3,32,7,1,1,16)
    end
  end
  -- Two-sided slot banks: each model is one player station, not one giant slab.
  for side=0,1 do for color=0,2 do
    local name='arcade_'..side..'_'..color
    b=model(name,16,16);local accent=({1,C.purple,7})[color+1]
    local function s(x,y,z,w,h,d,c)
      if side==1 then b(z,y,x,d,h,w,c)else b(16-z-d,y,x,d,h,w,c)end
    end
    s(1,0,2,14,2,13,3);s(1,2,3,14,10,11,C.navy)
    s(1,12,2,14,2,13,accent);s(1,14,3,14,14,5,3)
    s(2,26,8,12,3,1,accent);s(3,27,9,10,1,1,11)
    s(2,17,8,12,8,1,8)
    for reel=0,2 do
      s(3+reel*4,18,9,3,5,1,4);s(4+reel*4,19+reel%2,10,1,2,1,({1,11,12})[reel+1])
    end
    s(3,14,11,3,1,2,11);s(8,14,11,2,1,2,1);s(12,14,11,1,2,1,7)
    s(5,4,14,6,2,1,3)
  end end
  b=model('arcade_end',16,16);b(1,0,1,14,2,14,3);b(1,2,2,14,21,12,C.navy)
  b(1,23,2,14,2,12,C.purple);b(4,9,14,8,5,1,11);ball(b,6,9,15,0)
  b=model('lounge_chair',16,16)
  for _,x in ipairs({3,11})do for _,z in ipairs({4,11})do b(x,0,z,2,6,2,3)end end
  b(2,6,3,12,2,11,C.purple);b(2,8,3,12,6,2,C.purple);b(3,9,5,10,3,1,14)
  b=model('lounge_chair_south',16,16)
  for _,v in ipairs(P.models.lounge_chair.boxes)do
    b(16-v[1]-v[4],v[2],16-v[3]-v[6],v[4],v[5],v[6],v[7])
  end
  for _,side in ipairs({'left','right'})do
    b=model('lounge_chair_'..side,16,16)
    for _,v in ipairs(P.models.lounge_chair.boxes)do
      b(side=='right' and v[3] or 16-v[3]-v[6],v[2],v[1],v[6],v[5],v[4],v[7])
    end
  end
  b=model('terrace_table',32,32)
  b(11,0,11,10,2,10,3);b(14,2,14,4,7,4,14)
  for x=1,30 do for z=1,30 do if (x-15.5)^2+(z-15.5)^2<215 then b(x,9,z,1,2,1,C.oak)end end end
  b(9,11,12,5,1,7,2);product(b,18,11,16,'bottle',7)
  -- Laboratory equipment includes real work surfaces, instruments and storage.
  b=model('lab_bench',32,24)
  counter(b,0,7,32,17,8,7);monitor(b,2,8,9,12,10,1)
  b(19,8,13,9,1,7,3);b(24,9,13,3,9,3,14);b(21,16,13,6,2,3,14)
  b(20,14,16,3,3,2,3);b(22,10,16,3,1,3,7)
  b(3,8,20,10,1,3,3);product(b,15,8,18,'bottle',12)
  b=model('research_console',32,32)
  counter(b,0,7,32,25,8,7);monitor(b,3,10,9,17,12,1)
  b(9,8,13,4,2,3,3);b(4,8,22,15,1,4,3)
  sample(b,'old_amber',16,8,15);b(22,8,11,8,1,6,2)
  for i=0,2 do b(23,9,12+i*2,5,1,1,16)end
  b=model('fossil_reconstructor',32,32)
  b(1,0,5,30,3,25,3);b(2,3,6,28,7,23,14);b(2,10,6,28,2,23,7)
  b(7,12,9,18,1,16,8);sample(b,'helix_fossil',8,13,8)
  for _,x in ipairs({4,26})do b(x,11,8,2,17,2,14);b(x,11,25,2,17,2,14)end
  b(4,28,8,24,2,19,14);b(7,27,9,18,1,1,7);b(7,27,25,18,1,1,7)
  monitor(b,10,5,28,12,5,1);b(3,5,29,4,2,1,12)
  b=model('fossil_bank',24,32)
  for _,v in ipairs(P.models.fossil_reconstructor.boxes)do
    local x=math.floor(v[1]*.75);local right=math.floor((v[1]+v[4])*.75)
    if right>x then b(x,v[2],v[3],right-x,v[5],v[6],v[7])end
  end
  b=model('lab_meeting_table',48,32);counter(b,0,0,48,32,8,7)
  b(18,8,11,12,1,10,2);b(20,9,12,8,1,1,16);product(b,32,8,17,'bottle',7)
  for _,spec in ipairs({{'oak_table',48},{'oak_table_small',32}})do
    b=model(spec[1],spec[2],24);counter(b,0,0,spec[2],24,6,7)
  end
  b=model('oak_computers',32,24);counter(b,0,0,32,24,6,7)
  monitor(b,1,8,3,14,11,1);b(6,6,6,3,2,3,3);b(2,6,14,13,1,4,3)
  b(18,6,5,6,12,8,14);b(19,9,13,4,1,1,3);b(19,15,13,4,1,1,7)
  b(25,6,9,6,1,10,2);b(26,7,10,4,1,1,16)
  -- Low exhibition plinths and open glass frames keep the specimens readable.
  local function case(b,w,d)
    b(1,0,2,w-2,2,d-3,C.walnut);b(1,2,2,w-2,5,d-3,14)
    b(2,7,3,w-4,1,d-5,C.navy)
    for _,x in ipairs({2,w-3})do for _,z in ipairs({3,d-4})do b(x,8,z,1,17,1,C.silver)end end
    b(2,25,3,w-4,1,1,7);b(2,25,d-4,w-4,1,1,7)
    b(2,25,3,1,1,d-6,7);b(w-3,25,3,1,1,d-6,7)
    b(w/2-6,5,d-2,12,4,1,2);b(w/2-4,6,d-1,8,1,1,3)
  end
  for variant=0,1 do
    b=model('museum_skeleton_'..variant,64,32);case(b,64,32)
    for _,offset in ipairs({0,29})do
      -- Articulated spine, ribs, legs, tail and a broad fossil skull.
      for i=0,11 do
        local y=13+math.floor(math.sin(i/11*math.pi)*5)
        b(8+offset+i,y,15,2,2,2,2)
        if i%2==0 then
          b(8+offset+i,y-2,12,1,3,1,4);b(8+offset+i,y-2,19,1,3,1,4)
          b(8+offset+i,y,13,1,1,6,2)
        end
      end
      b(5+offset,17,13,5,5,6,2);b(5+offset,20,18,2,1,1,3)
      b(4+offset,16,15,4,1,5,4)
      for _,x in ipairs({10,18})do
        b(x+offset,9,13,2,5,2,2);b(x+offset,8,11,4,1,4,4)
        b(x+offset,9,18,2,5,2,2);b(x+offset,8,18,4,1,4,4)
      end
      for i=0,5 do b(21+offset+i,12-math.floor(i/2),15,2,1,2,2)end
      if variant==1 then
        for i=0,5 do b(12+offset+i,19+i%2,7+i,1,1,3,2)end
      end
    end
  end
  b=model('museum_moon',64,32);case(b,64,32)
  sample(b,'moon_stone',6,8,8);sample(b,'old_amber',25,8,8);sample(b,'helix_fossil',42,8,8)
  b=model('museum_shuttle',48,32);case(b,48,32)
  b(22,8,13,4,4,6,16)
  for x=7,39 do
    local radius=math.min(4,math.floor((x-5)/2),math.floor((42-x)/2))
    b(x,12,16-radius,1,math.max(2,radius),radius*2,4)
  end
  b(33,16,14,5,1,4,8);b(8,16,15,7,6,2,4)
  for i=0,10 do b(14+i,12,5+i,9,1,1,4);b(14+i,12,26-i,9,1,1,4)end
  b(7,12,13,3,3,6,3);b(6,13,14,1,1,4,11)
  b=model('amber_case',16,16);P.models.amber_case.support=6;b(1,0,1,14,6,14,14) -- Amber itself belongs to the collectible entity.
  for _,x in ipairs({1,14})do b(x,7,1,1,13,1,7);b(x,7,14,1,13,1,7)end
  b(1,20,1,14,1,1,7);b(1,20,14,14,1,1,7)

  b=model('lab_analysis',48,32)
  counter(b,0,5,48,26,10,7)
  monitor(b,3,13,8,25,14,1);b(11,10,11,6,3,4,14)
  b(3,10,25,24,1,4,3);for x=5,23,3 do b(x,11,26,2,1,1,14)end
  b(32,10,9,13,16,18,14);b(33,12,27,11,12,1,8)
  for y=13,21,4 do b(34,y,28,5,1,1,7);b(42,y,28,1,1,1,12)end
  b(32,26,10,13,1,16,7)
  b=model('lab_wall_tools',16,32)
  b(0,0,18,16,12,13,14);b(0,12,18,16,1,13,7)
  b(1,13,17,14,12,2,C.navy)
  for x=3,12,4 do b(x,17,19,1,6,1,14);b(x-1,21,20,3,2,1,7)end
  product(b,3,13,24,'bottle',12);product(b,9,13,24,'bottle',7)
  for phase=0,2 do for _,short in ipairs({false,true})do
    b=model('bookshelf_'..phase..(short and '_short' or ''),16,short and 24 or 32)
    local z=short and 7 or 15
    b(1,0,z,14,2,16,3);b(1,2,z,14,26,2,C.walnut)
    b(0,2,z,2,26,16,C.oak);b(14,2,z,2,26,16,C.oak)
    b(0,28,z,16,2,16,C.walnut);b(1,28,z+15,14,1,1,C.oak)
    -- Closed lower cabinet, with two handles beneath the open book shelves.
    b(2,2,z+2,12,6,14,C.walnut);b(7,4,z+16,1,2,1,11);b(9,4,z+16,1,2,1,11)
    for row,y in ipairs({8,18})do
      b(2,y,z+2,12,1,14,C.oak)
      for col=0,3 do
        local h=5+(phase+row+col)%3;local x=2+col*3
        local c=({1,7,12,11,C.purple})[(col+phase+row)%5+1]
        if col==3 and (phase+row)%2==0 then
          for n=0,2 do b(x,y+1+n*2,z+10,3,1,5,c);b(x,y+2+n*2,z+10,3,1,4,2)end
        else
          b(x,y+1,z+10,2,h,5,c);b(x,y+3,z+15,2,1,1,11)
          b(x,y+h,z+10,2,1,4,2)
        end
      end
    end
  end end
  F.retailThemes=themes
end
