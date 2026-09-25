# Errors / Diagnostics support reports

Open Errors / Diagnostics (Fehler / Diagnose) and choose Send logs. This works
with an empty error list. Confirm once to send the loaded KASC and/or VASC
reports. Both reports share one automatically generated report ID; give that ID
to the maintainer with a description or screenshot of the issue. Each mod shows
its own delivery result. No save file is attached and nothing uploads on opening.

The previous separate Diagnostics root entry is merged into this screen.
Device diagnostics remains available there (START); SELECT opens Send logs.
Touch buttons provide the same actions. The old per-mod send entry points lead
to the same combined screen. Both updated mods are required for combined sending.

Reports contain bounded, redacted session evidence, available error receipts,
download diagnostics and runtime context. The client allows 500 KiB per mod;
older engines that reject that size locally fall back to a marked 48 KiB excerpt.
The receiver rejects bodies above 512 KiB. No uncertain network upload is
retried automatically. KASC and VASC upload sequentially to avoid temporary-file
collisions in older engine POST workers.

A manual send first obtains a server-signed ticket, valid for 120 seconds and
bound to the report ID and source IP. The client solves an 14-bit SHA-256 proof
in small frame-budgeted batches. Invalid, expired, or forged tickets are rejected.
This is automated abuse protection, not verified player-account authentication.
No account login or manually issued code is required for updated clients.

Receiver limits: five tickets per minute globally; one new send operation per
IP per 60 seconds, allowing both mod reports for the same ID. It additionally
limits request size, concurrent connections, admission attempts, retained bytes
(128 MiB) and report count (2,000). Only the configured Synology proxy's overwritten
X-Real-IP is trusted. IP rate keys are salted hashes held in memory.

Retention is seven days. A daily cleanup removes expired matching report files
and writes a private summary of deleted/retained counts and bytes. It does not
remove the private signing key or unrelated files. Legacy clients retain their
server-issued support-code authorization path.
