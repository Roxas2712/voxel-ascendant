-- Presentation policy only: never changes KASC difficulty or battle rules.
local B={}
B.order={'poke','great','ultra','master','safari','apri_red','apri_blue','apri_yellow','apri_green','apri_pink','apri_black','apri_white'}
B.definitions={
 poke={label='POKEBALL',kind=0,base={.80,.10,.075},accent={.80,.10,.075}},
 great={label='SUPERBALL',kind=1,base={.045,.30,.83},accent={.94,.12,.085}},
 ultra={label='HYPERBALL',kind=2,base={.065,.075,.095},accent={1,.78,.035}},
 master={label='MEISTERBALL',kind=3,base={.40,.16,.67},accent={.96,.27,.64}},
 safari={label='SAFARIBALL',kind=5,base={.33,.49,.22},accent={.72,.64,.36}},
 apri_red={label='APRIKOKO ROT',kind=4,base={.78,.12,.15},accent={.96,.70,.37}},
 apri_blue={label='APRIKOKO BLAU',kind=4,base={.13,.43,.76},accent={.64,.85,.94}},
 apri_yellow={label='APRIKOKO GELB',kind=4,base={.96,.73,.13},accent={.42,.30,.10}},
 apri_green={label='APRIKOKO GRUEN',kind=4,base={.23,.56,.24},accent={.75,.91,.40}},
 apri_pink={label='APRIKOKO ROSA',kind=4,base={.92,.39,.59},accent={1,.82,.79}},
 apri_black={label='APRIKOKO SCHWARZ',kind=4,base={.11,.14,.18},accent={.61,.67,.77}},
 apri_white={label='APRIKOKO WEISS',kind=4,base={.90,.88,.80},accent={.37,.43,.29}},
}
B.difficulty={standard='poke',high='great',hard='ultra',very_hard='ultra',extreme='master'}
function B.resolve(selection,difficulty,mapId)
 if type(mapId)=='string'and mapId:match('^SAFARI_ZONE_')then return 'safari'end
 if selection==nil or selection=='auto'then return B.difficulty[difficulty]or'poke'end
 return B.definitions[selection]and selection or'poke'
end
function B.choices()
 local rows={{'AUTO: KASC','auto'}}
 for _,key in ipairs(B.order)do rows[#rows+1]={B.definitions[key].label,key}end
 return rows
end
return B
