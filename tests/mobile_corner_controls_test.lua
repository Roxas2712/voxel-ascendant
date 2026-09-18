local M=assert(loadfile('lib/MobileTouchLayout.lua'))()
local function eq(a,b,msg)assert(a==b,msg)end
for _,size in ipairs{{956,440,62,0,832,420},{440,956,0,60,440,862},{844,390,48,0,748,369}}do
 local ww,wh,x,y,w,h=unpack(size)
 local source={select={cx=ww/2-25,cy=wh-45,w=44},start={cx=ww/2+25,cy=wh-45,w=44},hotbar={cx=ww-30,cy=30,w=44},a={cx=ww-40,cy=wh-70,w=65}}
 local t={layout=function()return source end,visible=function()return true end,layoutOx=x,layoutOy=y,layoutW=w,layoutH=h,positions={}}
 M.install(t);local wrapper=t.layout;M.install(t);eq(wrapper,t.layout,'duplicate wrapper')
 local moved=t:layout();assert(moved.select.cx<ww*.25 and moved.start.cx>ww*.75)
 assert(moved.select.cy<wh*.25 and moved.start.cy<wh*.25)
 assert(moved.hotbar.cy-moved.start.cy>44*1.44,'overlapping right controls')
 assert(moved.select.cx-44*.72>=x and moved.start.cx+44*.72<=x+w,'unsafe edges')
 eq(source.select.cy,wh-45,'cached engine layout mutated');eq(moved.a,source.a,'A moved')
 t.positions.select={x=.5,y=.8};eq(t:layout().select,source.select,'custom select lost')
 t.preview=true;eq(t:layout(),source,'editor preview changed');t.preview=false
 t.skinId='skin';eq(t:layout(),source,'skin changed');t.skinId=nil
 t.visible=function()return false end;eq(t:layout(),source,'desktop/controller changed')
end
print('PASS corner controls: safe-area landscape/portrait, hit geometry, hotbar spacing, custom layout, editor, skin, desktop, idempotence')
