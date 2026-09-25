# VASC 3.0.51 — Errors / Diagnostics and support logs

Complete update based on 3.0.50, published as a regular Latest release for launcher updates. Recommended pairing: KASC 6.7.27. Update both installed mods for combined log sending.

## Changes
- Merge Errors and Diagnostics into one **Errors / Diagnostics** entry (**Fehler / Diagnose** in German). Device diagnostics remains available inside it.
- Send support logs even when the error list is empty. After one confirmation, the installed KASC and/or VASC reports are sent with a shared, automatic report ID and separate delivery results.
- Remove the manual support-code requirement for updated clients. Short-lived server-signed tickets and a small, frame-budgeted verification step authorize each send.
- Allow up to 500 KiB per mod, with a marked 48 KiB excerpt only when an older engine rejects the larger request locally. Uploads run sequentially to avoid older engine temporary-file collisions.
- Nothing uploads merely by opening the menu. Reports contain redacted diagnostic evidence; no save file is attached. Share the report ID with the maintainer when describing the problem.

## Receiver limits and retention
The receiver allows five new tickets per minute globally and one new send per IP every 60 seconds; the same operation can contain both mod reports. It enforces a 512 KiB request limit, storage quotas, ticket expiry and daily cleanup of reports older than seven days. Tickets provide automated abuse protection, not verified player-account authentication.

## Validation
Client and menu regressions passed, including empty-error confirmation, single/combined sending, partial failure, cancellation, timeout, size fallback and controlled iOS bridge responses. Eleven receiver tests passed. Native macOS game testing successfully sent both reports to the live HTTPS receiver and checked the merged menus and device diagnostics. Portrait and landscape layouts were inspected. No physical iPhone/Android or fresh native Crystal test is claimed.

## Install
Close the game, update through the launcher or import Voxel-Ascendant-3.0.51.zip, then restart. Existing saves and optional/custom artwork are preserved. See SUPPORT_REPORTS.md and QA-REPORT.md for details.
