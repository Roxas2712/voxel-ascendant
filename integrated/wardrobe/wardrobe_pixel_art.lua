-- Pure, deterministic native-pixel composer shared by game and offline export.
-- Source is always the protected KASC crystal_chars 16x96 sheet. Garment
-- ownership is selected from original palette + pose, never from a prior layer.
return function(P)
 local M={version=P.version,sources=P.sources}
 local function rgb(hex)return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,1 end
 local function key(r,g,b)return string.format('%02x%02x%02x',math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5))end
 local hairPixels={RED={['2d2221']=true},BLUE={['944016']=true},GREEN={['683a2b']=true,['3f241d']=true}}
 local skin={RED='f4ae7e',BLUE='f4aa77',GREEN='f0a77a'}
 function M.build(base,id,parts,selection,newImage)
  assert(base:getWidth()==16 and base:getHeight()==96,'expected original six-frame KASC sprite')
  local out=newImage(16,96);out:paste(base,0,0,0,0,16,96)
  local up=parts.upper~='original'and assert(P.upper[id][parts.upper],'unknown 2D upper')
  local low=parts.lower~='original'and assert(P.lower[parts.lower],'unknown 2D lower')
  local shoe=parts.footwear~='original'and assert(P.footwear[parts.footwear],'unknown 2D footwear')
  if id=='BLUE'and parts.footwear=='champion-shoes'then shoe={'d8ac48','23252c'}end
  local hair=P.hair[selection.hair];local streak=P.hair[selection.streak]
  local function put(x,y,color)if color then out:setPixel(x,y,rgb(color))end end
  for frame=0,5 do
   local side=frame%3==2;local back=frame%3==1;local step=frame>=3 and 1 or 0
   for y=0,15 do for x=0,15 do
    local Y=frame*16+y;local r,g,b,a=base:getPixel(x,Y);local c=key(r,g,b)
    if a>0 then
     local eye=id=='GREEN'and not back and(
       side and x==5 and(y==6+step or y==7+step)
       or not side and(x==5 or x==9)and(y==7+step or y==8+step))
     if hairPixels[id][c]and not eye then
      if hair then put(x,Y,hair[(id=='GREEN'and c=='3f241d')and 2 or 1])end
      if streak and(x==5 or x==6)then put(x,Y,streak[1])end
     end
     local upper=(id=='RED'and y>=9 and(c=='ac262b'or c=='f5efdc'))
      or(id=='BLUE'and y>=10 and(c=='23242a'or c=='4c4e58'))
      or(id=='GREEN'and((c=='222228')or(c=='f5efdc'and y==11+step)))
     if up and upper then
      local color=up[(x+y)%5==0 and 2 or 1]
      if parts.upper:find('champion',1,true)then
       if (y==10+step and not side and(x==4 or x==11))or x==7 then color=up[3]end
       if id=='RED'and not back then
        if y==10+step and(x==6 or x==9)then color=P.colors.cream
        elseif x==7 or x==8 then color=P.colors.ink end
       elseif id=='GREEN'and not back and y==10+step then color='226e41'end
      elseif parts.upper=='lotta-vest'then
       if (not back and x>=6 and x<=9)or(side and x==7)then color=up[3]end
      elseif parts.upper:find('jacket',1,true)and not back and x==7 then color=up[3]end
      put(x,Y,color)
     end
     -- Green's native lower includes bare legs. Trousers cover only those
     -- leg pixels; the face and moving hands remain owned by the base frame.
     local lower=(id=='RED'and(c=='2c5b84'or c=='3f789f'))or(id=='BLUE'and c=='664591')
      or(id=='GREEN'and(c=='27272d'or(y>=13 and c==skin[id])))
     if low and lower then
      if not(parts.lower=='lotta-shorts'and c==skin[id])then
       local color=low[(x+y)%4==0 and 2 or 1]
       if not side and y==13 and(x==7 or x==8)then color=P.colors.ink end
       put(x,Y,color)
      end
     end
     -- Shoe pixels are anchored to each original foot, never added outside
     -- its silhouette. Keep the black sole at y=15 for the original grounding.
     local foot=y==14 and lower or(id=='GREEN'and y==14 and c=='f5efdc')
     if shoe and foot then put(x,Y,shoe[(x%3==0)and 1 or 2])end
     if id=='GREEN'and parts.accessory=='pink-bag'and(c=='1c4e31'or(c=='40b058'and y>=11))then put(x,Y,P.colors.pink)end
    end
   end end
   local head=parts.head or'original'
   local bare=id=='RED'and head=='open-hair'
   local cap=head:find('cap',1,true)~=nil
   assert(head=='original'or head=='source-head'or bare or cap,'unknown native head '..head)
   if bare or cap then
    local backwards=head:find('backward',1,true)~=nil
    local direction=side and(backwards and'leftBack'or'left')or(back~=backwards and'back'or'front')
    local stamp=bare and P.bare[side and'left'or(back and'back'or'front')]or P.cap[direction]
    local accent=head:find('lotta',1,true)and P.colors.pink or P.colors[id:lower()]
    local natural=id=='RED'and'86563b'or(id=='BLUE'and'944016'or'683a2b')
    for y=0,4 do for x=0,15 do
     local Y=frame*16+y+step
     local br,bg,bb=base:getPixel(x,Y)
     -- Green's profile has one skin pixel at the hairline; never erase it.
     if key(br,bg,bb)~=skin[id]then
      local tag=stamp[y+1]:sub(x+1,x+1)
      local color=({O=P.colors.ink,W=P.colors.cream,C=accent,h=hair and hair[1]or natural})[tag]
      if tag=='h'and streak and(x==5 or x==6)then color=streak[1]end
      if color then put(x,Y,color)else out:setPixel(x,Y,0,0,0,0)end
     end
    end end
    -- Red's original embroidered cap extends below the crown into rows 5/6.
    -- Replace ONLY its red/white ink there with the hair beneath the new head.
    -- Skin, ears and all original face/outline pixels remain protected.
    if id=='RED'then
     for y=5,6 do for x=0,15 do
      local Y=frame*16+y+step;local r,g,b=base:getPixel(x,Y);local c=key(r,g,b)
      if c=='d3352f'or c=='ffffff'or c=='f5efdc'then put(x,Y,hair and hair[2]or'493126')end
     end end
    end
    if cap and direction=='front'then
     if head:find('lotta',1,true)then
      put(7,frame*16+1+step,accent);put(6,frame*16+2+step,accent);put(8,frame*16+2+step,accent);put(7,frame*16+3+step,accent)
     else -- Tiny diagonal League mark: lean + baseline, not a square text L.
      put(8,frame*16+1+step,accent);put(7,frame*16+2+step,accent)
      for x=6,9 do put(x,frame*16+3+step,accent)end
     end
    end
   end
   if parts.eyewear~='original'and not back then
    local y=frame*16+7+step
    if side then
     put(4,y,P.colors.ink);put(5,y,P.colors.ink)
    else
     for _,x in ipairs({4,5,6,7,8,9,10,11})do
      if parts.eyewear=='sunglasses'or x~=5 and x~=10 then put(x,y,P.colors.ink)end
     end
    end
   end
  end
  return out
 end
 function M.monochrome(image,newImage)
  local out=newImage(image:getWidth(),image:getHeight())
  for y=0,image:getHeight()-1 do for x=0,image:getWidth()-1 do
   local r,g,b,a=image:getPixel(x,y)
   local l=.2126*r+.7152*g+.0722*b
   local shade=l>.50 and 2/3 or(l>.20 and 1/3 or 0)
   out:setPixel(x,y,shade,shade,shade,a)
  end end
  return out
 end
 return M
end
