# VASC 3.0.28-rc.1 — local hotfix candidate

- One-time options upgrade enables Natural human animation, dialogue poses and HD people, with the actor grid off. Later player changes remain authoritative. Shared implementation for Gen1/Gen2 and desktop/mobile.
- Lossless PNG recompression: decoded pixels, dimensions and all non-IDAT PNG chunks are unchanged. Assets referenced by runtime content hashes retain their original bytes.
- 46 byte-identical battle character sheets reuse the bundled overworld images. Precomputed atlas bounds keep their original content hashes.
- No JPEG conversion, reduced resolution, removed scenery, reduced audio quality or deleted geometry cache.

Not published. Physical iPhone validation remains outstanding.
