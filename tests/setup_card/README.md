# Your Look integration checks

Run only in a disposable Gen1 engine host with VASC and KASC, an isolated POKEPORT_IDENTITY, and optional Crystal/HD content installed for preview checks. Never point these drivers at a real player save. The copied source fixture must include the current integrated VASC and KASC menu.

Set POKEPORT_DRIVER to a driver here and VASC_SETUP_DEMO_ROOT to the fixture root (containing host/mods/VOXEL_ASCENDANT and an evidence directory). The native drivers create fresh test games. The flow driver exercises German UI; the localization driver covers English and German. The standalone rules test takes the VASC source root as arg[1].

- flow-v3: draft selections, content-return flow, real previews, apply-once persistence, F3/KASC entry, first use and new playthrough.
- safety: startup order, cancelled benchmark restores the entire save/world/settings, GPU probe and recommendations.
- localization: both languages and nine pages.
- cobblemon: bundled models/textures with empty read-only cache, no redundant install or download actions.
- benchmark: full 120 seconds plus targeted retests; actual rendered effects and restoration of saves/options.
- acquisition: existing content/import dispatch and return to draft; ROM dialog cancellation is stubbed.

Physical phone validation is separate; native macOS tests do not certify Android/iOS rendering. Gen2 uses its existing menu and does not install this Gen1 setup.
