# Optional Pokémon HD content — neutral-host RC

## Release gate

The withdrawn R65b endpoint is not used. The download source is now
`https://vasc-downloads.ascendant-content.workers.dev`, which serves the files
directly without an account, a browser login or a private-NAS redirect.
Do not bypass TLS checks or reuse an old endpoint.

VASC uses the game's existing download API; no new game/mobile app build is
required. If that API is missing in a particular game build, downloads report
unavailable instead of pretending to succeed. Real public downloads and shared
cache use have been tested on desktop in both game generations. The mobile API
contract is tested with native I/O doubles; a physical phone test is still due.
The one-time startup offer has also been tested with the real public catalog.
The notice waits for the start menu or a settled idle world, not combat, story
or movement. Later/B remembers the offered revisions in the shared profile.
Choosing downloads opens package selection; it does not itself download files.

## Alternative download source

If the main source fails, VASC retries the failed content request once through
an alternative HTTPS source and uses that source for the rest of the session.
The menu only displays “Using alternative download source.” All checksums and
package checks remain required; Cancel retains verified chunks for resumption.
This additional hostname can help with restrictions affecting the main hostname,
but both hosting routes use Cloudflare and are not independent outage protection.

## Installation and use

1. Install this VASC ZIP; disable standalone APO to avoid duplicate providers.
2. Open VASC → Pokémon + Models → Pokémon HD Downloads.
3. Choose Check for Updates, then a generation or a 20-species stage.
4. Check the displayed size. Press A a second time to approve the download.
   Use Wi-Fi if needed: the mod does not detect metered cellular connections.
5. Keep the download page open. Cancel keeps verified parts for resumption.
6. After verification finishes, restart the game to activate the new content.

No new Pokémon HD PNGs are included in this ZIP. An existing verified VASC
content cache is reused; upgrading the mod never deletes a previous download.
For a genuinely empty test use a separate game profile/device without that
cache. Do not delete your saves to test this.

## Shared between game generations

Within the same application installation/profile, Gen1 and Gen2 share the VASC
HD content cache. A downloaded Kanto stage can therefore be used by either game
generation without storing or downloading a second copy. The generation labels
in the download menu describe the Pokémon collection, not an exclusive target
game. Only supported, installed species gain HD; switching games does not create
missing Johto or other assets. Restart after installing new content to activate it.

Separate application sandboxes, devices, or deliberately separate profiles do
not automatically share this cache. The shared disk cache also does not mean
all downloaded Pokémon are loaded into RAM at once.

Without installed content the Pokémon HD controls in VASC are greyed out.
Human HD characters/actions remain included for both generations. Missing
Pokémon use the available MMO/original fallback; compatible Stadium 2 choices
remain available independently. After a partial download only installed species
gain HD; enabling HD does not invent missing assets.

Currently published: eight Kanto stages, 151 species / 304 variants, about
448 MiB of PNG data. Other generations are unavailable until published and
admitted by the renderer. This RC uses the frozen APO RC32 species registry:
new species/registry changes still require a matching VASC runtime update.

Downloads are explicit and checksum-verified. Separate anonymous start and
completion receipts count transfers, not unique people or devices. Interrupted
or corrupt packages never count as verified completion. No user identifier is
sent by the mod; ordinary network infrastructure can still see connection IPs.

The mod verifies each chunk and complete package before activation. On existing
game builds, the native download API may buffer a response before the mod can
check its size; VASC does not claim to impose a native streaming memory limit.
Payloads are split into chunks of at most 4 MiB at the approved source. Download
storage is separate from the renderer's bounded, on-demand graphics caches.

## Rollback

Reinstall the preceding VASC ZIP to roll back the runtime. Pokémon downloads
are separate from saves and bundled human assets. Keep the optional cache:
there is no need to remove it for a runtime rollback.
