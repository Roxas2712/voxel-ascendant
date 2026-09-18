-- Runtime decal using the user's original wordmark and crown references.
-- Source images remain unchanged; only their foreground is sampled.
return function(mod)
 local G=love.graphics
 local canvas=G.newCanvas(256,96);local font=G.newFont(19)
 G.push('all');G.setCanvas(canvas);G.origin();G.clear(0,0,0,0);G.setShader();G.setColor(.15,.14,.12,1);G.setFont(font)
 G.printf('Designed and Credits by',0,5,256,'center');G.setCanvas();G.pop()
 local pixels=canvas:newImageData();canvas:release();font:release()
 local ink={.13,.12,.10}
 local word=love.image.newImageData(mod.path..'/assets/omega-reference.png')
 -- Crop to the complete ΩDIAS wordmark, omitting the unrelated left fragment.
 for y=0,35 do for x=0,101 do
  local red=word:getPixel(24+x,20+y)
  if red>.5 then
   for dy=0,0 do pixels:setPixel(58+x,40+y+dy,ink[1],ink[2],ink[3],math.min(1,(red-.5)*2))end
  end
 end end
 word:release()
 local crown=love.image.newImageData(mod.path..'/assets/crown-reference.png')
 for y=0,29 do for x=0,39 do
  local red=crown:getPixel(118+math.floor(x*405/40),27+math.floor(y*294/30))
  if red<.5 then pixels:setPixel(174+x,42+y,ink[1],ink[2],ink[3],1)end
 end end
 crown:release()
 local texture=G.newImage(pixels);pixels:release();texture:setFilter('linear','linear');return texture
end
