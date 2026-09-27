# Development and testing

Player instructions belong in the [README](../README.md) and
[usage guide](USING_ODDORG.md). This page is for maintaining OddOrg.

## Current references

- [Product behavior](../PRODUCT.md)
- [UI requirements](UI_PRODUCT_GUIDE.md)
- [Player test checklist](../tests/PLAYTEST.md)
- [1.11.0 audit](RELEASE_CANDIDATE_AUDIT_2026-09-26.md)
- [Active and retired artwork](../addons/oddorg/assets/README.md)

## Offline checks

From the repository root, with LuaJIT available:

```text
luajit tests/run.lua
luajit tests/storage_layout_test.lua
luajit tests/ui_textures_test.lua
luajit tests/textured_skin_test.lua
```

The main suite replaces Ashita state and transport with local test doubles. It
fails if code attempts real packet-manager access. Texture tests use inert
native stubs. These checks do not operate a game client.

Set `ODDORG_TEST_FILTER` to a case-name substring to run a focused main-suite
check. Clear it before a full run. Compile changed Lua modules with `luajit -b`
and review `git diff --check` before packaging.

Keep regression cases for protection precedence, settings persistence and
failure recovery, changing characters, loaded-bag checks, transfer confirmation,
timeouts, convergence, and UI action visibility. Update obsolete UI fixtures
when an accepted design changes; retain behavioral assertions.

## Packaging

The install ZIP has an `oddorg/` directory containing the files from
`addons/oddorg/`. Do not package player settings, runtime logs, local experiments,
or development-only character models. Preserve existing settings during upgrades.

Verify the extracted package, include checksums, and verify the published
download. Record source checks, installed-file checks, and player observations
separately. Server approval is a separate process handled by the project owner.

## Historical material

Versioned audit reports describe the state and evidence at the time they were
written. They are not current player instructions. Retired banner and mascot
notes are provenance records, not requests to restore those features.
