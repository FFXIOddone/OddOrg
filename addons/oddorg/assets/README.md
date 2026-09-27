# OddOrg artwork

## Used by the current UI

| Asset | Purpose |
| --- | --- |
| `surface-atlas.png` | Dark panel and control materials. |
| `destination-atlas.png` | Bag and feature icons where the current UI uses them. |
| Native item icons | Loaded from the player's client resources by item ID. Not redistributed here. |

The two atlases are original images generated with the built-in Image Gen tool.
Their prompts are recorded in `texture-prompts.json`. Crop bounds are defined in
`ui_art.lua`; destination rows are not assumed to be equal-height regions.

Home and Settings have text-only headers. Item rules lists current locations as
`Storage name: quantity`, without bag icons or location cards. Automatic-care
feature rows and the Bulk Run bag summary still use destination artwork.

## Retired artwork

These files are preserved for provenance and earlier installations. They are not
shown in the current Home or Settings headers:

- `crystal-header.png`
- `oddorg-seal-banner.png`
- `odd-home.png`, `odd-home-blink.png`, and `odd-home-smirk.png`

Mascot integration and the crystal/infinity banner were retired. Do not treat
these assets or their original prompts as the current UI specification. The
[UI guide](../../../docs/UI_PRODUCT_GUIDE.md) describes the accepted design.

The [seal notes](oddorg-seal-banner.md) record the retired banner's generation
history. `crystal-header.png` was generated on 2026-09-23 at 2172 × 724 pixels.
Its original prompt is retained below as a provenance record.

## Historical crystal-header prompt
Final generation prompt:

> Create one production background artwork asset for a premium in-game inventory assistant called OddOrg. No words, no letters, no numbers, no logo, no UI controls, no frames. Wide panoramic aspect ratio 3:1, ideally 1536x512. Sophisticated dark fantasy meets precision instrument design. Background is almost black blue graphite (#090f19), matte, extremely quiet on the left 60 percent so native UI text can be placed over it later. In the far right third, a beautiful sculptural cluster of translucent ice-cyan crystals with sharp physically rendered facets, a faint internal cool aqua glow and small restrained warm champagne-gold reflections; luxurious understated light rather than neon. Surround the crystal with one or two very subtle thin engraved astronomical arcs, barely visible geometry and soft volumetric haze, all localized to the right. No UI mockup, no text, no rectangular border, no grid, no starfield, no busy particles. Right-side crystal extends elegantly through the height with sufficient margin, everything fades naturally into the nearly black left. High-end game art, tactile, exquisite material rendering, cinematic controlled light, crisp details at small size, excellent dark negative space. This is a bitmap asset to load in a Lua/Ashita interface as a shallow banner; keep the central vertical band of the right artwork visually strong.

Keep this asset in the distributed addon folder. Do not load it from the
developer's image-generation directory or fetch it over the network at runtime.
