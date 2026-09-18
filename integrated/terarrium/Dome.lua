-- Optional translucent glass, drawn after all actors and before the HUD.
return function(api)
 local G=love.graphics;local mesh,shader
 local S={}
 local tints={clear={.78,.91,.96},blue={.30,.65,1},rose={1,.51,.68},gold={1,.79,.36}}
 function S.draw(arena,y,style)
  if not mesh then
   local verts={};local function point(a,b)
    return {77*math.cos(a)*math.sin(b),3.7+72*math.cos(b),77*math.sin(a)*math.sin(b)}
   end
   for j=0,23 do for i=0,95 do
    local a,b=i*math.pi/48,(i+1)*math.pi/48;local c,d=j*math.pi/48,(j+1)*math.pi/48
    for _,p in ipairs({point(a,c),point(a,d),point(b,d),point(a,c),point(b,d),point(b,c)})do verts[#verts+1]=p end
   end end
   mesh=G.newMesh({{'VertexPosition','float',3}},verts,'triangles','static')
   shader=G.newShader([[
    uniform vec3 tint;uniform vec3 eye;uniform float glassPass;uniform float ballKind;uniform vec3 shellBase;uniform vec3 shellAccent;varying vec3 localPos;
    float stroke(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));}
    vec4 effect(vec4 color,Image tex,vec2 uv,vec2 sc){
     vec3 n=normalize(vec3(localPos.x/77.0,(localPos.y-3.7)/72.0,localPos.z/77.0));
     vec3 v=normalize(eye-localPos);float facing=dot(n,v);
     bool window=localPos.z>1.6;
     if(glassPass<0.5){
      if(window)discard;
      float light=0.67+0.27*max(0.0,dot(n,normalize(vec3(-0.5,0.8,0.7))));
      vec3 ball=shellBase;
      float bands=1.0-smoothstep(9.0,10.5,abs(abs(localPos.x)-33.0));
      if(ballKind>0.5 && ballKind<2.5)ball=mix(ball,shellAccent,bands);
      if(ballKind>2.5 && ballKind<3.5){
       vec2 lobe=vec2((abs(localPos.x)-34.0)/13.5,(localPos.y-51.0)/22.0);
       ball=mix(ball,shellAccent,1.0-smoothstep(.91,1.0,length(lobe)));
       vec2 p=vec2(localPos.x/13.0,(localPos.y-40.0)/11.0);
       float mark=min(min(stroke(p,vec2(-.8,-.7),vec2(-.8,.7)),stroke(p,vec2(-.8,.7),vec2(0.0,-.05))),min(stroke(p,vec2(0.0,-.05),vec2(.8,.7)),stroke(p,vec2(.8,.7),vec2(.8,-.7))));
       if(localPos.z < -12.0)ball=mix(ball,vec3(1.0),1.0-smoothstep(.09,.13,mark));
      }
      if(ballKind>3.5 && ballKind<4.5){
       vec2 p=vec2(localPos.x/13.0,(localPos.y-40.0)/10.0);
       float leaf=length(vec2((p.x+.3*p.y)*1.5,p.y));
       float mark=(1.0-smoothstep(.72,.8,leaf))*smoothstep(.055,.085,abs(p.x));
       if(localPos.z < -12.0)ball=mix(ball,shellAccent,mark);
      }
      if(ballKind>4.5){
       vec3 p=floor(localPos/5.5);
       float patch=sin(p.x*.87+p.y*1.23+p.z*.72)+cos(p.x*.41-p.z*1.18);
       ball=patch>.6?shellAccent:patch<-.45?vec3(.18,.28,.115):shellBase;
      }
      vec3 shell=ball*light;
      if(localPos.z>-1.4)shell=mix(ball,vec3(1.0),0.24);
      return vec4(shell,1.0);
     }
     if(!window || facing<0.0)discard;
     float edge=pow(1.0-facing,3.0);
     float glint=pow(max(0.0,dot(n,normalize(vec3(-0.45,0.8,0.52)))),48.0);
     float glint2=pow(max(0.0,dot(n,normalize(vec3(0.6,0.55,0.6)))),95.0);
     float border=1.0-smoothstep(1.6,3.4,localPos.z);
     return vec4(mix(tint,vec3(1.0),clamp(glint+glint2+border,0.0,1.0)),0.10+edge*0.38+glint*0.58+glint2*0.40+border*0.5);
    }
   ]],[[
    uniform mat4 vp;uniform mat4 model;varying vec3 localPos;
    vec4 position(mat4 transform_projection,vec4 p){localPos=p.xyz;return vp*model*p;}
   ]])
  end
  local x,z=arena.mid[1],arena.mid[2];local eye=api.Voxel3D.eye
  G.push('all')
  local ok,err=pcall(function()
   G.setShader(shader);shader:send('vp','row',api.Voxel3D.vp);shader:send('model','row',api.Mat4.translate(x,y,z))
   shader:send('eye',{eye[1]-x,eye[2]-y,eye[3]-z});shader:send('tint',tints[style]or tints.clear)
   local ball=arena.terarrium.ballStyle or 'poke'
   local appearance=api.ballAppearance(ball)
   shader:send('ballKind',appearance.kind);shader:send('shellBase',appearance.base);shader:send('shellAccent',appearance.accent)
   G.setColor(1,1,1,1);G.setBlendMode('alpha','alphamultiply');G.setMeshCullMode('none');G.setDepthMode('lequal',true);shader:send('glassPass',0);G.draw(mesh)
   G.setDepthMode('lequal',false);shader:send('glassPass',1);G.draw(mesh)
  end)
  G.pop();if not ok then error(err)end
 end
 function S.release()if mesh then mesh:release();shader:release();mesh,shader=nil,nil end end
 return S
end
