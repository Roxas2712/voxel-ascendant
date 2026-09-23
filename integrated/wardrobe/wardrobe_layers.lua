-- Cosmetic layers are registered to each existing frame, never to an
-- animation clock. Rods, bicycles, thrown balls and arm poses remain owned
-- by the source animation. All rectangles below are cell-local.
return function(mod)
  local L={version='layers-6',donors={}}
  local colors={black={.13,.14,.18},brown={.40,.22,.12},blond={.88,.68,.30},
    silver={.70,.75,.80},red={.66,.16,.15},blue={.16,.36,.68},purple={.47,.24,.63}}
  local function clamp(v,a,b)return math.max(a,math.min(b,v))end
  local function skin(r,g,b)return r>.40 and g>.23 and r>g*1.08 and g>b*1.17 and r-g<.38 end
  local function components(data,x0,y0,w,h,predicate)
    local seen,result={},{}
    local function match(x,y)
      if x<0 or y<0 or x>=w or y>=h then return false end
      local index=y*w+x
      if seen[index]then return false end
      local r,g,b,a=data:getPixel(x0+x,y0+y)
      return a>.25 and predicate(r,g,b,x,y)
    end
    for y=0,h-1 do for x=0,w-1 do
      if match(x,y)then
        local queue={{x,y}};seen[y*w+x]=true
        local c={l=x,t=y,r=x,b=y,n=0}
        local cursor=1
        while cursor<=#queue do
          local p=queue[cursor];cursor=cursor+1;c.n=c.n+1
          c.l=math.min(c.l,p[1]);c.r=math.max(c.r,p[1]);c.t=math.min(c.t,p[2]);c.b=math.max(c.b,p[2])
          for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
            local nx,ny=p[1]+d[1],p[2]+d[2]
            if match(nx,ny)then seen[ny*w+nx]=true;queue[#queue+1]={nx,ny}end
          end
        end
        c.pixels=queue;result[#result+1]=c
      end
    end end
    table.sort(result,function(a,b)return a.n>b.n end)
    return result
  end
  local function bounds(data,x0,y0,w,h)
    local b={l=w,t=h,r=-1,b=-1}
    for y=0,h-1 do for x=0,w-1 do
      local _,_,_,a=data:getPixel(x0+x,y0+y)
      if a>.2 then b.l=math.min(b.l,x);b.r=math.max(b.r,x);b.t=math.min(b.t,y);b.b=math.max(b.b,y)end
    end end
    return b.r>=b.l and b or nil
  end
  local function clip(b,w,h)
    b.l=clamp(math.floor(b.l),0,w-1);b.r=clamp(math.ceil(b.r),0,w-1)
    b.t=clamp(math.floor(b.t),0,h-1);b.b=clamp(math.ceil(b.b),0,h-1)
    return b
  end
  function L.head(data,x0,y0,w,h,id,direction)
    local body=bounds(data,x0,y0,w,h);if not body then return nil end
    if id=='RED'then
      local groups=components(data,x0,y0,w,h,function(r,g,b,x,y)
        return r>g*1.45 and r>b*1.35 and r>.27 and y<body.t+(body.b-body.t)*.59
      end)
      local cap
      for _,c in ipairs(groups)do
        if c.n>=math.max(2,w*h*.0009)and (not cap or c.t<cap.t and c.n>cap.n*.16)then cap=c end
      end
      if cap then
        local cw,ch=cap.r-cap.l+1,cap.b-cap.t+1
        return clip({l=cap.l-cw*.18,r=cap.r+cw*.18,t=cap.t-ch*.08,
          b=cap.b+ch*(direction==2 and .48 or .73),cap=cap},w,h)
      end
    else
      local groups=components(data,x0,y0,w,h,function(r,g,b,x,y)
        if y>body.t+(body.b-body.t)*.6 then return false end
        if id=='BLUE'then return r>.38 and r-g>.23 and g>b*1.5 end
        return r>.13 and r<.76 and r>g*1.32 and g>b*1.25 and g<.47
      end)
      local c=groups[1]
      if c and c.n>2 then
        local width=c.r-c.l+1
        return clip({l=c.l-width*.06,r=c.r+width*.06,t=c.t,b=c.t+width*(id=='BLUE'and .87 or .84),
          hairBottom=id=='GREEN'and math.floor(body.t+(body.b-body.t)*.80)or nil},w,h)
      end
    end
    return clip({l=body.l,r=body.r,t=body.t,b=body.t+(body.b-body.t)*.37},w,h)
  end
  local function direction(path,cols,row)
    if cols==3 then return row end
    if path:find('_back',1,true)then return 2 end
    return ({[0]=0,[1]=2,[2]=1,[3]=0,[4]=2,[5]=1})[row]or 0
  end
  local function donor(kind,dir)
    local key=kind..':'..dir
    if L.donors[key]then return L.donors[key]end
    local data=love.image.newImageData(mod.path..'/assets/wardrobe/heads/'..kind..'.png')
    if kind=='beanie-cap'then
      local w,h=data:getDimensions();local cw,ch=w/2,h/2
      local x0,y0=(dir%2)*cw,math.floor(dir/2)*ch
      local b={l=cw,t=ch,r=-1,b=-1}
      for y=0,ch-1 do for x=0,cw-1 do
        local _,_,_,a=data:getPixel(x0+x,y0+y)
        if a>.87 then b.l=math.min(b.l,x);b.r=math.max(b.r,x);b.t=math.min(b.t,y);b.b=math.max(b.b,y)end
      end end
      assert(b.r>=b.l,'empty modular cap')
      local out=love.image.newImageData(b.r-b.l+1,b.b-b.t+1)
      for y=0,out:getHeight()-1 do for x=0,out:getWidth()-1 do
        local r,g,blue,a=data:getPixel(x0+b.l+x,y0+b.t+y)
        if a>.87 then out:setPixel(x,y,r,g,blue,1)end
      end end
      data:release();L.donors[key]=out;return out
    end
    local w,h=data:getDimensions();local cw,ch=w/3,h/4
    local b=bounds(data,0,dir*ch,cw,ch)
    assert(b,'empty head donor '..kind)
    -- Walking donors include complete figures, but only the compact head
    -- above the collar is used. It is shared across every existing pose.
    b.b=b.t+(b.b-b.t)*(dir==2 and .33 or .365)
    b=clip(b,cw,ch)
    local out=love.image.newImageData(b.r-b.l+1,b.b-b.t+1)
    out:paste(data,0,0,b.l,dir*ch+b.t,out:getWidth(),out:getHeight())
    data:release();L.donors[key]=out
    return out
  end
  local function put(data,x,y,r,g,b,a)
    local w,h=data:getDimensions()
    if x<0 or y<0 or x>=w or y>=h then return end
    data:setPixel(x,y,r,g,b,a)
  end
  local function replace(data,x0,y0,w,h,box,kind,dir)
    local d=donor(kind,dir);local dw,dh=d:getDimensions()
    local tw,th=box.r-box.l+1,box.b-box.t+1
    -- Erase the old head's silhouette; source pixels outside this ellipse
    -- include raised hands, rods and the actual throw animation.
    local cx,cy=(box.l+box.r)/2,(box.t+box.b)/2
    for y=box.t,box.b do for x=box.l,box.r do
      if ((x-cx)/(tw*.56))^2+((y-cy)/(th*.61))^2<=1 then put(data,x0+x,y0+y,0,0,0,0)end
    end end
    for y=0,th-1 do for x=0,tw-1 do
      local sx=clamp(math.floor((x+.5)*dw/tw),0,dw-1)
      local sy=clamp(math.floor((y+.5)*dh/th),0,dh-1)
      local r,g,b,a=d:getPixel(sx,sy)
      if a>.06 then put(data,x0+box.l+x,y0+box.t+y,r,g,b,a)end
    end end
  end
  local function recolor(data,x0,y0,box,id,selection,dir)
    local target=colors[selection.hair];local streak=colors[selection.streak]
    if not target and not streak then return end
    local w,h=box.r-box.l+1,box.b-box.t+1
    for y=box.t,box.hairBottom or box.b do for x=box.l,box.r do
      local r,g,b,a=data:getPixel(x0+x,y0+y)
      local u,v=(x-box.l)/w,(y-box.t)/h
      local isHair
      if id=='RED'then
        isHair=math.max(r,g,b)<.40 and math.max(r,g,b)>.055
          and math.max(r,g,b)-math.min(r,g,b)<.14 and (v<.58 or u<.23 or u>.77 or dir==2)
      elseif id=='BLUE'then isHair=r-g>.22 and g>b*1.6 and b<.19 and(v<.84 or dir==2)
      else isHair=r<.70 and g<.40 and r>g*1.3 and g>b*1.2 end
      if a>.15 and isHair then
        local color=streak and u>.25+.13*v and u<.34+.13*v and streak or target
        if color then
          local shade=.46+math.max(r,g,b)*.85
          data:setPixel(x0+x,y0+y,clamp(color[1]*shade,0,1),clamp(color[2]*shade,0,1),clamp(color[3]*shade,0,1),a)
        end
      end
    end end
  end
  local function glasses(data,x0,y0,w,h,box,kind,dir)
    if kind=='none'or not kind or dir==2 then return end
    local groups=components(data,x0,y0,w,h,function(r,g,b,x,y)
      return x>=box.l and x<=box.r and y>=box.t and y<=box.b
        and skin(r,g,b)and r>.68 and g>.42 and b>.20
    end)
    local face=groups[1];if not face then return end
    local fw,fh=face.r-face.l+1,face.b-face.t+1
    local cy=face.t+fh*.38
    local centers=dir==0 and{face.l+fw*.28,face.l+fw*.72}or{face.l+fw*(dir==1 and .32 or .68)}
    local rx,ry=math.max(1,fw*(dir==0 and .18 or .17)),math.max(1,fh*.16)
    local line=math.max(1,fw*.035)
    for _,cx in ipairs(centers)do
      for y=math.floor(cy-ry-line),math.ceil(cy+ry+line)do for x=math.floor(cx-rx-line),math.ceil(cx+rx+line)do
        local dx,dy=math.abs(x-cx)/rx,math.abs(y-cy)/ry
        local edge=math.sqrt(dx*dx+dy*dy)
        if edge<=1.08 and (kind=='sunglasses'or edge>math.max(.65,1-line/rx))then
          local shade=kind=='sunglasses'and dy<.3 and .17 or .065
          put(data,x0+x,y0+y,shade,shade+.01,shade+.025,1)
        end
      end end
    end
    if #centers==2 then
      for x=math.floor(centers[1]+rx),math.ceil(centers[2]-rx)do put(data,x0+x,y0+math.floor(cy),.07,.08,.09,1)end
    end
  end
  function L.apply(data,id,selection,cols,rows,path)
    local w,h=data:getDimensions();local cw,ch=w/cols,h/rows
    local receipt={}
    for row=0,rows-1 do for col=0,cols-1 do
      local x0,y0=col*cw,row*ch;local dir=direction(path,cols,row)
      local box=L.head(data,x0,y0,cw,ch,id,dir)
      if box then
        if id=='RED'and selection.head~='classic'then
          local kind=selection.head=='none'and(selection.hairstyle=='spiky'and'spiky'or'none')or selection.head
          if kind=='beanie'and box.cap then
            local hat={l=box.l,r=box.r,t=box.t,
              b=math.min(box.b,box.cap.b+math.floor((box.cap.b-box.cap.t+1)*.24))}
            replace(data,x0,y0,cw,ch,hat,'beanie-cap',dir)
          else replace(data,x0,y0,cw,ch,box,kind,dir)end
        end
        recolor(data,x0,y0,box,id,selection,dir)
        glasses(data,x0,y0,cw,ch,box,selection.eyewear,dir)
        receipt[#receipt+1]={column=col,row=row,direction=dir,head=box}
      end
    end end
    return receipt
  end
  L.components=components;L.skin=skin;L.direction=direction;L.bounds=bounds
  return L
end
