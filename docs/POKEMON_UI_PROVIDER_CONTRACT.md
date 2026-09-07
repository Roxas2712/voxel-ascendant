# Pokémon UI Provider/Host contract v1

Voxel Ascendant exposes an autonomous, public presentation contract for three
box-like Pokémon surfaces:

- `pc_box`: the standard Game PC storage screen;
- `legacy_bank`: a companion-owned Legacy Bank;
- `battle_party`: the voluntary or forced-switch party picker.

VASC does not own storage or battle rules through this API. A **host** owns an
immutable model and every authoritative action. A **provider** owns complete
drawing and exclusive input for a negotiated session. A provider is listed or
selectable only when it intersects an active compatible host on the same
surface.

This contract does not own the battle HUD. `battleHudStyle=oras`, ORAS
HP/status cards, battle commands, party-ball receipts, and camera behavior are
independent from `pokemonUiBattleParty`. Selecting ASC BOX for `battle_party`
therefore changes only the team picker, including forced switch; it never
changes ORAS GLASS battle HUD ownership.

## Public API and schemas

The export is `voxelAscendantMod.exports.pokemonUi`:

```lua
{
  providerSchema = "voxel-ascendant/pokemon-ui-provider/v1",
  hostSchema = "voxel-ascendant/pokemon-ui-host/v1",
  sessionSchema = "voxel-ascendant/pokemon-ui-session/v1",
  modelSchema = "voxel-ascendant/pokemon-ui-model/v1",
  actionSchema = "voxel-ascendant/pokemon-ui-action/v1",
  actionResultSchema = "voxel-ascendant/pokemon-ui-action-result/v1",
  eventSchema = "voxel-ascendant/pokemon-ui-event/v1",
  apiVersion = 1,
  controllerGeneration = 1,
  hostGeneration = 1,
  capabilityDigestSchema = "pokemon-ui-capabilities/v1",
  transactionalDraw = "disposable_layer_commit_after_true",
  inputOwnership = "exclusive_after_accept",
  inputKeys = { "up", "down", "left", "right", "a", "b",
    "start", "select", "page_prev", "page_next" },
  viewportBounds = { maxDimension=2048, maxPixels=2097152 },
  requirements = { pc_box=..., legacy_bank=..., battle_party=... },
  register = function(providerReceipt) ... end,
  registerHost = function(hostReceipt) ... end,
  listHosts = function(surface) ... end,
  list = function(surface, optionalHostHandle) ... end,
  resolve = function(surface, optionalHostHandle) ... end,
  begin = function(hostHandle, request) ... end,
}
```

`schema` remains an alias for `providerSchema` for v1 consumers.

VASC never imports KASC or a private host module. A companion discovers this
public export through the normal mod-export mechanism. VASC registers its own
native Gen-I PC and battle-party hosts at their real screen-opening seams;
Legacy Bank remains companion-owned. A live external PC host wins at each
actual open, so load order cannot create two controllers.

## Options and live intersection

| Option key | Saved default | Scope |
| --- | --- | --- |
| `pokemonUiSkin` | `asc_box` | global preferred provider |
| `pokemonUiPcBox` | `follow_global` | standard PC override |
| `pokemonUiLegacyBank` | `follow_global` | Legacy Bank override |
| `pokemonUiBattleParty` | `asc_box` | battle party override |

Known provider IDs are `asc_box`, `oras_glass`, `game_default`, and
`kasc_frlg`. The PC and Legacy-Bank overrides additionally support
`follow_global`; their requested saved ID is retained when temporarily
unavailable, while dead rungs stay hidden and resolution returns
`game_default` without rewriting that intent. `pokemonUiBattleParty` is a
deliberately closed three-state selector: `asc_box`, `oras_glass`, or
`game_default`. Old `follow_global` values and foreign battle-party provider
IDs migrate to `asc_box`, so no hidden fourth state can survive in that row.

VASC registers `asc_box` for PC, Legacy Bank and battle party. Its native
Gen-I host makes PC and battle party available standalone; Legacy appears only
when a compatible external host is live. VASC also registers `oras_glass` as a
separate battle-party-only provider. It never creates dead PC/Legacy rows and
does not read or change the independently selected ORAS battle HUD.

Neither provider-only nor host-only registration advertises a skin. `list`
and `resolve` use the intersection of surface, controller generation, schema
set, logical viewport, selection mode, modes, actions and events. An opaque
host handle can narrow resolution to the exact host that is about to open a
screen.

## Surface capabilities

All registered lists include the complete baseline for their surface. A host
may negotiate a provider-supported superset, but begin binds the host's exact
sorted lists.

### `pc_box`

- selection: `single`
- modes: `browse_box`, `browse_party`, `action_menu`, `confirmation`, `message`
- actions: `navigate`, `inspect`, `dex_entry`, `move`, `withdraw`, `deposit`,
  `release`, `change_box`, `print_box`, `cancel`
- events: `opened`, `model_changed`, `focus_changed`, `box_changed`,
  `action_result`, `transfer_result`, `warning`, `closed`

### `legacy_bank`

- selection: `multi_cross_box`
- modes: `browse_legacy`, `browse_party`, `action_menu`, `message`
- actions: `navigate`, `inspect`, `dex_entry`, `withdraw`, `deposit`, `move`,
  `multi_select`, `cross_box_select`, `transfer_selected_to_pc`,
  `transfer_all_to_pc`, `cancel`
- events: `opened`, `model_changed`, `focus_changed`, `selection_changed`,
  `box_changed`, `action_result`, `transfer_result`, `capacity_warning`,
  `warning`, `closed`

Transfer and Dex behavior remain authoritative host operations. The provider
can request them and display the result; it cannot edit either backend.
`move` always carries one opaque source and one destination in a single
revision-bound dispatch; merely lifting or cancelling never commits anything.
On Legacy Bank, `move` is bank-to-bank. Party focus uses the separate
host-authorized `deposit` action, while bank focus uses `withdraw`; providers
must not reinterpret a Party entry as a bank move source.

### `battle_party`

- selection: `single`
- modes: `browse_party`, `summary`, `message`
- actions: `navigate`, `inspect`, `select`, `cancel`
- events: `opened`, `model_changed`, `focus_changed`, `action_result`,
  `selection_rejected`, `forced_switch`, `warning`, `closed`

`cancel` remains negotiated during forced switch and is disabled through the
model. That preserves one complete controller instead of mixing UI fragments.

## Provider receipt

Every provider surface supplies all four schemas, modes and complete claims:

```lua
local unregister, reason = api.register({
  schema = api.providerSchema,
  apiVersion = 1,
  id = "kasc_frlg",
  owner = "kanto-ascendant",
  label = "KASC FRLG",
  surfaces = {
    legacy_bank = {
      controllerGeneration = 1,
      viewport = { width=512, height=288 },
      schemas = {
        model=api.modelSchema, action=api.actionSchema,
        actionResult=api.actionResultSchema, event=api.eventSchema,
      },
      modes = api.requirements.legacy_bank.modes,
      actions = api.requirements.legacy_bank.actions,
      events = api.requirements.legacy_bank.events,
      claims = {
        draw="complete", input="complete", commit="atomic",
        selection="multi_cross_box",
      },
      create = function(ctx) return completeController end,
    },
  },
})
```

Registration can coexist with a future/unknown schema receipt for diagnostics,
but such a surface never intersects this v1 manager.

## Host receipt and opaque handle

The backend registers independently:

```lua
local handle, reason = api.registerHost({
  schema = api.hostSchema,
  apiVersion = 1,
  id = "kanto_ascendant_storage_gen1",
  owner = "kanto-ascendant",
  hostGeneration = 1,
  surfaces = {
    pc_box = {
      controllerGeneration = 1,
      viewports = {
        { width=480, height=360 },
        { width=512, height=288 },
      },
      schemas = {
        model=api.modelSchema, action=api.actionSchema,
        actionResult=api.actionResultSchema, event=api.eventSchema,
      },
      modes = api.requirements.pc_box.modes,
      actions = api.requirements.pc_box.actions,
      events = api.requirements.pc_box.events,
      claims = {
        model="immutable_snapshot", actions="authoritative",
        input="exclusive", commit="atomic",
        fallback="whole_surface_next_frame", selection="single",
      },
    },
  },
})
```

The returned table is an opaque identity token with `handle:begin(request)`,
`handle:resolve(surface)`, `handle:list(surface)`, and
`handle:unregister()`. An unbound `api.begin(request)`, a copied receipt, or a
handle after unregister is rejected. Host unregister and provider unregister
revoke all matching live sessions and retained dispatch closures.

Each provider surface declares exactly one bounded logical `viewport`. Each
host surface declares a duplicate-free list of exact `viewports` it can
allocate and present without clipping. A provider intersects that host only
when its exact `{width,height}` pair is present. The host must use the
negotiated value returned by `resolve(...).viewport` or, authoritatively after
`begin`, `receipt.viewport`; selecting dimensions by provider ID is forbidden.

## Immutable model v1

Every opening, event and non-closed action result carries a complete snapshot:

```lua
{
  schema=api.modelSchema, apiVersion=1,
  host="kanto_ascendant_storage_gen1", hostGeneration=1,
  surface="pc_box", session="slot-1:pc:42", revision=0,
  locale="de", edition="red", mode="browse_box",
  title="BOX 1", help="A: ACTION  B: BACK", message=nil,
  focus={ zone="box:1", box=1, slot=1, id="box:1:1" },
  selection={ kind="single", ids={}, revision=0 },
  zones={
    ["box:1"]={ label="BOX 1", index=1, count=1, capacity=20,
      entries={
        { id="box:1:1", zone="box:1", box=1, slot=1,
          pokemon={ species=25, gender="female", shiny=false,
            nickname="PIKACHU", level=24, hp=52, maxHp=60,
            attack=43, defense=31, speed=55, special=40,
            art={ kind="pokemon", species=25, gender="female" } },
          enabled=true, selected=false, tags={"party-eligible"} },
      } },
    party={ label="PARTY", count=3, capacity=6, entries={} },
  },
  availability={
    navigate={enabled=true}, inspect={enabled=true}, dex_entry={enabled=true},
    move={enabled=true},
    withdraw={enabled=true}, deposit={enabled=true},
    release={enabled=true, confirmationRequired=true},
    change_box={enabled=true}, print_box={enabled=false, code="no-printer"},
    cancel={enabled=true},
  },
  surfaceData={ currentBox=1, boxCount=12, boxCapacity=20,
    partyCapacity=6, canPrint=false },
}
```

Required root fields are the version/binding fields, `mode`, `focus`,
`selection`, `zones`, exact per-action `availability`, and `surfaceData`.
`surfaceData` is deliberately small:

- PC: `title`, `currentBox`, `boxCount`, `boxCapacity`, `partyCapacity`,
  `canPrint`;
- Legacy: `title`, `currentBox`, `boxCount`, `boxCapacity`, `partyCapacity`,
  `selectedCount`, `moveSource`;
- battle party: `title`, `forcedSwitch`, `canCancel`, `reason`.

`pokemon` and optional `art` are resolver-neutral descriptors. Allowed
Pokémon fields are `species`, `form`, `gender`, `shiny`, `egg`, `nickname`,
`level`, `hp`, `maxHp`, optional calculated `attack`, `defense`, `speed`,
`special`, `status`, `ability`, `item`, `palette`, `types`, `markings`, and
`art`. Art accepts only `kind="pokemon"`, `species`, `form`, `gender`,
`shiny`, `egg`, `variant`, and `palette`. `spritePath`, images, canvases,
userdata, functions, metatables, raw `mon`, Game/save/storage objects and
cyclic tables are forbidden. Providers resolve art from stable IDs themselves.
Absent optional stats remain absent; a provider must not reinterpret them as
real zero values or reach back into an authoritative save to fill them.

`entry.slot` is the visible provider seat, not a backend array index. A host
may keep dense authoritative arrays and map that visible seat through private,
namespaced metadata. The opaque entry ID is the only identity the provider
may carry across a Box page change. Eggs must be published as neutral
`species="EGG", egg=true` descriptors without future species, nickname,
shiny, moves, stats, Ability or item; `inspect` and `dex_entry` reject them.

The manager deep-copies bounded plain data. Its authoritative revision gate is
stored separately, so a provider mutating its own copy cannot change dispatch
validation.

## Opening and controller receipt

Only the registered handle can bind its callbacks:

```lua
local controller, receipt = handle:begin({
  surface="pc_box", session="slot-1:pc:42",
  controllerGeneration=1, atomicLayer=true,
  model=snapshot,
  actions={ -- exactly every action declared by this host surface
    navigate=function(actionEnvelope) ... end,
    -- ...
  },
  events=api.requirements.pc_box.events, -- exact host event set
})
```

The provider receives `ctx.model`, exact `ctx.modes/actions/events`, the host
and provider identities, schemas, and `ctx.dispatch`. Dispatch remains closed
during construction. It opens only after this complete receipt validates:

```lua
controller.receipt = {
  schema=api.sessionSchema, apiVersion=1,
  owner=ctx.owner, provider=ctx.provider,
  host=ctx.host, hostOwner=ctx.hostOwner,
  hostGeneration=ctx.hostGeneration,
  surface=ctx.surface, session=ctx.session,
  controllerGeneration=1, schemas=ctx.schemas,
  capabilityDigest=ctx.capabilityDigest,
  viewport={ width=ctx.viewport.width, height=ctx.viewport.height },
  complete=true,
  claims={
    draw="complete", input="complete", commit="atomic",
    selection=ctx.selection, modes=ctx.modes,
    actions=ctx.actions, events=ctx.events,
  },
}
```

The deterministic capability digest binds the exact provider, host, surface,
schemas, provider viewport, host viewport set, selection, modes, actions and
events. It is a stale-receipt equality guard, not a cryptographic identity
proof.

The controller implements `draw`, `handleInput`, `onEvent`, `close`, and may
implement `update`. An accepted wrapper has `inputExclusive=true`. A
`handleInput` return of `false` means no UI state changed; the input remains
consumed and is never replayed into the native screen.

Hosts normalize engine input before calling the accepted controller. The exact
input envelope is bounded plain data:

```lua
controller:handleInput({
  pressed={ left=true, a=true },
})
```

The top level contains only `pressed`. That table is sparse and contains only
Boolean values under `up`, `down`, `left`, `right`, `a`, `b`, `start`,
`select`, `page_prev`, and `page_next`. It may be empty for an idle probe.
Raw Game input objects, methods, metatables, unknown buttons and non-Boolean
values are terminal contract violations; they never reach provider code.

## Actions and results

`ctx.dispatch(action, payload)` requires the provider to echo
`modelRevision=ctx.model.revision` from the immutable snapshot it actually
rendered. The manager deep-copies and verifies that revision first, then stamps
only the reserved host/session/action bindings:

```lua
{
  schema=api.actionSchema, apiVersion=1,
  host=..., hostGeneration=1, surface=..., session=...,
  action="withdraw", modelRevision=12, -- supplied and echoed by the provider
  target={ id="box:1:1", zone="box:1", box=1, slot=1 },
}
```

Reserved binding fields cannot be supplied by a provider. `modelRevision` is
mandatory on every payload; a missing or stale value revokes the session rather
than applying an action to a newer box state. The remaining payload fields are:

- `navigate`: `direction=up|down|left|right|page_prev|page_next`;
- `inspect`, `dex_entry`, `withdraw`, `deposit`, `release`, `select`:
  `target` location;
- `release`: optional `confirmationToken` from the preceding result;
- `change_box`, `cross_box_select`, `print_box`: positive `boxIndex`;
- `move`: `target` plus `destination={zone,box?,slot}`;
- `multi_select`: `target`, `selected=boolean`;
- `transfer_selected_to_pc`: `selectionRevision=modelRevision`;
- `transfer_all_to_pc`: `scope="withdrawable"`;
- `cancel`: optional `scope="prompt"|"surface"`.

Every callback returns exactly one versioned result, never an `(ok, payload)`
tuple:

```lua
{
  schema=api.actionResultSchema, apiVersion=1,
  host=..., hostGeneration=1, surface=..., session=...,
  action="withdraw", requestRevision=12,
  status="applied", code="withdrawn", model=revision13Snapshot,
  message={severity="info", text="POKéMON WITHDRAWN"},
}
```

Statuses are `applied`, `rejected`, `confirmation_required`, and `closed`.
`applied` advances revision. Rejected and confirmation results do not regress.
`closed` has no model. Confirmation requires
`confirmation={token,prompt,default="yes"|"no"}`; the provider resubmits the
action with that token after explicit input.

## Events, revocation and atomic draw

Host events use:

```lua
controller:onEvent("model_changed", {
  schema=api.eventSchema, apiVersion=1,
  host=..., hostGeneration=1, surface=..., session=...,
  type="model_changed", revision=13, model=revision13Snapshot,
})
```

Every non-closed event has a complete non-regressing model. `closed` has no
model and exactly the current revision. The manager revokes dispatch and the
session before invoking the provider's closed callback.

The host allocates the disposable canvas/layer at exactly
`receipt.viewport.width × receipt.viewport.height`, presents that same logical
size, and clips neither axis. It commits the layer only after
`controller:draw()` returns exactly `true`. An error or false return discards
the entire layer and retires the session; the next frame is a whole
native/host fallback, never a composite of visual fragments.

Constructor, receipt, model, action, result, event, draw, input and lifecycle
violations all fail closed at the provider boundary and fail open visually to
`game_default`. Retained dispatch is revoked on any terminal condition.
Cleanup is immediate outside provider callbacks and deferred only until the
current provider call unwinds, preventing both reentrant close and orphaned
controllers.
