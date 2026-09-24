# Voxel Ascendant 3.0.40 — Public Test Update

Complete installable update, published as a regular GitHub release so the launcher updater can detect it. Testing status is described here; the GitHub prerelease flag is not used. Recommended pairing: KASC 6.7.22.

## Changes since 3.0.39
- Added an Errors submenu with readable, screenshot-friendly reports, report IDs, pagination and touch navigation. Repeated reports are grouped. Reports stay local and session-only; nothing is automatically sent.
- Graphics-check incidents are distinguished from normal gameplay. Battle diagnostics now record the requested Pokémon style, actual model readiness and missing model/texture failures to help investigate Cobblemon fallbacks.
- Download introductions and Your Look setup invitations now appear once per installation. Both remain available manually in the Ascendant menus. Normal updates and new saves do not repeatedly reopen them. Separate maintainer-controlled revisions allow a deliberate future re-invitation.
- Replaced the player-centred local-light selection with a spatial light grid, allowing authored lights across the visible scene to remain active while the player moves. Dense overlapping lights still use a bounded per-cell budget. This does not change fog or authored Card settings.
- Corrected a mobile depth-buffer lifetime defect: nested character texture draws now retain the world depth attachment instead of relying on temporary depth storage. This targets incorrect character/grass occlusion on newer mobile renderers.
- Corrected the setup water-effect wrapper to preserve both return values.

## Validation and remaining mobile checks
Automated checks cover Errors deduplication, startup persistence and re-invitation, depth allocation/resize/fallback, shader linking and packaged asset integrity. Native desktop runs cover menus and battle models; mobile-policy simulations do not substitute for physical phones. See QA-REPORT.md for the final package checks.

The exact iPhone rectangle around the player and the reported iPhone Cobblemon battle failure still require physical-device confirmation. Android flicker, city-banner artifacts and texture popping also need confirmation on the updated package. These reports are not claimed as conclusively fixed. No general smartphone performance guarantee is made.

## Installation
Close the game and import the complete ZIP as an update to VOXEL_ASCENDANT through your launcher. Restart after updating. Keep your existing saves and optional artwork. No engine, ROM or player save is included. For reports, include version, device and an Errors screenshot; attach the session log for deeper investigation.
