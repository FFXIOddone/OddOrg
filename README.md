# OddOrg

**Less inventory management. More room to play.**

OddOrg helps keep your FFXI bags organized. Choose where your items belong,
keep the supplies you need in Inventory, and let automatic care handle the
routine sorting. Review a plan before reorganizing your existing bags.

## Install

1. Download **[OddOrg-v1.12.0.zip](https://github.com/FFXIOddone/OddOrg/releases/download/v1.12.0/OddOrg-v1.12.0.zip)**.
2. Extract the `oddorg` folder into your Ashita `addons` folder.
3. In game, enter `/addon load oddorg`, then `/oddorg`.

Upgrading? Replace the addon files, keep your `config/addons/oddorg` settings,
and enter `/addon reload oddorg`.

OddOrg is built for Ashita. Server approval is separate from this download;
follow your server's addon rules.

## Start here

Open **Settings** from the Home screen. There are three places to work:

| Tab | What you do there |
| --- | --- |
| **Automatic care** | Choose which routine tasks OddOrg handles and where item types belong. |
| **Item rules** | Make exceptions for individual items, set supplies to carry, or leave items untouched. |
| **Bulk Run** | Review and organize the items already in your bags. |

Hover over labels and controls for explanations. **Apply** buttons appear when
you have changes to save. Settings are saved for each character and take effect
without restarting OddOrg.

## Automatic care

Turn on the tasks you want:

- **Free Inventory slots** — move eligible spare items into storage to work
  toward your chosen number of empty slots. The slider accepts **1–80**.
- **Sort incoming items** — put eligible incoming items where your rules say
  they belong.
- **Moogle deposits** — deposit eligible surplus crystals and clusters when
  you approach an Ephemeral Moogle.

Use **Apply automatic settings** to save your changes. **Pause all** temporarily
stops automatic care; resume it when you're ready.

### Choose where items go

OddOrg has a default arrangement you can customize. Under **Storage Layout**:

1. Choose an **Item type**.
2. Choose where to **Store in**.
3. Click **Set destination**, then **Apply layout**.

Leave a type on **OddOrg placement (base)** to use the default behavior, choose
an exact bag, or choose **Leave where it is**. Hover over an item type to see
what it means and examples from your bags.

You don't need to select a preset or create a named layout to get started.

### OddOrg Default

Each item type has a home and one overflow bag for new stacks:

| Item type | Home | Overflow |
| --- | --- | --- |
| General items, fish, logs | Satchel | Mog Safe 2 |
| Usable items and scrolls | Case | Mog Safe |
| Crystals and clusters | Sack | Mog Safe 2 |
| Quest items | Locker | Mog Safe 2 |
| Currency and other recognized non-equipment types | Mog Safe | Mog Safe 2 |
| Furnishings, plants, flowerpots, mannequins | Storage | Mog Safe |

Automatic care first fills compatible partial stacks in accessible bags, even
when those stacks are outside the configured home. Once a stack is full, the
next items use the home/overflow route. Stored stacks stay put during automatic
sorting. **Bulk Run** combines partial stacks first, then places the resulting
stacks according to your layout. Ignore rules and manual protections still apply.

Unavailable bags are skipped. If the preferred home and overflow are full,
OddOrg Default uses spare space in Safe, Safe 2, Satchel, Sack, Case, Locker,
then Storage, skipping bags already tried. This fallback never uses gear-only
wardrobes for ordinary items or overrides an explicit item destination.
If no accessible storage has room, items stay where they are.
Automatic placement into restricted **Storage** needs
a confirmed Mog House visit with OddOrg loaded; enter again after a reload if
needed. Equipment keeps the wardrobe arrangement. Unknown item
types and social items stay in place.

Inventory keeps **one stack per owned type** of prepared food/drink, common
HP/MP medicines, status remedies, Silent Oil, and Prism Powder when your
empty-slot target leaves room. Non-stackable medicines count as one item.
Existing carried supplies get priority when space is tight. Raw ingredients,
harmful status potions, ammo, and job tools do not receive automatic carry
targets; use Item rules for those.

Enable **Free Inventory slots** to refill supplies from accessible bags. Extras
follow the storage table when sorted. Saved carry targets and manual protections
take priority over the default slot budget, and a saved target of **0** disables
default carrying for that item. Changing the defaults does not overwrite your
saved destinations or item rules.

## Item rules

Find an item and choose how OddOrg should handle it:

- **Keep in Inventory** sets the number of individual items you want to carry.
  **+1 stack** adds one stack's worth to that number. With Free Inventory slots
  enabled, OddOrg can refill a shortfall from eligible accessible storage.
- **Target Storage Placement** chooses where extra copies belong. An exact bag
  takes priority over the general storage arrangement.
- **Ignore all**, **Ignore amount**, and **Ignore none** control how many copies
  OddOrg must leave untouched. Ignored copies are separate from your carry target.

Click **Apply item settings** when you're happy with the changes.

For example, you can keep a supply of an item in Inventory and send extras to
Sack, or choose **Ignore all** for something you don't want OddOrg to move.

Crystal and cluster rules also have a deposit option when a suitable staging bag
is selected. Review that option and the Moogle deposit status before enabling
automatic deposits. A storage destination alone does not grant deposit permission.

## Organize your existing bags

1. Open **Bulk Run**.
2. Under **Organize what...**, choose **All bags**, **Wardrobes**, or **Storage bags**.
3. Click **View Plan**. Review the bag summary or switch to individual moves.
4. Click **Run organization** when you're ready.

**Run organization** appears after the plan is displayed. **Stop** and **Status**
appear while work is running. Each run is limited to **50 transfers**, across
all its planning passes. A storage-to-storage move uses two transfers through
Inventory. Batches can stop below 50 to finish those transfers safely. Use
**View Plan** after a batch finishes to check and continue remaining work.

Bulk Run can temporarily stage items in free Inventory slots to consolidate
stacks or exchange items between full bags. The empty-slot slider, even at 80,
does not prohibit that temporary staging.

A plan with nothing to move says **Already organized — no moves needed**.
Changing settings invalidates an old plan; use **View Plan** again. If settings
change during a run, that run stops so it cannot continue using the old rules.

For a manual crystal deposit, choose **Crystals**, choose the source bags, then
**Deposit surplus** near an Ephemeral Moogle. This is separate from organization
and does not use the View Plan button.

## What to expect

- OddOrg does **not sell or discard items**.
- Normal organization leaves equipped gear alone and respects item protections.
- Your carried supplies and protected items take priority over the free-slot
  target. Setting 80 does not guarantee 80 empty slots.
- A specific destination chooses the home for new stacks. Automatic care may
  first fill an existing partial stack elsewhere; Bulk Run applies the destination.
- Storage access still matters. Use a Mog House where required; automatic
  stacking into **Storage** requires confirmed residence access.
- **Mog Safe 2** is included once OddOrg observes that your character has unlocked
  it. If it is missing after a reload, zone or log in again to refresh access.
- Avoid rearranging bags during a run. Manual moves can interrupt it, and
  confirmed manual choices receive temporary protection from being undone.
- Crystals and clusters you withdraw from an Ephemeral Moogle stay in Inventory
  for the session. Breaking a protected cluster also protects its twelve crystals;
  unrelated crystals you obtain later still follow your normal rules.
- If a move cannot be confirmed, OddOrg stops and tells you. Check your bags
  before trying again. Check your Moogle's balance after a crystal deposit.
- If storage validation takes too long, OddOrg stops the move. Let the client
  settle and check your bags before starting a fresh plan.
- **Stop** also pauses automatic care. Resume it from Automatic care when ready.

## Help

- [Report a problem](https://github.com/FFXIOddone/OddOrg/issues)
- [Release notes](https://github.com/FFXIOddone/OddOrg/releases/tag/v1.12.0)
