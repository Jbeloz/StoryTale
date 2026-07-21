# Gemini Head and Face Improvement Test

This is an isolated asset test. It does not change the Flutter app or Cloudflare Worker.

## Test setup

- Gemini model: `gemini-3.1-flash-image`
- Generation size: `2K` for clearer facial lines
- Final canvas: `1254 x 1254`
- Reference face: `../character_face.png`
- Head base: `../character_head_no_face.png`
- Gemini generates a flat green background. The green is removed locally and the result is saved as a transparent PNG.
- The approved original eye pixels are restored after generation so neither eye can move, resize, rotate, or change spacing.

## Shared locked-face prompt

> Edit only the supplied transparent facial-feature layer. Keep the full square canvas and every feature at the exact same coordinates and scale. Keep both eyes and both irises pixel-aligned with the reference: do not move, resize, redraw, rotate, recenter, widen, narrow, or replace either eye. Change only the eyebrows and mouth needed for the requested expression. Keep the small nose mark unchanged. Preserve the same clean dark line thickness, grayscale colors, and chibi art style. Output only the two eyes, two eyebrows, small nose mark, and mouth. Do not draw skin, head, ear, hair, neck, body, text, border, or extra features. Fill every other pixel with flat pure chroma green `#00FF00` with no shadow, gradient, texture, or glow.

## Expressions

1. `face_neutral.png`: approved original facial layer; no Gemini regeneration.
2. `face_talking.png`: change only the mouth into one small, clear open-talking mouth; keep the eyebrows neutral.
3. `face_happy.png`: change only the eyebrows into a gently raised relaxed shape and the mouth into one clear small smile.
4. `face_sad.png`: change only the eyebrows into a soft upward-inner sad shape and the mouth into one small downturned curve; no tears.
5. `face_angry.png`: keep each eyebrow's original length, thickness, line weight, and horizontal position; lower only the inner end by about 10 degrees and use one small narrow clenched-teeth mouth. Keep both original eyes fully open and completely unchanged. Do not create glowing eyes, enlarged irises, asymmetric eyes, shifted eyes, extra eye lines, oversized eyebrows, or an exaggerated screaming mouth.

## Deterministic eye lock

After Gemini returns a face, StoryTale clears the generated pixels inside the two approved eye rectangles and copies the same rectangles from `face_neutral.png`. This is stronger than prompting alone and guarantees that the final test images retain the approved eye placement.

## Results

- Five final face layers and five assembled head previews were created.
- Every final face and head is a transparent `1254 x 1254` PNG.
- Talking, happy, sad, and angry each have `0` different eye pixels compared with the approved neutral face.
- The final face layers have `0` green-dominant artifact pixels after local despill.
- Both white pupil highlights are preserved from the approved source in every expression (`819` left-highlight pixels and `872` right-highlight pixels in the validation regions).
- The `2K` Gemini output produces clearer eyebrows and mouths than the earlier `1K` test before resizing.
- The first angry result was rejected because Gemini made the eyebrows too long and heavy. The restrained second prompt is the approved test result.
- The neutral face uses the approved original source rather than spending an unnecessary Gemini request.

## Recommended head-generation order

1. Keep one approved transparent head base.
2. Keep one approved neutral facial layer as the eye and nose source of truth.
3. Ask Gemini for each expression at `2K` on a flat green background.
4. Remove the green background with a soft alpha matte and despill.
5. Resize the facial layer to `1254 x 1254`.
6. Restore the approved eye and nose rectangles pixel-for-pixel.
7. Compose the facial layer over the head base and validate transparency, dimensions, green spill, and eye equality.

This pipeline is tested here but is not wired into the app or Worker in this no-code test.

## White-highlight correction

The first local test cleanup compared colors as unsigned 8-bit values. Adding the green tolerance near pure white could wrap around and incorrectly remove white eye-highlight pixels. The corrected test widens the color values before comparison, rebuilds the approved neutral layer from `character_face.png`, and restores those corrected eye pixels after every other processing step. No new Gemini generation was needed for this correction.
