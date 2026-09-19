# Voxel Ascendant 3.0.32

An update for Generation 1 and Generation 2, with visual repairs, clearer camera behaviour and improved mobile rendering options.

## New and improved

- **Gen2 rendering options:** choose 1080P, native resolution or 720P directly from the quick menu. The previous hidden mobile resolution cap is removed. Mobile tree rendering now uses the compatible geometry path, and world/camera shader calculations use higher precision.
- **Animated Gen2 battle Pokémon:** the battle renderer can use animated fronts supplied by the companion sprite provider. Animation and provider settings still apply; missing assets keep their normal fallback.
- **MAP battles:** opening the attack-selection menu can keep the last valid camera and reframe it for the larger menu instead of unnecessarily dropping back to 2D.
- **Safari Zone:** more rocky terrain and less moss, cleaner ground, and recognizable exit frames. Native paths and exits are preserved.
- **Fuchsia and surrounding areas:** replaced additional original checkerboard ground motifs with continuous paving. The fossil exhibit displays Amonitas/Omanyte or Kabuto according to the original fossil choice, and the neighbouring enclosure uses the intended Pokémon presentation.
- **Window rendering:** removed overlapping solid surfaces behind glass that could produce broken or flickering panes.
- **Celadon rooftops:** modern voxel floors, glazing, stair entrances and vending machines. Distant scenery is drawn from the actual connected Kanto world, with voxel forests and landmarks, live sky and lighting. Outdoor rain now applies to the roofs.
- **Bikers:** native Biker trainers in both generations use the seated bicycle artwork wherever the registered assets are available.
- **Johto buildings:** Crystal's Olivine lighthouse is recognized as one complete tower. Goldenrod's north gate now has a complete building and roof instead of a flattened facade with a raised window fragment.

## Still being worked on

- The new source-world distant scenery for **Johto** is not included yet. Existing Johto backgrounds remain.
- Further Johto house and wall styling is still planned.
- The reported Gen2 flicker on physical phones and the reporter's installed animated-sprite package still need device verification. The changes above are not a claim that every mobile rendering issue is resolved.

## Installation

Download **Voxel-Ascendant-3.0.32.zip** for the normal mod update. Do not delete your optional sprite downloads or saves just to update. An optional **Preserve-Installed-Sprites** desktop installer is also attached; it makes a backup and preserves omitted optional sprite files and settings.

Higher scene resolution and expanded tree geometry can use more GPU time or memory. Choose 720P if needed.

## Validation

Native macOS runs cover Gold, Crystal and Yellow, with focused automated regressions and visual comparisons from the development candidates. The Goldenrod gate was entered through normal movement in both Gold and Crystal. Archive contents, Lua syntax, checksums and the preserving installer are checked for this release. These checks do not substitute for physical iPhone/Android testing.
