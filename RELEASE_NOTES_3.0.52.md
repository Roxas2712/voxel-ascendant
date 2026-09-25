# VASC 3.0.52 — Terrarium zoom

Complete update based on 3.0.51, published as a regular Latest release for launcher updates. Recommended KASC pairing remains 6.7.27.

## Changes
- Zoom into or out of Terrarium battles while keeping the authored camera position, viewing direction and orientation. Only the field of view changes; optional idle rocking retains its existing behavior.
- On touch screens, spread two fingers to zoom in and pinch them together to zoom out. Start the gesture on the scene, away from the touch controls.
- On desktop, use the mouse wheel or Q/E. On a controller, click the right stick to zoom in or the left stick to zoom out.
- Keep the zoom through attacks, command menus and changes between the two Terrarium arrangements. Automatically remember the chosen zoom in a small per-playthrough profile and restore it in later battles and after restarting the game.
- Keep Terrarium zoom separate from the MAP/DISCS starting-distance setting and keep shadow framing synchronized with the optical zoom.
- Add the controls to the Terrarium menu help. Includes the Errors / Diagnostics support-log update from 3.0.51.

## Validation
Regression tests verify fixed camera position/direction, optical scaling, bounds, input routing, zoom lifetime, restart persistence, bounded storage writes, malformed profiles and isolation from other camera preferences. Existing Terrarium, lighting, camera-visibility and battle-view transaction tests passed. Native LÖVE/macOS testing covers Q/E, wheel, stick clicks, two-finger touch events, landscape/portrait layouts, both Terrarium arrangements and an attack. The isolated test host reports engine 0.3.2; no physical Android/iPhone test is claimed. See QA-REPORT.md.

## Install
Close the game, update through the launcher or import Voxel-Ascendant-3.0.52.zip, then restart. Existing saves and optional/custom artwork are preserved.
