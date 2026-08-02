# Character Clothing Sheet Plan

## Goal

StoryTale will create book characters by dressing the locked Sprite Studio
template, not by asking Gemini to draw a complete character. One Gemini image
request produces one fixed-layout clothing sheet. StoryTale then removes the
flat background, cuts the known cells locally, and attaches each clothing PNG
to its matching rig part.

The separated body-parts image supplied for this plan becomes the starting
layout reference. Before implementation it must be copied into the project as
a versioned canonical template and paired with an exact crop manifest.

## Decisions

- The existing `humanoid_v1` head and nine body pieces never change.
- Gemini designs clothing only. It must not generate a new head, body, pose,
  face, hand, or leg shape.
- The sheet keeps the exact input width, height, cell positions, orientation,
  and spacing.
- One approved crop manifest defines the cells. StoryTale does not use AI to
  find or cut the parts.
- Green is removed locally after generation. No second provider request is
  needed for transparency.
- Poses remain local transform JSON. Clothing follows the same bones as the
  body part underneath it.
- A character's sheet is generated once and reused in every chapter and pose.
- There is no automatic regeneration loop. A failed result becomes
  `needsAttention` and keeps the safe undressed/template fallback.

## Canonical sheet

The sheet contains the unchanged reference head plus these nine fixed clothing
slots:

1. `torso`
2. `upper_arm_right`
3. `lower_arm_right`
4. `upper_arm_left`
5. `lower_arm_left`
6. `upper_leg_right`
7. `lower_leg_right`
8. `upper_leg_left`
9. `lower_leg_left`

The head is an alignment and style reference only. The normal clothing sheet
must leave its head cell empty. Hair, facial parts, hats, crowns, glasses, and
other head items use their own component groups.

The canonical files will be:

```text
assets/images/characters/generation_templates/humanoid_v1/clothing_sheet_v1/
|-- guide.png
|-- allowed_regions.png
|-- protected_regions.png
|-- crop_manifest.json
`-- prompt_contract.md
```

`crop_manifest.json` stores the sheet dimensions and one fixed rectangle,
anchor, output canvas, side, and layer role for every slot. These values may be
hard-coded for `clothing_sheet_v1`, but they must live in one versioned
manifest instead of being repeated across widgets and services.

## Gemini request

Gemini receives:

1. the exact canonical clothing guide;
2. the character's source-backed design brief;
3. garment names, materials, colors, and role details;
4. the fixed slot map and left/right labels; and
5. one approved StoryTale clothing-sheet example when available.

The prompt requires:

- output the exact same sheet dimensions and arrangement;
- keep every garment aligned over its matching body-part guide;
- show clothing pixels only on pure `#00FF00` green;
- do not draw skin, anatomy, a face, hair, a complete body, text, labels,
  shadows outside the pieces, or an assembled character;
- keep right and left pieces in their assigned slots and front-facing
  orientation;
- preserve small joint overlap allowances at shoulders, elbows, hips, and
  knees so seams stay covered while posing; and
- leave unused cells completely green.

Gemini may design sleeves, gloves, trousers, stockings, shoes, armor sections,
and other fitted garments inside their correct cells. It may not place a cape,
long skirt, robe train, large coat tail, weapon, or loose item across several
body cells. Those use extension or accessory sheets.

## Local processing

After Gemini returns the sheet, StoryTale performs these steps locally:

1. Verify the output has the exact template dimensions.
2. Remove only the connected flat green background with edge cleanup.
3. Reject unexpected opaque pixels in protected gaps and the head cell.
4. Cut every slot using the fixed crop rectangles.
5. Apply its allowed-region mask and joint-overlap allowance.
6. Preserve transparent padding and the canonical attachment anchor.
7. Save each non-empty clothing layer as a transparent PNG.
8. Recompose all nine layers over the untouched neutral body.
9. Validate the recomposed neutral character and four built-in poses.
10. Register the outfit only when every required layer passes.

The local splitter never guesses boundaries. It does not crop by visual
content, resize individual parts, or ask Gemini to repair a failed cell.

## Output package

```text
books/<book-id>/story-bible/characters/<character-id>/appearance/
|-- appearance.json
|-- generation/
|   |-- clothing_sheet_source.png
|   |-- clothing_sheet_clean.png
|   `-- generation.json
|-- outfits/<outfit-id>/
|   |-- outfit.json
|   `-- fitted/
|       |-- torso.png
|       |-- upper_arm_right.png
|       |-- lower_arm_right.png
|       |-- upper_arm_left.png
|       |-- lower_arm_left.png
|       |-- upper_leg_right.png
|       |-- lower_leg_right.png
|       |-- upper_leg_left.png
|       `-- lower_leg_left.png
|-- extensions/<extension-id>/
`-- accessories/<accessory-id>/
```

Empty fitted slots are represented in metadata and do not require blank PNG
files. For example, short sleeves may leave both lower-arm clothing slots
empty so the locally selected skin tone remains visible.

## Loose garments and accessories

Items that cannot bend with one body part remain separate:

- `outfit_back`: cape, robe back, long-hair-safe coat tail, or skirt back;
- `outfit_front`: skirt front, apron, sash, or coat front;
- `head_accessory`: hat, crown, helmet, headband, or hair clip;
- `face_accessory`: glasses, mask, eyepatch, or facial jewelry;
- `rear_body_accessory`: sheath, backpack, wings, or rear weapon; and
- `held_item`: sword, staff, book, tool, gun, or story prop.

Held items use a hand anchor and one approved layer mode:

- behind the complete arm;
- between lower arm and hand/grip overlay; or
- in front of the hand.

These groups are requested only when the story requires them. They do not
change the nine-cell clothing sheet.

## Character creation flow

When whole-volume preparation starts a new human character, it will:

1. Merge names and appearances into one stable Story Bible identity.
2. Build and lock a source-backed visual design brief.
3. Select the closest template actor, skin tone, face style, and hair catalog
   starting point without changing rig geometry.
4. Generate the modular face and hair components required by that identity.
5. Send the canonical clothing sheet and clothing-only prompt to Gemini once.
6. Remove green, split, mask, validate, and store the nine fitted layers.
7. Generate only source-required loose garments and accessories.
8. Compose Idle, Talking, Pointing, and Walking locally from the same layers.
9. Show one read-only package review containing Character, Layers, Faces,
   Poses, and Details.
10. Mark the character ready only after the complete package passes.

Progress is reported as `design brief`, `face`, `hair`, `clothing sheet`,
`local cutout`, `accessories`, `pose proof`, and `ready`. Completed components
are reused by design hash, so retrying after an interruption starts at the
first missing component.

## Back-hair default rule

`None` is a valid per-actor default for back hair. Saving an actor with no back
hair stores a nullable/explicit-none back-hair selection in that actor's
appearance record. It does not delete Short, Medium, Long, or generated
back-hair assets from the catalog. The same Elder or Hero may therefore use no
back hair by default while another book character selects long hair later.

Hair choice and its saved X/Y/scale fit belong to actor appearance data, not
pose data. `Save project default` must save both the selected hair IDs,
including `None`, and their fitted transforms.

## Implementation phases

### Phase 7G.1A.1 - Appearance-default persistence correction

- Save front-hair selection, optional back-hair selection, X/Y, and scale in
  each actor appearance record.
- Treat `None` as a real saved value instead of falling back to another style.
- Keep every catalog option available after saving a default.
- Confirm actor switching and all four poses use the saved appearance.

### Phase 7G.1B.1 - Canonical clothing-sheet contract

- Approve the exact guide image and version it as `clothing_sheet_v1`.
- Create the crop, allowed-region, protected-region, seam, and anchor manifest.
- Add the clothing-only Gemini prompt and response metadata contract.

### Phase 7G.1B.2 - One-sheet generation

- Call Gemini through the existing private Worker with the guide and brief.
- Keep one sequential request active and deduplicate by design hash.
- Preserve provider/model/request metadata without adding an app rate limit.

### Phase 7G.1B.3 - Local cutout and package builder

- Remove green locally, cut fixed cells, apply masks, and store transparent
  fitted clothing PNGs.
- Reject resized, rearranged, assembled, or anatomy-redrawn results.
- Compose the outfit over the immutable rig.

### Phase 7G.1B.4 - Extensions and accessories

- Generate only story-required loose garments and accessories.
- Add fixed anchors and approved layer modes.

### Phase 7G.1C - Pose and fidelity gate

- Prove the same appearance in Idle, Talking, Pointing, and Walking.
- Confirm seams, left/right ownership, hair, face, tint, and held items.
- Lock the package before Phase 7H connects it to Story Mode.

## Acceptance checks

- Gemini output uses the exact canonical sheet size and cell arrangement.
- The head and nine base geometries remain unchanged.
- The returned image contains clothing layers, not another complete body.
- Every fitted layer aligns in neutral and follows its body part in all four
  poses.
- Joint motion does not expose large clothing gaps.
- Left and right slots are never swapped.
- Green removal leaves no visible halo and preserves garment edges.
- Empty clothing slots reveal the locally tinted base skin correctly.
- No pose or chapter requires another clothing-generation call.
- `None` back hair and fitted hair transforms survive actor and pose changes.
- Normal users cannot regenerate or replace a paid result automatically.

