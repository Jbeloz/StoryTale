# StoryTale Character Sheet V4 1K Provider Contract

This is a strict fixed-layout image-edit request for one coherent StoryTale
character. It is not a request for another assembled body.

## Request fields

- `ACTOR_ROLE`: `default` for the checked-in guide; the same geometry may later
  be used for `heroine` with heroine-specific references.
- `CHARACTER_NAME`: approved Story Bible display name.
- `CHARACTER_BRIEF`: source-backed appearance description only.
- `OUTFIT_BRIEF`: one coherent outfit fitted across all body-piece cells.
- `HAIR_BRIEF`: one coherent front hairstyle plus Short, Medium, and Long rear
  length options using the same color, texture, and design language.

These fields never permit changes to the locked geometry contract.

## Required provider inputs

1. `guide.png` - the exact `2048 x 512` V4 transport layout.
2. `assembled_reference.png` - how the locked default actor parts connect.
3. `allowed_regions.png` - white pixels may contain generated appearance.
4. `protected_regions.png` - white pixels must preserve the locked source.
5. `seam_allowances.png` - white markers identify required connections.
6. `crop_manifest.json` - the only valid cells, scales, anchors, and outputs.

## Exact provider-output contract

- Return one PNG at exactly `2048 x 512` using `4:1` and provider size `1K`.
- Keep every transport crop at its exact manifest coordinates and size.
- Keep untouched background exactly flat `#00FF00`.
- Do not move, rotate, merge, tightly crop, label, or border any cell.
- Do not resize artwork inside a transport cell.
- Draw only inside white pixels from `allowed_regions.png` and preserve every
  protected white pixel.
- Keep each connection covered through its transport seam marker.

## V4 transport rule

V4 cells are uniformly reduced transport copies of the exact Sprite Studio
output canvases. StoryTale, not the provider, will mask each complete crop,
resize it exactly once to the manifest's `outputCanvas`, and reapply the hard
output mask. The provider must not compensate by enlarging or repositioning
artwork inside a cell.

## Hair catalog rules

- Draw one front-hair layer in `front_hair`.
- Draw matching rear-hair alternatives in `back_hair_short`,
  `back_hair_medium`, and `back_hair_long`.
- All hair layers belong to the same character and share color, line style,
  texture, highlights, crown, and hairline logic. Only rear length differs.
- Every rear option must attach correctly to the same front hair and head.
- Hair remains independent from head and body pixels.
- `none` remains a runtime visibility option and requires no image cell.

## Character and clothing rules

- The checked-in guide and assembled reference use actor `default`.
- Heroine use keeps every crop, scale, mask, anchor, seam, and final output
  unchanged; only the brief and actor-specific hair references change.
- Keep one identity across face details, hair options, palette, and outfit.
- In `head`, modify only the allowed facial-detail area. Never redraw the skull,
  ears, skin base, neck edge, or protected pixels.
- In body cells, draw only clothing fitted to that exact separated body part.
- Keep right-side artwork in right-side cells and left-side artwork in
  left-side cells.
- Do not add scenery, shadows, text, props, extra characters, replacement
  anatomy, or unrelated objects.

## Rejection conditions

Reject the result if its format or dimensions differ, a transport cell moves,
green background changes outside allowed pixels, locked geometry changes, hair
options describe different characters, clothing misses seams, or the upscaled
parts cannot reproduce the supplied assembled character. V4 also remains
unaccepted if its 1K face, hair edges, clothing seams, or pose proofs are
visibly worse than the V3 2K fallback.
