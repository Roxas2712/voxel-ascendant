local root=arg[1]or'.'
local f=assert(io.open(root..'/integrated/ascendant_pokemon_overworld/src/voxel_characters.lua','rb'))
local source=f:read('*a');f:close()
local first=assert(source:find('local function matMul',1,true))
local last=assert(source:find('local function rotateX',first,true))
local block=assert(source:match('(if breathScale ~= 1 then.-)\n          if self.debugLog'))
local run=assert((loadstring or load)(source:sub(first,last-1)..
  '\nreturn function(cardModel,cardSun,breathScale) '..block..' return cardModel,cardSun end'))()
local identity={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
for _,breath in ipairs({1,1.01,1.008})do
  local model,sun=run(identity,nil,breath)
  assert(model[6]==breath and sun==nil,'optional shadow became mandatory')
  model,sun=run(identity,identity,breath)
  assert(model[6]==breath and sun[6]==breath,'desktop shadow lost breathing alignment')
end
print('PASS actual HD breathing block with and without optional mobile sun matrix')
