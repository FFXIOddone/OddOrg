# OddOrg product direction

Storage layout starts from OddOrg's existing placement rules. Users customize
individual category destinations in My layout, with no required name or quickset.
An omitted base override inherits OddOrg placement; false explicitly leaves the
category where it is; a bag ID fixes its destination. Overrides live in the
optional version-1 `overrides` field and apply only when `active` is empty.
Existing named layouts retain their earlier unassigned-means-stay behavior.
The four 1.10 preset definitions remain only for existing saved active IDs and
are no longer offered as new choices. Choosing or applying layout changes never
enables global automation or grants new per-item deposit permission.

OddOrg is a focused utility for players managing one or several characters.
Its purpose is to preserve collecting capacity and remove recurring inventory
housekeeping without interfering with belongings the player intentionally carries.
Success means its absence is felt as inventory babysitting and missed collecting
opportunities, rather than success being measured by the number of features.

The intended experience is set once, keep playing: preserve usable Inventory
space, organize accessible Mog House storage and wardrobes, and deposit surplus
crystals and clusters at an Ephemeral Moogle. Deposits are the crystal feature's
boundary. No selling, discarding, travel, withdrawals, or cross-client control.

The product standard: open OddOrg and immediately understand what it will do,
what it leaves alone, and whether it needs anything from you, then forget it
exists. After setup, normal play should require no routine checking, repeated
commands, or reopening the window. Keep routine success and temporary waits
quiet. Interrupt only when the player needs to act, with a clear reason and
next step; do not repeat an unchanged notice. Useful status remains available
when the player chooses to look. Judge each change by the attention and manual
work it removes while preserving player intent.

Player intent takes precedence over making space. Per-character keep rules apply
to every move and deposit. An exhausted safe destination or a protected Inventory
requires an actionable notice, never overriding a protection. Names and categories
cannot establish a player's quest or crafting intentions.

## First upgrade: protected housekeeping

- Persist keep-all and keep-quantity rules per character using Ashita settings.
- Prefer reserving quantities already in Inventory; protect any remaining reserve
  in storage. This release does not automatically retrieve a missing reserve.
- Honor protections in organization planning, physical move validation, and every
  crystal batch. Stop queued work when rules or character settings change.
- Expose item protections and quantities in game, plus the existing crystal scopes.
- Revalidate and retain the selected Moogle throughout a deposit run. Gather
  stored surplus alongside carried surplus to fill up to eight trade slots;
  use smaller batches when Inventory room is limited. Require observed item
  changes before continuing and preserve quantities when retrieved stacks merge.
- Verify offline with representative inventories and inert transport replacements.
  Installed and in-game behavior require separate evidence through allowed routes.

## Second upgrade: keep collecting

- Enable background clearing once per character; keep five free Inventory slots
  by default, adjustable from 1 to 20.
- Crystals and clusters are eligible by default. Other items require explicit
  opt-in; an item can also be excluded. Keep rules always take precedence.
- Use only available portable Satchel, Sack, and Case capacity while idle. Move
  one whole unreserved stack at a time and confirm it before continuing.
- Hold item types manually retrieved through native bag controls for the session.
  Observe native outgoing move intent, not all inventory gains. Expose per-item
  release and persistent Keep rules for intentions that outlast the session.
- Explain low-space blockers without repeatedly announcing unchanged conditions.
  Incoming sorting finishing must not hide an unmet free-space target. Escalate
  the notice when Inventory becomes completely full; never override protections.
  An unconfirmed transfer pauses until the player resumes.
- Discover a nearby Ephemeral Moogle when an explicit deposit starts; preserve
  identity and zone across all batches without changing the player's selected
  target or requiring repeated targeting.

Native retrieval holds do not cover other addons' injected retrievals or survive
reload; saved Keep rules do.

## How to evaluate subsequent work

Start with the player's complete experience and the unwanted work that remains.
Choose the smallest coherent improvement supporting this promise. Include its
necessary connecting steps; defer unrelated feature growth. A focused utility may
need careful internals while keeping a small, understandable surface.

## Player flow: set up, close, keep playing

Version 1.5.1 implements the drafted setup, single Apply, saved-state summary,
adjacent Ignore controls, and quiet routine automatic deposits described here.
Offline interaction tests cover the connecting steps; the complete experience
still needs in-game verification. Existing character settings are preserved;
existing users are not forced through setup again.

Version 1.5.2 moves all work controls into Settings. The home view contains only
the character, current state, relevant activity or attention, and one Settings
entry. Settings separates Automatic care, Ignore items, and First Bulk Run.
First Bulk Run frames manual organization and deposits as initial cleanup that
can also be repeated deliberately. It is optional, not a prerequisite for normal
automation. Keep native layouts compact, clearly grouped, and scrollable; show
details where the player makes the relevant choice rather than on the home view.

Version 1.6.0 gives those pages a consistent native visual layout: navigation
stays separate from the selected settings, related controls are grouped, and
On/Off states use text as well as color. Quantity controls show their units and
limits. Unsaved changes and disabled actions must be visually distinct.
Native screenshots and player feedback, rather than offline tests alone,
determine whether the layout meets that standard.

Version 1.7.0 builds a recognizable visual identity around the same workflow:
original crystal artwork, layered surfaces, explicit switch states, and a stable
item browser beside the selected rule. The artwork is decorative; native text
and controls remain separate and functional if it cannot load. Visual effects
must not add routine notifications or run inventory work merely from opening a
page. Typography and control hit targets must remain readable at the game UI scale.

1. **Open and understand.** Present the outcome: keep usable Inventory space and
   deposit extra crystals during normal play. Identify the current character.
   Settings > First Bulk Run contains manual organization and crystal deposits.
   Home uses one identity header, a compact care-status row with a secondary
   Settings action, and muted activity detail. Avoid repeated branding/taglines
   competing with status. Preserve active work and recorded pause reasons.
2. **Choose what happens automatically.** In Settings > Automatic care, use outcome labels: keep a chosen
   number of Inventory slots free, store extra items as they arrive, and deposit
   extra crystals when passing an Ephemeral Moogle. Explain that only crystals
   and clusters are eligible by default; other items need explicit permission.
3. **Set item outcomes when useful.** In Settings > Item rules, show current
   locations and let the player choose a carried Inventory target, default or
   exact extra-item destination, and explicit crystal donation permission.
   Keep/Ignore quantities remain separate from maintained supply.
4. **Review once and start.** Summarize global switches and saved item outcomes,
   then offer clear Apply actions. Saving item rules never enables global
   automation. First setup performs no moves before the player enables a feature.
   The player can then close the window.
5. **Play normally.** Eligible loot is stored while ready; combat, crafting,
   loading, and zoning cause quiet waits. Near a Moogle, gather eligible carried
   and stored crystals before trading up to eight actual Inventory slots at a
   time. Continue while the same NPC remains in range. Leaving ends that visit's
   work; no targeting, window reopening, or repeated commands should be needed.
   Large deposits still require enough time nearby to complete the batches.
6. **Respect deliberate changes.** A confirmed native manual move holds only its
   moved quantity at its destination for the session. Show the temporary choice
   in Item rules, let the player release it, and shrink it as that stock is
   consumed. A saved Keep amount protects stock beyond the current session.
7. **Ask for help only when necessary, then return to quiet work.** An alert must
   name the blocked useful outcome, its cause, and the appropriate next action.
   Do not make the player decipher internal queue states or routinely press
   Resume after normal waits. Resume a confirmed resolved space shortage on the
   next safe check. Explicit Pause and uncertain transfers require deliberate
   resumption; never silently retry a transfer whose result is unknown.

When opened again, home should answer whether automatic care is on and whether
anything needs attention. Settings holds what is allowed or ignored and all
manual tools. Routine progress and success belong in the UI rather than chat.
A temporary wait is not an action request.

### Implementation status and remaining checks

- Main controls now name player outcomes and save together through Apply. The
  active summary is separate from draft edits. Saving an Item rule preserves
  the setup draft; a character or actual automatic-setting change resets it.
  Manual bag scopes and crystal collection sources have distinct labels.
- Automatic Moogle starts, empty visits, completion, and normal departure are
  quiet. Manual feedback and unconfirmed-transfer notices remain visible.
  An unchanged Apply does not interrupt work or rearm a claimed Moogle visit.
- Temporary manual overrides cover only the confirmed moved quantity at its
  current location, shrink as stock is consumed, and do not include later copies.
  Offer per-item release; use a saved Keep quantity for protection beyond the
  current session.
- A nearby-Moogle pass rearms after leaving range; standing beside it is not a
  continuous deposit trigger. Preserve protection against duplicate or uncertain
  trades when improving continuation.

Acceptance is an ordinary play session on each character with the window closed:
collect loot, retrieve crafting stock, zone or fight, and pass a Moogle. Approved
extras should move, ignored items should stay untouched, normal waits should
recover, and routine success should remain quiet. A genuine blocker should need
one understandable intervention, followed by normal unattended operation. This
requires player-observed evidence; source review alone cannot establish it.

## Item settings: show the result before applying

Use direct language attached to the selected item: Ignore all, Ignore an amount,
or Ignore none. Amounts are individual items, with a slider, exact entry, and
stack shortcuts. Show ignored and remaining quantities, where the ignored stock
stays, and what storing or Moogle deposits could use. Keep automatic permission
separate from the ignored amount, and save both through one Apply action.
Temporary pauses after manual retrieval remain separate. Existing reserve rules
still apply; this UI does not retrieve items to fill a reserve.

## Stable organization before automatic house visits

- Overflow placement prefers existing residents. Sorting must reach a stable
  result instead of exchanging equivalent stacks on repeated passes.
- While background clearing is enabled, stored items eligible for that clearing
  stay stored during organization. Deposits retain their explicit surplus rules.
- Verify a useful first plan followed by no further moves from the resulting
  inventory, including changed slot indices and wardrobe overflow.
- Version 1.5.1 gives the preview shared styling and a bounded scroll area.
  Existing saved window dimensions remain player-controlled; native sizing and
  readability still need player verification.

## Current workflow: follow normal play

The product owner's CatsEye clarification supersedes the 1.3 house-entry trigger.
Most bags and wardrobes are available outside the house. Requiring a special
visit creates avoidable work; only the restricted Storage bag needs that access.

- Sort approved Inventory arrivals while alive and idle, independent of the
  free-slot target. Respect the crystal defaults, explicit item opt-ins, Keep
  rules and retrieval holds. Move one whole unreserved stack at a time.
- Use category destinations and existing matching stack room. Leave stored items
  in place so each loot arrival cannot trigger a broad reorganization.
- Exclude Storage from unattended sorting and deposits. Manual organization
  retains full accessible-bag and wardrobe sorting, including Safe2 and Storage.
- Require loaded-container flags as well as a coherent scan. A quiet interval
  while bags download is not evidence that apparently empty slots are free.
- Offer separate nearby-Moogle deposit automation, triggered when the player
  passes within range. Retain NPC identity, source observations and protections;
  stop new actions on departure/activity change and attempt once per pass.
- Never change the player's target or movement. Keep UI closed during automatic
  work. Large crystal deposits require remaining nearby through their batches.
- Preserve manual controls, per-character preferences, and actionable stop
  reasons. The enabled 1.3 house preference migrates to incoming sorting.

These workflows still require player-observed in-game evidence. Offline tests
and installed hashes do not establish server acceptance, native UI quality, or
the Moogle's actual stored balance. Native UI sizing/style still needs checking.

## Shared storage quicksets (version 1.8.0, 2026-09-23)

The player's newer request expands the item-specific plan to saved category
layouts. Automatic care and First Bulk Run share one active per-character
quickset. Assigning a type permits automatic management; untouched quantities,
retrieval holds, equipped/locked items, and explicit item exclusions take priority.
Unassigned or unrecognized types stay in place in a custom layout. The named
OddOrg defaults option retains the prior behavior until the player chooses a set.

Store types by verified resource Type/Flags and equipment Slots, plus exact
crystal and cluster IDs. Do not label name guesses as crafting or medicine types.
Mixed resource groups are labeled as mixed. Only equipment can target wardrobes;
Storage is restricted to a bulk run with access. Full/unavailable destinations
wait or reject the bulk plan without silently selecting another bag.

Automatic care contains compact controls beside the quickset editor. Save & use
persists and activates the named set. First Bulk Run selects those same saved
sets; Preview groups projected item quantities by bag and type, including stock
that stays untouched. Run always rebuilds from current data. Draft layout cards
are destination rules, not a claim that a transfer has already been validated.
Offline cases cover shared routing, full/locked behavior, stable second plans,
saved-set isolation, UI editing, and partial-reserve preview totals. Native
appearance and the first real quickset moves still need player observation.

## Item rules: destinations and carried supply

Version 1.9.0 implements the source path for per-item outcomes, maintained
Inventory targets, exact temporary manual overrides, and a textured route preview.
Offline tests cover planner decisions, UI edits, persistence, refill, donation
protection, and override consumption. This is source/offline evidence; installation,
live bag access, server behavior, and native rendering remain unverified until a
player checks them in game. No withdrawal from a Moogle or item conversion is
implied.

## Native UI finish: textured controls and restrained motion

Version 1.9.2 carries the existing crystal, graphite, leather, brushed-metal,
and route-accent materials through the search field, numeric inputs, sliders,
checkboxes, selectors, buttons, and route cards. On pointer entry, the textured
surface and nested cyan edge ease into their final appearance, hold steady while
hovered, and soften on exit. Keyboard focus keeps a clear cyan outline; disabled
buttons stay subdued. Toggle knobs ease to their new state.

The change preserves native ImGui hit areas, text editing, selection, keyboard
navigation, and state. Offline renderer cases cover the entry/exit response,
steady hover appearance, and disabled styling. The complete animated appearance
still needs a player check in Ashita; the agent does not capture or drive FFXI
windows.

### Implemented player controls and behavior

- **Item rules** keeps Ignore all/amount/none and adds a carried Inventory target,
  an exact extra-item destination, and a separate crystal/cluster donation choice.
- A saved `default` destination follows the active quickset or existing defaults.
  `stay` leaves copies in their current bags. A specific compatible bag is exact;
  a full or unavailable bag does not fall back. Restricted Storage remains a
  manual bulk-run destination, and wardrobes are limited to compatible equipment.
- A specific item outcome can authorize its own movement only while the relevant
  character automation is enabled. It does not turn on a global switch. Items
  without a rule keep their existing quickset/default and permission behavior.
- With **Keep Inventory slots free** enabled, a carried target can refill its
  shortfall from eligible, unlocked accessible bags, preferring the saved exact
  destination. Keep quantities and temporary overrides take priority. The target
  stock remains protected from sorting and deposits; unavailable or missing stock
  stays pending rather than being fabricated or taken from restricted Storage.
- A crystal/cluster donation rule needs explicit permission and a specific staging
  bag. That bag is the only stored source for the rule; carried eligible surplus
  can also be deposited. Unattended Moogle deposits still require the separate
  character switch. Storage assignment alone never permits donation.
- The browser and editor preview current stock and location, carried target and
  refill need, extra-item route, blocked destination, and possible donation amount.
  Item drafts survive browsing, and Apply saves per-character outcomes without
  changing global automation.

### Temporary manual move semantics

Offline cases verify that a confirmed native manual bag move creates a temporary
quantity/location override for the exact moved amount. Addon-injected moves and
unconfirmed requests do not create one. A later confirmed manual move shifts the
held amount with the stock; observed consumption shrinks the hold. Newly collected
copies do not inherit it. The player can release the override by item. Character
change and addon reload clear session overrides; saved Item and Keep rules persist.

Example outcomes (illustrative choices, not actual character settings):

| Item | Saved outcome |
| --- | --- |
| Fire Crystal | Keep 24 in Inventory; store extras in Sack until the next Moogle deposit. |
| Wind Crystal | Store in Case; do not deposit. |
| Goblin Armor | Store in Sack. |
| Quest item | Ignore this item; leave every copy where it is. |

### Visual editor direction and current evidence

The player requested a visual representation of what goes where. Use a spatial
route editor: a selected bag, Inventory, and (for crystals) the Ephemeral Moogle.
Put the destination selector on the bag and the carried-quantity control on
Inventory. Label directional arrows with the item quantities being moved; show
the resulting stock on each location. Refill arrows point into Inventory;
storing arrows point toward the chosen bag. Moogle collection visibly passes
through Inventory before the deposit, preserving the carried supply.

The native Item rules editor now draws location cards with item and bag artwork,
quantities, route direction, refill state, and Moogle donation state. It uses live
inventory snapshots and saved/draft settings in source; opening the page does not
start moves. Offline renderer checks cover mocked layout behavior, not actual
Ashita appearance. Full, locked, ignored, and selected states must remain
distinguishable by labels as well as appearance.

The player approved this visual direction and requires textures throughout the
finished interface. Use recognizable item icons and destination artwork, with
cohesive textured panels, item slots, and controls. Keep text, quantities, and
directional arrows crisp above the artwork. Full, locked, ignored, and selected
states must remain distinguishable by labels or symbols as well as appearance.
The coverage checklist in [the artwork notes](addons/oddorg/assets/README.md)
is part of visual completion. Version 1.7.1 supplies the destination and material
atlases and uses native game item icons. Offline checks cover texture ownership,
clipping decisions, and fallback controls. Actual in-game appearance remains a
separate acceptance step.

Native cohesion review, 2026-09-23: the player-approved browser route editor is
not the installed Automatic care page. Adding textures to the older form layout
does not implement that composition. Preserve all current artwork. The next
visual pass must use a common layout: compact header, consistent destination
cards and artwork scale, controls attached to their outcomes, restrained material
surfaces, and consistent spacing/type hierarchy. Arrows in the current Item rules
page represent implemented source actions. Compare the page with the player's
current in-game view before claiming visual parity; offline renderer checks do
not establish it.

Native cohesion pass, version 1.7.2: the player's screenshot confirms the 1.7.1
artwork renders, but the repeated material backplates compete with the items.
Preserve the PNGs; remove added icon backplates, use quieter shared surfaces,
and replace narrow vertical location tiles with measured horizontal bag cards.
The native Item rules editor builds on that compact navigation and fixed Apply
area. It shows current locations, carried target, extra route, and explicit
donation choice. Live appearance and real bag movement still need player
observation.

### One rule throughout the workflow

- Explicit ignored stock, equipped/locked items, and deliberate temporary manual
  overrides take precedence over automatic placement. Normal readiness checks
  still apply; no rule grants access to an unavailable bag.
- A carried target is a maintained supply. Refill the shortfall from eligible,
  accessible stored stock while ready, preserve that supply from sorting and
  deposits, and never fabricate missing stock. Crystals and clusters stay separate.
- Carried targets take precedence over the desired free-slot count. Clearing must
  not remove refilled stock and then trigger another refill. A lack of capacity
  leaves replenishment pending without evicting protected items.
- Incoming sorting, free-space clearing, manual organization, previews, and Moogle
  staging must use the same destination and quantity decisions. Temporary staging
  through Inventory is part of a move; it must not become a new sorting request.
- New arrivals follow the saved rule. First Bulk Run applies the same arrangement
  to existing stored items; arrivals must not trigger repeated whole-bag reshuffles.
- Routine waits recover quietly. A blocked destination is visible in settings;
  interrupt only for an actionable impact such as collecting space running out.
- Manual moves must not be immediately undone or silently rewrite a saved rule.
  The implemented session override tracks the confirmed quantity at its current
  location; consumption shrinks it, unrelated new copies follow the saved rule,
  and release/reload behavior is documented above.

### Acceptance and remaining checks

Offline acceptance is complete for source decisions: destination precedence,
no-fallback behavior, Keep and carry-target allocation, exact staging-bag donation,
refill reservations, per-character Apply, and confirmed quantity/location overrides.
The player playcheck remains necessary to verify visual fit, actual unlocked/access
behavior, persistent settings on both characters, full-bag waits, consumption and
refill, manual retrieval/put-away, zoning, and actual Moogle balance.

Multi-bag quotas, schedules, and cross-character logistics remain outside this
scope.
