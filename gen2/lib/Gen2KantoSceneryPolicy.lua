-- Crystal's Kanto is not Gen1's map catalogue. These narrow presentation
-- contracts fix native-name collisions without changing maps, warps or actors.
local P={}
local layouts={
 VERMILION_DIGLETTS_CAVE_SPEECH_HOUSE={tileset='TILESET_HOUSE',environment='INDOOR',width=4,height=4,class='interior'},
 VICTORY_ROAD_GATE={tileset='TILESET_GATE',environment='GATE',width=10,height=9,class='interior'},
 -- Blaine moved to this small natural cavern. INDOOR controls game behavior;
 -- the visual shell is rock, not the generic building-border extrusion.
 SEAFOAM_GYM={tileset='TILESET_CAVE',environment='INDOOR',width=5,height=4,class='cave'},
 VERMILION_PORT={tileset='TILESET_PORT',environment='ROUTE',width=10,height=18,class='water'},
 -- Keep their land-facing edges and terrain classification. The native
 -- shoreline opens east on Route 14 and south along Route 27's sea channel.
 ROUTE_14={tileset='TILESET_KANTO',environment='ROUTE',width=10,height=18,
  edges={east='open_water'},connections={north={'ROUTE_13',0},west={'ROUTE_15',9}}},
 ROUTE_27={tileset='TILESET_JOHTO',environment='ROUTE',width=40,height=9,
  edges={south='open_water'},connections={east={'ROUTE_26',-45},west={'NEW_BARK_TOWN',0}}},
}
local function layout(map)
 local d=map and map.def
 local id=map and(map.id or d and d.id)
 local spec=layouts[id]
 if not(d and spec and d.generation==2 and d.tileset==spec.tileset
   and d.environment==spec.environment and d.width==spec.width and d.height==spec.height
   and (d.outdoor==nil or d.outdoor==(spec.environment=='ROUTE')))then return nil end
 local connections=d.connections or{}
 for edge,expected in pairs(spec.connections or{})do
  local c=connections[edge]
  if not c or c.mapId~=expected[1] or c.offset~=expected[2]then return nil end
 end
 for edge in pairs(connections)do if not(spec.connections and spec.connections[edge])then return nil end end
 return spec
end
function P.classFor(map)
 local spec=layout(map)
 return spec and spec.class or nil
end
function P.edgeFor(map,edge)
 local spec=layout(map)
 if spec and spec.edges then return spec.edges[edge]end
 if not spec or spec.class~='water'then return nil end
 -- Northern background faces Vermilion; the two lateral faces and southern
 -- sailing direction remain open sea. Native pier, ship, stairs and two
 -- warps stay in their own BODY geometry, with no added near-field plants.
 if edge=='north'then return 'harbor' end
 if edge=='south'or edge=='west'or edge=='east'then return 'open_water' end
 return nil
end
return P
