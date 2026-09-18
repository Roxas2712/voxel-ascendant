-- Kanto adapter for the existing Gen2JohtoArenaProps entrance marker.
-- Same occupied voxels, sphere/button and plaque pixels; uses the existing
-- VoxelItems palette. No replacement bitmap or trainer sprite is introduced.
-- Source geometry SHA256: 05c4c1afe56323c72a2d3ded5008101c5dc121d8dfd99ff84589d99b349e9306
local M={}
local specs={
 PEWTER_GYM={ts='GYM',w=5,h=7,at={{3,9},{6,9}}},
 CERULEAN_GYM={ts='GYM',w=5,h=7,at={{3,10},{6,10}}},
 VERMILION_GYM={ts='GYM',w=5,h=9,at={{3,13},{6,13}}},
 CELADON_GYM={ts='GYM',w=5,h=9,at={{3,14},{6,14}}},
 FUCHSIA_GYM={ts='GYM',w=5,h=9,at={{3,14},{6,14}}},
 VIRIDIAN_GYM={ts='GYM',w=10,h=9,at={{15,14},{18,14}}},
 FIGHTING_DOJO={ts='DOJO',w=5,h=6,at={{3,8},{6,8}}},
 SAFFRON_GYM={ts='FACILITY',w=10,h=9,at={{9,14}}},
 CINNABAR_GYM={ts='FACILITY',w=10,h=9,at={{17,12}}},
}
local native={GYM={{2,56},{18,19},{34,35},{50,51}},
 DOJO={{2,56},{18,19},{34,35},{50,51}},
 FACILITY={{1,1},{39,47},{55,63},{61,62}}}
local rows={
 '3000000000000003','0033001111003300','0330111221110330','0301112332111030',
 '0301112332111030','0011111221111100','0011111111111100','0001111111111000',
 '0030011001100300','0033000330003300','0003330330333000','0300333003330030',
 '0300003333000030','0300000000000030','0330000000000330','0333333333333330',
 '0333333333333310','0332222222222110','0332222222222110','0332222222222110',
 '0332111111132110','0332122222232110','0132121111232100','0310122222230010',
 '0132121211232100','0310122222230010','0332121121232110','0332122222232110',
 '0332333333332110','0332222222222110','1032222222222101','1100000000000011',
}
 local function occupied(x,y,z)
  if x<0 or x>=16 or y<0 or y>=30 or z<0 or z>=32 then return false end
  if y<2 then return true end -- only the low foot spans both blocked cells
  if y<14 then return x>=1 and x<15 and z>=10 and z<22 end
  if y<16 then return z>=8 and z<24 end
  return (x+.5-8)^2+(y+.5-23)^2+(z+.5-16)^2<=7.2^2
 end
M.occupied=occupied
function M.register(P,F)
 local model={boxes={},frameW=16,frameH=48,depth=32,offsetY=-16}
 local gray={3,16,14,4}
 for y=0,29 do for z=0,31 do for x=0,15 do
  if occupied(x,y,z)then
   local color=y>=24 and 1 or(y>=22 and 3 or 4)
   if y<16 then color=14
   elseif z>=16 then
    local radius2=(x+.5-8)^2+(y+.5-23)^2
    if radius2<=2.2^2 then color=4 elseif radius2<=3.2^2 then color=3 end
   end
   if y>=2 and y<14 and z==21 and x>=3 and x<13 then
    color=gray[tonumber(rows[32-y]:sub(x+1,x+1))+1]
   end
   model.boxes[#model.boxes+1]={x,y,z,1,1,1,color}
  end
 end end end
 P.models.gym_ball_marker=model
 for id,spec in pairs(specs)do
  for _,at in ipairs(spec.at)do
   local id,spec,at=id,spec,at
   table.insert(F.patterns,1,{kind='gym_ball_marker',sets={[spec.ts]=true},maps={[id]=true},
    x=at[1]*2,y=at[2]*2,tiles=native[spec.ts],guard=function(map)
     local d=map.def
     return d.generation~=2 and d.width==spec.w and d.height==spec.h and not d.outdoor
      and not next(d.connections or {})
      and not map:isWalkableCell(at[1],at[2]) and not map:isWalkableCell(at[1],at[2]+1)
      and not map:isWarpTileCell(at[1],at[2]) and not map:isWarpTileCell(at[1],at[2]+1)
    end})
  end
 end
end
M.specs=specs
M.native=native
return M
