# Startup introductions: release-owner control

Download introduction and Your Look setup are each automatically displayed once per installation. Showing the screen consumes that invitation, including closing it, keeping settings or saving a draft. Both remain accessible through the Ascendant menu. Setup drafts remain save-specific, while the automatic-display receipt is installation-specific. Download removal/repair does not remove these receipts.

Ordinary package versions, guide schema versions, incomplete downloads, new saves and adding KASC do not reissue the introduction.

Only at the maintainer's explicit request, increase the corresponding integer in `lib/StartupPrompts.lua`:

- `REVISIONS.downloads`: reissue the download introduction once.
- `REVISIONS.setup`: reissue the setup guide once.
- Increase both to reissue both, in download-then-setup order.

Keep this module identical in VASC and KASC packages. Do not automatically increment these counters during release builds. Never reset or delete a user's receipt to announce an update. Higher stored revisions also suppress older releases after a downgrade.

The initial migration respects the existing download opt-out and any existing setup receipt, including a draft. A later explicitly incremented revision can invite those users again. Older versions did not persist every download dismissal, so an unrecorded dismissal may receive one final introduction after migrating.

Receipts are installation cache keys `sprite-content/startup-seen-downloads-v1` and `sprite-content/startup-seen-setup-v1`, shared by VASC and standalone KASC. No account-wide sync is implied. If the persistence backend fails, the current process still suppresses repeats and records a warning; restart persistence cannot be guaranteed until storage works.
