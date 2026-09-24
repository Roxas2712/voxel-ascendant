# Mobile actor/grass occlusion: depth retention

The mobile scene used `{canvas, depth=true}`. Actor rig/blink textures can be painted into another Canvas inside the scene's character pass, then restore the world target. A temporary depth attachment cannot carry earlier terrain/actor depth through that sequence on the newer renderer.

The source contract is visible in LOVE's [Graphics::setRenderTargets](https://github.com/love2d/love/blob/main/src/modules/graphics/Graphics.cpp) (temporary depth/stencil reset on bind) and [Metal Graphics::endPass](https://github.com/love2d/love/blob/main/src/modules/graphics/metal/Graphics.mm) (internal depth store discarded). LOVE 11/OpenGL may retain it, which makes a desktop-only test insufficient.

Mobile Voxel3D now owns a non-readable depth attachment alongside each scene color canvas. Both have `dpiscale=1`, matching dimensions and lifetime. It stays separate from the optional sampled depth used by desktop reflections. Allocation/binding failure is diagnosed before falling back to the internal buffer.

Validation: `tests/mobile_depth_attachment_test.lua` covers the production allocator, format fallback, resize/DPI, desktop behavior and diagnosed allocation failure. The private full-game GPU driver tests a real scene attachment across nested canvas draws, with the LOVE 12 temporary reset explicitly modeled on LOVE 11 for the failing control. This confirms the retention fix, not disappearance of the reported rectangle on physical iPhone hardware. Physical iPhone confirmation remains required.
