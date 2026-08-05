# StoryTale Character Sheet V4 Provider Contract

This is a strict fixed-layout image-edit request for one coherent StoryTale
character. It is not a request for a second full-body illustration.

V4 is V2's cell set on the smallest supported square canvas. It differs from V3
in exactly two ways: the canvas is `1024 x 1024` at the `1:1` aspect ratio
instead of `4096 x 1024` at `4:1`, and there is one selected rear-hair cell
instead of three alternatives. Every cell keeps its native size, so each
extracted part has the same pixels it would have in V2 or V3.

## Request fields

- `ACTOR_ROLE`: `default` for the checked-in guide; the same geometry may later
  be used for `heroine` with the heroine brief and actor-specific references.
- `CHARACTER_NAME`: approved Story Bible display name.
- `CHARACTER_BRIEF`: source-backed appearance description only.
- `OUTFIT_BRIEF`: one coherent outfit fitted across all body-piece cells.
- `HAIR_BRIEF`: one coherent front hairstyle plus the single rear length named
  by `BACK_HAIR_SELECTION`.
- `BACK_HAIR_SELECTION`: one of `short`, `medium`, `long`, or `none`.

They are data fields, not permission to change the geometry contract.

## Required provider inputs

1. `guide_<actor>_<length>.png` - the exact `1024 x 1024` separated-part layout,
   using the variant whose rear-hair silhouette matches `BACK_HAIR_SELECTION`.
   `guide_default_short.png`, `guide_default_medium.png`, and
   `guide_default_long.png` are published for the `default` actor. Every variant
   shares identical cells, masks, anchors, and seams; only the shape drawn in
   `back_hair_selected` differs. For `none`, send the `medium` guide and leave
   that cell flat green.
2. `assembled_reference.png` - how the locked default actor parts connect.
3. `allowed_regions.png` - white pixels may contain generated appearance.
4. `protected_regions.png` - white pixels must preserve the locked source.
5. `seam_allowances.png` - white markers identify required connection points.
6. `crop_manifest.json` - the only valid cells, sizes, anchors, and role data.

## Exact output contract

- Return one PNG at exactly `1024 x 1024` using the `1:1` aspect ratio and `1K`
  provider size.
- Keep every crop at the exact coordinates and dimensions in the manifest.
- Keep the untouched background exactly flat `#00FF00`, including the `18` pixel
  gap around every cell.
- Do not move, rotate, merge, tightly crop, resize, label, or border any cell.
- Every crop already equals the exact raster canvas assembled by Sprite Studio.
- Do not draw outside the white pixels in `allowed_regions.png`.
- Preserve the white pixels in `protected_regions.png` exactly.
- Keep every required connection covered through its seam marker.

## Hair rules

- Draw one front-hair layer in `front_hair`.
- Draw one rear-hair layer in `back_hair_selected`, at the length named by
  `BACK_HAIR_SELECTION` and matching the silhouette in the supplied guide
  variant.
- One request produces one length. To offer a character in several lengths,
  send one request per length using the matching guide, and keep
  `CHARACTER_BRIEF`, `OUTFIT_BRIEF`, and the palette byte-identical between
  those requests so the results stay the same character.
- Both hair layers belong to the same character: identical color, line style,
  texture, highlights, and crown/hairline logic.
- The rear layer must attach correctly to the same front-hair layer and head.
- Hair stays independent from the head and body pixels.
- `none` means leave `back_hair_selected` flat green; it is a runtime visibility
  choice and needs no artwork.

## Character and clothing rules

- Use the request's actor role and source-backed brief. The checked-in guide and
  assembled reference currently use the `default` actor.
- The same fixed layout is heroine-compatible because the heroine uses the
  same `humanoid_v1` geometry. Before a heroine provider request, StoryTale must
  supply the heroine brief and actor-specific hair references without changing
  any crop, mask, anchor, seam, or output size.
- Keep one identity across the face details, hair, palette, and outfit.
- In `head`, modify only the allowed facial-detail area. Do not redraw the
  locked head silhouette, ears, neck edge, or protected pixels.
- In body cells, draw only clothing fitted to that exact body part.
- Right-side artwork stays in right-side cells and left-side artwork stays in
  left-side cells.
- The separated head, torso, arms, legs, and selected hair option must assemble
  into the supplied Sprite Studio character without changing pivots or seams.
- Do not add scenery, shadows, text, props, extra characters, or unrelated
  objects.

## Clothing continuity across joints

This is the part most likely to fail, so it is stated explicitly.

Garments are drawn in separate cells but must read as one outfit on the
assembled character. Each body cell carries seam markers at the joints it shares
with its neighbour:

- `torso` meets `head` at the neck, both upper arms at the shoulders, and both
  upper legs at the hips.
- each `upper_arm_*` meets `torso` at the shoulder and its `lower_arm_*` at the
  elbow.
- each `upper_leg_*` meets `torso` at the hip and its `lower_leg_*` at the knee.

Where a garment crosses one of those joints, its edge colour, thickness, trim,
fold direction, and shading must match on both sides of the seam, so the two
cells line up when the rig is posed. A sleeve that ends at the elbow in
`upper_arm_right` must continue at the same width and colour where
`lower_arm_right` begins.

## Rejection conditions

Reject the result if its format or dimensions differ, a cell moves or resizes,
green background is altered outside allowed pixels, locked geometry changes,
front and rear hair describe different characters, clothing fails to match
across a seam, or the separated parts cannot reproduce the supplied assembled
character.
