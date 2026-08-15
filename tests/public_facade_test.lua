local PublicFacade = assert(loadfile("lib/PublicFacade.lua"))()

local sentinels = {
  AntiAlias = {},
  BattleArena = {},
  BattleCam = {},
  OverworldBattle = {},
  Voxel3D = {},
  VoxelScene = {},
  VoxelState = {},
  WallDecals = {},
}
local privateLookups = 0
local source = setmetatable(sentinels, {
  __index = function()
    privateLookups = privateLookups + 1
    return "PRIVATE"
  end,
})

local facade = PublicFacade.new(source)
assert(type(facade.require) == "function")
for name, value in pairs(sentinels) do
  assert(facade.require(name) == value)
end

assert(facade.mod == nil)
assert(facade.path == nil)
assert(facade.data == nil)
assert(facade.cache == nil)
assert(facade.require("ChunkMesher") == nil)
assert(facade.require("PublicFacade") == nil)
assert(facade.require("../main") == nil)
assert(facade.require({}) == nil)
assert(privateLookups == 0)

local ok = pcall(function() facade.mod = {} end)
assert(not ok)
ok = pcall(function() facade.require = function() end end)
assert(not ok)
assert(getmetatable(facade) == "VOXEL_ASCENDANT public compatibility facade")

print("ok public facade is allowlisted and owner-isolated")
