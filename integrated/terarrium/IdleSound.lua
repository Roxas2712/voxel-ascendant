-- Original synthesized low, resonant capture-style impact (no sampled game audio).
return function()
 local source
 local S={}
 function S.play()
  if not source then
   local rate=44100;local data=love.sound.newSoundData(math.floor(rate*.42),rate,16,1)
   for i=0,data:getSampleCount()-1 do
    local t=i/rate;local attack=math.min(1,t/.006)
    local phase=2*math.pi*(83*t+35*.045*(1-math.exp(-t/.045)))
    local value=attack*(.54*math.exp(-t*11)*math.sin(phase)+.18*math.exp(-t*18)*math.sin(phase*2.03)+.06*math.exp(-t*40)*math.sin(2*math.pi*740*t))
    data:setSample(i,value)
   end
   source=love.audio.newSource(data,'static');data:release()
  end
  source:stop();source:play()
 end
 function S.stop()if source then source:stop()end end
 function S.release()if source then source:stop();source:release();source=nil end end
 return S
end
