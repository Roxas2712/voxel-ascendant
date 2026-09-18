-- Original geometry for identifiable field pickups; no inventory semantics.
return function(P)
  P.itemKinds={HELIX_FOSSIL='helix_fossil',DOME_FOSSIL='dome_fossil',OLD_AMBER='old_amber',
    LEAF_STONE='leaf_stone',FIRE_STONE='fire_stone',WATER_STONE='water_stone',
    THUNDER_STONE='thunder_stone',MOON_STONE='moon_stone',SUN_STONE='sun_stone'}
  P.objectKinds.MTMOONB2F_DOME_FOSSIL='dome_fossil'
  P.objectKinds.MTMOONB2F_HELIX_FOSSIL='helix_fossil'
  local function model(kind)
    local m={boxes={}};P.models[kind]=m
    return function(x,y,z,w,h,d,c)m.boxes[#m.boxes+1]={x,y,z,w,h,d,c}end
  end
  do
    local b=model('item_capsule')
    for x=4,11 do for z=4,11 do for y=0,11 do
      local dy=y<3 and 3-y or y>8 and y-8 or 0
      if (x+.5-8)^2+(z+.5-8)^2+dy^2<=3.7^2 then
        b(x,y,z,1,1,1,y>=8 and 11 or y==7 and 3 or 2)
      end
    end end end
    b(7,12,7,2,1,2,3);b(7,13,7,2,1,2,1)
    -- Dark serial label with a bright C; unlike a Pokeball's round button.
    b(6,2,11,4,4,1,3)
    b(7,3,12,1,2,1,4);b(8,3,12,1,1,1,4);b(8,5,12,1,1,1,4)
    b(5,6,7,1,2,1,4)
  end
  for _,kind in ipairs({'helix_fossil','dome_fossil','old_amber'}) do
    local b=model(kind)
    for x=3,12 do for z=3,12 do
      local r=((x+.5-8)/5)^2+((z+.5-8)/4.5)^2
      if r<1 then
        local h=math.floor(2+(1-r)*4)
        b(x,0,z,1,h,1,kind=='old_amber' and 11 or 2)
        if kind=='dome_fossil' and z>5 and z<10 and x%3==0 then b(x,h,z,1,1,1,10) end
      end
    end end
    if kind=='helix_fossil' then
      for i=0,42 do
        local a=i*.28;local r=.5+i*.075
        local x,z=math.floor(8+math.cos(a)*r),math.floor(8+math.sin(a)*r)
        b(x,5-math.floor(r/2),z,1,1,1,11)
      end
      b(9,1,10,3,2,2,3)
    elseif kind=='dome_fossil' then
      b(4,1,9,2,2,2,3);b(10,1,9,2,2,2,3)
      b(5,2,10,1,1,1,11);b(10,2,10,1,1,1,11)
    else
      b(5,3,5,6,3,6,11);b(6,6,6,4,1,4,4)
      b(7,7,7,2,1,2,13);b(5,6,7,2,1,1,13);b(9,6,8,2,1,1,13)
    end
  end
  for _,spec in ipairs({{'leaf_stone',12},{'fire_stone',15},{'water_stone',7},
      {'thunder_stone',11},{'moon_stone',14},{'sun_stone',11}})do
    local b=model(spec[1]);local c=spec[2]
    for x=4,11 do for z=3,12 do
      local r=((x+.5-8)/4.2)^2+((z+.5-8)/5.2)^2
      if r<1 then b(x,0,z,1,math.floor(2+(1-r)*4),1,c) end
    end end
    if spec[1]=='leaf_stone' then
      for z=5,11 do local w=z<8 and z-4 or 12-z;b(8-w,5,z,w*2,1,1,9);b(8,6,z,1,1,1,11) end
    elseif spec[1]=='thunder_stone' then
      b(8,6,5,2,1,3,4);b(6,6,8,4,1,1,4);b(6,5,9,2,1,3,4)
    elseif spec[1]=='moon_stone' then
      b(5,4,5,2,1,2,16);b(9,5,8,2,1,2,16);b(6,3,11,2,1,1,16)
    elseif spec[1]=='water_stone' then
      b(7,6,6,2,1,4,9);b(6,5,9,4,1,2,9)
    else b(7,6,6,2,1,5,4);b(6,5,8,4,1,3,11) end
  end
  -- The native book sprite is also Daisy's paper map and Cinnabar's diaries.
  local b=model('town_map')
  b(1,0,3,14,1,11,2);b(1,1,3,14,1,10,4)
  b(2,2,4,12,1,8,7)
  for _,r in ipairs({{3,5,4,5},{7,4,3,7},{10,6,3,5}})do b(r[1],3,r[2],r[3],1,r[4],12)end
  b(4,4,6,8,1,1,11);b(5,4,6,1,1,5,11);b(9,4,5,1,1,5,11)
  for _,pt in ipairs({{4,6},{5,10},{9,5},{9,9},{11,6}})do b(pt[1],5,pt[2],1,1,1,1)end
  b(7,2,3,1,1,11,2);b(1,2,12,14,1,1,4)
  for _,kind in ipairs({'research_diary','magazine'})do
    b=model(kind);local color=kind=='magazine' and 7 or 13
    b(1,0,3,14,1,11,color);b(2,1,4,12,1,9,2);b(2,2,4,5,1,8,4);b(8,2,4,5,1,8,4)
    b(7,1,3,1,2,11,color)
    for z=5,10,2 do b(3,3,z,3,1,1,16);b(9,3,z,3,1,1,16)end
    if kind=='magazine' then
      b(9,3,5,3,1,4,7);b(10,4,6,2,1,2,11);b(8,3,11,5,1,1,color)
    else b(12,2,11,1,1,3,1)end
  end

  for _,kind in ipairs({'town_map','research_diary','magazine'})do
    P.models[kind].step=.5
    for _,box in ipairs(P.models[kind].boxes)do box[2]=box[2]/2;box[5]=box[5]/2 end
  end

end
