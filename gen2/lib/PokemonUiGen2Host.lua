-- Gen2 PC adapter for the shared ASC BOX surface. Saves remain ordinary dense
-- Gen2 boxes; presentation seats are metadata, never a second Pokemon bank.
local V = ...
local Host = {}
local Boxes = require("src.core.gen2.Boxes")
local Mail = require("src.core.gen2.Mail")
local Screens = require("src.ui.Screens")
local backend = setmetatable({}, {__index=function(_, key)
  if key == "COUNT" then return Boxes.NUM_BOXES end
  if key == "CAPACITY" then return Boxes.MONS_PER_BOX end
end})
function backend.ensure(save)
  save.boxes = save.boxes or {}
  for i=1,Boxes.NUM_BOXES do save.boxes[i] = save.boxes[i] or {} end
  return save.boxes
end
local adapter = setmetatable({storageBoxes=backend}, {__index=V})
local source = assert(V.mod:read("lib/PokemonUiGen1Hosts.lua"))
local Shared = assert((loadstring or load)(source, "@PokemonUiSharedStorage"))(adapter)
local Session = setmetatable({}, {__index=Shared.PcSession})
Session.__index = Session

function Session:buildModel()
  local model = Shared.PcSession.buildModel(self)
  local target = model.focus.id and self.bindings[model.focus.id]
  if target and target.zone == "party" then
    local allowed, reason = Boxes.canDeposit(self.game.save, target.slot,
      self.game.save.currentBox)
    model.availability.deposit = self:availability(allowed, reason)
  end
  if target and target.mon.isEgg then
    model.availability.release = self:availability(false, "egg_hidden")
  end
  model.zones.box.label = Boxes.name(self.game.save, model.zones.box.index)
  return model
end

-- Validate both participants before the shared atomic move touches a list.
-- Mail is keyed by PARTY SLOT in Gold, so a reorder must follow each Pokemon.
function Session:beforeMove(source, destination, target)
  local save = self.game.save
  local leaves = source.zone == "party" and destination.zone == "box" and source.mon
    or source.zone == "box" and destination.zone == "party" and target
  if leaves then
    if Mail.monHoldsMail(leaves) then return false, "Remove MAIL." end
    local arrives = source.zone == "box" and source.mon or target
    local healthy = Boxes.healthyCount(save.party)
      - ((leaves.hp or 0)>0 and 1 or 0)
      + (arrives and not arrives.isEgg and (arrives.maxHp or arrives.hp or 0)>0 and 1 or 0)
    if (leaves.hp or 0)>0 and healthy < 1 then
      return false, "You can't deposit the last healthy POKéMON!"
    end
  end
  local letters = {}
  local partyMail = save.mail and save.mail.party or {}
  for slot, mon in ipairs(save.party) do letters[mon] = partyMail[slot] end
  return true, nil, letters
end

local function withdrawHealth(mon)
  mon.status, mon.statusTurns = nil, nil
  mon.hp = mon.isEgg and 0 or (mon.maxHp or mon.hp)
end
function Session:afterMove(source, destination, target, letters)
  local save = self.game.save
  if source.zone == "party" and destination.zone == "box" then
    Boxes.enterBox(source.mon)
    if target then withdrawHealth(target) end
  elseif source.zone == "box" and destination.zone == "party" then
    withdrawHealth(source.mon)
    if target then Boxes.enterBox(target) end
  end
  if save.mail and save.mail.party then
    local partyMail = save.mail.party
    for i=1,Boxes.PARTY_SIZE do partyMail[i] = letters[save.party[i]] end
  end
end

function Session:release(envelope)
  local target = self:locate(envelope.target)
  if target and target.mon and target.mon.isEgg then
    return self:reject(envelope, "egg_hidden", "You can't release an EGG!")
  end
  return Shared.PcSession.release(self, envelope)
end
function Session:inspect(envelope)
  local target = self:locate(envelope.target)
  if not target or not target.mon then return self:reject(envelope,"stale_target") end
  Screens.push(self.game, "Gen2SummaryMenu", {save=self.game.save, mon=target.mon,
    onClose=function() self.game.stack:pop() end})
  return self:result(envelope,"applied","summary_opened")
end
function Session:dexEntry(envelope)
  local target = self:locate(envelope.target)
  if not target or not target.mon then return self:reject(envelope,"stale_target") end
  if target.mon.isEgg then return self:reject(envelope,"egg_hidden") end
  Screens.push(self.game,"Gen2PokedexMenu",{save=self.game.save,
    entrySpecies=target.mon.species,onClose=function() self.game.stack:pop() end})
  return self:result(envelope,"applied","dex_opened")
end

-- Game2 calls widescreen presenters in physical pixels rather than supplying
-- the Gen1 512x288 UI transform. Scope it to this surface, including fallback.
local function drawWidescreen(screen,w,h)
  if screen.fallback and type(screen.native.drawWidescreen)=="function" then
    return screen.native:drawWidescreen(w,h)
  end
  local g=love.graphics
  local width,height=screen:uiSize()
  w,h=tonumber(w) or width,tonumber(h) or height
  local scale=math.min(w/width,h/height)
  g.push("all"); g.origin(); g.setColor(1,252/255,236/255,1)
  g.rectangle("fill",0,0,w,h)
  g.translate(math.floor((w-width*scale)/2),math.floor((h-height*scale)/2))
  g.scale(scale,scale)
  screen.preserveHostTransform=true
  local ok,err=pcall(Shared.HostScreen.draw,screen)
  screen.preserveHostTransform=nil
  g.pop()
  if not ok then error(err,0) end
end

function Host.install(PokemonUi)
  if Host.installed then return true end
  local handle,why=PokemonUi.registerHost({schema=PokemonUi.HOST_SCHEMA,
    apiVersion=PokemonUi.API_VERSION,id="vasc_gen2_native",owner="VOXEL_ASCENDANT",
    hostGeneration=PokemonUi.HOST_GENERATION,
    surfaces={pc_box=Shared.hostSurface(PokemonUi,"pc_box")}})
  if not handle then return nil,why end
  Host.handle=handle
  Shared.installRawInputHooks()
  local Native=require("src.ui.gen2.BoxMenu")
  local baseNew=Native.new
  Native.new=function(game,opts,...)
    local native=baseNew(game,opts,...)
    -- Immutable asset catalogue only, never the Game or live save. Gen2 does
    -- not populate the Gen1 Data singleton used by the original provider.
    V.ascBoxData=game.data
    PokemonUi.surfaceSettings.pc_box:sync(V.mod.options:get("pokemonUiPcBox"))
    if native.save ~= game.save then return native end
    for _,host in ipairs(PokemonUi.listHosts("pc_box")) do
      if host.owner~="VOXEL_ASCENDANT" then return native end
    end
    if PokemonUi.resolve("pc_box",handle).effective==PokemonUi.GAME_DEFAULT then
      return native
    end
    local screen=Shared.HostScreen.new(native)
    screen.drawWidescreen=drawWidescreen
    screen.pointerToLogical=function(self,x,y)
      local w,h=love.graphics.getDimensions()
      local width,height=self:uiSize()
      local scale=math.min(w/width,h/height)
      return (x-math.floor((w-width*scale)/2))/scale,
        (y-math.floor((h-height*scale)/2))/scale
    end
    local state=Shared.PcSession.new(PokemonUi,handle,game,native,screen)
    setmetatable(state,Session)
    state.surface,state.hostId="pc_box","vasc_gen2_native"
    if opts and opts.mode=="deposit" then state.focusZone="party" end
    if screen:activate(state) then
      local Mobile=V.require("MobileMenuPresentation")
      Mobile.attach(screen,{owner="box_pc",logicalSize=function(s)return s:uiSize()end,
        enabled=function(s)return not s.fallback end,backdrop={1,252/255,236/255,1}})
      return screen
    end
    return native
  end
  Host.installed=true
  return true
end
Host.Session=Session
Host.Shared=Shared
return Host
