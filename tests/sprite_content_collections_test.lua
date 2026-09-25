-- RC4 handoff behavioral tests, run against this worktree's actual modules.
local root=arg[1] or '.'
SpriteCatalog=assert(loadfile(root..'/lib/SpriteCatalog.lua'))()
SpriteDownloadSelection=assert(loadfile(root..'/lib/SpriteDownloadSelection.lua'))()
SpriteDownloadMenuModel=assert(loadfile(root..'/lib/SpriteDownloadMenuModel.lua'))()
SpriteBundledInventory=assert(loadfile(root..'/lib/SpriteBundledInventory.lua'))()
SpriteContentMenu=assert(loadfile(root..'/lib/SpriteContentMenu.lua'))()
data=assert(loadfile(root..'/lib/SpriteCatalogData.lua'))()
bundles=assert(loadfile(root..'/lib/SpriteBundleData.lua'))()

local c=SpriteCatalog.new(data)
function c:relevant(p)return p.family~='pokemon-gorochu'end
for _,p in ipairs(data.packages)do if bundles[p.id]then p.transferBytes=bundles[p.id].bytes end end
local base=SpriteDownloadSelection.base(c);local expected=0
for _,p in ipairs(data.packages)do if c:relevant(p)and p.published and not SpriteDownloadSelection.isHd(p)then expected=expected+1 end end
assert(#base==expected and #base>250)
local expanded=SpriteDownloadSelection.expand(c,{base[1],base[1]});assert(#expanded==#base)
local seen={};for _,id in ipairs(expanded)do assert(not seen[id]and not SpriteDownloadSelection.isHd(c.packages[id]));seen[id]=true end
for _,id in ipairs(base)do assert(seen[id])end
local hd;for _,p in ipairs(data.packages)do if SpriteDownloadSelection.isHd(p)then hd=p.id;break end end
assert(#SpriteDownloadSelection.expand(c,{hd})==1)
assert(#SpriteDownloadSelection.expand(c,{base[1],hd})==#base+1)
-- Real menu/model with an in-memory store. Capture the public choices and callbacks.
local store={receipt=function()end,packageMounted=function()return false end}
local model=SpriteDownloadMenuModel.new(c,store,{importIds={}})
local game={stack={states={},push=function(self,p)self.states[#self.states+1]=p end,top=function(self)return self.states[#self.states]end}}
local function guided(_,_,opts)return {items=opts.rows,choose=opts.onChoose,key=opts.key}end
local requested
local session={cobblemon=function()return nil end,needsCobblemonDownload=function()return false end,catalog=c,model=model,store=store,epoch=1,removal={pending=function()end},installer={state='idle'},
planFor=function(_,ids)return c:plan(ids,store)end,confirmDownload=function(_,ids)requested=SpriteDownloadSelection.expand(c,ids)end,notice=function()end}
local menu=SpriteContentMenu.new({},game,guided,false,session)
assert(menu.items[1].label=='DOWNLOAD / UPDATE ALL'and not menu.items[1].right)
assert(menu.items[2].label=='BASE SPRITE PACK');assert(menu.items[3].label=='OPTIONAL HD SPRITES')
menu.choose(menu.items[2]);local pack=game.stack:top();assert(#pack.items==4,'base fragments exposed as main choices')
pack.choose(pack.items[1]);assert(#requested==#base,'base choice did not select whole pack')
menu:openFamily('pokemon-crystal');assert(game.stack:top().key=='vasc_content_collection_pokemon-crystal')
menu:downloadAll();assert(#requested>#base)
-- A fully installed collection must not become a new network operation.
function store:receipt(id)local p=c.packages[id];return {verified=true,revision=p.revision,manifestSha256=p.manifestSha256}end
requested=nil;menu:downloadAll();assert(requested==nil)
print('PASS real catalogue base completeness, dedup, optional HD separation, main menu, exact family routing, download all and installed skip')
-- Directory pruning is advisory and never invents an installed receipt.
local pin={path='index',sha256='indexhash'}
local index={schema='ascendant.bundled-manifest-index/v1',owner='kasc',packages={{id='one',manifestSha256='manifesthash',manifestBytes=8}}}
local manifest={id='one',files={}}
for i=1,10000 do manifest.files[i]={owner='kasc',logicalPath='assets/crystal_animated/front/normal/1/'..i..'.png'}end
local stats=0
local mod={read=function(_,k)return k=='index'and'index'or'manifest'end,info=function(_,k)stats=stats+1;if k=='assets'then return {type='directory'}end end}
local d={owner='kasc',mod=mod,pin=pin,directoryInfo=true,sha=function(s)return s=='index'and'indexhash'or'manifesthash'end,decode=function(s)return s=='index'and index or manifest end}
local inv=SpriteBundledInventory.new(d);local state=inv:status('one');inv:advance(10001)
assert(not state.checking and not state.complete and state.present==0 and stats<10,'absent frames individually statted')
-- Engines that cannot report directories still check every file.
stats=0;mod.info=function(_,k)stats=stats+1;if k:match('%.png$')then return {type='file',size=1}end end
inv=SpriteBundledInventory.new(d);state=inv:status('one');inv:advance(10001);assert(state.complete and stats>=10000)
-- Errors and zero-byte files cannot turn into Already installed.
mod.info=function(_,k)if k:match('/1.png$')then error('filesystem error')end;return {type='file',size=0}end
inv=SpriteBundledInventory.new(d);state=inv:status('one');inv:advance(10001);assert(not state.complete and state.failed)
print('PASS absent-directory pruning, older file-only API fallback, file error and empty-file rejection')
