local Catalog=dofile('lib/SpriteCatalog.lua');local Model=dofile('lib/SpriteDownloadMenuModel.lua')
local catalog=Catalog.new(dofile('lib/SpriteCatalogData.lua'));local store={receipt=function()end,packageMounted=function()return false end}
local cb;local session={epoch=1,catalog=catalog,store=store,model=Model.new(catalog,store,{importIds={}}),
 removal={pending=function()end},installer={state='idle'},cobblemon=function()return cb end,needsCobblemonDownload=function()return false end,
 planFor=function(_,ids)return catalog:plan(ids,store)end}
local stack={};local game={stack={push=function(_,p)stack[#stack+1]=p end}}
local function guided(_,_,opts)
 opts.rows[#opts.rows+1]={label='HELP',value='__kasc_help:'..opts.key,__kascFeatureHelp=true}
 return{items=opts.rows,index=1,rows=6,scroll=0,choose=opts.onChoose}
end
local menu=dofile('lib/SpriteContentMenu.lua').new({},game,guided,false,session)
menu.index=2;local id=assert(menu.items[2].group).id
cb={available=function()return true end};session.epoch=2;menu:update()
assert(menu.items[menu.index].group and menu.items[menu.index].group.id==id,'inventory refresh changed the selected collection')
menu.index=#menu.items-1;local action=assert(menu.items[menu.index].action);cb=nil;session.epoch=3;menu:update()
assert(menu.items[menu.index].action==action,'removed row shifted focus to a different action')
assert(menu.scroll<=menu.index-1 and menu.index<=menu.scroll+menu.rows,'selection scrolled out of view')
local help=menu.items[#menu.items];assert(help.__kascFeatureHelp,'refresh removed contextual HELP')
menu.index=#menu.items;cb={available=function()return true end};session.epoch=4;menu:update()
assert(menu.items[menu.index]==help,'refresh changed HELP focus or identity')
print('PASS download menu: collection/action identity survives refreshed content and stays visible')
