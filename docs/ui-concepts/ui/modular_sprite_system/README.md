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

Keep all ten approved rig-part geometries (one neutral head plus nine body
pieces) as immutable local assets. Do not ask Gemini for a replacement
full-body character and do not split a newly invented silhouette into runtime
pieces. Gemini may design only aligned face, front/back hair, clothing,
garment-extension, and accessory overlays.

Keep one transparent full-body composite as a review reference, but build it
locally from the shared rig plus approved appearance layers. `rig.json` stores
each base part's position, size, parent, pivot, geometry hash, and fixed layer
order. Poses change transforms only.

Face details, front/back hair, and fitted clothing are requested as one
canonical character sheet aligned to the separated-parts guide. StoryTale removes
green and cuts the nine known cells locally through one versioned manifest.
Front hair, optional back hair, their saved X/Y/scale fits, and skin tone live
in the character appearance instead of pose JSON.

## Runtime idea

The app stacks transparent PNG parts and rotates them around saved joints:

1. Rear accessory, back hair, and rear limbs with clothing
2. Torso, fitted outfit, and loose-garment extensions
3. Front limbs with clothing and held-item rear layer
4. Immutable head base
5. Eyes/brows, nose, mouth, details, and face accessory
6. Front hair, head accessory, held-item front/grip layer, and effects

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
storage, and Story Mode pose/face resolution. Locked-template book-character
appearance composition is the current Phase 7G.1 correction. See the
[Sprite Studio plan](../../../SPRITE_STUDIO_PLAN.md) for editor behavior and the
[Generated Character Pipeline plan](../../../GENERATED_CHARACTER_PIPELINE_PLAN.md)
for the production rig gate,
[Character Sheet V1 plan](../../../CHARACTER_SHEET_PLAN.md) for
outfit generation and cutting, plus the
[Master Roadmap](../../../ROADMAP.md) for the global next phase.
