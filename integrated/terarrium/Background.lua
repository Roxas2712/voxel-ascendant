-- A quiet presentation frame behind the complete 3D scene and battle HUD.
return function(api)
 local G=love.graphics;local shader
 local presets={night={{.045,.065,.11},{.31,.56,.79}},forest={{.065,.11,.085},{.36,.62,.40}},stone={{.13,.14,.145},{.63,.67,.65}},gallery={{.83,.85,.85},{.42,.48,.51}}}
 local S={}
 function S.draw(arena,selection)
  if S.failure then return false end
  local appearance=api.ballAppearance(arena.terarrium.ballStyle)
  local base,accent
  if presets[selection]then base,accent=unpack(presets[selection])
  else
   accent=appearance.base
   base={.075+accent[1]*.09,.08+accent[2]*.09,.09+accent[3]*.09}
   if arena.terarrium.ballStyle=='ultra'or arena.terarrium.ballStyle=='apri_black'then accent=appearance.accent end
  end
  G.push('all')
  local ok,err=pcall(function()
  if not shader then shader=G.newShader([[
   uniform vec2 size;uniform vec3 base;uniform vec3 accent;uniform float light;
   vec4 effect(vec4 color,Image tex,vec2 uv,vec2 sc){
    vec2 p=sc/size;vec2 q=(p-vec2(.5,.46))*vec2(size.x/size.y,1.0);
    float halo=exp(-dot(q,q)*7.5);
    float vignette=smoothstep(.3,.85,length(q));
    vec3 rgb=base*(1.0-vignette*.24)+accent*halo*(light>.5?.025:.075);
    float inset=min(min(sc.x,sc.y),min(size.x-sc.x,size.y-sc.y));
    float frame=1.0-smoothstep(.45,1.25,abs(inset-18.0));
    float edge=min(sc.x,size.x-sc.x);
    float corner=(1.0-step(62.0,edge))+(1.0-step(62.0,min(sc.y,size.y-sc.y)));
    rgb=mix(rgb,mix(accent,vec3(.72),.36),frame*(corner>0.0?.32:.10));
    float floorGlow=exp(-pow((p.y-.84)*22.0,2.0))*exp(-pow((p.x-.5)*3.4,2.0));
    rgb+=accent*floorGlow*(light>.5?.016:.035);
    return vec4(rgb,1.0);
   }
  ]])end
  local canvas=G.getCanvas();local w,h
  for _=1,3 do if type(canvas)=='table'and not canvas.getDimensions then canvas=canvas[1]or canvas.canvas else break end end
  if canvas and canvas.getDimensions then w,h=canvas:getDimensions()else w,h=G.getDimensions()end
   G.origin();G.setShader(shader);shader:send('size',{w,h});shader:send('base',base);shader:send('accent',accent);shader:send('light',selection=='gallery'and 1 or 0)
   G.setDepthMode('always',false);G.setColor(1,1,1,1);G.setBlendMode('replace');G.rectangle('fill',0,0,w,h)
  end)
  G.pop()
  if not ok then
   S.failure=tostring(err)
   if api.reportEffectFailure then pcall(api.reportEffectFailure,'background',S.failure)end
   return false
  end
  return true
 end
 function S.release()if shader then shader:release();shader=nil end;S.failure=nil end
 return S
end
