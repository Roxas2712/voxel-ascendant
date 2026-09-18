-- Presentation clock only. No game state, random generator or asset work.
local Idle={}
local function smooth(x) return x*x*(3-2*x) end
function Idle.blink(state,now,eligible,seed)
  if not eligible or type(now)~='number' or now~=now or math.abs(now)==math.huge then
    state.nextBlink,state.blinkStart,state.blinkObserved=nil,nil,nil
    state.blinkAmount=0
    return 0
  end
  if state.blinkObserved==now then return state.blinkAmount or 0 end
  if state.blinkObserved and (now<state.blinkObserved or now-state.blinkObserved>.25) then
    state.nextBlink,state.blinkStart=nil,nil
  end
  state.blinkObserved=now
  if not state.nextBlink then
    local first=state.blinkSerial==nil
    state.blinkSerial=state.blinkSerial or 0
    local phase=((tonumber(seed) or 0)*.754877666+state.blinkSerial*.618033989)%1
    state.nextBlink=now+(first and 1.0 or 2.4)+phase*(first and 1.2 or 2.4)
  end
  local age=now-state.nextBlink
  local amount=0
  if age>=0 and age<.26 then
    if age<.07 then amount=smooth(age/.07)
    elseif age<.11 then amount=1
    else amount=1-smooth((age-.11)/.15)end
  elseif age>=.26 then
    -- Missed intervals never replay a backlog after a stall/background pause.
    state.blinkSerial=(state.blinkSerial or 0)+1
    local phase=((tonumber(seed) or 0)*.754877666+state.blinkSerial*.618033989)%1
    state.nextBlink=now+2.4+phase*2.4
  end
  state.blinkAmount=amount
  return amount
end
-- Infrequent weight shifts, separate from the blink schedule. The renderer
-- applies this only to a source-reviewed body that supports the movement.
function Idle.shift(state,now,eligible,seed)
  if not eligible or type(now)~='number' or now~=now or math.abs(now)==math.huge then
    state.nextShift,state.shiftObserved,state.shiftHold=nil,nil,nil
    state.idleShift=0
    return 0
  end
  if state.shiftObserved==now then return state.idleShift or 0 end
  if state.shiftObserved and (now<state.shiftObserved or now-state.shiftObserved>.25) then
    state.nextShift,state.shiftHold=nil,nil
  end
  state.shiftObserved=now
  local serial=state.shiftSerial or 0
  local phase=((tonumber(seed) or 0)*.569840291+serial*.754877666)%1
  if not state.nextShift then
    state.nextShift=now+8+phase*6
    state.shiftHold=1.8+phase*1.4
    state.shiftSide=phase<.5 and -1 or 1
  end
  local age=now-state.nextShift
  local hold=state.shiftHold
  local amount=0
  if age>=0 and age<1.2 then amount=smooth(age/1.2)
  elseif age>=1.2 and age<1.2+hold then amount=1
  elseif age>=1.2+hold and age<2.4+hold then
    amount=1-smooth((age-1.2-hold)/1.2)
  elseif age>=2.4+hold then
    state.shiftSerial=serial+1
    state.nextShift,state.shiftHold=nil,nil
  end
  state.idleShift=amount*state.shiftSide
  return state.idleShift
end
return Idle
