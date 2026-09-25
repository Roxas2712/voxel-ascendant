# VASC 3.0.51 validation

2026-09-25. Complete package based on 3.0.50.

- Client regressions: KASC-only, VASC-only, combined sends, explicit confirmation with no errors, shared report ID, partial failures, cancel/cooldown/timeout, redaction, 500 KiB cap and marked 48 KiB older-engine fallback.
- Ticket validation and bounded proof work; controlled iOS bridge success and rate-limit responses.
- Existing error inbox, detail, menu ownership and support transition regressions; shared Gen-II menu language and start-menu checks.
- Eleven receiver tests: signed tickets, expiry/IP binding/forgery, global and per-IP limits, size and storage quotas, persistence failures and seven-day cleanup.
- Native macOS game: both reports delivered through public HTTPS and verified on the NAS, one merged root entry in both menus, device diagnostics accessible. Portrait and landscape rendering inspected.
- Packaging: compile every Lua file, ZIP CRC, byte-for-byte source comparison and regenerated embedded receipts where present. Public asset hashes and anonymous downloads verified after upload.

Limits: iOS bridge uses controlled responses; no physical iPhone/Android test, fresh native Crystal test or complete playthrough. No save-format changes. Abuse protection does not verify player accounts.
