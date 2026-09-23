-- A deliberately small, data-only Molang arithmetic interpreter. Never load()
-- pack text. Unknown queries fail the clip instead of executing foreign code.
local M={}
local functions={
 ['math.sin']=function(x)return math.sin(x*math.pi/180)end,
 ['math.cos']=function(x)return math.cos(x*math.pi/180)end,
 ['math.abs']=math.abs,['math.floor']=math.floor,['math.ceil']=math.ceil,
 ['math.sqrt']=math.sqrt,['math.min']=math.min,['math.max']=math.max,
 ['math.clamp']=function(x,a,b)return math.max(a,math.min(b,x))end,
 ['math.lerp']=function(a,b,t)return a+(b-a)*t end,
 ['math.pow']=math.pow,['math.exp']=math.exp,
 ['math.mod']=function(a,b)return a%b end,
}
function M.compile(value)
 if type(value)=='number' then assert(value==value and math.abs(value)<1e6,'invalid scalar');return value end
 assert(type(value)=='string' and #value<1024,'invalid expression');value=value:lower()
 local tokens={};local p=1
 while p<=#value do
  local tail=value:sub(p);local t=tail:match('^%s+')
  if t then p=p+#t else
   t=tail:match('^%d*%.?%d+[eE][%+%-]?%d+') or tail:match('^%d*%.?%d+') or tail:match('^[%a_][%w_%.]*') or tail:match('^[%+%-%*/%%%^%(%)%,]')
   assert(t,'unsupported Molang syntax');tokens[#tokens+1]=t;p=p+#t
  end
 end
 assert(#tokens<=256,'expression too complex')
 local i,depth=1,0;local expr
 local function atom()
  depth=depth+1;assert(depth<32,'expression nesting')
  local t=tokens[i];i=i+1;local n=tonumber(t);local out
  if n then assert(n==n and math.abs(n)<1e6,"invalid scalar");out=n
  elseif t=='-' or t=='+' then out={t=='-' and 'neg' or 'pos',atom()}
  elseif t=='(' then out=expr(0);assert(tokens[i]==')','missing )');i=i+1
  elseif t=='q.anim_time' or t=='query.anim_time' or t=='q.life_time' or t=='query.life_time' then out={'time'}
  elseif functions[t] then
   assert(tokens[i]=='(','missing function arguments');i=i+1;out={t}
   if tokens[i]~=')' then repeat out[#out+1]=expr(0);if tokens[i]~=',' then break end;i=i+1 until false end
   assert(tokens[i]==')' and #out>=2 and #out<=4,'invalid function arguments');i=i+1
  else error('unsupported Molang value: '..tostring(t))end
  depth=depth-1;return out
 end
 local precedence={['+']=1,['-']=1,['*']=2,['/']=2,['%']=2,['^']=3}
 expr=function(min)
  local out=atom()
  while precedence[tokens[i]] and precedence[tokens[i]]>min do
   local op=tokens[i];i=i+1;out={op,out,expr(precedence[op]-(op=='^' and 1 or 0))}
  end
  return out
 end
 local out=expr(0);assert(i>#tokens,'trailing expression');return out
end
function M.value(a,t)
 if type(a)=='number'then return a end
 local op=a[1];if op=='time'then return t end
 local x=M.value(a[2],t)
 if op=='neg'then return -x elseif op=='pos'then return x end
 local y=a[3] and M.value(a[3],t)
 if op=='+'then return x+y elseif op=='-'then return x-y elseif op=='*'then return x*y
 elseif op=='/'then return y~=0 and x/y or 0 elseif op=='%'then return y~=0 and x%y or 0 elseif op=='^'then return x^y end
 if a[4]then return functions[op](x,y,M.value(a[4],t))elseif a[3]then return functions[op](x,y)else return functions[op](x)end
end
return M
