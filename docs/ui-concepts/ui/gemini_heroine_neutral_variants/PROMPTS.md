# Heroine Neutral Face Variants

This isolated asset test keeps the original three neutral heroine choices and adds five Round 2 choices. No other expressions are generated until one neutral face is approved.

## Shared rules

- Model: `gemini-3.1-flash-image`
- Gemini output: `2K`, square, flat green background
- Final face and preview: transparent `1254 x 1254` PNG
- Keep the reference face's canvas, eye centers, eye spacing, facial-feature scale, grayscale colors, and clean chibi line style.
- Keep both eyes symmetrical and fully inside their original facial area.
- Each iris must retain two crisp white highlights: one larger round highlight and one smaller white dot.
- Keep a calm neutral expression: no open mouth, broad smile, sadness, anger, tears, blush, or dramatic emotion.
- Output only eyebrows, eyes, small nose mark, and one small closed mouth. Do not draw skin, head, ear, hair, neck, body, accessories, text, or extra features.
- Fill every other pixel with uniform pure chroma green `#00FF00` without shadows, texture, glow, or gradient.

## Variant 1 — Soft Gentle

> Image 1 is the edit target and approved geometry reference. Create a cute neutral heroine facial layer that remains very similar to the reference. Keep the same eye centers and spacing, but make the irises subtly rounder and only slightly larger, add one delicate short outer eyelash to each eye, use thin softly curved eyebrows, keep the small nose dot, and use one tiny relaxed closed mouth. Preserve the grayscale shading and calm half-lidded look. Keep one large round white iris highlight and one smaller white highlight dot in each eye. Follow all shared rules.

## Variant 2 — Bright Cute

> Image 1 is the edit target and approved geometry reference. Create a brighter cute neutral heroine facial layer while keeping the same facial placement and chibi style. Open both eyes only slightly more vertically without moving their centers, use softly rounded irises with clear grayscale gradients, add two very short fine outer eyelashes per eye, use shorter gently raised eyebrows, keep the small nose dot, and use one tiny straight closed mouth with softened ends. The face must still look neutral rather than excited. Keep one large round white iris highlight and one smaller white highlight dot in each eye. Follow all shared rules.

## Variant 3 — Elegant Cute

> Image 1 is the edit target and approved geometry reference. Create an elegant cute neutral heroine facial layer that remains recognizable as the reference. Keep both eye centers and spacing unchanged, refine the eyes into a soft almond shape with slightly longer upper outer lashes, retain medium-size grayscale irises, use thin graceful eyebrows with a subtle arch, keep the small nose dot, and use one very small calm closed mouth. Avoid making the eyes narrow, mature, seductive, or emotional. Keep one large round white iris highlight and one smaller white highlight dot in each eye. Follow all shared rules.

## Results

- All three variants were generated separately with their recorded prompts.
- All final faces and head previews are transparent `1254 x 1254` PNGs with `0` green-dominant artifact pixels.
- Every eye retains multiple visible white highlight components after transparency removal.
- Variant 1 is the roundest and cutest, with the most decorative eye highlights.
- Variant 2 is brighter and slightly more open while remaining neutral.
- Variant 3 is the calmest and stays closest to the original neutral face.
- Generation stops at these neutral choices until the user approves one.

## Round 2 — Version 2 Cuteness + Version 3 Simplicity

Round 2 uses two references: Image 1 is the approved bright-cute version and Image 2 is the approved simple-elegant version. Every result must remain neutral, use the same canvas and feature placement, contain exactly one large white iris highlight plus one small white highlight dot per eye, and avoid extra decorative reflections.

### Round 2 Variant 1 — Balanced Core

> Combine Image 1's slightly brighter, more open heroine eyes with Image 2's simple line work. Use eye openness exactly halfway between the references, medium-size rounded irises, one very short outer eyelash per eye, thin eyebrows matching Image 2, the same small nose dot, and one tiny straight closed mouth. Keep the grayscale shading clean and minimal with exactly two white highlights per iris.

### Round 2 Variant 2 — Soft Round

> Use Image 2 as the main simple style, then add only Image 1's softer round iris shape. Keep the upper eyelids and eyebrows restrained, make the irises about five percent rounder without moving their centers, use one short tapered outer lash per eye, and keep a tiny relaxed closed mouth. Use exactly two white highlights per iris and no extra reflections.

### Round 2 Variant 3 — Calm Spark

> Keep Image 2's minimal eyebrows, mouth, line thickness, and calm expression, but open both eyes slightly toward Image 1 and brighten the grayscale iris gradient. Keep medium irises, one subtle outer lash per eye, the same eye spacing, and exactly one large plus one small white highlight in each iris. Do not add lower decorative highlights.

### Round 2 Variant 4 — Simple Cute

> Preserve about seventy percent of Image 2's simple neutral design and add only a small amount of Image 1's cuteness. Enlarge each iris by about five percent, soften the lower eye curve, keep the original thin eyebrows, use only one tiny outer lash per eye, and keep one very small straight mouth. Retain exactly two white highlights per iris with no extra sparkle.

### Round 2 Variant 5 — Bright Refined

> Preserve Image 1's clearer, brighter gaze but simplify every line to match Image 2. Reduce the iris decoration to exactly two white highlights, shorten the outer lashes, use Image 2's thin calm eyebrows and tiny mouth, and keep the eye centers, spacing, and neutral expression unchanged. The result should look cute at first glance but simple when viewed closely.

### Round 2 Results

- All five variants were generated by Gemini using the bright-cute and simple-elegant faces as references.
- The first raw result contained a faint duplicated lower-eye artifact; local cleanup removed it and aligned the intended features to the shared head template.
- Every final face layer and head preview is a transparent `1254 x 1254` PNG with transparent corners and `0` green-dominant artifact pixels.
- Variant 1 has the widest eyes and strongest balanced gaze.
- Variant 2 is the softest and roundest while keeping restrained eyelashes.
- Variant 3 is the calmest, with slightly smaller-looking irises.
- Variant 4 adds the clearest outer eyelash shape while remaining neutral.
- Variant 5 stays closest to the simple-elegant reference with a slightly brighter gaze.
- Gemini retained the cute reference's small lower iris sparkle in these tests even though the prompts requested only two highlights.
- Generation stops at these five Round 2 neutral choices until the user approves one.
- **Approved choice:** Round 2 Variant 4 — Simple Cute (`heroine_neutral_r2_04_simple_cute.png`).
