# Universal Hair Fit Plan

## Goal

StoryTale gives every actor and hairstyle one reusable fit. A hairstyle may be
positioned and resized once in Sprite Studio, saved as the project default,
and reused by every pose without actor-specific rendering code.

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
- The rig supplies the initial display size and pivot.
- Sprite Studio exposes X/Y and scale for front and back hair.
- Each actor stores its own front-hair fit. Each actor and back-hair style
  stores its own back-hair fit.
- Hair rotation remains attached to the head; the saved fit is an appearance
  adjustment, not a pose adjustment.

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
- the saved fit stays inside the approved X/Y and scale limits.

If validation passes, the new files enter the actor's hair catalog. Their
stored actor/style fit is reused by every pose and does not alter the image or
rig geometry.

## Actor hair catalogs

Phase 7G.1A gives Default, Hero, Heroine, Elder, and Adult one fitted default
front-hair selection and one optional fitted back-hair selection. The V1 actor
records currently resolve approved Short, Medium, or Long entries from the
shared fixed-slot catalogs. Phase 7G.1B may add actor-specific generated
artwork without changing the slots. Front and back catalogs stay independent:

```text
hair/
|-- front/<front-style-id>.png
|-- back/<back-style-id>.png
`-- styles.json
```

The actor appearance record stores the stable front asset ID, nullable back
asset ID, compatible rig/template version, head anchor, and separate optional
X/Y/scale fits. A composed hairstyle preset may reference one entry from each
catalog, but neither file requires the other to exist.

Short, Medium, and Long remain available for alignment checks and form the V1
starter catalog. Every actor appearance points to one front-hair choice and an
optional back-hair choice. `None` is a valid saved back-hair default. It hides
the back layer for that actor but does not delete Short, Medium, Long, or
generated back-hair styles from the catalog.

Hair selection belongs to the character appearance and is reused by every
pose. Hair movement continues to follow the head, while changing skin tone
does not recolor hair.

## Acceptance checks

- Front and back hair visually form one hairstyle.
- Head movement carries both layers.
- Moving front hair does not move the head or back hair.
- Moving back hair does not move the head or front hair.
- Front and back hair expose reusable X/Y and scale controls.
- Default, Hero, Heroine, Elder, and Adult each expose fitted front hair and an
  optional fitted back-hair default.
- Switching actor or hairstyle restores that actor/style's saved fit.
- Saving the project default preserves hair selection, including `None`, and
  its fit for all built-in poses without removing catalog entries.
- Clicking empty canvas space clears the selected part.
