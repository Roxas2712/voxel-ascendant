local M={}
function M.encode(v)
 local t=type(v)
 if t=='nil'then return 'null' elseif t=='boolean'then return tostring(v)
 elseif t=='number'then assert(v==v and math.abs(v)<math.huge,'nonfinite JSON');return string.format('%.14g',v)
 elseif t=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)local m={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'};return m[c]or string.format('\\u%04x',c:byte())end)..'"'
 elseif t=='table'then
  local n,array=0,true;for k in pairs(v)do n=n+1;if type(k)~='number' or k<1 or k%1~=0 then array=false end end
  local out={};if array and #v==n then for i,x in ipairs(v)do out[i]=M.encode(x)end;return '['..table.concat(out,',')..']'end
  local keys={};for k in pairs(v)do assert(type(k)=='string','JSON key');keys[#keys+1]=k end;table.sort(keys)
  for _,k in ipairs(keys)do out[#out+1]=M.encode(k)..':'..M.encode(v[k])end;return '{'..table.concat(out,',')..'}'
 end
 error('invalid JSON data')
end
return M
