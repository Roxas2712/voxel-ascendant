# VASC content presets and injector

The current Voxel Ascendant source contract pins VASC Content Selector 0.5.0,
but the checked-in platform-artifact contract is still
`PENDING_EXTERNAL_BUILD`. A reviewed Universal macOS private-QA build exists;
the required signed Windows x86_64 EXE and Linux x86_64 executable do not yet
have accepted receipts in this tree. Portable Python remains a developer and
diagnostic fallback only. It is never substituted for a missing native
player artifact, and this source tree must not claim a complete one-click
platform delivery while the contract is pending.

## One-click platform delivery gate

Windows and Linux binaries cannot be cross-built honestly on the macOS RC
host. The selector's `Build desktop apps` workflow therefore performs these
native external steps from the same pinned 0.5.0 source:

1. Windows runs `scripts/build-windows.ps1`, executes the frozen EXE with
   `--artifact-self-test`, requires the canonical receipt, then Authenticode-
   signs and hashes the final EXE.
2. Ubuntu 22.04 runs `scripts/build-linux.sh`, executes the frozen ELF with the
   same headless self-test, then hashes the renamed x86_64 artifact.
3. macOS rebuilds the Universal 2 app from the same frozen source and repeats
   the native preset cross-contract, architecture, self-test and code-signing
   gates. A distribution candidate additionally needs the configured
   Developer ID/notarization receipt; the current private-QA build is ad-hoc
   signed and is not a notarized player release.

The RC maintainer downloads the Windows/Linux workflow artifacts, reviews
their checksums and self-test receipts, and records their exact bytes in
`SELECTOR_PLATFORM_ARTIFACTS_CONTRACT.json`. The RC bundler then requires all
four input files through `--windows-artifact`, `--windows-self-test`,
`--linux-artifact`, and `--linux-self-test`. It verifies the source-ledger and
build-recipe hashes, exact artifact/receipt sizes and SHA-256, PE32+ x86_64 GUI
headers plus an Authenticode certificate, ELF64 x86_64 headers, and canonical
0.5.0 self-test receipts before writing any delivery bundle.

The checked-in contract is deliberately `PENDING_EXTERNAL_BUILD` until those
real native bytes exist. That status is a release blocker, not permission to
ship portable Python under Windows/Linux labels. After a reviewed contract is
installed, the accepted player paths will be `Injector/Windows/VASC Content
Selector.exe`, `Injector/Linux/VASC Content Selector`, and the reviewed native
macOS app; exact receipts remain under `Injector/Receipts`.

## Discovery

The selector searches the platform's standard Gen1Recomp/LÖVE mod locations.
It prefers the current `VOXEL_ASCENDANT` package and can migrate an existing
`VASC4J` location. When Kanto Ascendant is installed alongside VASC, the
selector indexes its file-backed character sprites and music automatically.
ROM/ChipAsm music remains labelled as an in-engine original because it has no
external file that can be imported.

## Scope and inheritance

Named presets use the version-2 active-pointer contract and may target:

- the installation default;
- all Generation 1 games;
- all Generation 2 games; or
- one concrete game.

A narrower scope may inherit its parent selection or copy it into a new named
preset before editing. Resolution is deterministic: game, generation, then
default. The VASC menu exposes `CONTENT SOURCE`, `PRESET & SCOPE`, and a direct
`RESTORE VASC DEFAULT` action.

## Route-scoped ARENA battle backgrounds

A preset may also contain the optional `vasc-battle-backgrounds/v1` contract.
It can add or replace only the `ARENA_BACKDROP` surface and must name one
generation, game and route/map per rule. Battle kind, trainer and one concrete
battle may narrow that rule further. `MAP`, `DISCS` and `DEFAULT/2D` never
consume this surface.

Several images may form one explicitly scoped pool. `deterministic-shuffle`
chooses exactly once from that pool when the battle starts, keeps the choice
through every Pokémon switch and chooses again only for the next battle. It is
not a global randomizer: another route, map or battle without a matching rule
continues to use the existing VASC/authored fallback. `add` applies only where
no authored ARENA painting exists; `replace` applies only where one exists.

The Selector plan and VASC runtime both verify the canonical plan digest,
asset size and SHA-256. Accepted PNG dimensions are 640×400, 1280×800,
1920×1200, 2560×1600 and 3840×2400; one background is limited to 32 MiB.
Invalid content never changes the selected battle architecture.

## Engine-side verification and fallback

The selector does not grant trust to imported content. VASC reads
`active.json` and its referenced manifest with fixed byte limits, rejects
unsafe paths and malformed JSON, and verifies the declared size and SHA-256 of
every selected asset before use. The generated manifest hash is checked by the
engine as well as by the selector.

CUSTOM is atomic. If its pointer reference is structurally valid but its
manifest or any asset is absent, invalid or no longer matches its receipt,
VASC uses the base declared by that CUSTOM selection:

- `base_profile=retro` tries one complete public RETRO provider and then the
  packaged VASC DEFAULT if that provider is absent, colliding or not ready;
- `base_profile=vasc-default` goes directly to packaged VASC DEFAULT.

An explicit `mode=VASC_DEFAULT` selection terminates scope resolution and does
not opportunistically visit RETRO. A malformed pointer cannot select RETRO at
all. If `active.json` is absent, the normal/default request remains on VASC
DEFAULT; only a previously saved CUSTOM request keeps the historical RC8 loose
sprite/music folders as a migration bridge. This legacy path is deliberately
distinct from a rejected preset generation.

The same rules apply after v2 chooses game, generation and then default scope;
they are byte-identical in the Gen-1 and Gen-2 runtimes. A structurally valid
v1 pointer remains migration input and is normalized to its default-scope
selection before the same validator runs. Restoring the default removes only
the active custom selection; named presets remain available for later reuse.

## Forward compatibility

Desktop RC10 is the reference implementation. No Android or iOS importer ships
in this RC. Future mobile clients should write the identical bounded
pointer/manifest contract into their platform user-content directory; they
must not invent a different mobile schema.
