-- Public choices: one complete base collection, plus optional HD collections.
local M={}
function M.isHd(p)return p and (p.adapter=='existing-HdContentStore'or (p.family or ''):match('^pokemon%-hd%-'))and true or false end
function M.base(catalog)
 local ids={}
 for _,p in ipairs(catalog.data.packages)do
  if p.published==true and (not catalog.relevant or catalog:relevant(p))and not M.isHd(p)then ids[#ids+1]=p.id end
 end
 return ids
end
function M.expand(catalog,ids)
 local out,seen,wantsBase={},{},false
 for _,id in ipairs(ids)do
  local p=catalog.packages[id]
  if p and not M.isHd(p)then wantsBase=true end
  if not seen[id]then out[#out+1]=id;seen[id]=true end
 end
 if wantsBase then for _,id in ipairs(M.base(catalog))do if not seen[id]then out[#out+1]=id;seen[id]=true end end end
 return out
end
return M
