# StoryTale Character Sheet V2 Provider Prompt Contract

Contract ID: `character_sheet_v2`

Contract version: `2`

Required output: one `2048 x 2048` PNG (`2K`, `1:1`)

This contract is used only after the Story Bible has approved one source-backed
character design. Values inside `{{double_braces}}` are supplied by StoryTale.
They are data fields, not permission to change the contract.

## Required provider inputs

1. `guide.png` - the exact balanced transport layout.
2. `assembled_reference.png` - how the locked parts connect locally.
3. `allowed_regions.png` - white pixels may contain generated appearance.
4. `protected_regions.png` - white pixels must preserve the locked source.
5. `seam_allowances.png` - white pixels are the only approved joint overlap.
6. The approved character design brief and selected back-hair length.

## Prompt template

Create the separated appearance sheet for one coherent StoryTale character.
First reason about the character as one complete front-facing person, then draw
only the permitted separated appearance artwork into the supplied guide cells.

Character identity: `{{character_name}}`

Source-backed design brief: `{{character_design_brief}}`

Age and role: `{{age_and_role}}`

Skin tone: `{{skin_tone}}`

Hair requirements: `{{hair_requirements}}`

Selected back-hair length: `{{short|medium|long|none}}`

Outfit requirements: `{{outfit_requirements}}`

Approved accessories for this request: `{{approved_accessories_or_none}}`

Use one consistent identity, palette, material treatment, lighting, line
weight, and rendering style across every active region. The face, front hair,
selected back hair, torso clothing, sleeves, gloves, trousers, stockings,
boots, armor, trim, and patterns must all belong to that same character.

## Non-negotiable layout rules

- Return exactly one `2048 x 2048` PNG using the `2K` image size.
- Keep every crop rectangle at the exact position and size recorded in
  `crop_manifest.json`.
- Keep the untouched background exactly flat `#00FF00`.
- Do not move, rotate, merge, tightly crop, or add borders around any cell.
- The larger body cells and smaller hair cells are transport regions. Do not
  infer new anatomy or change the proportions of the supplied part inside one.
- Draw the chosen Short, Medium, or Long design only in
  `back_hair_selected`. If the selection is `none`, leave that slot green.
- Keep right-side artwork in right-side cells and left-side artwork in
  left-side cells.
- Artwork outside white pixels in `allowed_regions.png` will be discarded.
- Pixels marked white in `protected_regions.png` must remain the locked source.
- Joint overlap is allowed only where `seam_allowances.png` is white.

## Anatomy and content rules

- The supplied head and nine body pieces are immutable anatomy references.
- Do not replace or redraw the skull, ears, skin base, torso, arms, hands,
  legs, feet, silhouettes, pivots, padding, or proportions.
- In the head cell, add only face details supported by the brief.
- In body cells, add only clothing fitted to that exact body part.
- Hair must remain an independent front or back layer; never attach it to the
  head pixels.
- Leave a clothing cell green when that body area is intentionally uncovered.
- Do not invent details absent from the approved Story Bible brief.

## Forbidden output

Do not add an assembled character, another person, duplicate body parts,
scenery, furniture, props outside approved cells, text, labels, borders,
guides, UI, signatures, logos, watermarks, gradients in the green background,
or explanatory panels. Return the separated sheet only.

## Provider failure behavior

If the requested exact canvas or edit contract cannot be followed, return an
error to StoryTale. Do not silently substitute another size, layout, or image.
StoryTale does not automatically retry or repair a failed sheet.
