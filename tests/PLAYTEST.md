# OddOrg 1.9.2 player check

## 1.9.2 visual interaction pass

Open Home and Settings at the normal UI scale. Confirm panels, route cards,
buttons, text inputs, selectors, checkboxes, and sliders show a coherent,
readable material texture. Hover each interactive control: its surface and cyan
layered edge should ease in once, hold a composed appearance, and fade softly on
exit. There should be no recurring sweep or pulse. Tab through controls and
confirm the cyan focus outline is visible. Disabled actions should remain quiet
and should not animate as enabled controls. Toggle an option and confirm its knob
moves smoothly without delaying the setting change. Labels, caret, selection, and
slider values must remain legible throughout.

Quickset flow: in Automatic care, assign Crystals to Sack and Clusters to Case,
name and save the set. Check that the compact controls and bag cards fit both
normal and expanded windows. First Bulk Run must show that same active name.
Preview should show crystal types/quantities under their intended bags, with
ignored stock still in its current location. Run, then Preview again: no further
moves should be needed for those types. Check a full destination: it must wait
or reject without using a different bag. Unknown/unassigned types stay put.
Keep some crystals ignored and collect another stack during ordinary play;
automatic sorting must use the same destination while respecting that reserve.
Reload and switch characters to check saved-set isolation. Moogle deposits keep
their own toggle and permission. Storage routes are bulk-only.

Offline tests do not establish native Ashita rendering or server behavior. Run
these on each character after reloading OddOrg; the agent does not drive the game.

Item rules: choose a crystal, set an Inventory target (for example, 24), choose
one exact storage bag, and preview the route. Apply it and verify the saved outcome
appears in the item browser. With global automation off, confirm the rule alone
does not move anything. Enable **Keep Inventory slots free** with less than the
target carried and eligible crystals in the chosen bag plus another bag. Refill
should prefer the chosen bag, move only the shortfall, and keep both the target
and any Keep quantity protected. If the destination is locked or full, OddOrg
must not use a substitute.

For crystals or clusters, separately allow donation and select a staging bag. With
the carried target met, verify a nearby deposit uses only eligible carried stock
and stock from that staging bag. Turn off the character Moogle switch and confirm
the saved item rule does not start unattended donations. Check the actual Moogle
balance during play; inventory changes alone do not prove a successful deposit.

Manual overrides: move a partial stack through native controls and wait for
confirmation. Item rules should show only that quantity at its new location as a
temporary choice. Consume some of it and confirm the held amount shrinks; collect
new stock of the same item and confirm it does not inherit the override. Manually
put away some carried stock and verify the override follows that confirmed amount.
Release it, then reload and verify all session holds clear while saved item rules
remain.

The crystal artwork should appear in the header with readable text over its
dark area. Check the custom switches in both On and Off states, hover feedback,
and keyboard navigation if enabled in Ashita. In Item rules, the item browser
stays beside the selected rule; each pane should scroll without hiding the other.
Check after Alt-Tab and a resolution change: the artwork and controls should
still render correctly. Texture/device behavior is not proven by offline mocks.

Visual check at your normal UI scale: Settings should have top navigation,
consistent opaque dark panels, aligned controls, and clear On/Off states. The
empty-slot target should be compact and show a 1-20 slot range. With no edits,
Apply should look inactive; after an edit it should become prominent. Check
the smallest permitted window size and a larger size for clipped labels,
overlapping controls, and usable scrolling. Compare against the approved reference
screenshot if available; offline layout checks cannot prove this rendered result.

Home and navigation: open `/oddorg`. Expect the character, a compact status,
relevant current activity, and one **Settings** button. Setup fields and manual
actions belong in Settings. Resize each view and check that its scrollable
content remains usable. Back returns to Home; closing either view stops no work.

Open Settings and switch between **Automatic care**, **Item rules**, and
**First Bulk Run**. Only the selected section should be shown. Item rules
should edit in place, without a second window. First Bulk Run should expose
manual bag choices, Preview, organization, and crystal deposit controls without
starting anything merely because the section was opened.

Automatic setup: open **Settings > Automatic care** and check that active choices
match the previous setup. Edit the three automatic-action On/Off controls and the
empty-slot target. Saved status must stay unchanged until **Apply automatic
settings**. Review Item rules, apply the automatic choices, close the window,
and confirm they survive reload independently on each character. Saving while
paused must leave all automatic actions paused until explicitly resumed.

With the window closed, collect eligible loot, zone or fight, and pass a Moogle.
Normal waits should recover without pressing Resume. Automatic Moogle start,
empty visits, confirmed completion, and walking out of range should not create
routine chat messages. A manual deposit should still report its outcome, and
an unconfirmed transfer must still stop with an actionable notice.

Open the window only when desired: confirm it shows which automatic actions are
on, any actual blocker, and where to change ignored items. The manual controls
must distinguish organization bag scopes from crystal collection sources. Check
the main window and organization preview at your normal UI scale, including a
long item list; no control should require an unexpectedly tall window.

Item rules: open **Settings > Item rules**, select a crystal, and compare
Inventory/other-bag counts with the game. Try Ignore all, Ignore an amount, and
Ignore none. The slider and exact entry should agree, with counts measured in
individual items. Change the carried target, destination, and donation checkbox
and confirm they update only the preview until **Apply item settings**. Apply,
reload, and verify each choice persisted for that character. For a Keep amount
spanning bags, the preview should reserve Inventory first and then other bags.
Confirm labels, route cards, controls, and scrolling remain readable at your UI
scale.

1. Open `/oddorg`, protect an intentional crystal reserve and a quest item, then
   enable background clearing. With fewer than the configured free slots and an
   extra unreserved crystal stack, stand idle. The surplus should move to an
   available portable bag, the reserved stock and quest item should stay, and the
   free-slot count should increase. The window may be closed during normal play.
2. Retrieve a partial stack manually with native bag controls. After confirmation,
   only the moved quantity should show as a temporary choice and stay put. End
   the override deliberately, or apply a saved Keep amount for ongoing crafting.
3. Let the character enter combat or craft; background moves should wait until
   idle. If all portable bags are full, expect one actionable low-space notice,
   no repeated moves, and no changes to protected items.
4. Stand near an Ephemeral Moogle without targeting it. Start a deposit with one
   free Inventory slot and multiple stored crystal stacks. Expect continuation
   through observed moves/trades while keeping reserves. Observe the Moogle's
   actual stored balance; inventory disappearance alone is not balance proof.
5. Use Stop/Pause, then Resume, and reload on both characters. Confirm that each
   character keeps its own enabled state, free-slot target, and item rules. Manual
   overrides last only for the current session; saved rules survive reload.

Report the character, visible status text, intended carry rule, and observed item
counts for any mismatch. Do not mark these checks passed from source or hashes.

Loading status: zone with no manual run active. Once bags finish loading,
automatic status should recover and no permanent queue error should claim they
are still loading. A run interrupted by zoning should say it stopped, while a
genuine incomplete snapshot names the waiting bag/flag mask in status and probes.

Locked Safe2: click Preview and Organize on a character without Safe2 unlocked.
Neither should route items into Safe2, even if its reported size is positive.
The remaining accessible bags should organize normally. On an unlocked character,
a native local-player update should confirm access (`storage_access` in probes)
and preserve it across reloads. If a transfer fails, the manual status should
name its step, item, source, and destination instead of showing a deposit error.

Transfer pacing: run Organize after reloading. It should leave the configured
delay after each confirmed transfer, including when a response was slow. Check
whether the remaining plan finishes; successful manual movement alone does not
prove the intermittent addon rejection is fixed. Unconfirmed moves must still
stop without resending.

Organization stability: with identical material stacks split between Inventory
and a full overflow bag, Preview should not propose exchanging those stacks.
After any useful organization finishes, preview again without changing items;
expect no further rearrangement. With background clearing enabled, an eligible
item already stored should remain stored when organization runs.

Incoming sorting: enable `/oddorg sort on` on one character outside the Mog House.
An enabled old house setting should migrate automatically. Gain an unreserved
crystal stack while many Inventory slots remain free; it should move once to
available storage. An unknown quest item, excluded crystal, or manually retrieved
held item should remain carried. Opt in one other item and confirm it sorts.
Existing stored items should not reshuffle. No automatic move should use the
restricted Storage bag. Repeat after a zone change: wait for complete bag loading,
with no false empty-bag plan or first pull into an already-full destination.

Nearby deposits: protect a crystal reserve, enable `/oddorg deposit on`, and walk
past an Ephemeral Moogle without targeting it. Expect one protected surplus run
with no window opening or target change. Stay nearby to finish multiple batches;
walk away during a run and expect no further staged moves/trades after the sent
action settles. Standing beside the Moogle after completion or a failed run must
not restart it. Walk beyond eight yalms for at least two seconds and return to
allow a new attempt. Check the actual stored crystal balance, not just Inventory.

Pause/Stop or manually retrieve an item during automatic work. A sent action may
finish, but no later queued action should follow it. The confirmed moved quantity
should have a session hold. Resume restores automatic sorting; a claimed Moogle pass
still requires leaving and reapproaching. Check each character's independent
sort/deposit settings after reload. Manual Organize remains available for full
bag/wardrobe layout changes and appropriate Mog House Storage access.
