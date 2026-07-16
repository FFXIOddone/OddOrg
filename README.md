# OddOrg

## Use

Use `oddorg` in a Mog House while naked. Remove equipped gear first so equipment can be organized, and make sure the storage tabs you want to use are accessible.

Copy `addons/oddorg` into your Ashita `addons` folder, then load it in game:

```txt
/addon load oddorg
```

Open the button UI with `/oddorg`. The addon stays closed when loaded and only
opens when requested. Pick an organization scope, or choose **Crystals** to
trade crystals and clusters to a targeted Ephemeral Moogle. A tiny progress bar
is shown while either queue is running.

## Commands

```txt
/oddorg
/oddorg organize preview all
/oddorg organize run all
/oddorg organize stop
/oddorg organize status
/oddorg ephemeral dump all
/oddorg ephemeral stop
/oddorg ephemeral status
/oddorg probes on
/oddorg probes off
/oddorg probes clear
/oddorg probes status
```

Scopes: `all`, `wardrobes`, or `storage`.

Crystal scopes: `all`, `inventory`, or `storage`. Target an Ephemeral Moogle
before starting a crystal dump.

Options: `equipped`, `social`, `delay=0.8`, `probes`, `noprobes`.
