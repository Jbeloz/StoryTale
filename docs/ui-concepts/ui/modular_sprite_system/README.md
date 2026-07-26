# StoryTale Modular Sprite System

This folder compiles the approved sprite references and plans the Gacha-style character system. The original Gemini test folders remain unchanged so their raw outputs and prompts are still available.

## Approved heroine starting point

- Head base: `approved/heroine/head/head_base.png`
- Approved neutral face: `approved/heroine/faces/neutral.png`
- Current body reference: `approved/heroine/body/body_reference.png`
- Combined head preview: `approved/heroine/preview/head_neutral.png`

The approved neutral face is **Round 2 Variant 4 — Simple Cute**.

## Folder guide

```text
modular_sprite_system/
├── approved/heroine/       Approved assets we can build from
├── references/             Useful final results from earlier tests
├── templates/humanoid/     Jointed human-part rules
├── templates/animals/      Animal rig families
├── characters/             One folder per finished character
└── ASSET_COUNT_PLAN.md      Counts and build phases
```

## Main design rule

Create and approve one complete neutral full-body character first. After approval, split that exact image into reusable parts. Do not ask Gemini to design every limb independently because the clothes, line thickness, colors, and proportions can drift.

Keep one transparent full-body master as the alignment reference. Runtime body
parts may be tightly cropped, but `rig.json` must store each part's original
position, size, parent, pivot, and layer order so the neutral pose can reproduce
the approved master exactly.

## Runtime idea

The app stacks transparent PNG parts and rotates them around saved joints:

1. Back hair and rear limbs
2. Torso and outfit
3. Front limbs
4. Head base
5. Face expression
6. Front hair and accessories

Poses and movements are saved as joint angles and positions, not as newly generated full-body pictures. This lets the same character walk, talk, point, react, and idle without regenerating their clothes or body.

## Current Sprite Studio prototype

The first working rig is bundled at:

```text
assets/images/characters/rigs/humanoid_v1/
|-- rig.json
|-- base/                 ten transparent head/body-part PNGs
`-- poses/neutral.json    reusable pose values
```

Open the editor through `Profile -> Sprite Studio`. Parent transforms are
inherited, so rotating an upper arm also moves its connected lower arm. Parts
1-6 provide alpha-aware selection, permanent body-layer rules, a responsive
pinned canvas, precise transform controls, Undo/Redo, bone controls derived
from the existing pivots, the modular face catalog, named custom poses, local
storage, and Story Mode pose/face resolution. Generated book-specific rig
import remains future work. See the
[Sprite Studio plan](../../../SPRITE_STUDIO_PLAN.md) for editor behavior and the
[Master Roadmap](../../../ROADMAP.md) for the global next phase.
