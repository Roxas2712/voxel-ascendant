# Scenery assets added for video feedback

## Rooftop panoramas

Generated with the built-in `image_gen` tool, then copied unchanged into the project. Both PNGs are 2172 × 724. They are painted environmental approximations of Kanto, not exact map captures.

- `assets/scenery/celadon-rooftop-east.png`
- `assets/scenery/celadon-rooftop-west.png`

Original tool outputs, retained unchanged:

- `/Users/maarten/.codex/generated_images/01a0b65e-9437-7300-aca9-79670b7e4a9c/exec-06b915a5-da70-46da-a552-c6c0ab992456.png`
- `/Users/maarten/.codex/generated_images/01a0b65e-9437-7300-aca9-79670b7e4a9c/exec-2fbcbfb1-266a-492a-894c-4c6a5f641641.png`

### East prompt

Use case: stylized-concept. Asset type: actual in-game environment panorama bitmap, not a screenshot or mockup. Create a very wide 3:1 panoramic matte painting, 3072 by 1024 if possible, for a Pokémon Kanto rooftop terrace. View outward from about the sixth floor of Celadon City's department store toward Saffron City in the distance. Elevated horizontal camera looking over many lower roofs; lower half contains rooftops, treetops, narrow streets and parks seen from above, upper half the distant city and layered hills, pale blue sky in the upper third. Distinctive distant cream and blue-glass Silph Co highrise toward the right center, red-roof and green-roof Kanto houses, Japanese small-city feel, no modern megacity. Crisp hand-painted pixel-art-inspired game scenery that fits a colorful voxel Pokemon world, coherent simple faceted geometry, restrained detail, gentle sunny daylight, strong atmospheric perspective so you can see very far. One continuous unbroken view; no foreground terrace, furniture, people, Pokemon, window mullions, glass reflections, borders, text, logos or watermarks. Buildings below viewpoint, no horizon at ground/player level. Keep left and right ends unobtrusive with similar sky color for wraparound scenery. The delivered image must contain ONLY the scenic bitmap.

### West prompt

Use case: stylized-concept. Asset type: actual in-game environment panorama bitmap, 3:1 landscape. A continuous elevated rooftop view over the western half of Pokemon Celadon City in Kanto, from sixth-floor level, as a companion environment matte painting to a view east toward Saffron. Lower half full of distinctly lower roofs viewed from above, cream buildings with green and muted red roofs, Celadon-style courtyard gardens, compact residential blocks transitioning into woodland, a distant cycle path and lake toward the left, forested rolling hills behind. No skyscrapers or towers. Upper third pale sunny blue sky with small puffy clouds. Horizon roughly 40 percent below top. Crisp hand-painted pixel-art-inspired game scenery, simple faceted building geometry suited to colorful voxel Pokemon, light atmospheric haze, long visibility. Wide horizontal elevated camera, gentle sunny daylight, calm saturated green/cream/blue palette. Entire image is ONLY the scenery bitmap; no terrace or foreground frame, no glass reflections, no people, Pokemon, labels, UI, border, watermarks. Visually consistent depth from near low rooftops to hazy far hills. Make end edges calm and similar in color, no distinct large landmark at either edge.

## Aquarium sheets

These are existing project assets copied byte-for-byte into a core scenery location so the aquarium does not depend on optional follower downloads. No image generation or editing was used for them.

Source directory: `/Users/maarten/Documents/Recompile/vasc-gen1-stadium-hd-release-3015/integrated/ascendant_pokemon_overworld/assets/pokemmo-followers/`.

| Destination | Source filename | SHA-256 |
|---|---|---|
| `aquarium-116.png` | `follower_116_none_normal_base.png` | `2d455160621f66501c118c7f1e289e6e14734ab63ca6f37c39faa4f20d7846de` |
| `aquarium-118.png` | `follower_118_none_normal_base.png` | `4f6cbbfcfd264301d4d832b7053b33531ce211bff38760bc6e7a6bfe4b48411d` |
| `aquarium-129.png` | `follower_129_none_normal_base.png` | `05fd85ff387642bbb9d2426fc34f14ca11e82cbe79abbc56cb158546548be24f` |

Attribution follows the existing `integrated/ascendant_pokemon_overworld/THIRD_PARTY_NOTICES.md`: user-provided PokeMMO follower input; credited sources include Kuplion, TooManyLuigis, Mortedesu, Billla, CrissCy and Game Freak. These artwork files are not covered by the code's MIT license. The existing notes do not establish public redistribution permission; this working copy does not publish them.
