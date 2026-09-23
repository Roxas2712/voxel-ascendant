-- Native 16px wardrobe art. Palette ramps and small pixel stamps are editable
-- source assets: no HD image, resampling, generated pose or external editor at runtime.
local P={version=2}
P.sources={RED="68527c0c4c437daa0789f3f0ee48a93ede750f6d8c145b996d1f69c28ad16f64",BLUE="da4a00424bc45b81cddaa5992f3a86cd52afe4c2bcafa66215c8d73491a9599e",GREEN="de94aa12ba95b9c05a81b940bba945485ee6ad0cba3575b66b30dc0c493dd07f"}
P.colors={ink='191419',cream='eee6cf',gold='d8ac48',pink='db6d97',
 red='ce393b',blue='3870c4',green='40b058'}
P.upper={
 RED={['city-jacket']={'354455','202a38','c94442'},['trail-jacket']={'b64b38','743127','d4b56d'},['champion-jacket']={'b72422','282728','e3b652'}},
 BLUE={['city-jacket']={'44688b','293951','b4c2cc'},['trail-jacket']={'77614a','463c36','5480b0'},['champion-jacket']={'355dab','202d55','e3b652'}},
 GREEN={['cream-tee']={'eee6cf','b7a788','eee6cf'},['rust-tee']={'c87755','884938','e5a67d'},
  ['champion-ivory']={'eee6cf','b7a788','d8ac48'},['lotta-vest']={'34313b','211f28','eee6cf'}},
}
P.lower={['city-trousers']={'365571','24394b'},['trail-trousers']={'bda477','7a694c'},
 ['champion-trousers']={'393941','23232c'},['indigo-jeans']={'365571','24394b'},
 ['sand-cargo']={'bda477','7a694c'},['champion-plum']={'795069','493343'},['lotta-shorts']={'508bae','2e5879'}}
P.footwear={['city-shoes']={'d5d4c9','707681'},['trail-shoes']={'79533d','443528'},
 ['champion-shoes']={'b72c29','eee6cf'},['cream-sneakers']={'e6ddc5','828779'},
 ['brown-boots']={'79533d','443528'},['champion-oxblood']={'8c3d4f','49262f'},['lotta-boots']={'db6d97','34313b'}}
P.hair={black={'343240','201e29'},brown={'86563b','493126'},blond={'dbb568','916c3b'},
 silver={'b9c8d2','73818e'},red={'b45339','753528'},blue={'5189bf','325174'},purple={'9466af','634373'}}
-- The head occupies the SAME five rows in every direction; walking frames
-- offset it down exactly one pixel, as in all three original sheets.
-- O outline, W crown, C character/pink colour, . transparent. No facial rows.
P.cap={
 front={'.....OOOOOO.....','....OWWWWWWO....','...OWWWWWWWWO...','...OWWWWWWWWO...','..OOCCCCCCCCOO..'},
 back={'.....OOOOOO.....','....OWCCCCWO....','...OWCCCCCCWO...','...OWCCOOCCWO...','...OCCOWWOCCO...'},
 left={'.....OOOOOO.....','....OWWWWWCO....','...OWWWWWWCCO...','...OWWWWWWCCO...','.OOCCCCCCCCCO...'},
 leftBack={'.....OOOOOO.....','....OCWWWWWO....','...OCCWWWWWWO...','...OCCWWWWWWO...','...OCCCCCCCCOOO.'},
}
P.bare={
 front={'......OO.O......','...OOOhOhhOO....','...OhhhhhhhO....','..OhhhOhOOhhO...','..OOhOhOOOhhO...'},
 back={'......OOOO......','....OOhhhhOO....','...OhhhhhhhhO...','...OhhhhhhhhO...','...OhhhhhhhhO...'},
 left={'......OO.O......','...OOOhOhhOO....','...OhhhhhhhhO...','..OhhhOhhhhhO...','..OOhOhhhhhhO...'},
}
return P
