# VASC — HD Download Fallback

When the main HD content source fails, VASC now retries through an additional HTTPS hosting address. Interrupted downloads retain verified chunks; checksums and package verification remain required. The in-game help shows only “Alternative download source”. Both hosting routes use Cloudflare, so this can help with hostname-specific restrictions but is not independent Cloudflare outage protection.

Download **Voxel-Ascendant-RC66g-Download-Fallback.zip**. Internal version: **3.0.0-rc.15.1**. Based on public RC66g, with only the downloader, download-menu wording, HD guide, manifest and runtime receipt updated.

**KASC users:** install [KASC 6.7.0-rc.5](https://github.com/Roxas2712/kanto-ascendant/releases/tag/v6.7.0-rc.5), which explicitly admits this VASC build. Older KASC versions may reject it. [KASC Cards 1.3.0-rc.5](https://github.com/Roxas2712/kasc-cards/releases/tag/v1.3.0-rc.5) pin the matching pair. Do not downgrade an existing newer save branch to bypass a version lock.

Validation: all eight hosted packages / 912 files / 470411456 bytes checksum-verified through 921 anonymous HTTPS reads. Real desktop Net/Fetch/HostShell transport tests cover unavailable primary, fallback, legacy download, cancellation/resume, activation/restoration and a bounded HTTPS blob. Five focused regression suites pass. No Brazil, physical-phone or exhaustive whole-game certification is claimed. Other RC66g known limitations remain.

Close the game, replace VASC, update the matching KASC/Card if used, then restart. Keep saves and downloaded content. Previous releases remain available for rollback.
