# OddOrg release candidate audit

## Verdict

Offline release-candidate checks passed after one safety fix. No additional
confirmed blocker remained in this bounded audit. This is not proof of every
server/runtime condition, nor a public release or release tag.

Release follow-up: the owner subsequently reported the final player check passed
and authorized publication of 1.11.0. Discord approval submission remains with the
owner; publication does not imply third-party approval.

## Scope and findings

- Reviewed settings save/reload, current-rule planning, dispatch validation,
  confirmation, multi-pass completion, protection precedence, failure recovery,
  UI state transitions, native texture lifetime, and installed-file parity.
- **Fixed: equipped gear was only pinned during planning.** A direct move or
  equipment change between planning and dispatch could bypass that protection.
  Every ordinary gear transfer now checks the current equipment slots immediately
  before dispatch. Unreadable equipment state rejects the move. The documented
  explicit `equipped` organization option remains supported; keep rules still win.
- Updated obsolete test fixtures for the accepted UI: hidden clean-state actions,
  View Plan, two-frame preview visibility, plain storage quantities, text-only
  banner, base-layout overrides, slider range, and final convergence check.
  Removed old crystal-banner texture assertions; shared texture lifecycle remains
  independently covered by the texture backend suite.
- Added regressions for direct/queued equipped gear, unavailable equipment,
  explicit opt-in, repeated-state stopping, additional planning passes, protected
  partial-stack consolidation, the 80/81 slot boundary, and zero-move Run visibility.

## Evidence

All commands run from the repository root with inert Ashita/native stubs:

| Check | Result |
| --- | --- |
| `luajit tests/run.lua` | 148 cases passed; zero real packet-manager accesses |
| `luajit tests/storage_layout_test.lua` | Passed |
| `luajit tests/ui_textures_test.lua` | 5 cases passed |
| `luajit tests/textured_skin_test.lua` | 12 cases passed |
| LuaJIT bytecode compilation of all 8 addon Lua modules | Passed |
| `git diff --check` | Passed |

The main suite covers save failure recovery, character isolation, live preference
replacement without addon reload, current protections on new plans/runs, reserve
accounting, loaded-bag gates, confirmation timeouts, deposit staging, and manual
movement cancellation. Focused tests are available through `ODDORG_TEST_FILTER`.

Audited main-file SHA-256:
`BC948E1CC98E988F09637BB22268051AACB2D7B4B950D520A416C0D680D945BB`.

Before installation, all 18 source package files matched production except this
new main-file fix. Installation uses a verified backup and an exact-file manifest
in the operator's local workspace backup directory (timestamped receipt).

Workspace doctor had zero errors and three unrelated workspace housekeeping
warnings. OddOrg's local checks above are the applicable verification path.

## Limits and final player check

- No game window was captured or controlled; no packets or game commands were
  issued by the audit. Passive logs show successful earlier addon loads and a
  zero-move plan, not live proof of the newly installed guard.
- Reload once to load the code fix. Subsequent settings changes require no addon
  restart. Review View Plan, run a real organization, and confirm completion plus
  a fresh zero-move plan. Confirm equipped gear stays in place and saved item
  changes affect the next plan. Crystal deposits still require a live balance
  check; offline removal confirmation cannot prove the Moogle's credited balance.
- Full target bags use conservative capacity checks. A merge that requires a
  spare physical slot can still be blocked; this is documented behavior.
- Organization stops honestly on a repeated bag state or the 16-pass bound.
  Offline checks confirm the stop path; they do not claim every inventory layout
  can be completed within that bound.
