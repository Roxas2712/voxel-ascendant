-- Internal, frozen APO payload. This does NOT open the external Card host to
-- executable foreign registrations. Each subscription and provider has one
-- revocable lifetime, including when the payload fails halfway through boot.
local M = { ID="ascendant.pokemon-overworld.visual-provider", VERSION="0.4.0-rc.32" }
local ROOT="integrated/ascendant_pokemon_overworld/"
local function chunk(mod, path, ...)
  local source, err=mod:read(path)
  assert(type(source)=="string", err or path)
  local fn, compileErr=(loadstring or load)(source,"@"..mod.path.."/"..path)
  assert(fn,compileErr)
  return fn(...)
end
local function find(mod,id)
  if id==mod.id then return {id=id,exports=mod.exports,version=mod.version} end
  if not mod.find then return nil end
  local ok,value=pcall(mod.find,mod,id)
  if not ok or value==nil then ok,value=pcall(mod.find,id) end
  return ok and value or nil
end
function M.new(mod)
  local self={mod=mod,state="pending",undo={},active=false,lastError=nil}
  local modules={}
  local V={mod=mod}
  function V.require(name)
    if modules[name]==nil then modules[name]=chunk(mod,"lib/"..name..".lua",V) end
    return modules[name]
  end
  self.options=V.require("OverworldPokemonOptions")
  local HdPolicy=V.require("HdContentPolicy")
  -- Downloads activate in a separate store; the renderer's boot mount stays
  -- immutable until restart, including while a scene retains GPU textures.
  self.hdStatus={schema="vasc.hd-content-cache/v1",packages=0,epoch=0,
    networkConfigured=false,rendererConnected=false,charactersBundled=true,
    state="cache_api_unavailable"}
  if mod.cache and love and love.data and type(love.data.hash)=="function" then
    local ok,store=pcall(function()
      local Json=V.require("ContentJson")
      local deps={cache=mod.cache,decode=Json.decode,
        sha256=function(bytes)
          return love.data.encode("string","hex",love.data.hash("sha256",bytes))
        end}
      local Store=V.require("HdContentStore")
      local Download=V.require("HdContentDownload")
      local bundled=assert(Download.catalog(mod:read("data/hd-content-catalog.json"),Json.decode))
      local cached=mod.cache:read("hd-content/catalog.json")
      local catalog=Download.catalog(cached,Json.decode) or bundled
      local boot=Store.new(deps)
      for _,p in ipairs(catalog.packages)do boot:restore(p.id)end
      local download=boot:forkVerified()
      self.hdBoot=boot
      local receipts,receiptFailure
      if type(Download.BASE)=="string" then
        local receiptOk,value=pcall(function()
          return V.require("HdReceiptJournal").new({cache=mod.cache,sha256=deps.sha256,
            origin=Download.BASE,now=function()return os.time()end})
        end)
        if receiptOk then receipts=value else receiptFailure=true end
      end
      self.hdDownload=Download.new({store=download,catalog=catalog,cache=mod.cache,
        fetch=mod.fetch,decode=Json.decode,receipts=receipts})
      if receiptFailure then self.hdDownload.warnings.receipt_unconfirmed=true end
      return download
    end)
    if ok then self.hdContent=store; self.hdStatus=store:health(); self.hdStatus.state="prepared"
    else self.hdStatus.state="cache_initialization_failed";self.hdStatus.error=tostring(store) end
  end
  mod.exports.pokemonHdContent={
    ready=function()return self.hdBoot and self.hdBoot:health().packages>0 or false end,
    downloader=function()return self.hdDownload end,
  }
  local defaults={}
  for _,spec in ipairs(self.options.schema(mod)) do defaults[spec.key]=spec.default end
  function self:get(key)
    local value=mod.options and mod.options:get("apo_"..key)
    if value==nil then return defaults["apo_"..key] end
    return value
  end
  function self:cleanup()
    self.active=false
    if self.hdDownload then self.hdDownload:cancel() end
    if self.child and mod.exports.overworldPokemon==self.child.exports then mod.exports.overworldPokemon=nil end
    local errors={}
    for i=#self.undo,1,-1 do
      local ok,err=pcall(self.undo[i])
      if not ok then errors[#errors+1]=tostring(err) end
    end
    self.undo={}
    self.state=#errors==0 and "inactive" or "cleanup_failed"
    if #errors>0 then self.lastError=table.concat(errors,"; "); return false,self.lastError end
    return true
  end
  local function retain(fn)
    if type(fn)=="function" then self.undo[#self.undo+1]=fn end
    return fn
  end
  if self.hdDownload and mod.hooks and type(mod.hooks.wrap)=="function"then
    self.hdOffer=V.require("HdContentOffer").new({downloader=self.hdDownload,cache=mod.cache,
      enabled=function()return self.active end,
      show=function(game,spec)return require("src.ui.Screens").push(game,"VascPokemonHdOffer",spec)end})
    retain(function()self.hdOffer:close()end)
    retain(mod.hooks:wrap("core.update",function(nextFn,game,dt)
      local result={nextFn(game,dt)}
      local ok=pcall(self.hdOffer.tick,self.hdOffer,game,dt)
      if not ok then self.hdOffer:close()end
      if self.active then pcall(self.hdDownload.background,self.hdDownload)end
      return (unpack or table.unpack)(result)
    end))
  end
  local function proxy()
    local child={id="ascendant_pokemon_overworld",version=M.VERSION,
      path=mod.path.."/"..ROOT:sub(1,-2),exports={},log=mod.log,
      _vascIntegrated=true}
    child._vascStadiumAvailable=function(dex)
      local probe=mod.exports.overworldPokemonModelAvailable
      if type(probe)~="function" then return false end
      local ok,ready=pcall(probe,dex)
      return ok and ready==true
    end
    function child:read(path)
      assert(type(path)=="string" and not path:find("..",1,true) and path:sub(1,1)~="/","invalid APO path")
      if path:sub(1,31)=="assets/pokemon-animation-cards/" then
        return self._vascHdStore and self._vascHdStore:read(path) or nil
      end
      if HdPolicy.optional(path)then return nil end
      return mod:read(ROOT..path)
    end
    function child:info(path)
      assert(type(path)=="string" and not path:find("..",1,true) and path:sub(1,1)~="/","invalid APO path")
      if path:sub(1,31)=="assets/pokemon-animation-cards/" then
        return self._vascHdStore and self._vascHdStore:info(path) or nil
      end
      if HdPolicy.optional(path)then return nil end
      return mod.info and mod:info(ROOT..path) or nil
    end
    child.find=function(first,second)
      local id=second or first
      return find(mod,id)
    end
    child.options={get=function(_,key) return self:get(key) end}
    child.save={
      get=function(_,key,default) return mod.save:get("apo_"..key,default) end,
      set=function(_,key,value) return mod.save:set("apo_"..key,value) end,
    }
    child.events={on=function(_,event,fn,priority)
      return retain(mod.events:on(event,function(payload,...)
        if not self.active then return end
        if event=="mod.options_changed" and type(payload)=="table" and (payload.mod or payload.modId)==mod.id then
          if type(payload.key)~="string" or payload.key:sub(1,4)~="apo_" then return end
          local translated={}
          for k,v in pairs(payload) do translated[k]=v end
          translated.mod=child.id; translated.key=payload.key:sub(5)
          payload=translated
        end
        return fn(payload,...)
      end,priority))
    end}
    child.hooks={wrap=function(_,name,fn,priority)
      return retain(mod.hooks:wrap(name,function(nextFn,...)
        if not self.active then return nextFn(...) end
        return fn(nextFn,...)
      end,priority))
    end}
    -- APO uses only this content registry. Preserve exact pre-card entries;
    -- no general loader/foreign-save access is handed to the child.
    local sprites=mod.content and mod.content.sprites
    child.content={sprites={}}
    if sprites then
      child.content.sprites.get=function(_,id) return sprites:get(id) end
      for _,method in ipairs({"register","patch"}) do
        child.content.sprites[method]=function(_,id,value)
          local before=sprites:get(id)
          local result=sprites[method](sprites,id,value)
          retain(function()
            if before then sprites:override(id,before) else sprites:remove(id) end
          end)
          return result
        end
      end
    end
    child._apoOwn=function(service)
      retain(function()
        if type(service.restore)=="function" then service:restore() end
        if type(service.vascRestore)=="function" then service.vascRestore() end
      end)
    end
    child._vascHdStore=self.hdBoot
    return child
  end
  function self:health()
    local api=self.child and self.child.exports
    local runtime=api and api.runtime and api.runtime.health() or {}
    local renderer=api and api.voxelCharacters and api.voxelCharacters.health() or {}
    local hd=self.hdContent and self.hdContent:health() or self.hdStatus
    hd.networkConfigured=self.hdDownload and self.hdDownload:configured()
      and self.hdDownload:available() or false
    hd.startupOfferState=self.hdOffer and self.hdOffer.state or "unavailable"
    hd.rendererConnected=self.active and self.hdBoot~=nil
    hd.restartRequired=self.hdDownload and self.hdDownload.changed or false
    return {schema="vasc.overworld-pokemon-card/v1",id=M.ID,version=M.VERSION,
      state=self.state,ok=self.state=="active",error=self.lastError,
      restartRequired=(self:get("enabled")==true)~=self.active,
      hdContent=hd,
      snapshot="APO RC32: Kanto 151 animation handoff; VASC integration QA",
      runtime={state=runtime.state,owner=runtime.owner,error=runtime.lastError},
      renderer={vasc=renderer.vasc,error=renderer.vascError}}
  end
  local descriptor={schema="ascendant.card/v1",id=M.ID,version="1.0.0",owner=mod.id,
    requires={},optionalRequires={},consumes={},
    provides={"ascendant.overworld-pokemon/v1","ascendant.overworld-characters/v1"},
    tests={"tests/overworld_pokemon_card_test.lua"},
    docs={"docs/maintainer/VASC_APO_INTEGRATION.md"},
    saveNamespace="vasc.apo",
    impact={runtimeOwners={"vasc.overworld-pokemon.presentation"},
      saveWrites={"vasc.apo"},publicHooks={"ui.party.submenu","movement.collision","vasc.sprite.overworld"},
      files={"lib/OverworldPokemonCard.lua","lib/OverworldPokemonOptions.lua"}},
    lifecycle={
      install=function() return {} end,
      activate=function()
        self.active=true
        self.child=proxy()
        if self.hdBoot then
          local Assets=require("src.render.Assets")
          retain(V.require("HdContentAssets").install(self.hdBoot,
            self.child.path.."/",Assets,love.graphics,love.image,love.filesystem))
        end
        chunk(mod,ROOT.."main.lua")(self.child)
        mod.exports.overworldPokemon=self.child.exports
        self.state="active"
        local service={health=function() return self:health() end}
        return {},service
      end,
      deactivate=function() return self:cleanup() end,
      abort=function() return self:cleanup() end,
      health=function() return self:health() end,
    }}
  local Registry=V.require("core/AscendantCardRegistry")
  self.registry=Registry.new()
  assert(self.registry:register(descriptor))
  function self:start()
    if self.state~="pending" then return self.state=="active",self.lastError end
    if self:get("enabled")~=true then self.state="disabled"; return true end
    if find(mod,"ascendant_pokemon_overworld") then
      self.state="external_owner"; self.lastError="Disable the standalone APO package before using the integrated Card."
      return false,self.lastError
    end
    -- APO requires the modern generation/public owner seams. Older supported
    -- VASC engines retain their original rendering rather than half booting.
    local ok,version=pcall(require,"src.core.GameVersion")
    if not ok or type(version.generation)~="function" then
      self.state="unsupported_engine"; self.lastError="APO needs the modern generation API"; return false,self.lastError
    end
    local activated,err=self.registry:activate(M.ID,{mod=mod})
    if not activated then self.state="failed"; self.lastError=tostring(err) end
    return activated,err
  end
  function self:stop() return self.registry:deactivate(M.ID,{mod=mod},"overworld-card-stop") end
  return self
end
return M
