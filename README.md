# OddOrg

**Less inventory management. More room to play.**

OddOrg helps keep your FFXI bags organized. Choose where your items belong,
keep the supplies you need in Inventory, and let automatic care handle the
routine sorting. Review a plan before reorganizing your existing bags.

## Install

1. Download **[OddOrg-v1.11.0.zip](https://github.com/FFXIOddone/OddOrg/releases/download/v1.11.0/OddOrg-v1.11.0.zip)**.
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
appear while work is running. OddOrg checks the bags again as it works so you
shouldn't need to repeat the same run just to finish the plan.

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
- A specific destination stays specific. If that bag is full or unavailable,
  OddOrg will not quietly choose another one.
- Storage access still matters. Use a Mog House where required; restricted
  **Storage** moves are handled by a manual bulk run.
- Avoid rearranging bags during a run. Manual moves can interrupt it, and
  confirmed manual choices receive temporary protection from being undone.
- If a move cannot be confirmed, OddOrg stops and tells you. Check your bags
  before trying again. Check your Moogle's balance after a crystal deposit.
- **Stop** also pauses automatic care. Resume it from Automatic care when ready.

## Need more detail?

- [Common questions and commands](docs/USING_ODDORG.md)
- [What's new in 1.11.0](docs/releases/v1.11.0.md)
- [Report a problem](https://github.com/FFXIOddone/OddOrg/issues)
- [Development and testing](docs/DEVELOPMENT.md)
