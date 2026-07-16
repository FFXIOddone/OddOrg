# OddOrg

## Use

Use `oddorg` in a Mog House while naked. Remove equipped gear first so equipment can be organized, and make sure the storage tabs you want to use are accessible.

Copy `addons/oddorg` into your Ashita `addons` folder, then load it in game:

```txt
/addon load oddorg
```

Open the button UI with `/oddorg`. The addon stays closed when loaded and only
opens when requested. Pick a scope, then preview or run the organizer. A tiny
progress bar is shown while organization is running.

## Commands

```txt
/oddorg
/oddorg organize preview all
/oddorg organize run all
/oddorg organize stop
/oddorg organize status
/oddorg probes on
/oddorg probes off
/oddorg probes clear
/oddorg probes status
```

Scopes: `all`, `wardrobes`, or `storage`.

Options: `equipped`, `social`, `delay=0.8`, `probes`, `noprobes`.
