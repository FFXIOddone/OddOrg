# OddOrg 1.11.0 player checklist

Use a test character and ordinary native bag controls. Record the character,
zone, relevant settings, before/after item counts, visible OddOrg status, and the
step that failed. Do not mark a live check passed from source, tests, logs, or
matching installed hashes.

## Window and navigation

1. Open `/oddorg`. Confirm Home shows the character, short care state, free
   Inventory slots, items freed this session, and one **Settings** button.
2. Switch among **Automatic care**, **Item rules**, and **Bulk Run**. Only the
   selected page should appear. Opening, closing, or navigating the window must
   not start or stop housekeeping.
3. Check Home near 360 x 223 and Settings near 855 x 646, then resize both.
   Confirm labels wrap, controls remain reachable, and content scrolls where
   needed. The header itself must never have a scrollbar.
4. Confirm the Settings header is text only, with the character above the page
   title. Enabled care uses the active green accent; paused or disabled care uses
   gold.

## Automatic care settings

1. Enable **Free Inventory slots**. Confirm its slider appears above the three
   feature controls and accepts 1-80. **Empty Inventory slots** is hover help on
   that slider, not a permanent label.
2. Change the slot target and feature switches. **Apply automatic settings**
   should appear only while the draft differs from saved settings. Revert every
   change and confirm Apply disappears.
3. Apply a change. Confirm **Saved for this character** appears briefly, the
   change takes effect without a reload, and it persists after reload.
4. Verify settings independently on a second character. Saving while paused must
   not silently resume work.
5. Edit **OddOrg Default**, set one item type to a compatible bag, and apply it.
   The next plan should use the base override without a reload. Unchanged types
   retain OddOrg placement. Existing named layouts should remain selectable.

## Item rules and protections

1. Select an item and compare each displayed `Storage name: quantity` row with
   the game. Locations with zero stock should be absent.
2. Set **Keep in Inventory** with the exact input and **+1 stack**. The shortcut
   must add the real stack size to the existing amount.
3. Under **Target Storage Placement**, test OddOrg placement, Leave copies
   untouched, and one compatible exact bag. Non-equipment must not offer a
   wardrobe; Storage is a Mog House bulk destination.
4. Test Ignore none, a quantity, and all copies. For a quantity spanning bags,
   Inventory copies should be protected before stored copies.
5. Confirm **Apply item settings** appears only for unsaved changes, disappears
   after reverting, and gives a brief saved result after apply. Reload and verify
   the rule remains character-specific.
6. Protect a quest item and a crystal reserve. Confirm every applicable workflow
   below leaves the protected quantities untouched.

## Bulk Run organization

1. At rest, confirm all scope buttons remain visible and only **View Plan** is
   offered; Stop, Status, and Run should be hidden.
2. Select Storage bags and use **View Plan**. Review the embedded bag summary and
   individual moves. A zero-move plan should still explain the result and reveal
   **Run organization**.
3. Change scope or layout, or dismiss the preview. Run must hide until another
   plan has been displayed.
4. View a useful plan, then run it. The run must rebuild from current bags.
   During work, Stop and Status appear while unsafe scope changes stay disabled.
5. Completion is valid only when a fresh follow-up plan contains no moves. View
   another plan without changing bags and expect a fixed point.
6. Split compatible unprotected partial stacks across accessible storage bags.
   Confirm they co-locate when capacity permits and do not exchange forever.
7. Press Stop before the first transfer and during a later pass. No unsent action
   should follow; an already sent transfer may settle and must be reported.

## Access and transfer safety

1. Without confirmed Safe2 access, no plan may target Safe2 because it reports
   positive capacity. Repeat after a native update confirms access and after it
   reports locked again.
2. Outside the appropriate Mog House, unattended sorting and deposits must not
   use Storage. Manual Storage scope may use it only when loaded and accessible.
3. Equip a wardrobe item and run organization. The equipped copy must remain
   pinned. Locked, held, social, unknown, and protected items should also remain
   untouched under their default rules.
4. Zone while bags load. OddOrg should wait for loaded-container evidence and
   then recover, without treating incomplete bags as empty.
5. Fill an exact destination after preview. The run should stop with the item and
   recovery reason, without choosing another bag or claiming completion.
6. Delay a transfer response. The next move must wait for confirmation and its
   quiet interval. Missing confirmation must stop the run without resending.

## Automatic sorting and carried targets

1. Enable Free Inventory slots with a reachable target. While alive and idle,
   add an eligible unreserved stack with too few free slots. Confirm one stack
   moves at a time and each move is confirmed before another begins.
2. Enter combat, craft, zone, or make required bags unavailable. Work should wait
   and recover on a later safe check without requiring Resume.
3. Enable Sort incoming items while Inventory has ample space. Gain an approved
   item and confirm it follows the saved layout once. Existing stored stock must
   not trigger a broad reshuffle.
4. Fill destinations or protect every candidate. Expect one actionable status,
   no repeated attempts, and no protection override.
5. Set **Keep in Inventory** above the carried amount and provide eligible stock
   in an accessible bag. Confirm only the shortfall refills and the maintained
   quantity is not sorted or donated.
6. Repeat with protected stock, a locked source, unavailable stock, and Storage.
   The shortfall must remain pending rather than use inaccessible stock.

## Native manual holds

1. Move part of a stack with native bag controls. After confirmation, Item rules
   should show a session hold for exactly the moved quantity at its destination.
2. Acquire more copies and consume held stock. New copies must not inherit the
   hold; consumption should shrink it.
3. Move the held quantity again natively, then release it through Item rules.
   The hold should follow the confirmed move and then clear.
4. Reload. Session holds should clear while saved Item rules remain. Injected
   addon moves are outside the native manual-hold contract.

## Crystal and cluster deposits

1. In **Bulk Run**, choose Crystals and a source scope. **Deposit surplus** does
   not require View Plan. Stop and Status appear only during an active deposit.
2. Protect a reserve and provide carried and staged stored surplus. Confirm only
   allowed crystals and clusters are gathered and traded, using smaller batches
   when Inventory space is limited.
3. Stay near the same Ephemeral Moogle through multiple batches. OddOrg must not
   change the player's target or movement. Verify the actual Moogle balance;
   disappearing Inventory is insufficient proof.
4. Walk out of range while a batch settles. No new action should start after the
   sent action settles. Standing nearby after success or failure must not restart
   immediately.
5. Enable Moogle deposits and approach without targeting. Expect one automatic
   attempt for the encounter. Leave beyond the rearm distance for at least two
   seconds, return, and confirm a new attempt is allowed.
6. Force an unconfirmed stage or trade. OddOrg must stop, preserve protection
   budgets, avoid retrying, and show an actionable failure. Empty visits and
   confirmed automatic completion should remain quiet.

## Report a discrepancy

Include the character, zone, scope or rule, before/after counts by bag, exact
visible status, and whether the action was automatic or manual. Keep source,
package, installation, and live-observation evidence separate.
