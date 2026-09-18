-- Explicit immutable legacy adapter. This is NOT an eight-frame animation
-- contract: the existing renderer owns the three poses and on/off cadence.
local M={KIND='apo.legacy-flame-155/v1',PACKAGE='apo.pokemon-hd.g02.dex0152-0171'}
local prefix='assets/pokemon-flame-cards/cyndaquil-v1/dex-155__cyndaquil__'
local originals={
 normal={on={'a37ee5fbab0b91b0dca24ab27e81fcdf7cb863b490083d166ec9dbdfa46e252a',276112},
  off={'c673a98f41f40a9c4777776b6b238eb1ae735efe6657d1028456ad44fe7bf6d4',159322},
  runtime={'4f6d53561429e10beb4489639cf189f4483b57fc1b36e450848cb185a6a0a7cf',3778}},
 shiny={on={'be7af9efefb2de3110bb186b2871d368c57fa83aed56c25b6626d2232db6f6f0',276170},
  off={'3434c8b4a25de527d1768141180a4a06036c94c9f18cac797b23e1100ebf7d8f',160099},
  runtime={'26da4b8a5c25bf2eb775a2ea6b5d7ee0c76603d10def9d1681b7df1ce806567d',3805}},
}
local function path(palette,kind)
 return prefix..palette..'__'..(kind=='runtime'and'runtime.png'or'fire-'..kind..'__walk-3x4.png')
end
function M.path(value)
 for palette in pairs(originals)do for _,kind in ipairs({'on','off','runtime'})do
  if value==path(palette,kind)then return true end
 end end
 return false
end
function M.validate(entry,files)
 if type(entry)~='table' or entry.kind~=M.KIND or entry.dex~=155
  or entry.form~='00' or entry.gender~='none' or not originals[entry.palette]
  or entry.sourceId~='apo-cyndaquil-go-fire-v1-'..entry.palette
  or entry.runtime_content_width~=15 or entry.runtime_content_height~=16
  or type(entry.clips)~='table' or type(entry.layout)~='table'
  or type(entry.provenance)~='table'
  or entry.provenance.admissionSha256~='e2824660b66b673e4c5a287dd9098e8017f4ea8751b0458022a0113c965ec2c6'
  or entry.provenance.status~='verified-render' then return false end
 local expected={cell_width=256,cell_height=256,left=19,top=55,right=239,bottom=203,
  anchor_x=128,anchor_y=196.65827212120067,reference_height=101}
 for k,v in pairs(expected)do if entry.layout[k]~=v then return false end end
 for k in pairs(entry.layout)do if expected[k]==nil then return false end end
 local count=0
 for kind,clip in pairs(entry.clips)do
  count=count+1;local original=originals[entry.palette][kind]
  if not original or type(clip)~='table' or clip.logicalPath~=path(entry.palette,kind)then return false end
  -- No duration/columns fiction: v1 legacy behavior lives in the renderer.
  for k in pairs(clip)do if k~='logicalPath'then return false end end
  local file=files[clip.logicalPath]
  if not file or file.sha256~=original[1] or file.bytes~=original[2]
   or file.width~=(kind=='runtime' and 16 or 768)
   or file.height~=(kind=='runtime' and 96 or 1024)then return false end
 end
 return count==3
end
function M.textureAllowed(value,width,height)
 -- Exactly four immutable3x4 on/off textures (12MiB RGBA total) plus two
 -- tiny native strips. This is not permission for other full HD atlases.
 for palette in pairs(originals)do for _,kind in ipairs({'on','off','runtime'})do
  if value==path(palette,kind)then
   return width==(kind=='runtime' and 16 or 768)
    and height==(kind=='runtime' and 96 or 1024)
  end
 end end
 return false
end
return M
