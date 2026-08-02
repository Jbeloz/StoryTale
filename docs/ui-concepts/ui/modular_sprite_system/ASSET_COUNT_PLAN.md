# Modular Sprite Asset Count Plan

There is no single fixed image total because every book character may need a
different face catalog, hairstyle, outfit, and set of accessories. StoryTale
keeps the total manageable by sharing immutable rig geometry and pose data.

## Shared humanoid rig

`humanoid_v1` owns ten local base PNGs that are not regenerated per character:

| Base part | Count |
| --- | ---: |
| Head | 1 |
| Torso | 1 |
| Left and right upper arms | 2 |
| Left and right lower arms with hands | 2 |
| Left and right upper legs | 2 |
| Left and right lower legs with feet | 2 |
| **Shared base total** | **10** |

Hands remain joined to lower arms and feet remain joined to lower legs for the
first version. A different body proportion requires another manually approved
and versioned rig; Gemini cannot replace or reshape these base parts.

## One book-character appearance

Character-specific files are layers placed over the shared rig:

| Appearance group | Typical count |
| --- | ---: |
| Eyes/brows expression layers | 1-6 |
| Nose layer | 1 |
| Mouth expression layers | 2-6 |
| Optional details such as wrinkles | 0-2 |
| Front hair | 1 |
| Optional back hair | 0-1 |
| Fitted clothing overlays cut from one sheet | 0-9 |
| Loose garments and accessories | As required by the story |

The exact PNG count depends on which catalog parts can be reused. `None` is a
valid saved back-hair default and does not delete Short, Medium, Long, or
generated catalog choices. All saved hair X/Y/scale fits belong to appearance
data and are reused by every pose.

One Gemini character-sheet request returns the fixed-layout separated face,
hair, and clothing artwork. StoryTale removes green and cuts the known cells locally using the
versioned crop manifest. Idle, Talking, Pointing, Walking, and named poses add
no PNGs because they reuse the same layers with transform JSON.

## Animal rig families

Do not create one rig for every species. Start with reusable families:

| Rig family | Parts | Suggested images |
| --- | --- | ---: |
| Small quadruped: cat, dog, fox | Head, torso, tail, four legs | 7 |
| Large quadruped: wolf, horse, cow | Head, torso, tail, four legs | 7 |
| Bird | Head, body, two wings, tail, two legs | 7 |
| Background or unusual creature | One static whole sprite | 1 |

Recurring speaking animals may add neutral, talking, and one strong-emotion
face state. Rare or background animals stay static unless the plot needs
important movement or dialogue.

## Possible future humanoid rigs

Future approved templates may cover:

1. small child;
2. teen or petite adult;
3. average adult;
4. broad or tall adult; and
5. elder.

These are separate versioned rig families, not five copies required for the
current MVP. Build a new family only after the shared `humanoid_v1` pipeline
passes its complete character-package gate.

## Current production order

1. **Implemented Phase 7G.1A.1:** persist front hair, optional back hair including `None`,
   skin tone, and universal per-style hair fits.
2. **Phase 7G.1B.1:** version the canonical character-sheet guide and exact crop/mask
   manifest.
3. **Phase 7G.1B.2:** generate one separated character sheet from the source-backed
   character brief.
4. **Phase 7G.1B.3:** remove green, cut known cells, validate, and build the
   reusable appearance package locally.
5. **Phase 7G.1B.4:** add only source-required loose garments and accessories.
6. **Phase 7G.1C:** prove the same appearance in all required faces and four
   built-in poses before Story Mode binding.

See the [Character Sheet V1 Plan](../../../CHARACTER_SHEET_PLAN.md)
for the sheet contract and the [Master Roadmap](../../../ROADMAP.md) for global
status and development order.
