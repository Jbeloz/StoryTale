# Elder Face Prompt Pack

These prompts produced the bundled Elder starter parts. The built-in image
generator created flat green sources; StoryTale then removed the background
locally and normalized every output to the approved 1254 x 1254 anchors.

## Shared prompt

Create only the facial features of a wise, gentle elderly male chibi character
using the same simple grayscale anime line art as the StoryTale reference.
Preserve white sclera and white pupil highlights. Keep both eyes level, fully
inside their original positions, and aligned to the exact 1254 x 1254 canvas.
Use a perfectly flat #00FF00 background. Do not draw the head, skin, ear, hair,
beard, glasses, body, text, watermark, shadow, gradient, or texture.

## Expression changes

- **Neutral:** calm mature eyes, softly aged eyebrows, small nose, tiny neutral
  mouth, and a few subtle age lines.
- **Talking:** keep Neutral unchanged and replace only the mouth with one small
  open talking mouth.
- **Happy:** gently curve the mature eyes and add a small calm smile.
- **Sad:** raise the inner eyebrows slightly, lower the gaze, and add one small
  downturned mouth.
- **Angry:** lower the eyebrows toward the center, narrow the eyes without
  moving them, and use one small closed clenched-teeth mouth.
- **Surprised:** raise the eyebrows and open the eyes slightly wider while
  preserving their centers; use the shared Talking mouth in the final set.

## Reusable detail

The subtle outer and under-eye age lines are saved once as
`details/wrinkles.png` and reused by all six Elder sets.

All Elder layers were moved together to the shared actor anchor after the first
preview showed the entire face too far left. This correction applies to every
Elder expression, not only Neutral.
