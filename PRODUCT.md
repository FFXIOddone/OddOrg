# OddOrg 1.11.0 product and maintenance contract

OddOrg is an Ashita v4 inventory organizer for FFXI. It keeps usable Inventory
space available, sorts approved arrivals into accessible bags, organizes storage
and wardrobes on demand, and deposits eligible surplus crystals and clusters at
an Ephemeral Moogle. Settings are stored per character.

The product goal is quiet, reliable housekeeping. Player intent always wins over
freeing space. OddOrg must stop with a useful reason when it cannot confirm a
safe action; it must never bypass a protection to meet a space target.

## Player workflow

Open `/oddorg` to see the current character, short care status, free Inventory
slots, and items freed this session. Settings contains three pages:

- **Automatic care** sets the target of 1-80 empty Inventory slots and enables
  Free Inventory slots, Sort incoming items, or Moogle deposits. Changes remain
  drafts until **Apply automatic settings** appears and is used. Saving applies
  immediately; no addon reload is required.
- **Item rules** defines one item's protection and automation outcome. **Keep in
  Inventory** maintains a carried quantity when free-slot care is enabled.
  **Target Storage Placement** follows OddOrg placement, leaves copies where they
  are, or selects an exact compatible bag. Crystal and cluster donation requires
  its own permission and staging bag. **Ignore** protects all copies or a chosen
  quantity in their current locations.
- **Bulk Run** selects All bags, Wardrobes, Storage bags, or Crystals. Storage
  organization requires **View Plan** before **Run organization** becomes
  available. Crystal deposits use their separate **Deposit surplus** action.

The default storage layout is **OddOrg Default**. Players may customize its
category overrides without creating a named layout. Existing named layouts stay
supported for saved-data compatibility. A specific per-item destination takes
precedence over category placement.

## Automatic behavior

Automatic work runs only for the active, alive, idle character after required
bags are loaded and coherent.

- Free-slot care moves one eligible unreserved Inventory stack at a time until
  the requested target is met or no safe destination exists.
- Incoming sorting handles approved arrivals even when the free-slot target is
  already satisfied. It does not use the Mog House-only Storage bag.
- Carried supply refill draws only the confirmed shortfall from accessible saved
  stock. Ignore quantities and temporary holds remain protected.
- Nearby deposits make one attempt per Ephemeral Moogle encounter. OddOrg does
  not change the player's target or movement. The player must remain near the
  same NPC while batches finish and must leave beyond the rearm distance before
  another automatic attempt.

Crystals and clusters have supported deposit behavior. Other items require
explicit storage permission and are never donated. OddOrg does not sell,
discard, convert, travel, withdraw from a Moogle, or control another client.

## Protection and transfer invariants

Every planned action is revalidated against current character identity, bag
access, item identity and quantity, locks, equipped state, capacity, Ignore
rules, carried targets, refill reservations, and session holds immediately before
send.

OddOrg treats a transfer as complete only after the source total, destination
total, and selected source slot show the requested change. Unconfirmed work stops
without automatic retry. Native stack consolidation is also observed before a
run continues.

A confirmed native manual bag move creates a session-only hold for the moved
quantity at its new location. The hold follows later confirmed native movement
and shrinks when that stock is consumed. Newly acquired copies do not inherit it.
Injected moves are outside this observation contract. Reloading or changing
characters clears session holds; saved Item rules persist.

## Bulk planning and convergence

**View Plan** is an estimate built from the current coherent snapshot. Starting
the run rebuilds the plan rather than replaying a saved queue. Changing scope or
layout, dismissing the preview, or updating settings invalidates run readiness.

Execution uses confirmed menu-flow transfers through Inventory. After each queue
finishes, OddOrg builds another plan from the observed bags. Completion means a
fresh plan contains no remaining moves. A repeated bag state or the 16-pass safety
limit stops with an error instead of claiming success. Compatible unprotected
partial stacks may be brought together across storage bags; equipped, locked,
social, held, and protected items remain pinned unless an explicit supported
operator option says otherwise.

Safe2 is excluded until a native character update confirms access, even if the
client reports positive capacity. Storage is used only when the appropriate Mog
House access is available. Optional unavailable wardrobes and bags fail closed.

## Failure and recovery behavior

Normal loading, combat, crafting, and zoning waits stay quiet and resume on a
later safe check. Explicit Pause and uncertain transfers require the player to
resume. Stop prevents later queued actions, though an already sent action may
still settle. Character, settings, or layout changes cancel stale queued work.

Errors should name the blocked outcome and a practical recovery step: free the
chosen destination, wait for bags to load, check Inventory after an uncertain
transfer, adjust an item rule, or enter the appropriate Mog House.

## Maintenance and evidence

Preserve saved-data compatibility, exact per-character ownership, protection
precedence, and fail-closed access checks. Keep the interface compact: short
visible state, help on the related control, event-driven Apply buttons, and no
decorative banner artwork or mascot.

Use `docs/UI_PRODUCT_GUIDE.md` for accepted interaction and visual contracts.
Offline tests can prove planning, validation, persistence, and inert renderer
behavior. Source checks, passing tests, package hashes, installation, and live
player observation are separate evidence levels. Never claim native rendering,
server acceptance, or Moogle balance from offline evidence alone.
