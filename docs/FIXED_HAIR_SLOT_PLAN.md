# Fixed Hair Slot Plan

## Goal

StoryTale must not resize every new hairstyle by hand. Each hairstyle is made
for a permanent front-hair slot and back-hair slot that already fit the
humanoid head.

## Runtime layers

The standard character uses these head layers:

1. `back_hair` behind the head and torso;
2. `head`;
3. face parts;
4. `front_hair` above the head and face.

Both hair layers are children of `head`. Moving or rotating the head moves both
hair layers. Moving one hair layer only adjusts that layer.

## Fixed asset contract

- Front and back hair are separate transparent PNG files.
- Front hair uses the locked `1254 x 1254` head canvas. Back hair uses the
  locked `1254 x 2150` character canvas so medium and long hair may extend
  behind the torso and legs without changing its fitted head anchor.
- The artwork must keep the same head center, crown, ears, and hairline guides.
- Transparent padding is part of the contract and must not be trimmed.
- The rig supplies the permanent display size and pivot.
- Hair scale is always `1.0`; Sprite Studio does not show a resize control for
  fixed hair slots.
- Only a small X/Y correction is allowed when an unusual hairstyle needs it.

## Default hairstyle

The existing dark navy front hair remains the default front layer. A matching
dark navy back layer is added behind the head. The back layer contains only the
rear crown, side tufts, and short nape; it must not contain bangs, a face, skin,
eyes, or body parts.

## Future generated hair

Gemini or another image generator receives the canonical head guide and the
fixed slot rules. It generates a front layer and a back layer on the unchanged
canvas. StoryTale validates:

- exact canvas size;
- transparent background;
- non-empty pixels inside the allowed hair region;
- no opaque pixels in forbidden face/body regions; and
- scale remains `1.0`.

If validation passes, the new files can replace the hairstyle without manual
resizing. The generated character pipeline may select a small stored X/Y
offset, but it must never change the slot size.

## Actor hair catalogs

Phase 7G.1A gives Default, Hero, Heroine, Elder, and Adult one fitted default
hairstyle each. One hairstyle record always contains both files:

```text
hair-style
|-- front.png
|-- back.png
`-- style.json
```

`style.json` stores the stable style ID, actor profile ID, front/back asset
IDs, compatible rig/template version, head anchor, and optional small X/Y
correction. Sprite Studio switches the pair as one catalog choice. It never
mixes unmatched front and back files automatically.

Short, Medium, and Long are shared test/reference back parts. They remain
available for alignment checks, but every starter actor must have a complete
front/back pair before Phase 7G.1A is complete.

Hair selection belongs to the character appearance and is reused by every
pose. Hair movement continues to follow the head, while changing skin tone
does not recolor hair.

## Acceptance checks

- Front and back hair visually form one hairstyle.
- Head movement carries both layers.
- Moving front hair does not move the head or back hair.
- Moving back hair does not move the head or front hair.
- Hair has no resize control.
- Default, Hero, Heroine, Elder, and Adult each expose one complete fitted
  front/back default hairstyle.
- Switching actor or hairstyle changes the front/back pair together.
- Saving the project default preserves hair position for all built-in poses.
- Clicking empty canvas space clears the selected part.
