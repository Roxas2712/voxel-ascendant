local root=arg[1] or "."
local Menu=assert(loadfile(root.."/lib/HdContentMenu.lua"))()
local Download=assert(loadfile(root.."/lib/HdContentDownload.lua"))()
assert(Download.BASE=="https://vasc-downloads.ascendant-content.workers.dev","unapproved endpoint enabled")
Download.BASE=nil -- Explicitly exercise the missing-configuration failure path.
local blocked=Download.new({catalog={packages={}},store={},fetch={get=function()error("must not fetch")end}})
assert(not blocked:check() and not blocked:start(1,nil,true))
for _,de in ipairs({false,true})do
  local spec
  local d={status="error",message="fetch failed for https://private.invalid/token: curl: (60) SSL: no alternative",
    catalog={packages={}},store={epoch=0},busy=function()return false end,update=function()end}
  local mod={exports={pokemonHdContent={downloader=function()return d end}}}
  local opened=0
  local menu=Menu.new(mod,{},function(_,_,s)
    spec=s;return {items=s.rows,update=function()end,onSelectKey=function(item)opened=opened+1;assert(item.action=="status")end}
  end,de)
  menu:update()
  assert(menu.items[1].right==(de and "FEHLER" or "ERROR"))
  assert(menu.items[1].help:find("TLS",1,true))
  assert(not menu.items[1].help:find("private",1,true) and not menu.items[1].help:find("https",1,true))
  assert(spec.footer:find(de and "SEL:HILFE" or "SEL:HELP",1,true))
  spec.onChoose(menu.items[1],menu);assert(opened==1)
  d.message="unexpected https://private.invalid/secret";menu:update()
  assert(not menu.items[1].help:find("private",1,true))
  d.message="Public download source not configured";menu:update()
  assert(menu.items[1].help:find(de and "noch nicht eingerichtet" or "not configured",1,true))
  d.status="ready";d.changed=true;d.message="Download verified. Restart the game to enable HD."
  d.warnings={fallback_used=true,receipt_unconfirmed=true,catalog_not_saved=true,untrusted="private.invalid/secret"}
  menu:update()
  assert(menu.items[1].right==(de and "NEUSTART" or "RESTART"))
  assert(menu.items[1].help:find(de and "Zählung nicht bestätigt" or "count not confirmed",1,true))
  assert(menu.items[1].help:find(de and "Speichern fehlgeschlagen" or "saving failed",1,true))
  assert(not menu.items[1].help:find("private",1,true),"raw warning leaked")
  assert(menu.items[1].help:find(de and "Alternative Downloadquelle" or "alternative download source",1,true))
  d.status="downloading";d.message="apo.pokemon-hd.g01.dex0001-0020"
  menu:update()
  assert(menu.items[1].help:find(de and "Paket 1-20" or "package 1-20",1,true))
  assert(not menu.items[1].help:find("#",1,true),"native font ligature in package range")
end
for _,de in ipairs({false,true})do
  local spec,menu,top,decisions
  decisions=0
  local game={stack={top=function()return top end,pop=function()top=nil end,
    push=function(_,v)top=v end}}
  local buildCalls=0
  package.loaded["src.ui.Screens"]={build=function(_,id)
    assert(id=="VascPokemonHdDownloads");buildCalls=buildCalls+1;return {download=true}
  end}
  menu=Menu.offer({},game,function(_,_,s)
    spec=s;return {items=s.rows,onCancel=function()end}
  end,de,{count=2,bytes=1048576,decide=function()decisions=decisions+1 end})
  top=menu
  assert(spec.rows[1].label==(de and "SPÄTER" or "LATER"))
  assert(spec.help:find("1.0",1,true))
  for _,row in ipairs(spec.rows)do
    assert(#row.help<100,"portrait offer summary must stay compact")
    assert(row.help:find("1.0 MB",1,true))
  end
  assert(spec.rows[1].help:find(de and "Pokemon + Modelle" or "Pokemon + Models",1,true))
  assert(spec.rows[2].help:find(de and "bestätigen" or "Confirm",1,true))
  spec.onChoose(spec.rows[2],menu)
  assert(decisions==1 and buildCalls==1 and top.download)
  top=menu;menu.onCancel();assert(decisions==2)
end
print("PASS HD menu: EN/DE status, bounded redacted errors, A opens help, unapproved endpoint blocked")
