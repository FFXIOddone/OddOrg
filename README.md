# OddOrg

For current UI direction and acceptance criteria, read the
[UI product guide](docs/UI_PRODUCT_GUIDE.md). The release history below includes
older designs that have since been superseded.

## OddOrg 1.11.0

Download **OddOrg-v1.11.0.zip** from the
[release page](https://github.com/FFXIOddone/OddOrg/releases/tag/v1.11.0).
Extract its `oddorg` folder into your Ashita `addons` folder. Keep existing
character settings in `config/addons/oddorg`; do not delete them when upgrading.
Load with `/addon load oddorg`, or reload an existing installation with
`/addon reload oddorg`. Open the interface with `/oddorg`.

Server approval is separate from this release. Follow your server's addon policy.
See [release notes and review summary](docs/releases/v1.11.0.md).

See the [September 26 audit](docs/RELEASE_CANDIDATE_AUDIT_2026-09-26.md)
for checks, fixes, and evidence limits. The owner confirmed the final player check
passed before authorizing this release. The base layout is now
**OddOrg Default**; its selector appears only when other layouts are available.
Bulk Run uses **View Plan**, then **Run organization**. Saved settings apply to
new plans and runs without restarting the addon. Automatic care supports a
target of **1-80** empty Inventory slots, bounded by actual Inventory capacity.

Equipped gear is rechecked before dispatch as well as during planning. The
advanced `equipped` organization option remains an explicit opt-in; direct
single-item moves and ordinary UI runs do not bypass this check.

Version 1.11.0 makes OddOrg placement the base for **My layout**. In Automatic
care, select an item type and choose **OddOrg placement (base)**, **Leave where
it is**, or an exact bag. Select **Set destination**, then **Apply layout**.
Only your changes override the base; unchanged types retain its item-aware
placement and fallback bags. Existing automation switches remain separate.
Bulk Run uses this same layout; **Preview** shows the actual allocation.
Specific destinations do not fall back when unavailable or full. Item rules,
carried targets, exclusions and protections retain their precedence.

The canned 1.10 presets are no longer offered as new choices. Existing saved
layouts and an already-active preset remain readable/selectable for continuity.
Choose **My layout (OddOrg base)** to start customizing the base instead.

### Previous 1.10 presets (retained only for saved-layout compatibility)

Version 1.10.0 originally added four built-in storage quicksets alongside OddOrg defaults.
These definitions remain solely to resolve preferences saved with that version.

| Quickset | Storage preference |
| --- | --- |
| Portable split | Equipment in Wardrobe; general items, fish and logs in Satchel; crystals/clusters in Sack; usable items, scrolls, currency and quest items in Case. |
| Crafting bench | General items, fish, logs and crystals/clusters together in Safe; equipment in Wardrobe; usable items in Case; quest items in Sack. General items is a mixed category, not a crafting-only classifier. |
| Wardrobe by slot | Weapons, ammo and other equipment in Wardrobe; armor in Wardrobe 2; accessories in Wardrobe 3; usable items in Case; crystals/clusters in Sack. Requires access to all three wardrobes. |
| Home archive | Equipment in Locker; general items, quest items, fish, logs, books, scrolls, furnishings, plants, flowerpots and mannequins in Safe; crystals/clusters in Storage; usable items in Case. Locker access is required; Storage is used only during Mog House bulk runs. |

Unlisted categories stay where they are. Existing protections, carried targets,
item-specific routes and bag-access checks still apply. Unmodified built-in
presets do not consume custom slots. Change their routes or name to save a custom
copy (up to 12 custom sets); saving an existing custom name replaces that set.

Version 1.9.7 simplifies Home: a roomier identity header, one status-and-Settings
row, and quieter activity text. Repeated branding and the tagline are removed.
Paused care shows its recorded reason; no automation settings or actions change.

Version 1.9.6 refines the infinity emblem into an abstract crystal formation:
no limbs or literal face, with directional shards suggesting a dragon pursuing
its tail. The two O loops and cyan/gold material identity remain.

Version 1.9.5 evolves the seal into a crystal dragon forming two linked O loops:
OddOrg's infinity emblem. Cyan facets and fine gold seams retain the crystal
material identity; the complete dragon stays visible in the responsive banner.

Version 1.9.4 introduces the crystal seal banner: interlocking cyan facets and
fine gold seams forming a clear O silhouette. The artwork stays proportionate
and fully visible as the window widens; titles remain native readable text.

Version 1.9.3 removes opaque backgrounds from layout panes so the shared texture
continues behind their contents. Automatic-care, item-route, and layout-bag cards
size to their wrapped text and controls instead of leaving fixed grey slabs.
The updated container appearance still needs a player check in Ashita.

Version 1.9.2 refines the native control skin with one eased material response on
hover. The texture and layered cyan edge settle into a steady surface and fade on
exit; they do not sweep or pulse. Native controls and toggle motion remain intact.
The updated appearance still needs a player check in Ashita.

Version 1.9.0 adds character-specific **Item rules** alongside storage quicksets.
For each item, choose the active quickset/default placement, leave extra copies in
their current bags, or name one exact compatible destination. Set a carried
Inventory target in individual items. When **Keep Inventory slots free** is on,
OddOrg can refill a shortfall from accessible stored stock, preferring the chosen
destination. Refill stock stays protected from sorting and deposits. A locked,
full, or unavailable exact destination never falls back to another bag.

Item rules do not enable global automation. Crystal and cluster donations need
explicit per-item permission and a selected staging bag; unattended deposits also
require the character's separate Moogle switch. The editor shows current stock,
the carried target, refills, extra-item route, and possible donations before
**Apply item settings** saves the choices for that character. Browsing between
items keeps unsaved drafts.

Confirmed native manual moves create a temporary override for only the moved
quantity and destination. Consuming stock shrinks that hold; newly collected
copies do not inherit it. Release is available per item, and holds clear on
character change or addon reload. Saved Keep and Item rules continue to persist.

Version 1.8.0 adds shared **storage quicksets**. In Automatic care, choose an item
type and bag, select **Set destination**, give the layout a name, then **Save & use
quickset**. Assigning a type permits automatic storing when sorting or free-space
clearing is on. Unassigned types stay put in a custom quickset; Ignore rules,
temporary holds, equipped items, and explicit item exclusions take priority.
**OddOrg defaults** restores the previous placement behavior.

First Bulk Run selects those same saved quicksets. **Preview** shows the resulting
item types and quantities grouped under bag artwork; **Show individual moves**
opens the transfer list. Run rebuilds from current inventory. Restricted Storage
remains bulk-only. Bulk capacity checks are conservative: a full bag can require a
spare slot even when a manual move could merge into an existing stack.

Quicksets are per character (up to 12 names, 1-32 ASCII letters/digits/spaces,
underscores or hyphens). Item types use the installed game's resource metadata,
including equipment slots and crystal/cluster IDs. **General items (mixed)** is
not a promise to identify crafting ingredients, and **Usable items** does not
separate food from medicine. Unknown types stay untouched. Offline checks verify
the routing and editor semantics; native appearance, installed state, and server
moves still need player verification.

Version 1.7.2 reorganized the native Ignore items page around current locations,
untouched quantities, and automatic actions for extras. At that time, destinations
and maintained Inventory supply were still planned; version 1.9.0 adds them to the
Item rules editor described above. All original artwork remains bundled, with
quieter panel and button textures.

All three PNG textures and the `ui_art.lua` / `ui_textures.lua` modules ship with
the addon. No image download is required in game. Texture loading and release
have offline coverage; native appearance still requires in-game observation.

OddOrg helps you manage inventory housekeeping on each character you play.
Version 1.4.0 sorts approved incoming items while you play and can deposit surplus
crystals when you pass an Ephemeral Moogle. It waits for Ashita's loaded-bag flags
so partially downloaded bags cannot be mistaken for available space.

Version 1.4.2 fixes a stale queue error that kept claiming bags were loading after
zoning, even once loading finished. An idle zone change no longer creates a queue
error; interrupted runs retain an accurate cancellation message. Loading status
names the bag and flag mask, or a missing API. `probes.tsv` records readiness
changes, recovery, and native inventory completion without bypassing the checks.

Version 1.4.3 fixes organization stopping on a locked Safe2. Reported bag size
does not establish its unlock: Safe2 is excluded until a native update confirms
it for the current character, and that result is saved across reloads. Other
bags remain usable. A stopped manual run now names the failed item and route;
each UI mode displays its own error.

Version 1.4.4 measures the manual organizer's delay from transfer confirmation,
so a slow response cannot cause the next move to be sent immediately. This is
a timing mitigation for an intermittent rejection; its live cause is still
unconfirmed. Failed transfers still stop without an automatic resend.

Version 1.4.5 gathers stored crystals and clusters before depositing, filling
up to eight actual Inventory slots per trade. Carried surplus joins the same
batch. Merged stacks share one trade slot, Keep quantities remain protected,
and limited Inventory space causes a smaller batch followed by more retrievals.

Version 1.4.6 fixes incoming sorting hiding a blocked free-space target. If OddOrg
cannot make room, it explains whether protections or full destinations are the
blocker. A warning repeats when Inventory becomes full, then stays quiet while
that condition is unchanged. Sorting alone also warns when completely full,
without applying the disabled background-clearing target.

Incoming sorting, low-space clearing, and nearby deposits are enabled separately
for each character. The product direction is in [PRODUCT.md](PRODUCT.md).

Version 1.5.0 replaces Item protections with **Ignore items**. Choose an item,
preview how much stays untouched and what automatic actions can use, then apply
the settings together. Existing saved rules continue to work.

Version 1.5.1 brings that flow to automatic setup. Review this character's active
settings, choose the work OddOrg should handle, and use **Apply automatic
settings** once. Edits stay a preview until applied. Then close the window and
play; routine automatic Moogle starts, empty visits, and completion stay quiet.

Version 1.5.2 separates the compact home view from Settings. Home shows the
character's current state and work in progress. Open **Settings** for **Automatic
care**, **Ignore items**, or **First Bulk Run**. First Bulk Run contains the
manual organization, preview, and crystal-deposit tools; it can be used again
whenever needed. Opening a page does not start work or enable automation.
Use `/oddorg settings` to open Settings directly.

Version 1.6.0 rebuilds the native settings layout with a navigation rail,
grouped controls, consistent dark surfaces, and explicit On/Off states.
The empty-slot target uses a bounded control instead of a full-width number
field. Unchanged Apply buttons are muted; edits still take effect only when
applied. All manual tools remain in **First Bulk Run**.

Version 1.7.0 adds original crystal artwork, a dedicated native visual layer,
scaled headings, animated On/Off switches, a fixed Apply area, and a split item
browser with scrolling rule details. Home stays compact, and First Bulk Run keeps the manual tools.
Artwork loads locally when the window opens; it does not fetch assets online.

## Install and use

Copy the complete `addons/oddorg` folder into your Ashita v4 `addons` folder.
Include all Lua files and the `assets` folder. Load it and open the controls:

```txt
/addon load oddorg
/oddorg
```

The window stays closed on load. Each character uses its own saved protections
and automation settings. Automation starts disabled on first setup. Existing
settings are preserved. An enabled 1.3 house preference becomes incoming sorting;
there is no longer a house-entry requirement. Nearby deposits remain a separate
opt-in.

Manual organization keeps items already occupying a suitable overflow bag instead
of swapping equivalent stacks between bags on each run. Item rules can also direct
individual items to an exact bag or keep them in place; the exact route is used
without fallback. Explicit crystal deposits obey the item rule, Keep quantities,
and temporary manual overrides.

1. Open **Settings > Item rules**. For each item, choose **Ignore all**, **Ignore
   an amount**, or **Ignore none**; set an Inventory target; and choose default
   placement, **Leave extras where they are**, or one exact destination. Crystal
   donations need their own checkbox and staging bag. Review the location cards,
   then select **Apply item settings**. These saved choices are per character.
2. In **Settings > Automatic care**, turn on **Keep Inventory slots free** to maintain five free Inventory slots while
   alive, idle, and ready. Adjust the target from 1 to 20 if needed. Per-item
   carry targets are maintained from accessible stored stock while this feature
   is on. Item destinations can permit their own automatic storage when a global
   automatic action is enabled; they never enable one by themselves. Keep and
   temporary overrides remain protected during sorting and deposits.
3. Turn on **Store extra items as they arrive** to store approved carried stacks whenever
   they arrive, even with plenty of free slots. It runs while alive and idle,
   without opening the window. Per-item exact destinations take priority; other
   items use the saved quickset/default behavior. Keep rules,
   retrieval holds, equipped items, locked items, and unknown items stay protected.
   Full exact destinations wait without choosing another bag. Default placement
   uses suitable bags/wardrobes; existing
   matching stack room is used first. On CatsEye the restricted **Storage** bag
   is excluded from unattended moves; Safe, confirmed-unlocked Safe2, Locker, portable bags, and
   unlocked wardrobes can be used. Actual server access still governs transfers.
   In **Settings > First Bulk Run**, manual **Preview** and organization remain available for **All bags**, **Wardrobes**,
   or **Storage bags**; manual runs use the full categories for unprotected items and
   can use Storage when you are in the appropriate Mog House.
4. For any crystal or cluster you want donated, explicitly enable its item
   donation and choose a staging bag in **Item rules**. Then turn on **Deposit
   crystals near a Moogle** and walk within six yalms of an
   **Ephemeral Moogle** during normal play. One deposit run starts per pass,
   without changing your target or opening the window. It continues only while
   the same Moogle remains in range and you are ready; walking away stops further
   actions. It retrieves stored surplus before trading until eight trade slots
   are ready, Inventory has no more room, or all eligible stock is gathered.
   Multiple batches take time, so stay nearby to finish a large deposit.
   Keep quantities, carried targets, and temporary overrides stay protected.
   For that rule, stored stock stages only from the selected item bag; carried
   eligible surplus can also be donated. Storage is excluded
   from unattended deposits. For a manual run, open **Settings > First Bulk Run**, select **Crystals**, choose **All bags**,
   **Inventory**, or **Storage bags** as the source, and use **Deposit surplus**. Your current
   Moogle target takes precedence; otherwise OddOrg finds the nearest one in
   range. It retains and revalidates the same identity and zone throughout the
   run, even if selection clears.

After choosing automatic actions, select **Apply automatic settings**. This saves
global switches while preserving per-item rules and Keep quantities.
Existing users keep their current choices. Applying changes does not resume an
explicit pause: use **Resume automatic actions** when ready. **Pause all automatic
actions** pauses clearing, incoming sorting, and nearby deposits together.
Both pause and resume are in **Settings > Automatic care**. **Back** returns to
the compact home view; navigating pages preserves edits until you apply them.

## Item rules

- **Ignore all**, **Ignore an amount**, and **Ignore none** remain available.
  Amounts count individual items. Inventory is protected first, then a saved
  shortfall is protected in storage. Existing equipped, locked, and social-item
  protections still apply.
- **Items to carry** is an additional target, separate from Ignore. When free-slot
  clearing is enabled, a shortfall can refill from eligible, unlocked bags. The
  chosen exact destination is preferred; restricted Storage is never used for
  automatic refill. The target and needed stored quantity remain protected from
  clearing, organization, and deposits.
- **Extras go to** chooses the active quickset/default route, keeps extras in
  their current locations, or assigns one exact bag. A full or unavailable exact
  bag blocks that route instead of selecting a substitute. Wardrobes are offered
  only for compatible equipment; Storage is manual bulk-run only.
- Crystal and cluster donation is a separate per-item choice. It requires a
  specific staging bag, and unattended donation also needs **Deposit crystals
  near a Moogle** enabled for the character. Storage routes never imply donation.
- The preview shows current quantities and locations, the carried target and
  refill shortfall, extra-item route, blocked destination, and possible Moogle
  amount. These are projections; live access, capacity, activity, and global
  switches still govern execution.
- **Apply item settings** saves Keep and per-item outcomes for this character.
  Global automation switches are unchanged. Browsing preserves unsaved item
  drafts; changing characters clears them.
- Crystals and clusters are separate items with separate rules. Keeping 24
  Fire Crystals does not protect Fire Clusters; one cluster counts as one item
  in its keep rule, although a deposit represents 12 crystal units.
- Changing a rule stops queued work so the next run uses the new settings.
  It cannot undo a transfer or deposit already sent. A fresh run waits out the
  pending action's confirmation window before accepting another request.

Rules apply to organization and crystal deposits, with fresh checks before
execution. Quantities can be split from a stack. Rules are stored through
Ashita's character-specific settings under
`config/addons/oddorg/<character>_<server ID>/settings.lua`.

When a native manual bag move is confirmed, OddOrg holds the exact moved quantity
at its destination for this session. It ignores addon-injected moves and does not
infer intent from ordinary loot gains. Consumed stock shrinks the hold; newly
collected copies do not inherit it. Use **Release temporary choice** in Item
rules to end it early. Holds clear on character change or addon reload; save an
Item rule or Keep quantity for protection that lasts longer. Other addons'
retrievals are not interpreted as manual intent.

OddOrg cannot infer which quest you are doing. Unknown items are excluded from
automatic Inventory clearing by default. Explicit manual organization still uses the
existing categories for unprotected items.

## Progress and interruptions

Crystal deposit progress reports remaining crystals, clusters, and bag retrievals
separately. A batched trade can satisfy several queued requests, so queue length
is not a move count. Confirmed quantities leave the display immediately, with a
separate animation-wait message. The crystal progress bar measures confirmed
crystal units (one cluster equals 12); completion logs count actual confirmed bag
transfers and trade batches. A 2026-09-26 production log exposed the old mismatch:
six queue entries represented three retrievals and one 34-crystal trade batch.

Transfers prefer the fullest unlocked matching stack that can accept the entire
source stack. This targets that existing slot directly instead of allocating a
new slot and then sorting it. Queued withdrawal slots are excluded. Partial
withdrawals retain automatic placement and require free space: the server's
[item-move implementation](https://github.com/LandSandBoat/server/blob/base/src/map/packets/c2s/0x029_item_move.cpp)
handles splits separately from whole-stack merges. Background destination selection
indexes stack room once per snapshot and resolves each candidate's routes once.
Transfer confirmation and pacing remain in place; these changes reduce avoidable
work rather than assuming faster packet rates are safe. Server behavior and
throughput still need production testing.

The window displays remaining actions and any stop reason. Transfers require
observed source-slot and destination changes before continuing. Crystal deposits
require changes in their actual source slots, an Inventory decrease, and the animation interval. This observes
item movement; it does not read the Moogle's stored balance.

After OddOrg confirms a stackable item arrived in storage, it automatically
requests the destination bag's native Auto Sort when matching partial stacks
exist. This covers crystals and other stackable items in Mog House storage and
portable bags. The next transfer waits for consolidation with unchanged item
totals; an unconfirmed sort stops the run after five seconds without resending.
Requests are spaced at least two seconds apart per bag. During bulk organization,
sorting a bag waits until queued withdrawals from that bag finish, preserving
their source-slot references. Existing conservative bulk capacity planning is
unchanged; this does not promise a run can start with an already-full destination.

The sort request uses the bag-scoped `0x03A` layout documented in
[Windower's packet fields](https://github.com/Windower/Lua/blob/dev/addons/libs/packets/fields.lua).
The implementation has been syntax checked; destination stacking still requires
in-game confirmation on the user's server.

Stored crystals are retrieved one confirmed move at a time, then deposited in
batches of up to eight Inventory slots. A single free slot still works through
smaller batches. If Inventory cannot accept a stack and there is no carried
surplus ready to deposit, storage is inaccessible, the Moogle leaves range or changes
identity, or a result cannot be confirmed, the run stops without an automatic
retry. Check the displayed reason and inventory before starting a fresh run.
Do not manually rearrange items while a run is active.

Background clearing sends one move at a time and confirms its result. It moves
whole unreserved stacks because splitting a protected stack would free no slot.
It pauses during combat, crafting, events, death, and zoning, and waits for a
stable character/zone and coherent inventory data before starting. It does not
open the window or announce each successful move. Low space produces a notice
when remaining items are protected/not allowed or portable bags are full.
An unconfirmed move pauses background clearing until **Resume**; it never keeps
retrying. Manual Stop also pauses background work. Saved settings survive reload;
session holds, pause state, and the freed-slot counter do not.

Incoming sorting shares the confirmed, one-move-at-a-time clearing runner. It
continues as approved stacks arrive, leaving other stored items untouched. Only
whole unreserved stacks are moved. Pause, Stop, changed protections, and manual
retrieval cancel pending work; a sent action may still complete. Resume allows
automatic sorting again. Zoning cancels runs and waits for fully loaded bags.

Nearby deposits make one attempt per pass, including an empty or blocked run.
They do not restart because inventory changes while you stand beside the NPC.
Walk beyond eight yalms for at least two seconds before approaching for another
automatic attempt, or deliberately start a manual deposit. An unconfirmed trade
is never automatically retried during that pass. Deposits observe item removal,
not the Moogle's stored balance. Check that balance during playtesting.

An unlocked, loaded bag is not proof of every server-side access condition (such
as Locker expiry). A rejected/unconfirmed transfer stops automatic sorting until
Resume. No automatic movement discards or sells items.

## Commands

```txt
/oddorg
/oddorg auto on
/oddorg auto slots 5
/oddorg auto allow 901
/oddorg auto exclude 4096
/oddorg auto pause
/oddorg auto resume
/oddorg auto off
/oddorg sort on
/oddorg sort status
/oddorg sort off
/oddorg deposit on
/oddorg deposit status
/oddorg deposit off
/oddorg keep list
/oddorg keep 4096 24
/oddorg keep 4096 all
/oddorg keep 4096 clear
/oddorg organize preview all
/oddorg organize run all
/oddorg organize stop
/oddorg organize status
/oddorg ephemeral dump all
/oddorg ephemeral stop
/oddorg ephemeral status
/oddorg status
```

Organization scopes: `all`, `wardrobes`, `storage`.
Crystal scopes: `all`, `inventory`, `storage`.
The legacy `/oddorg house` command is an alias for `/oddorg sort`.
Existing advanced organization options: `equipped`, `social`, `delay=0.8`,
`probes`, `noprobes`. Explicit keep rules always take precedence, including over
`equipped` and `social`. Probe controls remain `/oddorg probes on|off|clear|status`.

## Development verification

For texture changes, also run `luajit tests/ui_textures_test.lua` and
`luajit tests/textured_skin_test.lua`. These use inert native stubs and do not
interact with a game client.

From the repository root with LuaJIT on PATH:

```txt
luajit tests/run.lua
luajit tests/storage_layout_test.lua
```

Tests isolate Ashita settings, inventory, time, and UI. Transport functions are
inert captures, and any real packet-manager access fails the run. Cases cover
per-character persistence, partial-stack reserves, protected quest items,
organization scope/capacity, repeated deposits with one free slot, lost target
selection, changed identity, timeouts, and observed completion.

Background cases cover eligibility, protections, native retrieval holds,
portable-bag capacity, confirmation, readiness, and nearby Moogle discovery.
Automation cases cover incomplete bag loading, incoming item intent, protections,
proximity passes, cancellation, and persistence. Planner cases include
Safe2/Storage overflow and stability after a completed plan.
Item UI cases exercise draft edits, combined Apply, Ignore all/none, quantity
and slot previews, character changes, and ending temporary retrieval pauses.
Quickset cases cover shared automatic/bulk routes, full destinations without
fallback, repeated-plan stability, named-set persistence, item exclusion priority,
draft UI interactions, and quantity conservation in the by-bag preview.
Automatic setup cases cover draft preservation while editing Item rules,
combined saves, unchanged Apply, explicit pauses, character isolation, and failed
save/reload verification. Quiet-deposit cases retain manual feedback and failure
notices while suppressing routine automatic messages.

These are offline checks. They do not prove installation, native UI rendering,
or in-game behavior. No installation or game interaction is performed by the tests.
