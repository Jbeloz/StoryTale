# Visual-Novel Background Plan

Status: planned only. The app and Worker must not be treated as complete until
the implementation and validation steps below pass.

## Goal

Story Mode backgrounds are reusable visual-novel stages, not square
illustrations, isolated objects, floating islands, or character art. Each image
must show a complete physical place with enough open ground to position one to
three sprites without covering the important scenery.

For example, `moonlit_rose_garden` means a wide moonlit garden environment with
a path, surrounding roses, distant scenery, and open standing areas. It does
not mean a small floating planet displaying several roses.

## Required background contract

Every approved background must satisfy all of these rules:

- landscape `16:9` canvas, initially `1024 x 576`
- wide visual-novel establishing shot at a natural character eye level
- one continuous, grounded place that fills the frame
- clear foreground, middle ground, and distant background
- visible floor, path, grass, room floor, or another believable stage surface
- usable left, center, and right character-placement areas
- important landmarks behind the character lanes or near the outer edges
- enough safe crop space for the player's small pan and zoom movements
- lighting, weather, season, and damage taken from the requested state
- the book's approved background style reused across every location
- no characters, people, animals, text, UI, speech bubbles, or watermarks
- no floating island, miniature diorama, product display, isolated object,
  portrait composition, or close-up subject

The player may cover part of the lower frame with subtitles. Essential
landmarks must therefore stay out of the bottom subtitle-safe area.

## Structured location brief

Gemini should create a source-backed brief before image generation:

```text
VisualNovelBackgroundBrief
- locationId
- stateId
- placeDescription
- parentSetting
- foreground
- middleGround
- distantBackground
- stageSurface
- importantLandmarks
- characterSafeZones: left, center, right
- lighting
- weather
- styleNotes
- avoid
```

The brief must describe a specific place where a scene occurs. A broad world,
planet, kingdom, forest, or ocean is context only until the chapter identifies
a usable place inside it. Gemini must not invent a landmark that changes the
story.

## Prompt construction

Build the Cloudflare prompt from the approved brief in this order:

1. Specific physical place and parent setting.
2. Requested time, weather, season, or condition.
3. Wide `16:9` visual-novel background and camera description.
4. Foreground, middle-ground, and distant-background details.
5. Open left, center, and right sprite-placement lanes.
6. Approved book-wide art style.
7. Exclusions for characters, text, portrait framing, isolated objects,
   floating islands, and miniature dioramas.

Example intent:

```text
Wide 16:9 visual-novel background of a moonlit rose garden on the Little
Prince's planet. Show a continuous garden path with open walkable ground in the
foreground, rose bushes framing both sides, a small shelter and distant
landscape in the middle and background, and clear left, center, and right areas
for character sprites. Soft storybook night lighting. Environment only. No
characters, text, floating island, miniature diorama, isolated flowers, or
portrait composition.
```

## Cloudflare generation plan

The current FLUX.1 smoke-test route proves that Workers AI and authentication
work, but its square output is not the final Story Mode background contract.

The planned visual-novel route uses Cloudflare Workers AI with
`@cf/stabilityai/stable-diffusion-xl-base-1.0` because it accepts explicit
`width` and `height` inputs. The first target is:

```text
width: 1024
height: 576
output: provider image stream with its real MIME type preserved
```

The Flutter request remains `multipart/form-data` with a short location prompt.
The private Worker validates the request, constructs the model-specific JSON,
and returns raw image bytes. API keys and provider details remain outside the
Flutter app. Cloudflare currently marks this SDXL model as Beta, so background
generation stays behind a provider adapter and can be replaced without changing
the catalog or Story Mode data.

## Generation, review, and reuse

1. Collect distinct `locationId + stateId` requirements from the chapter plan.
2. Resolve an approved structured location brief.
3. Generate one pending landscape background for that pair.
4. Reject corrupt images or incorrect dimensions automatically.
5. Show the full uncropped landscape result in the review screen.
6. Let the user approve, reject, or regenerate it.
7. Keep the last approved asset active while a replacement is pending.
8. Register the stable asset ID only after approval.
9. Reuse that asset in every consecutive shot with the same location and state.
10. Generate another asset only for a real place change or meaningful visual
    state change.

Visual quality remains an approval decision. Automatic validation should not
pretend it can reliably judge whether the scenery matches the book.

## Story Mode use

- The background fills one clipped `16:9` stage viewport.
- Sprites use the planned left, center, and right safe zones.
- Camera presets may apply a small pan or zoom without revealing empty edges.
- The background never contains generated character stand-ins.
- Dialogue and subtitles remain separate layers.
- Missing or rejected backgrounds fall back to a neutral placeholder and do
  not silently use an unrelated location.

## Implementation order

1. Add the structured background brief and prompt builder.
2. Change only the background provider path to landscape SDXL.
3. Add dimension and response validation plus focused Worker tests.
4. Update the review card for landscape preview, reject, and regenerate.
5. Connect approved asset IDs to matching cutscenes.
6. Test multiple locations and multiple states in one imported EPUB chapter.

## Acceptance checks

- Cloudflare returns a valid `1024 x 576` image.
- The generated scene is landscape and shows a complete physical environment.
- One, two, and three full-body sprites can occupy the planned lanes.
- The lower subtitle area does not cover essential landmarks.
- No character, text, floating island, diorama, or isolated-object composition
  appears.
- Rejecting a result does not replace the last approved background.
- A chapter with two locations uses two matching backgrounds.
- A state change such as day to night uses the correct variant.
