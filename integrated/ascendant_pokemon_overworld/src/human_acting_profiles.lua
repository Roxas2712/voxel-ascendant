-- Exact admitted NPC source atlases; hero aliases are never inferred.
return {
 ["assets/characters/npcs/professor-elm-kasc-hd-4x3-walk-sheet-v1.png"]={
  atlas="assets/characters/acting/professor-elm-diagonal-v1.png",
 bounds={
   {left=219,right=443,top=44,bottom=601,imageWidth=1254,imageHeight=1254},
   {left=811,right=1035,top=44,bottom=600,imageWidth=1254,imageHeight=1254},
   {left=227,right=445,top=655,bottom=1205,imageWidth=1254,imageHeight=1254},
   {left=810,right=1027,top=653,bottom=1205,imageWidth=1254,imageHeight=1254},
  },
  -- Full-atlas pixels, reviewed against the four generated views. Rear
  -- diagonals expose one eye; nil is an intentionally absent second eye.
  eyes={
   {{297,165,326,207},{363,165,392,207}},
   {{866,165,895,208},{930,165,960,208}},
   {{266,773,287,805}},
   {{974,776,996,805}},
  },
 },
 ["assets/characters/npcs/professor-oak-kasc-hd-4x3-walk-sheet-v1.png"]={
  atlas="assets/characters/acting/professor-oak-diagonal-v1.png",
  turn={path="assets/characters/acting/oak-turn",from="down",to="down-left",eyes={
   [1]={{107,64,119,78},{135,64,147,78}},
   [2]={{96,65,106,81},{119,65,132,81}},
  },hashes={
   ["source-1.png"]="411d34c79fa3799a4420ef18014cb07d104053a7b446cc7a0c1ac92ed7c14d1a",
   ["source-2.png"]="7ef32ff4a479cf89538dfce8fedd39e5932235d426bbed914a103ad7a631afc6",
   ["forward.bin"]="59782c39bd4c0391a0e2b9d41709f4c2e8d4f7e18d8e7b3ebbaffc84789fc5f6",
   ["backward.bin"]="f03bb4ed71c5312391303831b85fa72e4ddff1c736bbb5cd6800a75b82a479b1",
  }},

  bounds={
   {left=201,right=456,top=42,bottom=605,imageWidth=1254,imageHeight=1254},
   {left=798,right=1053,top=42,bottom=605,imageWidth=1254,imageHeight=1254},
   {left=200,right=449,top=664,bottom=1208,imageWidth=1254,imageHeight=1254},
   {left=805,right=1054,top=663,bottom=1208,imageWidth=1254,imageHeight=1254},
  },
 },
 ["assets/characters/npcs/blue-kasc-hd-4x3-walk-sheet-v2.png"]={
  atlas="assets/characters/acting/blue-npc-diagonal-v1.png",
  poses={{
   key="_OaksLabOakChooseMonText",kind="observer",
   atlas="assets/characters/acting/blue-npc-folded-v1.png",
   bounds={
    {left=225,right=507,top=40,bottom=616,imageWidth=1254,imageHeight=1254},
    {left=757,right=1027,top=36,bottom=618,imageWidth=1254,imageHeight=1254},
    {left=242,right=501,top=640,bottom=1208,imageWidth=1254,imageHeight=1254},
    {left=762,right=1030,top=651,bottom=1209,imageWidth=1254,imageHeight=1254},
   },
  }},
  turn={path="assets/characters/acting/blue-turn",from="up",to="up-right",hashes={
   ["source-1.png"]="62620632a1c1214f477707d41e862d276887fcb523c386af386dc03c67ee8121",
   ["source-2.png"]="7248fb4d8a873e37720f06e6ffed13c11ed07fc6fd66effdba7496d6722bfa2e",
   ["forward.bin"]="747ce26ac87a4dd4f863e6d241d752a4886c6c005b7e590990de473e1af4122a",
   ["backward.bin"]="cfd509f97be74a59f1026541dcb1e1c3a1d05f9837d1a913436f77c52f30de19",
  }},

  bounds={
   {left=226,right=504,top=41,bottom=614,imageWidth=1254,imageHeight=1254},
   {left=758,right=1024,top=37,bottom=616,imageWidth=1254,imageHeight=1254},
   {left=244,right=499,top=640,bottom=1206,imageWidth=1254,imageHeight=1254},
   {left=763,right=1028,top=653,bottom=1206,imageWidth=1254,imageHeight=1254},
  },
 },
}
