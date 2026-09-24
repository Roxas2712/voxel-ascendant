-- Portable, paired frame-time evidence. No GPU timing claim and no absolute
-- 30 FPS cliff. A/B/B/A brackets drift; image readbacks use separate windows.
local M={REVISION=2,MIN_SAMPLES=20}
local function finite(n)return type(n)=='number'and n==n and n>0 and n<math.huge end
function M.quantile(a,q)
 local b={};for _,v in ipairs(a)do if finite(v)then b[#b+1]=v end end
 if #b==0 then return nil end
 table.sort(b);return b[math.max(1,math.ceil(#b*q))]
end
function M.summary(samples)
 local median=M.quantile(samples,.5);local deviations={}
 if median then for _,v in ipairs(samples)do if finite(v)then deviations[#deviations+1]=math.abs(v-median)+1e-12 end end end
 return {median=median,p95=M.quantile(samples,.95),mad=M.quantile(deviations,.5)or 0,n=#deviations}
end
local function usable(r)
 return type(r)=='table'and finite(r.median)and finite(r.p95)and type(r.n)=='number'and r.n>=M.MIN_SAMPLES
end
function M.compare(repeats,budget)
 local a,b,c,d=repeats[1],repeats[2],repeats[3],repeats[4]
 local out={method=M.REVISION,verdict='uncertain',reason='samples',valid=false}
 if not(usable(a)and usable(b)and usable(c)and usable(d))then return out end
 out.valid=true;out.off=(a.median+d.median)/2;out.on=(b.median+c.median)/2
 out.off95=(a.p95+d.p95)/2;out.on95=(b.p95+c.p95)/2
 out.delta=out.on-out.off;out.budget=finite(budget)and budget or 1/60
 out.repeats={a,b,c,d}
 local drift=math.max(math.abs(a.median-d.median),math.abs(b.median-c.median))
 local noise=math.max(a.mad or 0,b.mad or 0,c.mad or 0,d.mad or 0)*3
 out.noise=math.max(.001,noise,drift/2)
 -- These are engineering tolerances, not a statistical confidence interval.
 -- Large drift, stalls and contradictory pairs invalidate attribution.
 if drift>math.max(.002,out.off*.12)then out.reason='drift';return out end
 for _,r in ipairs(repeats)do
  if r.p95>r.median*1.6 and r.p95-r.median>.008 then out.reason='stalls';return out end
 end
 local d1,d2=b.median-a.median,c.median-d.median
 local material=math.max(.002,out.off*.12,out.noise*2)
 if math.abs(d1-d2)>math.max(.003,material*1.5)then out.reason='pairs';return out end
 -- An implausible speed-up usually means loading or another process changed.
 if out.delta < -material then out.reason='speedup';return out end
 local neutral=math.max(.0015,out.off*.05)
 if math.abs(out.delta)<=neutral then
  if out.on95-out.off95>math.max(.004,out.off95*.2)and out.on95>out.budget*1.15+.002 then out.reason='tail-cost';return out end
  out.verdict='pass';out.reason='negligible';return out
 end
 local goodHeadroom=out.on95<=out.budget*1.10+.001
 if goodHeadroom then out.verdict='pass';out.reason='headroom';return out end
 local overBudget=out.on95>out.budget*1.15+.002
 if d1>material and d2>material and overBudget then out.verdict='costly';out.reason='repeatable-cost';return out end
 out.reason='borderline';return out
end
function M.window(age,duration)
 -- Discard transition/warm-up, then measure without readbacks. Images are
 -- sampled only at the end; the next segment starts with a fresh warm-up.
 if age<1.25 then return 'warmup' end
 if age<duration-.8 then return 'timing' end
 return 'images'
end
function M.tier(seconds)
 for i,limit in ipairs({.050,.0333,.0222,.0143,.0083})do if seconds>=limit then return i end end
 return 6
end
return M
