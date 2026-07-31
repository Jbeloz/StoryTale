# Gemini Default Crying Face Test

This test adds one new modular face set without changing or replacing any
existing Default face.

## Generation

- Provider: Google Gemini through the existing StoryTale Cloudflare Worker
- Model configured by the Worker: `gemini-3.1-flash-image`
- Mode: `face-layer`
- Reference: the approved Default neutral facial-feature layer
- API requests used: one

## Prompt

> Create a clearly crying expression that is visibly different from the
> existing neutral, talking, happy, sad, angry, and surprised expressions.
> Keep both eyes at exactly the same coordinates, scale, spacing, and iris size
> as the reference, preserve the white pupil highlights, but make the eyelids
> visibly tearful and raise the inner eyebrows. Add one clean grayscale tear
> stream directly below each eye. Change the mouth into one small open trembling
> crying mouth. Keep the small nose mark identical. Do not redesign, move,
> resize, rotate, crop, or recenter any feature.

## Saved result

- `assets/images/characters/face_profiles/default/eyes/crying.png`
- `assets/images/characters/face_profiles/default/mouths/crying.png`
- Default set ID: `crying`
- The set reuses the approved Default nose and soft-cheek detail.
- Both new layers are transparent `1254 x 1254` PNG files.

The raw Gemini response is preserved under `raw/`, while
`previews/default_crying_head.png` shows the exact modular composition loaded by
Sprite Studio.
