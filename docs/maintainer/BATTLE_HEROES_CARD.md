# Battle Heroes Card

Imports Ascendant Battle Heroes 1.0.1 from mini-mod-battle-heroes as a Gen1 presentation Card. Existing sprites are unchanged. Its six character sheets and ball art live only under integrated/battle_heroes. Credits and licenses accompany them.

VASC > BALLWURF offers a persisted master switch (OFF by default), trainer presence, gestures and modern ball skins. In-flight animation retains the already decided native result and completes after disabling; no RNG, party, storage or bag mutations belong to this Card. Yellow starter walk-in, demo and link battles retain native handling. An installed standalone ascendant_battle_heroes owns presentation instead, preventing duplicate animation.

The independent registry can retire and reactivate this Card without retiring battle ownership. Installed thin adapters remain pass-through while retired, draining pending animation callbacks. This is Gen1 support using Johto animation timelines, not a Gen2 renderer implementation.

Trainer atlas bounds are prepared in `integrated/battle_heroes/data/atlas_bounds.lua`. Regenerate them with `python3 tools/generate_hero_atlas_bounds.py` (Pillow) after changing bundled character sheets. HeroAtlas verifies the SHA-256 of the same PNG bytes uploaded to the GPU, plus atlas dimensions and grid, before using these bounds. All camera directions are available without decoding/scanning another PNG mid-battle. Replaced art or a custom grid uses CharSprite's exact alpha scanner; authored clips use the shared cell-space union. The cache owns the image and its source bytes together until the presentation module is reloaded.
