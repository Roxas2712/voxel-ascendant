# Spring cherry blossom

With WEATHER set to AUTO, selected Kanto broadleaf voxel trees and generated outdoor skyline crowns bloom pink-white during spring. The weight rises smoothly during the first 120 seconds of the existing 960-second season, remains full until 60%, and fades to green by 90%. The year length and other weather remain unchanged.

Selection is a deterministic integer hash of map identity and tree position (roughly a quarter of eligible broadleaf trees), independent of model variant, load order, save/reload and the global RNG. Conifers are excluded. Nearby tree choices are cached on their existing placement descriptors. Distant generated tree crowns use the same positional selection policy. Painted bitmap panoramas and pre-baked rooftop captures are not recoloured as cherry trees; their existing seasonal material masks remain unchanged.

Only foliage texels receive blossom tint; trunks, terrain and actors retain their own materials. Green and blossom instances of each shared tree model use separate retained instance streams. No collision, Cut, encounter, card or fog changes.

Falling petals are depth-tested world geometry associated with nearby visible cherry crowns, capped at eight source trees and two petals per source. They reuse a 64-vertex mesh and one 1px texture. Position is derived from the existing weather clock and source coordinates, with no particle history or save data. Outside spring/AUTO/outdoors, no petal geometry is drawn. Asset cleanup and allocation/draw failure are isolated to this optional decoration.

Validation: tests/spring_blossom_test.lua covers bloom continuity/year boundaries, off/indoor gates, source/geometry budgets, stable irregular selection and separate stable instance streams. tests/spring_blossom_driver.lua uses the real game renderer and fresh-frame assertions for spring/summer/spring and generated skyline batches. Desktop and iOS-policy-on-desktop runs are distinct from physical device testing. Production shader validation covers 60 stages and 30 linked OpenGL/GLES programs.
