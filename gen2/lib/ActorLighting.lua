local V=...
local M={}
function M.install(Voxel3D)
 local Shadows=V.require('Shadows')
 local ShadowMap=V.require('ShadowMap')
 local GlassMask=V.require('GlassMask')
 local IDENTITY={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
function Voxel3D.lightCardSource(source)
  local lights=V.require("LocalLights")
  if not lights.supported then return source end
  source="varying LOVE_HIGHP_OR_MEDIUMP vec3 localCardWorld;\nvarying LOVE_HIGHP_OR_MEDIUMP vec3 localCardSun;\n"..source
  source=source:gsub("#ifdef VERTEX", "#ifdef VERTEX\nuniform mat4 localCardCaster;\nuniform mat4 localCardSunVP;",1)
  source=source:gsub("waterHeight = w.y;", "waterHeight = w.y; localCardWorld=w.xyz; localCardSun=(localCardSunVP*localCardCaster*vertex_position).xyz;",1)
  source=source:gsub("#ifdef PIXEL",function()
    return "#ifdef PIXEL\n"..lights.glsl()..[[
    uniform Image localCardShadowMap;
    uniform vec3 localCardShadowParams;
    float localCardDepth(vec2 uv) {
      vec4 c=Texel(localCardShadowMap,uv);return c.r+c.g/255.0;
    }
    float localCardShadow() {
      vec3 p=localCardSun;
      if(localCardShadowParams.x<=0.0 || p.x<0.0 || p.x>1.0 || p.y<0.0 || p.y>1.0 || p.z>1.0) return 1.0;
      float z=p.z-localCardShadowParams.y;
      float t=localCardShadowParams.z*.5;
      float lit=step(z,localCardDepth(p.xy+vec2(-t,-t)))
        +step(z,localCardDepth(p.xy+vec2(t,-t)))
        +step(z,localCardDepth(p.xy+vec2(-t,t)))
        +step(z,localCardDepth(p.xy+vec2(t,t)));
      vec2 edge=min(p.xy,1.0-p.xy);
      return 1.0-localCardShadowParams.x*smoothstep(0.0,.06,min(edge.x,edge.y))*(1.0-lit*.25);
    }
    vec3 localCardColor(vec3 rgb) {
      // Cards are two-sided artwork, not a flat physical sheet facing away
      // from every backlight. Wrapped diffuse keeps faces readable.
      vec3 n=vec3(0.0,1.0,0.0);
      return rgb*(localSceneTint*localSurfaceShade(1.0,n,localCardWorld)*localCardShadow()
        +localActorIrradiance(localCardWorld,n));
    }
    ]]
  end,1)
  source=source:gsub("p.rgb %* cardShade", "localCardColor(p.rgb * cardShade)")
  source=source:gsub("softToon%(p.rgb%) %* cardShade", "localCardColor(softToon(p.rgb) * cardShade)")
  return source
end
function Voxel3D.cardLightFailed(reason)
  V.require('LocalLights').fail(reason)
end
function Voxel3D.sendCardLighting(shader, caster)
  local lights=V.require("LocalLights")
  if not lights.supported or not shader:hasUniform("localCardCaster") then return end
  local updated=lights.send(shader,Voxel3D.localLightsActive)
  shader:send("localCardCaster","row",caster or IDENTITY)
  if updated then
    local sun=not lights.mobile and Voxel3D.localLightsActive and lights.active() and lights.current().sky
      and Shadows.enabled() and ShadowMap.active()
    shader:send("localCardSunVP","row",sun and ShadowMap.uvVP or IDENTITY)
    shader:send("localCardShadowMap",lights.mobile and GlassMask.blank() or ShadowMap.texture())
    shader:send("localCardShadowParams",{sun and Voxel3D.SHADOW_ALPHA or 0,ShadowMap.bias,1/ShadowMap.res})
  end
end

end
return M
