# Using OddOrg

For installation and a walkthrough of the three tabs, start with the
[README](../README.md).

## Why did an item stay where it was?

Open **Item rules** and select it. Check its carry target, Ignore setting,
storage destination, and any temporary manual choice. Also check whether the
destination is full or accessible. Automatic storage needs a character-level
automatic-care switch as well as permission to move the item.

Some partial stacks cannot be moved automatically without taking protected
copies with them. OddOrg leaves those stacks alone. Capacity checks can also
require a spare bag slot even when two stacks could eventually merge.

## Why aren't all my requested Inventory slots empty?

The slider sets a goal, not permission to move everything. Carried supplies,
ignored items, equipped or locked gear, access restrictions, and available
storage space can prevent reaching it. The goal is limited by your actual
Inventory capacity.

## What is the difference between carrying and ignoring?

**Keep in Inventory** maintains supplies you want available. When Free Inventory
slots is enabled, OddOrg can refill missing copies from eligible storage.

**Ignore** reserves copies that OddOrg must not move or deposit. It does not ask
OddOrg to bring them into Inventory. If you use both settings, they reserve
separate amounts.

## Do I need to reload after changing settings?

No. Click the relevant **Apply** button. Saved settings apply to subsequent
plans and runs. A change stops an active run and clears its old preview; select
**View Plan** again to continue with the new settings.

Reload only when installing updated addon files, or when deliberately resetting
session state. Reload clears temporary manual-move holds, pause state, and the
session freed-slot counter. Your saved rules remain.

## Why did a manual move change what OddOrg does?

A confirmed manual bag move creates a temporary hold for the amount you moved.
This helps prevent automatic care from immediately undoing your choice. New
copies do not inherit the hold; consuming held stock reduces it. You can release
the temporary choice in that item's rules. It is not a permanent rule change.

## Why did a run stop?

Read the reason shown in Bulk Run. Common causes include a full or unavailable
bag, changed settings, a manual movement, zoning, or an unconfirmed transfer.
Resolve the cause, then build a fresh plan. An already-sent action may still
finish after Stop, so let it settle before starting another run.

Organization also stops if a bag arrangement repeats or it reaches its 16-pass
safety limit. It reports remaining work instead of claiming completion. If that
persists with the same items, report the displayed reason and selected scope.

## Why won't automatic Moogle deposits repeat?

Automatic deposits make one attempt per approach, including an empty or blocked
attempt. Walk more than eight yalms away for at least two seconds before
approaching again, or deliberately use **Crystals > Deposit surplus** in Bulk Run.
Protected supplies stay protected. The Moogle must remain valid and in range.

## Where are the layout presets?

Start with **OddOrg Default** and change the item types you want stored differently.
You do not need a preset. If you have layouts saved by an older version, they
remain available for compatibility; the selector is hidden when there is only
one layout.

## Commands

Most players only need `/oddorg` to open the interface.

| Command | Action |
| --- | --- |
| `/addon load oddorg` | Load the addon. |
| `/addon reload oddorg` | Load updated addon files. |
| `/oddorg` | Open the interface. |
| `/oddorg auto pause` | Pause automatic care. |
| `/oddorg auto resume` | Resume automatic care. |
| `/oddorg status` | Show status. |
| `/oddorg organize preview all` | Preview organization of all bags. |
| `/oddorg organize run all` | Start organization directly from a command. |
| `/oddorg organize stop` | Stop organization and pause automatic care. |

Command-line organization also accepts `wardrobes` or `storage` instead of
`all`. Unlike the UI button, the `run` command does not require a displayed
preview. Prefer the UI if you want to review the plan first.

Advanced command options include `equipped`, `social`, and `delay=0.8`.
**`equipped` deliberately allows moving equipped gear.** It is not enabled by
normal UI runs. Explicit Ignore rules still apply.
