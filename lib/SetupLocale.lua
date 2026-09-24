-- English is the default. Only the Universal mod's published boot language
-- may opt this Card into German. Pending changes require that mod's restart.
local V=...
local M={}
function M.language()
 local mod=V and V.mod
 if type(mod)~='table' or type(mod.find)~='function' then return 'en' end
 local ok,handle=pcall(mod.find,'translation-german-universal')
 if not ok or type(handle)~='table' then ok,handle=pcall(mod.find,mod,'translation-german-universal')end
 local exports=ok and type(handle)=='table' and handle.exports
 return type(exports)=='table' and exports.bootLanguage=='de' and 'de' or 'en'
end
function M.text(en,de)return M.language()=='de' and de or en end
-- Normalize public setting labels too: owners may already have translated
-- them, and a saved benchmark can outlive a language restart.
local choices={
 {'OFF','AUS'},{'ON','AN'},{'CLASSIC','KLASSISCH'},{'NATURAL','NATUERLICH'},
 {'FOLLOW MODEL PRIORITY','MODELLREIHENFOLGE'},{'AUTO: MODELS > FULL HD','AUTO: MODELLE > FULL HD'},
 {'FULL HD > MODELS','FULL HD > MODELLE'},{'SPRITES ONLY','NUR SPRITES'},
 {'FINE OUTLINE','FEINE KONTUR'},{'SUBTLE ANIME','DEZENTES ANIME'},
 {'COMIC OUTLINE','COMIC-KONTUR'},{'PEOPLE','MENSCHEN'},{'BOTH','BEIDE'},
 {'FLAT SLICES','FLACHE SCHICHTEN'},{'SUBTLE','DEZENT'},{'MEDIUM','MITTEL'},
 {'STRONG','STARK'},{'EXTREME','EXTREM'},{'PASSABLE','DURCHLAUFBAR'},
 {'FRONT','VORNE'},{'BACK','HINTEN'},{'SIDE','SEITLICH'},
 {'SKY','HIMMEL'},{'FULL','VOLL'},{'NATIVE','NATIV'},
}
function M.choice(label)
 for _,pair in ipairs(choices)do if label==pair[1]or label==pair[2]then return M.text(pair[1],pair[2])end end
 return label
end
return M
