# Voxel Characters Card — local test 3

Card `vasc.gen1.voxel-characters`, version `0.1.0-test.3`, is an optional internal VASC presentation Card on RC21. It does not register a second gameplay or timeline owner. HD is the default appearance. `voxelCharacterCardEnabled=false` restores HD, preserving the stored outfit and chosen style for reactivation.

F6 and F3 → Characters share `apo_hd_walking_sprites` and `apo_human_art_style`: Original → HD → Voxel. F7 retains its follower role. Changes are rejected while moving, cycling, fishing, surfing or in a cinematic. KASC per-character Original selections remain authoritative.

The three protagonists and all 33 wardrobe presets route through one appearance resolver. Wardrobe choices, accessories and save slots remain KASC-owned. Voxel draft packs are admitted explicitly by this test Card; their manifests remain draft and this is not a release-quality designation.

House ball throws use the existing Battle Heroes timeline and the selected atlas, with voxel arm landmarks and a 256-wide carrier to avoid cutting the extended hand. HD retains the existing carrier.

Fishing consumes the dressed walking body and renders a fixed hold using the same pixel-arm/shoulder method as the house throw. No generated cast phases are selected. The existing SpeciesFishingCinematic owns cast, rod, line, float, bite and pullout; the field renderer supplies a matching hand anchor. Surf and Fly consume the selected ordinary body through FieldActorAppearance; both cinematic modules are otherwise unchanged from RC21.

Reversible: select HD/Original with F6, or disable VOXEL CHARACTERS CARD in sprite settings. No outfit or gameplay-save migration. The included demo uses a separate LOVE identity. Do not replace a working installation with this test without retaining its paired VASC/KASC modules.

Evidence and runnable integration drivers reside in the enclosing test bundle. The full wardrobe pose matrix is a technical completeness check, not blanket visual approval of every accessory combination. Bicycle garments use directly authored cycling masters registered to the existing body. Front/back opposed pedal frames, original red footwear, and trouser/boot boundaries are corrected. All 33 wardrobe presets and field actions are exercised by the TEST3 drivers.

Test 2 additionally corrects the mother crown material in all 18 walking/seated/blink cells, completes the 77-atlas NPC catalog, cleans NPC edge spill, and separates Green trouser coverage from connected arm/leg skin. Green’s 11 recipes and 55 throw poses were rechecked after the mask change.

## RC25 integration

Merged TEST3 onto RC24 (VASC 3.0.37-rc.23 / KASC 6.7.19-rc.6). The Cobblemon runtime identity and availability bridges are preserved alongside the voxel wardrobe bridge. The Card remains separate, optional and appearance-only. HD stays the default; its art assets remain draft. No demo character-switch hotkeys or demo gameplay overrides are installed. KASC chooses the protagonist; standalone Gen-1 VASC keeps native Red and uses its existing local wardrobe provider.
