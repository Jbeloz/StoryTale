# Humanoid Outfits

Use the canonical `character_sheet_v1` guide. Keep its exact dimensions and
separated-parts arrangement, but place generated appearance pixels only in
the nine body cells; the head stays reference-only. StoryTale removes green,
cuts the versioned rectangles locally, applies the matching body masks, and
attaches every accepted overlay to its existing rig part.

Sleeves follow arm parts, trousers follow leg parts, and shoes follow
lower-leg parts. Long skirts, capes, and loose coats remain separate anchored
extension layers because they cannot bend cleanly with both legs. See
[Character Sheet V1 Plan](../../../../../../CHARACTER_SHEET_PLAN.md).
