-- Small depth-tested particle layer, drawn after actors and before the HUD.
-- Geometry is allocated once; animation is shader-only, without extra canvases.
return function(api)
 local G=love.graphics
 local S={};local mesh,shader;local failed=false
 local function init()
  local vertices={}
  for i=0,17 do
   local angle=(i+.5)*2*math.pi/12
   local radius=i<12 and 49 or 27
   for _,uv in ipairs({{0,0},{1,0},{1,1},{0,0},{1,1},{0,1}})do
    vertices[#vertices+1]={math.cos(angle)*radius,0,math.sin(angle)*radius,uv[1],uv[2],i/18}
   end
  end
  shader=G.newShader([[
   varying vec2 puffUV; varying vec3 localPos;
   uniform vec3 tint; uniform vec3 actorA; uniform vec3 actorB;
   uniform float clock; uniform float smoke; uniform float towerMist;
   vec4 effect(vec4 color,Image tex,vec2 uv,vec2 sc){
    vec2 p=puffUV*2.0-1.0;
    float soft=1.0-smoothstep(0.15,1.0,dot(p,p));
    float clearActors=smoothstep(8.0,17.0,min(length(localPos.xz-actorA.xz),length(localPos.xz-actorB.xz)));
    float wave=0.5+0.5*sin(clock*0.55+localPos.x*0.12+localPos.z*0.09);
    float wisps=0.72+0.28*sin(localPos.x*0.37+clock*0.4)*sin(localPos.z*0.29-clock*0.3);
    float opacity=mix(0.28+towerMist*0.12+wave*0.14,0.18+wave*0.15,smoke);
    float rim=1.0-smoothstep(68.0,73.0,length(localPos.xz));
    return vec4(tint,soft*opacity*wisps*clearActors*rim);
   }
  ]],[[
   attribute float PuffSeed;
   uniform mat4 vp; uniform mat4 model; uniform float clock; uniform float smoke; uniform float towerMist;
   uniform vec3 right; varying vec2 puffUV; varying vec3 localPos;
   vec4 position(mat4 transform_projection,vec4 p){
    float age=fract(clock*(0.075+smoke*0.055)+PuffSeed);
    float width=mix(31.0+towerMist*9.0,8.0,smoke)*(0.8+age*0.5);
    float height=mix(12.0+towerMist*5.0,16.0,smoke);
    vec2 uv=VertexTexCoord.xy;
    vec3 center=p.xyz;
    center.x+=sin(clock*0.24+PuffSeed*31.0)*3.0;
    center.z+=cos(clock*0.19+PuffSeed*21.0)*2.0;
    center.y=mix(5.0+sin(clock*0.27+PuffSeed*21.0)*1.2,5.0+age*19.0,smoke);
    localPos=center+right*(uv.x-0.5)*width+vec3(0.0,(uv.y-0.5)*height,0.0);
    puffUV=uv;
    return vp*model*vec4(localPos,1.0);
   }
  ]])
  mesh=G.newMesh({{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'PuffSeed','float',1}},vertices,'triangles','static')
 end
 function S.draw(arena,y)
  local setup=arena.terarrium
  if failed or not setup or not setup.gymDesign then return end
  local smoke=setup.id=='CINNABAR_GYM'
  local tower=setup.id:match('^POKEMON_TOWER_[2-7]F$')~=nil
  if not smoke and setup.id~='FUCHSIA_GYM'and not tower then return end
  G.push('all')
  local ok,err=pcall(function()
   if not mesh then init()end
   local x,z=arena.mid[1],arena.mid[2];local eye=api.Voxel3D.eye
   local dx,dz=eye[1]-x,eye[3]-z;local distance=math.max(.001,math.sqrt(dx*dx+dz*dz))
   G.setShader(shader);shader:send('vp','row',api.Voxel3D.vp)
   shader:send('model','row',api.Mat4.translate(x,y,z))
   shader:send('clock',(api.clock and api.clock()or 0)%1000)
   shader:send('towerMist',tower and 1 or 0);shader:send('smoke',smoke and 1 or 0);shader:send('right',{dz/distance,0,-dx/distance})
   shader:send('tint',smoke and {.40,.37,.35}or(tower and{.67,.65,.78}or{.68,.70,.76}))
   shader:send('actorA',setup.actors.player);shader:send('actorB',setup.actors.enemy)
   G.setColor(1,1,1,1);G.setBlendMode('alpha','alphamultiply');G.setMeshCullMode('none')
   G.setDepthMode('lequal',false);G.draw(mesh)
  end)
  G.pop()
  if not ok then
   S.release();failed=true;S.failure=tostring(err)
   print('[VASC Terrarium] Optional gym atmosphere disabled: '..S.failure)
  end
 end
 function S.release()
  if mesh then mesh:release();mesh=nil end
  if shader then shader:release();shader=nil end
 end
 return S
end
