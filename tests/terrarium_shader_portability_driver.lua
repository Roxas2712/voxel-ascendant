-- Dump the installed Terrarium's auxiliary shaders, which are separate from
-- Voxel3D's world program. SHADER_OUT must be an existing isolated directory.
return function(game)
 local e=assert(game.mods.exports.VOXEL_ASCENDANT)
 local function up(fn,name,seen)
  if type(fn)~='function'then return end;seen=seen or {};if seen[fn]then return end;seen[fn]=true
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
  for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local found=up(v,name,seen);if found then return found end end
 end
 local V=assert(up(e.lib.require('VoxelScene').render,'V'));local out=assert(os.getenv('SHADER_OUT'))
 for _,name in ipairs{'Dome','Background','GymAtmosphere'}do
  local source=assert(V.mod:read('integrated/terarrium/'..name..'.lua'))
  local pixel=assert(source:match('G%.newShader%(%[%[(.-)%]%]'))
  local vertex=source:match('G%.newShader%(%[%[.-%]%],%[%[(.-)%]%]') or 'vec4 position(mat4 tp,vec4 p){return tp*p;}'
  for _,modern in ipairs{false,true}do for _,gles in ipairs{false,true}do
   local prefix=modern and '#pragma language glsl3\n' or ''
   local vs,ps=love.graphics._shaderCodeToGLSL(gles,prefix..pixel,prefix..vertex)
   local file=out..'/'..name..'-'..(modern and '3' or '1')..'-'..(gles and 'es' or 'gl')
   for ext,body in pairs{vert=vs,frag=ps}do local f=assert(io.open(file..'.'..ext,'w'));f:write(body);f:close()end
  end end
 end
 print('TERRARIUM_SHADER_STAGES_DUMPED',24);love.event.quit()
end
