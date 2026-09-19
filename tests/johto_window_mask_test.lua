local root=arg[1] or '.'
package.loaded['src.render.Assets']={}
local Mask=assert(loadfile(root..'/gen2/lib/GlassMask.lua'))({})
local art={'00000000','02222220','02332330','02332330','02332330','02332330','02332330','00000000'}
local mutated=false
local function read(x,y)
 local c=tonumber(art[y+1]:sub(x+1,x+1))/3
 if mutated and x==0 and y==0 then c=1 end
 return c,c,c,1
end
local panes=Mask.scan(read,8,8)
assert(#panes==2,'Johto panes missing')
local pixels={}
for _,r in ipairs(panes)do for y=r.y,r.y+r.h-1 do for x=r.x,r.x+r.w-1 do
 assert(read(x,y)==1,'frame/mullion accepted as glass');pixels[y*8+x]=true
end end end
local n=0;for _ in pairs(pixels)do n=n+1 end;assert(n==20)
mutated=true;assert(#Mask.scan(read,8,8)==0,'modified artwork must not get a native mask')
local blank=function()return 1,1,1,1 end
assert(#Mask.scan(blank,8,8)==0,'wall lit as a window')
-- The existing Gen1 pane detector remains available on Gen2 Kanto atlases.
local classic=function(x,y)
 local c=(y==0 or y==6 or x==0 or x==7)and 0 or 1
 return c,c,c,1
end
local original=Mask.scan(classic,8,7);assert(#original==1 and original[1].w==6 and original[1].h==5)
print('PASS_JOHTO_WINDOW_MASK',n)
