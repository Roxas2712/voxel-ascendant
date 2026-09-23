-- One solid, interactive home wardrobe; native furniture uses four shades.
-- VASC replaces this same stationary actor with its voxel cabinet model.
return function(mod,opts)
  local M={map='REDS_HOUSE_2F',x=5,y=1,sprite='SPRITE_KA_WARDROBE'}
  local path='ka_wardrobe_cabinet_v1.png'
  local pixels=love.image.newImageData(16,24)
  local palette={{0,0,0,0},{.08,.08,.08,1},{.35,.35,.35,1},{.68,.68,.68,1},{1,1,1,1}}
  local function rect(x,y,w,h,c)
    for py=y,y+h-1 do for px=x,x+w-1 do pixels:setPixel(px,py,unpack(palette[c]))end end
  end
  rect(1,1,14,22,2);rect(2,2,12,19,4);rect(3,4,4,15,3);rect(9,4,4,15,3)
  rect(3,4,3,1,5);rect(9,4,3,1,5);rect(7,3,2,18,2)
  rect(5,11,1,2,5);rect(10,11,1,2,5);rect(2,21,3,3,2);rect(11,21,3,3,2)
  pixels:encode('png',path);pixels:release()
  mod.content.sprites:register(M.sprite,{id=M.sprite,image=path,frames=1,walker=false,
    trueColor=false,frameWidth=16,frameHeight=24,anchorX=8,anchorY=24,kaWardrobe=true})
  local original=mod.content.maps:get(M.map)
  assert(original,'wardrobe home map missing')
  local objects={};for _,obj in ipairs(original.objects or{})do objects[#objects+1]=obj end
  for _,obj in ipairs(objects)do assert(obj.x~=M.x or obj.y~=M.y,'wardrobe cell occupied')end
  objects[#objects+1]={index=#objects+1,name='KA_HOME_WARDROBE',sprite=M.sprite,
    x=M.x,y=M.y,movement='STAY',range='DOWN',passable=false,text='TEXT_KA_WARDROBE'}
  mod.content.maps:patch(M.map,{objects=objects})
  mod.content.text:register('TEXT_KA_WARDROBE','A wardrobe full of travelling clothes.')
  mod.content.map_scripts:register(M.map,{priority=3500,
    onInteract=function(game,world,x,y)
      if x==M.x and y==M.y then opts.menu.open(game);return true end
    end,
    talk={TEXT_KA_WARDROBE=function(game,world,npc,done)
      local screen=opts.menu.open(game)
      if done then done()end
      return screen
    end}})
  return M
end
