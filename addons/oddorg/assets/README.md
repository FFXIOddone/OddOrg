# OddOrg artwork

## Current direction — 2026-09-26

Mascot integration has been scrapped for the addon. Home displays character
status and Settings without Odd or character animations. Mascot assets and the
historical notes below are retained as artwork references only; animation work
is paused and these images are not loaded by the Home UI.

`crystal-header.png` is original artwork generated for OddOrg with the built-in
Image Gen tool on 2026-09-23. Resolution: 2172 x 724. It is a decorative background;
all labels, status, and controls are rendered separately by the addon.

Final generation prompt:

> Create one production background artwork asset for a premium in-game inventory assistant called OddOrg. No words, no letters, no numbers, no logo, no UI controls, no frames. Wide panoramic aspect ratio 3:1, ideally 1536x512. Sophisticated dark fantasy meets precision instrument design. Background is almost black blue graphite (#090f19), matte, extremely quiet on the left 60 percent so native UI text can be placed over it later. In the far right third, a beautiful sculptural cluster of translucent ice-cyan crystals with sharp physically rendered facets, a faint internal cool aqua glow and small restrained warm champagne-gold reflections; luxurious understated light rather than neon. Surround the crystal with one or two very subtle thin engraved astronomical arcs, barely visible geometry and soft volumetric haze, all localized to the right. No UI mockup, no text, no rectangular border, no grid, no starfield, no busy particles. Right-side crystal extends elegantly through the height with sufficient margin, everything fades naturally into the nearly black left. High-end game art, tactile, exquisite material rendering, cinematic controlled light, crisp details at small size, excellent dark negative space. This is a bitmap asset to load in a Lua/Ashita interface as a shallow banner; keep the central vertical band of the right artwork visually strong.

Keep this asset in the distributed addon folder. Do not load it from the
developer's image-generation directory or fetch it over the network at runtime.

## Required texture coverage for the item-route interface

The visual route layout is approved. The player requested textures throughout
the finished interface on 2026-09-23. Version 1.7.1 bundles the header plus
`destination-atlas.png` (1448 x 1086, RGBA) and `surface-atlas.png`
(1254 x 1254, RGB). Both new atlases are original built-in Image Gen outputs.
Their exact prompts are saved in `texture-prompts.json`.

The destination atlas contains Inventory, Satchel, Sack, Case, Safe, Safe 2,
Storage, Locker, Wardrobe, Moogle, locked, and ignored artwork. The four material
regions are graphite panel, leather slot, brushed-metal control, and engraved
route accent. `ui_art.lua` records inspected crop bounds: destination rows use
pixel ranges 0-325, 325-675, and 675-1040; artwork is not assumed to follow a
perfectly equal grid. Numbered wardrobe labels remain native text.

The current source uses the art in automatic-care rows, bag location displays,
manual tools, item icons, panels, route cards, and native controls. The route
preview and item-rule editor use the same production PNGs. Input fields receive a
light brushed-metal texture. On hover, controls ease into a still brushed-metal
surface with a layered cyan edge; the accent holds while hovered and fades on
exit. These source changes do not establish how the addon looks in the live client; see
`tests/PLAYTEST.md` for player-side checks.

Version 1.7.2 preserves every image asset. It removes the extra material square
behind individual icons, quiets button/panel textures, and displays locations as
horizontal cards with room for full bag names. Native client item artwork may
include its own background; OddOrg does not alter those client resources.

| Surface | Required visual treatment |
| --- | --- |
| Item browser and stack contents | The matching game item icon, resolved by item ID. Use runtime client resources where supported. Never show a generic crystal for unrelated items. |
| Inventory | Recognizable Inventory/bag artwork with clear carried-quantity overlays. |
| Satchel, Sack, Case | Distinct destination artwork for each portable bag; the selected bag name remains visible. |
| Safe, Safe 2, Storage, Locker | Recognizable artwork for each storage type, including access-state treatment. |
| Wardrobes | Cohesive wardrobe artwork with an unmistakable number for each destination. |
| Ephemeral Moogle | Recognizable Moogle artwork and a clearly separate deposit state. |
| Panels, item slots, controls | Subtle graphite/material textures consistent with the crystal header; quieter surfaces behind text and numbers. |
| Routes and states | Matching material accents for route connections, selection, hover, disabled, full, locked, and ignored states. Native arrows, icons, labels, and quantities remain clear over the artwork. |

Prefer existing local client resources when an actual supported loading path is
verified. Create and bundle original artwork where suitable resources are absent;
do not assume every bag or NPC has a callable native icon. Client-owned item
icons should be resolved at runtime rather than copied into a public addon pack.
Record the source or generation prompt for each bundled original asset.

Source reference verified on 2026-09-23: the installed `equipmon` addon's
`load_item_texture` resolves `GetItemById(itemid)`, reads `Bitmap` and `ImageSize`,
and uses `D3DXCreateTextureFromFileInMemoryEx` with `d3d.gc_safe_release`.
OddOrg now uses that resource path through `ui_textures.lua`, with visible-item
loading, a bounded 128-item cache, and per-device asset caching. Missing textures
fall back to readable controls. A player screenshot confirms the 1.7.1 textures
render in-game; the revised 1.7.2 composition still needs player observation.

Size artwork for the actual interface scale, retain transparent edges where
needed, and reuse cached textures. Loading, decoding, and texture creation must
not happen on every frame; release owned resources on unload/device changes.
Texture failure must preserve usable controls and readable labels. That fallback
does not count as completed artwork. Verify the packaged assets and their native
appearance before calling the textured interface finished.

## Home mascot

odd-home.png is a byte-identical copy of art/odd-blender-puppet-v01/stills/0001.png: the existing transparent equipped Odd idle render. Home draws it between the status text and Settings without recoloring or generating new artwork. The Settings-page banner keeps its existing artwork.

Home renders a five-second procedural breathing idle from odd-home.png. It uses 32 contiguous texture strips, fixed lower legs, gentle head lift and chest movement. The illustration remains mirrored and anchored to the header's right side. The animation uses ImGui time per displayed frame; unavailable timing falls back to the static image. This is a lightweight idle deformation, not playback of the Blender gesture movie. Native appearance and frame pacing require in-game review.

Blink review pass: Odd is now 168 x 252 logical pixels (twice the previous dimensions). odd-home-blink.png is rendered from the same Blender frame-1 pose with only the approved blink material enabled; provenance is in art/odd-blender-puppet-v01/home-blink-receipt.json. Only the eye region is composited over the breathing idle, closing/holding/reopening over 0.20 seconds every 6.6 seconds. Both textures are cached when Home draws. This pass adds blinking only; further expressions wait for user review.

Completion-smirk review pass: odd-home-smirk.png uses the same idle pose with the approved smirk material enabled. The face eases in over 0.25 seconds, holds, and eases out over 0.45 seconds (3.2 seconds total). Confirmed organization, crystal-run completion, or background work reaching ready triggers it; empty runs and cancellation do not. Repeated completions have a six-second cooldown, and blinking pauses during the smirk. Breathing and layout remain unchanged. Native event playback awaits user review.
