# OddOrg UI product guide

Current UI requirements for maintainers, updated for OddOrg 1.11.0.
For player instructions, read the [README](../README.md).

## Purpose and authority

Read this before changing OddOrg's UI, copy, or interaction flow. It records
what the owner has asked for and why those decisions belong together. Newer
owner instructions override it. Historical artwork and README release notes
are not permission to restore a superseded design.

This is a product acceptance guide, not a claim that every state has been
observed working in-game. Source changes and production installation are
separate from player-visible verification.

## What a very good finished product looks like

OddOrg removes inventory work with a compact, legible, visually considered
interface. The next action is obvious. Explanations are available at the point
of use. A player does not have to interpret a paragraph of status messages,
repeat an operation to finish its work, or guess whether settings were saved.

The desired quality is high-end and distinctive. Detail belongs in the
materials, spacing, typography, and interaction quality. Adding more visible
content or decorative motion does not establish that quality.

### Core rules

1. **Give every visible element a current purpose.** Keep necessary labels,
   selected values, useful quantities, relevant failures, and the next action.
2. **Put explanation on the thing it explains.** Hover a heading, label,
   dropdown, checkbox, or button for help. No separate `(?)` markers.
3. **Reveal controls when they become useful.** An inactive action need not
   occupy space as a disabled button. Keep navigation and scope choices visible.
4. **Keep related information together.** Carry numbers belong with the carry
   control, destination behavior with placement, protection with Ignore.
5. **Let containers fit their contents.** No large blank grey slabs, detached
   footers, or empty space reserved for a hidden action.
6. **Make completion meaningful.** A finished organization run must check the
   resulting bags and find no remaining moves in the selected scope. A stopped
   or blocked run must say so rather than claim completion.

## Information hierarchy and tooltips

| Information | Treatment |
| --- | --- |
| Section or field name | Short visible label, using established heading styles |
| Instructions, definitions, fallback behavior | Tooltip on the related element |
| Item classification | Plain-language description plus one or two real matching item examples |
| Current quantities or meaningful targets | Visible beside the related control |
| Blue summary with only zero quantities | Hidden |
| Narrative destination summary repeating the selector | Tooltip |
| Eligible-to-store summary | Visible when there are items/slots eligible to move; hidden at zero |
| Saved confirmation | Appears after successful saving, then expires; current implementation uses three seconds |
| Unsaved changes / save failure | Visible while actionable |
| Running progress | Visible during the operation |
| Result or preview | Appears in response to an action, inside the owning container |
| Blocking failure | Visible with enough information to recover |

Grey explanatory text is a strong signal that the content should be a tooltip.
Do not mechanically hide all grey or white text: quantities, errors, and save
feedback may still be necessary. Decide by purpose, not color alone.

Tooltip copy should answer the player's question, not describe implementation
details. For example, explain what a usable item is and name matching items;
"resource type 7" is not an adequate explanation. Use the current bag/preview
snapshot for examples, deduplicate them, and do not invent an example when no
matching item is available. Counts mean individual items unless explicitly
labeled otherwise; avoid ambiguous `0 / 0` and unexplained "units".

Tooltips must attach to the intended element, remain readable within the screen,
and avoid adding permanent vertical space. Preserve keyboard access where the
existing control supports focus.

## Visual and layout requirements

- Retain the established dark textured surfaces and restrained gold/cyan palette.
- Container backgrounds must blend consistently; avoid mismatched opaque grey
  regions revealing oversized child panels.
- Size cards from actual wrapped text and controls, not a generous fixed height.
- Keep primary controls reachable. Let the editor reclaim footer space when
  Apply and confirmation text disappear.
- Keep layout stable as status text changes. Do not anchor artwork or unrelated
  controls to changing text widths.
- Hover effects should be restrained and visually deliberate. The owner rejected
  animations that merely demonstrated that something could move.
- Check narrow widths, wrapping, font scale, and long names. A source-level size
  calculation alone does not prove the screen looks correct.
- Use supported text glyphs. The attempted infinity window title rendered as `?`;
  do not repeat unsupported font/glyph assumptions.

## Screen contracts

### Home

- Compact identity and status panel with Settings in the header.
- Character name is prominent; the owner requested 1.5 times its former size.
- Avoid a redundant OddOrg label inside the header.
- Status uses separate short lines: care state, incoming-item state, free
  Inventory slots, and items freed this session. No semicolon joining the last
  two and no trailing period on the freed count.
- Opening dimensions are Home **360 x 223 px** and Settings **855 x 646 px**,
  taken from Oddone's current saved runtime dimensions on 2026-09-26. Reset to
  these dimensions when a window opens; allow manual resizing afterward.
  This supersedes continuous content-height snapping. Keep the compact inner
  spacing around Settings. Minimum usability constraints still apply at larger
  font scales, and there is no application maximum-size cap.
- No mascot, breathing, blinking, completion expression, or mascot dialogue.

### Automatic care

- Empty Inventory slots setting comes before the three toggle cards.
- Omit the redundant Currently on/off label. Put the Empty Inventory slots
  (1-80) explanation on the slider tooltip; keep its numeric value visible.
- Group Free Inventory slots, Sort incoming items, and Moogle deposits together.
- Toggle descriptions are tooltips on the title/control; cards fit the shorter
  content after the descriptions are removed.
- Apply automatic settings is visible only for unsaved changes.
- Saved for this character appears briefly only after successful saving.
- Pause/Resume remains correctly positioned when Apply is hidden.
- The Settings banner currently has no illustration. Do not add replacement art
  without a new direction from the owner.
- Its refined text-only design uses a muted character name above the tab title,
  the shared dark texture, and a narrow gold accent. Fit its height to the two
  lines; omit the redundant `/ ODDORG` branding.
- The Settings header never scrolls. Its accent is green when any automatic-care
  switch is enabled and care is not paused, otherwise gold. Home uses the same
  state to color the player name green; green means enabled, not a packet in flight.
- OddOrg defaults are the base for a customizable layout, not a collection of
  speculative preference presets. Retain old saved layouts for compatibility.
- Player documentation should lead with tasks and item placement. Do not market
  quicksets or legacy presets as a main feature or a required setup step.
- Label the base option **OddOrg Default**. Show the active-layout label and
  selector only when more than one layout is available. Automatic care always
  keeps its gold STORAGE LAYOUT heading above the item-type placement editor.
  Bulk Run hides its Storage Layout heading together with the single-layout selector.
- Show the gold LAYOUT PREVIEW heading only when the draft contains placement
  routes or explicit leave-in-place rules to display.

### Item rules

- Current stock is plain `<storage name>: <quantity>`, such as `Safe: 10`.
  No storage icons or surrounding location cards. This supersedes the earlier
  enlarged-icon design. The selected item's own icon is a separate element.
- Keep in Inventory has a numeric input followed inline by one **+1 stack**
  shortcut. Remove the redundant "Items to carry" label.
- +1 stack adds the item's real stack size to the existing amount; it does not
  replace the amount. No two-stack shortcut. The Ignore shortcut is additive too.
- Use **Target Storage Placement** instead of "Store Extra Items".
- Put the automatic-actions-off explanation on the automatic-storing checkbox.
- Keep preview quantities near their controls; do not restore the duplicate
  bottom cards and paragraph pile.
- Apply item settings appears only for changes that need saving. Reverting to
  the saved values should hide it again.
- Saved item rules appears briefly after a successful save. The editor expands
  into the space when the footer is not needed.
- Leave copies untouched remains a supported protection distinct from carry
  targets and placement. Moving it into an advanced section was suggested by
  the assistant, but has **not** been approved by the owner.

### Bulk Run

- Tab/title: **Bulk Run**, not "First Bulk Run".
- No decorative chest/scope image above the controls. Label: **Storage Layout:**.
- Scope heading: **Organize what...**. No numbered instructional headings.
- All scope-choice buttons remain visible, including during a run; existing
  safety disabling can prevent changing scope while work is active.
- Organization flow:
  1. At rest, show View Plan as the next action, spanning the scope-button area
     at twice the normal button height. Run organization appears on its own row.
  2. After a successful preview has been displayed, reveal Run organization.
     This includes zero-move plans; keep the no-moves explanation visible.
  3. While running, reveal Stop and Status.
  4. At idle, hide Stop and Status. A new run requires another preview.
- Changing scope or layout, or dismissing the preview, invalidates readiness to run.
- Saved settings apply to the next plan and run without an addon reload. Settings
  updates discard old previews and stop active queues. Only interrupted work gets
  a cancellation notice; a successful View Plan clears the old organization error.
- Organization Preview is embedded in the Bulk Run container. Individual moves
  and bag summaries switch within it; no detached preview window.
- Put the fresh-plan explanation and Safe2 fallback explanation on Run
  organization's tooltip. Keep actual run failures visible.
- Bag-summary classification rows have descriptive tooltips and real examples.
- Show run progress and relevant results on demand. Do not carry unrelated
  Item rules or Automatic care notices into this page.
- Crystal deposits currently have a separate Deposit surplus action, without
  an organization preview gate. Their Stop/Status buttons also appear only
  while active. Do not claim that a crystal preview flow already exists.

## Functional quality behind the UI

- Bring compatible partial stacks together across accessible storage bags when
  item rules and protections permit; merely sorting each bag is insufficient.
- Confirm transfers and stack consolidation before treating them as complete.
- One user-triggered organization run may need multiple internal planning passes
  as merges free capacity. Continue from confirmed state until a fresh plan finds
  no moves. Detect cycles and stop with an honest error at safety limits.
- Preserve carry targets, protected quantities, explicit destinations, access
  checks, and saved preferences. UI cleanup must not silently change these rules.
- Report actual quantities and transfers. Crystal units, stacks, bag transfers,
  and trade batches are different measurements.

## Decisions not to resurrect

| Superseded direction | Current direction |
| --- | --- |
| Mascot and companion integrated into addon UI | Removed; artwork retained separately |
| Crystal dragon/infinity Settings illustration | No banner illustration for now |
| Enlarged bag icons in Item rules | Plain storage name and quantity |
| Permanent help paragraphs and `(?)` hints | Help on existing text or controls |
| Always-visible Apply / Saved labels | Event-driven visibility |
| Detached organization detail window | Embedded preview |
| One queue exhausted means complete | Fresh plan must confirm no remaining moves |

## Before calling a UI change finished

Review the affected screen at rest, after an edit, after reverting the edit,
after saving, after the confirmation expires, during work, after completion,
and on a relevant error. Only the applicable states need attention for a narrow
change. Check that hidden content reclaims its space and that tooltips belong
to the intended targets. Confirm no old wording or duplicate explanation remains.

Report evidence honestly: implemented, syntax-checked, installed, and observed
in-game are different states. Never control or capture an FFXI window with
desktop automation. Use permitted passive evidence and owner-supplied review.
Do not label the product "100% correct" merely because the latest edit shipped.

When the owner changes direction, update the relevant contract and superseded
decision here, preserving unrelated decisions. Keep this guide practical rather
than turning it into a second implementation or a new validation framework.
