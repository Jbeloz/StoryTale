# Modular Sprite Asset Count Plan

There is no single fixed image total because every new character, outfit, and animal adds assets. The modular system keeps the total manageable by reusing rigs and pose data.

## One humanoid character

### Body rig: 9 PNG parts

| Part | Count |
|---|---:|
| Torso and pelvis | 1 |
| Left and right upper arms | 2 |
| Left and right forearm + hand | 2 |
| Left and right thighs | 2 |
| Left and right lower leg + foot | 2 |
| **Body total** | **9** |

Hands are initially joined to the forearms and feet are joined to the lower legs. This keeps the code and rig simple. Separate hands can be added later only for important hand gestures.

### Head and design: 8–10 PNG parts

| Asset | Count |
|---|---:|
| Head base | 1 |
| Neutral, talking, happy, sad, and angry faces | 5 |
| Back and front hair | 2 |
| Optional accessories | 0–2 |
| **Head/design total** | **8–10** |

### Expected total

- One human character with one outfit: **17–19 PNGs**.
- Each extra outfit: up to **9 more part overlays**.
- Poses and animations: **0 additional PNGs** because they reuse the jointed parts.
- Ten human characters with one outfit each: roughly **170–190 PNGs**.

Clothes should be attached to their matching part. For example, a sleeve follows the upper arm and forearm; trousers follow the thigh and lower leg. The final mobile export may merge each body part and clothing overlay into one PNG for faster rendering.

## Animal rig families

Do not create one rig for every animal species. Start with reusable families.

| Rig family | Parts | Suggested images |
|---|---|---:|
| Small quadruped: cat, dog, fox | Head, torso, tail, four legs | 7 |
| Large quadruped: wolf, horse, cow | Head, torso, tail, four legs | 7 |
| Bird | Head, body, two wings, tail, two legs | 7 |
| Background or unusual creature | One static sprite with slide/bob/scale movement | 1 |

Recurring speaking animals may add three face states: neutral, talking, and angry or happy. Background animals should stay static so they do not multiply the asset count.

## Reusable base library

Eventually, StoryTale can support five humanoid proportions:

1. Small child
2. Teen or petite adult
3. Average adult
4. Broad or tall adult
5. Elder

Five complete nine-part body templates would be **45 base body PNGs**. Add the three seven-part animal rigs and one static fallback for about **67 reusable base images**. These should not all be made immediately.

## Recommended build phases

### Phase 1 — Prove one heroine rig

1. Combine the approved head and current body on a `1024 x 2048` master canvas.
2. Approve the full-body proportions and neutral outfit.
3. Split the body into the nine humanoid parts.
4. Record shoulder, elbow, hip, knee, and neck pivot points.
5. Test neutral, talking, pointing, and reaction poses using the same parts.

### Phase 2 — Finish the heroine

1. Add the remaining four approved face expressions.
2. Separate front and back hair.
3. Attach clothing to the correct body-part layers.
4. Test simple idle, talking, walking, and reaction animations.

### Phase 3 — Prove reuse

1. Build one hero using the same rig.
2. Build one elder or broad adult with a different body base.
3. Confirm that pose files can be reused with adjusted joint positions.

### Phase 4 — Add animals

1. Make one small quadruped rig.
2. Make one bird rig.
3. Use static sprites for rare animals unless they need important movement or dialogue.

### Phase 5 — Generate per book

Gemini analyzes the book and lists recurring characters. Only recurring or speaking characters receive full rigs. Minor characters receive a neutral full sprite, and background crowds or animals use static sprites.

## Best next step

Do not create dozens of bases yet. First make the approved heroine into one clean nine-part rig. If its joints, clothes, layering, and Flutter movement work correctly, the same template can safely be copied for the other bases.

