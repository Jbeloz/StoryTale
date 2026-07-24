# StoryTale Asset Guide

## Bundled demo assets

```text
assets/books/               licensed demo EPUBs only
assets/images/backgrounds/  chapter backgrounds
assets/images/characters/   character sprites
assets/images/characters/rigs/ reusable demo rigs and pose JSON
assets/images/ui/           clean logo, onboarding, banner, and UI illustrations
assets/audio/narration/     optional prepared voices
assets/audio/sfx/           sound effects
assets/models/tts/          offline Tagalog TTS model and tokens
assets/models/voices/       five converted ONNX RVC voice packs
assets/animations/          demo ChapterStory movement data
assets/fonts/               Poppins font files and OFL license
```

StoryTale uses bundled Poppins Regular, Medium, SemiBold, and Bold weights so
the interface does not depend on downloading fonts at runtime.

## Dynamic local content

Uploaded EPUBs and created sprites are stored on the device while the app is running. They do not go into the project `assets` folder.

```text
books/<book-id>/book.json
books/<book-id>/cover.webp
books/<book-id>/story-bible/characters/<character-id>/design/master-source.jpg
books/<book-id>/story-bible/characters/<character-id>/sprites/anchors.json
books/<book-id>/story-bible/characters/<character-id>/sprites/master-transparent.png
books/<book-id>/story-bible/characters/<character-id>/sprites/rig.json
books/<book-id>/story-bible/characters/<character-id>/sprites/base-parts/*.png
books/<book-id>/story-bible/characters/<character-id>/sprites/outfits/<outfit-id>/parts/*.png
books/<book-id>/story-bible/characters/<character-id>/sprites/poses/*.json
books/<book-id>/story-bible/characters/<character-id>/sprites/faces/*.png
books/<book-id>/story-bible/characters/<character-id>/sprites/composites/*.png
books/<book-id>/story-bible/animals/<animal-id>/sprites/*.png
books/<book-id>/story-bible/creatures/<creature-id>/sprites/*.png
books/<book-id>/story-bible/plants/<plant-id>/states/*.png
books/<book-id>/story-bible/props/<prop-id>/states/*.png
books/<book-id>/story-bible/locations/<location-id>/backgrounds/
books/<book-id>/volumes/<volume-id>/source/original.epub
books/<book-id>/volumes/<volume-id>/chapters/<chapter-id>/chapter.json
books/<book-id>/volumes/<volume-id>/chapters/<chapter-id>/story/
books/<book-id>/jobs/
sprite-studio/rigs/<rig-id>/poses/<pose-id>.json
```

Recurring humans, animals, creatures, plants, props, and locations belong in
the shared story bible. Chapter folders contain only the analysis, script,
subtitles, audio, and references needed by that chapter. The complete layout
and lifecycle are defined in [Animated Story Mode plan](ANIMATED_STORY_MODE_PLAN.md)
and [Story Bible Entity and Asset Plan](STORY_BIBLE_ENTITY_ASSET_PLAN.md).

Character layers use transparent PNGs. The cropped head, torso, upper/lower
arms, and upper/lower legs are connected by the joints in `rig.json`. Face
expressions remain separate layers. The neutral composite is kept as a review
image and fallback. New outfits use overlays with the same dimensions and
pivots as their matching body parts. Poses such as idle, talking, pointing, and
walking are JSON transforms, so they do not require new body pictures. Named
custom poses are created in Sprite Studio and saved in app-local storage.
Built-in project poses remain under the matching bundled rig folder. Fixed
layer rules keep right limbs in front of left limbs and upper arms in front of
lower legs. See [Sprite Studio plan](SPRITE_STUDIO_PLAN.md).

The bundled working rig is in
`assets/images/characters/rigs/humanoid_v1/`. Its approved neutral reference
uses an oversized chibi head and short body. The original full-body placement
remains the alignment reference; runtime parts are cropped and reconstructed
using their saved positions and pivots.

Gemini 3.1 Flash Image creates one full-body master from the locked description,
full-proportion, approved-head, and approved-body references. StoryTale removes
the flat green background locally, splits that exact master into same-canvas
head/body PNGs, and builds the full-body review preview by rejoining them. It
does not pay for three separately generated parts. Reuse the approved layers
across every chapter and volume. Cloudflare Workers AI remains the location and
chapter-background source.

Speaking animals and creatures start with a transparent neutral sprite plus one
talking state and use whole-sprite movement. Plants and props use transparent
focus assets with only plot-required states. Do not generate an asset for every
noun, and never reuse an unrelated human actor as a placeholder.

The bundled Cloudflare background example is
`assets/images/backgrounds/cloudflare_examples/moonlit-rose-garden.jpg`.

Keep the original `.pth` files outside the Flutter assets. Only converted and tested `.onnx` voice packs belong in the app. Generate chapter audio once and reuse it. Generate or add sprites once, optimize them, record their source/license, and reuse them in chapter movements.

## Voice model folders

Put downloaded RVC files together by role:

```text
models/voices/raw/narrator/  model.pth + model.index (or model.model)
models/voices/raw/heroine/   model.pth + model.index (or model.model)
models/voices/raw/hero/      model.pth + model.index (or model.model)
models/voices/raw/deep/      model.pth + model.index (or model.model)
models/voices/raw/elder/     model.pth + model.index (or model.model)
```

These raw downloads are ignored by Git and are not bundled into Flutter.
Converted and tested mobile files later go into the matching folder under
`assets/models/voices/`.

Set conversion pitches in `models/voices/voice_settings.json`. Heroine and Hero
use `+16` by default. Run `./tool/run_storytale.ps1` after changing a raw model
or pitch; it validates the pairs, generates only stale chapter audio, updates
the manifest, and then starts Flutter. Flutter plays the generated WAV files;
it does not load `.pth` models or change their RVC pitch during playback.

Full UI mockup screenshots remain in `docs/ui-concepts/ui/`. They are design references and must not be bundled into the app.
