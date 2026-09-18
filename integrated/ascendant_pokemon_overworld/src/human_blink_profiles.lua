local eyes={
["red"]={width=495,height=900,path="red_cards_4x3.png",rows={
[0]={{61,55,74,73},{87,55,100,73}},
[1]={{59,297,72,313}},
[3]={{92,751,103,766}},
}},
["green"]={width=495,height=900,path="green_cards_4x3.png",rows={
[0]={{63,58,76,78},{89,58,104,77}},
[1]={{49,295,58,311}},
[3]={{105,751,113,765}},
}},
["blue"]={width=495,height=900,path="blue_cards_4x3.png",rows={
[0]={{64,62,79,80},{88,61,104,80}},
[1]={{62,297,71,313}},
[3]={{94,753,103,768}},
}},
["gold"]={width=495,height=900,path="gold_cards_4x3.png",rows={
[0]={{61,56,74,76},{88,56,101,76}},
[1]={{61,309,69,324}},
[3]={{96,761,104,776}},
}},
["kris"]={procedural=true,width=495,height=900,path="kris_cards_4x3.png",rows={
[0]={{64,62,77,81},{88,62,101,81}},
[1]={{51,297,61,313}},
[3]={{104,747,113,763}},
}},
["silver"]={width=495,height=900,path="npcs/silver-kasc-hd-4x3-walk-sheet-v1.png",rows={
[0]={{62,50,77,67},{83,50,96,66}},
[1]={{59,284,66,298}},
[3]={{98,740,105,753}},
}},
-- Source-specific NPC eye boxes; rear views deliberately retain the source.
["professor-oak"]={procedural=true,width=495,height=900,path="npcs/professor-oak-kasc-hd-4x3-walk-sheet-v1.png",rows={
[0]={{60,58,76,69},{86,57,102,69}},
[1]={{60,288,72,300}},
[3]={{92,736,104,747}},
}},
["professor-elm"]={procedural=true,width=495,height=900,path="npcs/professor-elm-kasc-hd-4x3-walk-sheet-v1.png",rows={
[0]={{64,57,76,70},{88,57,100,70}},
[1]={{59,286,70,300}},
[3]={{94,733,103,746}},
}},
["misty"]={procedural=true,width=495,height=900,path="npcs/misty-kasc-hd-4x3-walk-sheet-v1.png",rows={
[0]={{54,62,68,80},{80,61,94,80}},
[1]={{61,292,70,307}},
[3]={{93,742,101,758}},
}},
}
local packed={
["red"]={size={930,1691},rows={
[0]={{-98.659090909091,-88.241216161616},{-20.234848484848,-88.218488888889}},
[1]={{-95.801346801347,-414.219274074074}},
[3]={{-157.329966329966,-1139.510037037037}},
}},
["green"]={size={930,1691},rows={
[0]={{-103.149286987522,-93.903869281046},{-23.303030303030,-93.363546031746}},
[1]={{-76.695151515152,-410.420755555556}},
[3]={{-181.787878787879,-1139.563022222222}},
}},
["blue"]={size={930,1691},rows={
[0]={{-104.545454545455,-101.082832323232},{-22.083636363636,-98.724022222222}},
[1]={{-101.016317016317,-414.190071794872}},
[3]={{-161.037350246653,-1143.018891472868}},
}},
["gold"]={size={930,1691},rows={
[0]={{-98.682588597843,-89.884376647834},{-22.135618479881,-89.905493624772}},
[1]={{-99.347627215552,-437.144572327044}},
[3]={{-164.418787878788,-1158.577444444445}},
}},
["silver"]={size={930,1691},rows={
[0]={{-100.471590909091,-78.275177777778},{-12.151515151515,-78.392977777778}},
[1]={{-94.976874003190,-389.990332163743}},
[3]={{-168.775917065391,-1119.219184795321}},
}},
}
for role,profile in pairs(eyes)do profile.packed=packed[role]end
eyes["daisy-oak"]={procedural=true,width=495,height=900,path="npcs/daisy-oak-kasc-hd-4x3-walk-sheet-v2.png",rows={
 [0]={{61,60,75,78},{89,59,106,78}},
 [1]={{53,288,62,305}},
 [3]={{103,736,112,752}},
}}
eyes.blue.alternates={{procedural=true,width=495,height=900,path="npcs/blue-kasc-hd-4x3-walk-sheet-v2.png",rows={
 [0]={{68,63,81,80},{91,63,104,79}},
 [1]={{62,299,73,315}},
 [3]={{93,754,103,770}},
}},{procedural=true,width=495,height=900,trimBottomRows={[0]=208/225,[2]=211/225},path="npcs/blue-johto-gym-kasc-hd-4x3-walk-sheet-v1.png",rows={
 [0]={{67,64,80,80},{91,64,104,79}},
 [1]={{62,302,71,316}},
 [3]={{94,750,104,765}},
}}}
eyes["johto-mother"]={procedural=true,width=495,height=900,path="npcs/johto-mother-kasc-hd-4x3-walk-sheet-v1.png",rows={
 [0]={{62,64,75,81},{90,64,104,81}},
 [1]={{53,285,64,303}},
 [3]={{103,735,114,753}},
}}
eyes["reds-mother"]={procedural=true,width=495,height=900,path="npcs/reds-mother-kasc-hd-4x3-walk-sheet-v2.png",rows={
 [0]={{63,69,75,85},{88,69,99,85}},
 [1]={{58,292,67,309}},
 [3]={{98,739,108,754}},
}}
 eyes.bill={procedural=true,width=495,height=900,path='npcs/bill-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{62,63,76,79},{90,63,104,79}},[1]={{58,292,69,307}},[3]={{97,743,107,758}}}}
 eyes.kurt={procedural=true,width=495,height=900,path='npcs/kurt-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{62,59,74,70},{90,59,101,70}},[1]={{56,285,65,297}},[3]={{101,737,109,750}}}}
eyes["ace-trainer-male-gen2"]={procedural=true,width=495,height=900,path="npcs/ace-trainer-male-gen2-kasc-hd-4x3-walk-sheet-v1.png",rows={
 [0]={{65,68,78,83},{90,66,104,82}},[1]={{54,292,64,307}},[3]={{101,741,110,756}}}}
eyes["ace-trainer-female-gen2"]={procedural=true,width=495,height=900,path="npcs/ace-trainer-female-gen2-kasc-hd-4x3-walk-sheet-v1.png",rows={
 [0]={{63,59,76,76},{89,58,103,74}},[1]={{51,292,60,307}},[3]={{105,740,113,755}}}}
local function youngsterEyes(suffix)
 return {procedural=true,rimHeadEnd=105,width=495,height=900,path='npcs/youngster-gen1-bald-hd-4x3-walk-sheet-v1'..suffix..'.png',rows={
  [0]={{59,52,74,68},{89,52,104,68}},[1]={{57,282,67,299}},[3]={{97,739,107,756}}}}
end
eyes.youngster=youngsterEyes('')
eyes.youngster.alternates={youngsterEyes('-bald-green'),youngsterEyes('-bald-red')}
eyes.fisher={procedural=true,width=495,height=900,path='npcs/fisher-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{62,55,73,69},{89,54,98,69}},[1]={{59,280,68,294}},[3]={{97,731,106,745}}},alternates={}}
for _,path in ipairs({'npcs/fisher-kasc-hd-4x3-walk-sheet-v1-variant-gray-navy.png',
 'npcs/fisher-kasc-hd-4x3-walk-sheet-v1-variant-auburn-olive.png'})do
 eyes.fisher.alternates[#eyes.fisher.alternates+1]={procedural=true,width=495,height=900,path=path,rows=eyes.fisher.rows}
end
eyes.oak=eyes["professor-oak"]
-- Preserve Giovanni's diagonal upper eye contour while the lower lid closes.
eyes.giovanni={procedural=true,width=495,height=900,path='npcs/giovanni-kasc-hd-4x3-walk-sheet-v1.png',rows={[0]={{58,66,80,80},{88,66,108,80}},[1]={{49,290,63,304}},[3]={{103,740,117,754}}},lidStarts={[0]={{2,10},{10,2}},[1]={{10,2}},[3]={{2,10}}}}
-- Exact executive eye boxes. Ariana red iris pixels are distinct from hair.
eyes.archer={procedural=true,width=495,height=900,path='npcs/archer-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{60,73,79,86},{87,73,103,86}},[1]={{56,299,69,314}},[3]={{96,749,109,764}}}}
eyes.ariana={coloredIris=true,procedural=true,width=495,height=900,path='npcs/ariana-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{69,73,82,87},{99,72,113,88}},[1]={{51,297,62,313}},[3]={{110,750,119,766}}}}
-- Exact martial-leader eyes; sloping lids preserve brows.
eyes.bruno={rimHeadEnd=105,rimSoftEdge=true,procedural=true,width=495,height=900,path='npcs/bruno-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{54,64,76,81},{79,64,101,81}},[1]={{35,286,55,305}},[3]={{111,733,131,753}}},lidStarts={[0]={{2,10},{10,2}},[1]={{10,2}},[3]={{2,10}}}}
eyes.chuck={rimHeadEnd=105,rimSoftEdge=true,procedural=true,width=495,height=900,path='npcs/chuck-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{65,62,77,71},{88,62,100,71}},[1]={{54,295,64,304}},[3]={{101,743,111,752}}},lidStarts={[0]={{1,3},{3,1}},[1]={{3,1}},[3]={{1,3}}}}
-- Karen ordinary lids; Will lids stay inside the mask apertures.
eyes.karen={procedural=true,width=495,height=900,path='npcs/karen-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{61,62,74,79},{86,62,99,79}},[1]={{50,287,60,303}},[3]={{106,738,115,753}}}}
eyes.will={procedural=true,width=495,height=900,path='npcs/will-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{58,66,76,79},{85,66,103,79}},[1]={{56,297,66,308}},[3]={{103,746,114,756}}},
skinSamples={[0]={{68.5,86.5},{92.5,86.5}},[1]={{63.5,316.5}},[3]={{105.5,762.5}}},
eyeClips={[0]={{58,67,64,67,75,71,76,74,71,78,64,78,60,74,58,69},{86,71,98,67,102,67,103,70,100,76,95,78,89,77,86,74}},[1]={{56,301,60,298,65,298,66,300,65,305,62,307,59,306,57,304}},[3]={{103,748,105,746,109,747,113,750,112,753,109,755,105,754,103,751}}}}
-- Separate Koga eye landmarks; upper edges preserve the thick brows.
eyes.koga={procedural=true,width=495,height=900,path='npcs/koga-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{57,65,75,79},{84,65,102,79}},[1]={{50,293,64,308}},[3]={{102,743,116,758}}},lidStarts={[0]={{4,10},{10,4}},[1]={{10,4}},[3]={{4,10}}}}
eyes['koga-gen2']={procedural=true,width=495,height=900,path='npcs/koga-gen2-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{44,71,64,91},{72,71,93,91}},[1]={{41,300,57,320}},[3]={{108,746,123,765}}},lidStarts={[0]={{7,14},{14,7}},[1]={{13,6}},[3]={{6,13}}}}
-- Bugsy: manually reviewed side eyes exclude hair and face outline.
eyes.bugsy={procedural=true,width=495,height=900,path='npcs/bugsy-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{60,66,75,84},{90,66,105,84}},[1]={{53,288,63,305}},[3]={{103,737,113,754}}}}
-- Reviewed Johto leader eyes; Morty's blond hair is not a skin landmark.
eyes.morty={procedural=true,width=495,height=900,path='npcs/morty-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{63,65,74,80},{88,65,100,80}},[1]={{56,291,65,306}},[3]={{99,741,108,756}}}}
eyes.whitney={procedural=true,width=495,height=900,path='npcs/whitney-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{61,75,75,91},{89,75,103,91}},[1]={{57,299,66,315}},[3]={{99,751,108,766}}}}
-- Jasmine: reviewed pupils, excluding the brown hair components.
eyes.jasmine={procedural=true,width=495,height=900,path='npcs/jasmine-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{62,54,75,70},{88,54,101,70}},[1]={{57,290,66,306}},[3]={{99,740,108,755}}}}
-- Exact Johto leader sources; eyelids retain the upper eye contour.
eyes.clair={procedural=true,width=495,height=900,path='npcs/clair-kasc-hd-4x3-walk-sheet-v2.png',rows={
[0]={{70,63,82,77},{90,63,102,77}},[1]={{35,290,44,305}},[3]={{117,741,126,755}}}}
eyes.pryce={procedural=true,width=495,height=900,path='npcs/pryce-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{61,69,76,84},{88,69,103,84}},[1]={{51,294,60,308}},[3]={{105,743,114,757}}}}
-- Red NPC v2: exact apertures separate eyes from the dark cap edge.
eyes.red.alternates={{procedural=true,width=495,height=900,path='npcs/red-kasc-hd-4x3-walk-sheet-v2.png',rows={
[0]={{62,59,75,73},{88,59,100,73}},[1]={{64,301,73,316}},[3]={{92,754,102,769}}},
eyeClips={
[0]={{62,59,68,59,75,59,75,66,75,74,68,74,62,74,62,66},{88,59,94,59,101,59,101,66,101,74,94,74,88,74,88,66}},
[3]={{92,754,97,754,102,754,102,761,102,769,97,769,92,769,92,761}}}}}
-- Gold/Kris NPC sheets keep independent eye coordinates and shader resources.
eyes.gold.alternates={{procedural=true,width=495,height=900,path='npcs/gold-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{62,57,75,73},{88,57,101,73}},[1]={{61,305,69,320}},[3]={{96,756,104,771}}}}}
eyes.kris.alternates={{procedural=true,width=495,height=900,path='npcs/kris-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{64,53,77,70},{88,53,101,70}},[1]={{50,283,60,300}},[3]={{106,734,115,750}}}}}
-- Exact common Gen2 cards. Palette variants retain identical geometry but
-- receive distinct profile identities so cache ownership follows the source.
local function commonGen2Eyes(path,variants,rows)
 local profile={procedural=true,width=495,height=900,path=path,rows=rows,alternates={}}
 for _,variant in ipairs(variants)do
  profile.alternates[#profile.alternates+1]={procedural=true,width=495,height=900,path=variant,rows=rows}
 end
 return profile
end
eyes["swimmer-female-gen2"]=commonGen2Eyes('npcs/swimmer-female-gen2-kasc-hd-4x3-walk-sheet-v1.png',{
'npcs/swimmer-female-gen2-kasc-hd-4x3-walk-sheet-v1-variant-auburn-teal.png',
'npcs/swimmer-female-gen2-kasc-hd-4x3-walk-sheet-v1-variant-blond-navy.png'}, {
[0]={{59,75,76,91},{85,75,97,90}},[1]={{46,290,56,306}},[3]={{113,737,122,753}}})
eyes["twins-gen2"]=commonGen2Eyes('npcs/twins-gen2-kasc-hd-4x3-walk-sheet-v1.png',{
'npcs/twins-gen2-kasc-hd-4x3-walk-sheet-v1-variant-auburn-teal.png',
'npcs/twins-gen2-kasc-hd-4x3-walk-sheet-v1-variant-blond-navy.png'}, {
[0]={{64,76,77,90},{89,76,102,90}},[1]={{60,308,72,321}},[3]={{95,756,105,770}}})
eyes["fishing-guru"]=commonGen2Eyes('npcs/fishing-guru-kasc-hd-4x3-walk-sheet-v1.png',{
'npcs/fishing-guru-kasc-hd-4x3-walk-sheet-v1-variant-auburn-teal.png',
'npcs/fishing-guru-kasc-hd-4x3-walk-sheet-v1-variant-blond-navy.png'}, {
[0]={{60,63,75,79},{90,63,105,79}},[1]={{54,293,64,308}},[3]={{101,742,111,757}}})
eyes.gambler={procedural=true,width=495,height=900,path='npcs/gambler-kasc-hd-4x3-walk-sheet-v1.png',rows={
[0]={{62,56,73,72},{89,56,101,72}},[1]={{56,283,65,299}},[3]={{100,733,110,749}}}}
-- Exact common resident eyes. Glasses and heavily occluded faces stay out of
-- this batch; these apertures contain only visible eyes and preserve hair.
eyes["game-boy-kid"]=commonGen2Eyes('npcs/game-boy-kid-kasc-hd-4x3-walk-sheet-v1.png',{
'npcs/game-boy-kid-kasc-hd-4x3-walk-sheet-v1-variant-auburn-teal.png',
'npcs/game-boy-kid-kasc-hd-4x3-walk-sheet-v1-variant-blond-navy.png'}, {
[0]={{56,64,72,81},{86,64,102,81}},[1]={{52,294,62,310}},[3]={{103,744,113,760}}})
eyes["middle-aged-man"]=commonGen2Eyes('npcs/middle-aged-man-kasc-hd-4x3-walk-sheet-v1.png',{
'npcs/middle-aged-man-kasc-hd-4x3-walk-sheet-v1-variant-blond-navy.png',
'npcs/middle-aged-man-kasc-hd-4x3-walk-sheet-v1-variant-gray-olive.png'}, {
[0]={{61,61,72,79},{91,61,102,79}},[1]={{52,283,59,301}},[3]={{106,731,113,750}}})
eyes["receptionist-gen2"]=commonGen2Eyes('npcs/receptionist-gen2-kasc-hd-4x3-walk-sheet-v1.png',{
'npcs/receptionist-gen2-kasc-hd-4x3-walk-sheet-v1-variant-auburn-teal.png',
'npcs/receptionist-gen2-kasc-hd-4x3-walk-sheet-v1-variant-blond-navy.png'}, {
[0]={{62,74,78,90},{91,74,105,90}},[1]={{53,295,63,311}},[3]={{105,742,114,759}}})
-- High-use resident cards. The bounds include each authored brow/eye aperture,
-- but exclude hair, hats and the rear view so the shared procedural lid stays local.
eyes["link-receptionist"]={procedural=true,width=495,height=900,
 path='npcs/link-receptionist-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{59,54,75,75},{88,54,104,75}},[1]={{55,295,66,316}},[3]={{100,742,110,763}}}}
eyes.channeler={procedural=true,width=495,height=900,
 path='npcs/channeler-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{58,67,74,86},{87,67,104,86}},[1]={{52,282,63,302}},[3]={{100,732,112,747}}}}
eyes.psychic={procedural=true,width=495,height=900,
 path='npcs/psychic-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{59,77,75,94},{86,77,98,94}},[1]={{55,296,65,315}},[3]={{102,741,112,760}}}}
eyes["silph-worker-male"]={procedural=true,width=495,height=900,
 path='npcs/silph-worker-male-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{61,51,75,72},{87,51,102,72}},[1]={{56,283,66,303}},[3]={{100,732,112,752}}}}
eyes["picnicker-gen2"]={procedural=true,width=495,height=900,
 path='npcs/picnicker-gen2-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{59,63,74,84},{88,63,103,84}},[1]={{53,289,61,311}},[3]={{106,739,115,760}}}}
eyes["little-girl"]={procedural=true,width=495,height=900,
 path='npcs/little-girl-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{61,59,76,82},{89,59,106,82}},[1]={{49,286,59,310}},[3]={{106,731,116,755}}}}
eyes.juggler={procedural=true,width=495,height=900,
 path='npcs/juggler-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{62,70,75,85},{89,69,102,85}},[1]={{51,291,62,307}},[3]={{104,740,115,755}}}}
eyes["cue-ball"]={procedural=true,width=495,height=900,
 path='npcs/cue-ball-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{58,57,78,78},{85,57,106,78}},[1]={{49,269,69,299}},[3]={{98,710,118,733}}},
 lidStarts={[0]={{2,10},{10,2}},[1]={{10,2}},[3]={{2,10}}}}
eyes["jr-trainer-male"]={procedural=true,width=495,height=900,
 path='npcs/jr-trainer-male-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{61,61,75,78},{89,61,104,78}},[1]={{63,289,73,306}},[3]={{91,738,101,755}}}}
eyes.cook={procedural=true,width=495,height=900,
 path='npcs/cook-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{65,79,75,92},{89,79,98,92}},[1]={{53,311,60,324}},[3]={{104,763,112,776}}}}
eyes["silph-worker-female"]={procedural=true,coloredIris=true,width=495,height=900,
 path='npcs/silph-worker-female-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{63,70,70,80},{85,64,100,80}},[1]={{48,287,56,302}},[3]={{109,739,117,754}}}}
eyes["middle-aged-woman"]=commonGen2Eyes('npcs/middle-aged-woman-kasc-hd-4x3-walk-sheet-v1.png',{
 'npcs/middle-aged-woman-kasc-hd-4x3-walk-sheet-v1-variant-auburn-forest.png',
 'npcs/middle-aged-woman-kasc-hd-4x3-walk-sheet-v1-variant-gray-blue.png'}, {
 [0]={{62,55,75,76},{89,55,102,76}},[1]={{55,281,65,301}},[3]={{101,735,110,753}}})
eyes["safari-zone-worker"]={procedural=true,coloredIris=true,width=495,height=900,
 path='npcs/safari-zone-worker-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{60,58,76,80},{88,58,104,80}},[1]={{61,287,70,305}},[3]={{103,708,114,726}}}}
-- Story-facing leaders and common children. These exact face apertures keep
-- hair, headbands and brows outside the procedural lid.
eyes["misty-gen2"]={procedural=true,coloredIris=true,width=495,height=900,
 path='npcs/misty-gen2-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{59,55,73,72},{91,55,105,72}},[1]={{55,293,63,307}},[3]={{102,743,110,757}}},
 skinSamples={[0]={{82,75},{84,75}}}}
eyes["erika-gen2"]={procedural=true,width=495,height=900,
 path='npcs/erika-gen2-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{61,54,75,71},{91,54,105,71}},[1]={{53,293,62,307}},[3]={{103,743,112,757}}}}
eyes.erika={procedural=true,width=495,height=900,
 path='npcs/erika-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{61,54,75,71},{91,54,105,71}},[1]={{53,293,62,307}},[3]={{103,743,112,757}}}}
eyes.janine={procedural=true,coloredIris=true,width=495,height=900,
 path='npcs/janine-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{49,61,68,84},{81,61,100,84}},[1]={{50,287,62,308}},[3]={{103,737,115,758}}}}
eyes["lance-johto-champion"]={procedural=true,coloredIris=true,width=495,height=900,
 path='npcs/lance-johto-champion-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{58,62,73,80},{91,62,106,80}},[1]={{52,289,61,303}},[3]={{104,739,113,753}}},
 skinSamples={[1]={{70,302}},[3]={{95,752}}}}
eyes.lance={procedural=true,width=495,height=900,
 path='npcs/lance-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{56,54,76,77},{89,54,109,77}},[1]={{50,282,62,303}},[3]={{103,732,115,753}}}}
eyes["lt-surge-gen2"]={procedural=true,coloredIris=true,width=495,height=900,
 path='npcs/lt-surge-gen2-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{59,52,74,65},{92,52,107,65}},[1]={{54,286,64,300}},[3]={{101,736,111,750}}}}
eyes.sabrina={procedural=true,coloredIris=true,width=495,height=900,
 path='npcs/sabrina-kasc-hd-4x3-walk-sheet-v1.png',rows={
 -- Her side-view eye is partly covered by the straight hair edge. Keep those
 -- source pixels exact until a source-specific aperture has been reviewed.
 [0]={{59,55,75,69},{90,55,106,69}}}}
eyes.girl={procedural=true,width=495,height=900,
 path='npcs/girl-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{58,56,76,81},{89,56,108,81}},[1]={{50,287,62,309}},[3]={{103,737,115,759}}}}
eyes["little-boy"]={procedural=true,width=495,height=900,
 path='npcs/little-boy-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [0]={{59,74,74,89},{91,74,106,89}},[1]={{55,296,64,310}},[3]={{101,746,110,760}}}}
-- The Pokefan's authored front face already smiles with closed eyes. Only the
-- exact side views used by her seated house pose receive a procedural blink.
eyes["pokefan-female-gen2"]={procedural=true,seatedOnly=true,width=495,height=900,
 path='npcs/pokefan-female-gen2-kasc-hd-4x3-walk-sheet-v1.png',rows={
 [1]={{58,303,69,313}},[3]={{97,753,108,763}}}}
return eyes
