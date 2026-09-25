-- Exercise the actual resume block with changing settings/defaults.
local f=assert(io.open('lib/SetupCard.lua'));local source=f:read('*a');f:close()
local start=assert(source:find(' local saved=M.receipt(game)',1,true));local finish=assert(source:find(' self.effects=',start,true))
local code=source:sub(start,finish-1)
for _,page in ipairs({2.5,0/0,math.huge,-10,999})do
 local self={draft={choice='safe',flag=false,number=1},settings={choice={values={'safe','new'}},number={values={1,2}}},pages={{},{},{}}}
 local env=setmetatable({self=self,game={},M={VERSION=3,receipt=function()return{version=3,done=false,page=page,draft={choice='invalid',flag={},number=0/0}}end},V={mod={storage={read=function()return 5 end}}}},{__index=_G})
 setfenv(assert(loadstring(code)),env)()
 assert(self.page>=1 and self.page<=3 and self.page%1==0)
 assert(self.draft.choice=='safe'and self.draft.flag==false and self.draft.number==1)
end
print('PASS setup resume: invalid types/enums/numbers and fractional/non-finite pages recover safely')
