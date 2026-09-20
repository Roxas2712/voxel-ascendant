# VASC 3.0.35 — Steam Deck hotfix

- Recognize Steam Deck Vangogh and AMD Custom GPU 0405/0932 renderer names on Linux/Windows; generic AMD GPUs and screen resolution alone are not classified as Deck.
- AUTO uses BALANCED on recognized Deck hardware, including the shared host AUTO detector. Explicit graphics tiers and CUSTOM settings remain available.
- Gen1 Deck AUTO keeps native 1280×800 rendering on the built-in panel with a 1080p cap for larger displays and no automatic supersampling.
- Gen1/Gen2 world lighting uses a four-light budget; battles use two lights and terrariums two local lamps. HD sprite selections and desktop graphics APIs remain intact.
- Bounded menu glyph cache reduces repeated text allocations, with font reload and live-value handling preserved.

Works with KASC 6.7.17; no KASC data update is required. Select AUTO to use hardware defaults if you previously chose HIGH or CUSTOM manually.

Validation: device/profile and negative-control tests, Gen1/Gen2 lighting/fallback checks, support menus and cache regression tests. Physical Steam Deck FPS and complete elimination of reported stalls are not yet verified.
