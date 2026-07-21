# Heroine Modular Face Prompt Pack

Use the two reference images below for every prompt:

1. `assets/images/characters/face_profiles/heroine/reference/approved_neutral.png`
2. `assets/images/characters/rigs/humanoid_v1/faces/head_base.png`

Generate one image at a time. Every result must stay on the original 1254 x
1254 canvas, preserve the exact feature positions, and use a transparent PNG.
Do not crop the empty space.

## Eyes and eyebrows

Save the results in `assets/images/characters/face_profiles/heroine/eyes/`.

### `neutral.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her paired neutral eyes, eyebrows, eyelids, soft eyelashes, pupils, fully opaque white eye areas, and bright pupil highlights on a fully transparent 1254 x 1254 PNG; preserve the exact original positions, spacing, size, front-facing direction, and simple cute style, add no nose, mouth, head, skin area, hair, or background, and do not crop or move anything.

### `happy.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her paired happy eyes and eyebrows with a warm gentle expression, soft eyelashes, pupils, fully opaque white eye areas, and bright pupil highlights on a fully transparent 1254 x 1254 PNG; change only the eyelids and eyebrows needed for happiness while preserving the exact original eye positions, spacing, size, front-facing direction, and simple cute style, add no nose, mouth, head, skin area, hair, or background, and do not crop or move anything.

### `sad.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her paired sad eyes and eyebrows with slightly lowered eyelids and gently raised inner brows, soft eyelashes, pupils, fully opaque white eye areas, and bright pupil highlights on a fully transparent 1254 x 1254 PNG; preserve the exact original eye positions, spacing, size, front-facing direction, and simple cute style, add no tears, nose, mouth, head, skin area, hair, or background, and do not crop or move anything.

### `angry.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her paired angry eyes and eyebrows with firm inward-slanted brows and focused eyelids, soft eyelashes, pupils, fully opaque white eye areas, and bright pupil highlights on a fully transparent 1254 x 1254 PNG; keep both eyes inside the exact original positions and boundaries without shifting, stretching, enlarging, or making either eye uneven, preserve her simple cute style, add no nose, mouth, head, skin area, hair, or background, and do not crop anything.

### `surprised.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her paired surprised eyes and raised eyebrows with slightly more open eyelids, soft eyelashes, centered pupils, fully opaque white eye areas, and bright pupil highlights on a fully transparent 1254 x 1254 PNG; preserve the exact original eye positions, spacing, overall size, front-facing direction, and simple cute style without making the eyes oversized, add no nose, mouth, head, skin area, hair, or background, and do not crop or move anything.

## Nose

Save the result in `assets/images/characters/face_profiles/heroine/noses/`.

### `default.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her tiny simple nose mark and its minimal original shading on a fully transparent 1254 x 1254 PNG; preserve the exact original position, scale, front-facing direction, and cute understated style, add no eyes, eyebrows, mouth, head, skin area, hair, or background, and do not crop or move anything.

## Mouths

Save the results in `assets/images/characters/face_profiles/heroine/mouths/`.

### `neutral.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her small neutral closed mouth on a fully transparent 1254 x 1254 PNG; preserve the exact original position, width, line weight, front-facing direction, and simple cute style, add no eyes, eyebrows, nose, head, skin area, hair, or background, and do not crop or move anything.

### `talking.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her small natural talking mouth, slightly open and suitable for ordinary dialogue, on a fully transparent 1254 x 1254 PNG; preserve the exact original mouth center, scale, line weight, front-facing direction, and simple cute style without making it oversized, add no eyes, eyebrows, nose, head, skin area, hair, or background, and do not crop or move anything.

### `smile.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her small gentle smiling mouth on a fully transparent 1254 x 1254 PNG; preserve the exact original mouth center, scale, line weight, front-facing direction, and simple cute style without adding an exaggerated grin, add no eyes, eyebrows, nose, head, skin area, hair, or background, and do not crop or move anything.

### `sad.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her small subtle sad closed mouth with a light downward curve on a fully transparent 1254 x 1254 PNG; preserve the exact original mouth center, scale, line weight, front-facing direction, and simple cute style, add no eyes, eyebrows, nose, head, skin area, hair, tears, or background, and do not crop or move anything.

### `angry_teeth.png`

> Using the attached approved Heroine face as the exact identity and alignment reference, output only her small controlled angry mouth showing a little opaque white teeth on a fully transparent 1254 x 1254 PNG; preserve the exact original mouth center, compact scale, line weight, front-facing direction, and simple cute style without making it oversized or monstrous, add no eyes, eyebrows, nose, head, skin area, hair, or background, and do not crop or move anything.

## Fallback when transparency fails

Add this sentence to the end of a prompt only when the generator cannot return
real transparency:

> Use one perfectly flat pure green #00FF00 background with no shadows, glow, texture, or green pixels inside the requested face part so StoryTale can remove it locally.
