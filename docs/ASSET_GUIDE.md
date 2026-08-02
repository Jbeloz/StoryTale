# StoryTale Asset Guide

This document defines asset ownership and the target local folder layout. See
the [Master Roadmap](ROADMAP.md) for implementation status.

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

Uploaded EPUBs and generated book assets never go into the bundled Flutter
`assets` folder. In the current prototype, imported books remain in memory for
the app session while Story Bibles, background records, faces, and poses use
small local repositories. The persistent file hierarchy below is the target for
the later book/volume storage phase:

```text
books/<book-id>/book.json
books/<book-id>/cover.webp
books/<book-id>/story-bible/characters/<character-id>/character-design.json
books/<book-id>/story-bible/characters/<character-id>/appearance-manifest.json
books/<book-id>/story-bible/characters/<character-id>/generation-trace.json
books/<book-id>/story-bible/characters/<character-id>/face/eyes/*.png
books/<book-id>/story-bible/characters/<character-id>/face/noses/*.png
books/<book-id>/story-bible/characters/<character-id>/face/mouths/*.png
books/<book-id>/story-bible/characters/<character-id>/face/details/*.png
books/<book-id>/story-bible/characters/<character-id>/face/sets.json
books/<book-id>/story-bible/characters/<character-id>/hair/back.png
books/<book-id>/story-bible/characters/<character-id>/hair/front.png
books/<book-id>/story-bible/characters/<character-id>/generation/character-sheet-source.png
books/<book-id>/story-bible/characters/<character-id>/generation/character-sheet-clean.png
books/<book-id>/story-bible/characters/<character-id>/outfits/<outfit-id>/parts/*.png
books/<book-id>/story-bible/characters/<character-id>/outfits/<outfit-id>/outfit-back.png
books/<book-id>/story-bible/characters/<character-id>/outfits/<outfit-id>/outfit-front.png
books/<book-id>/story-bible/characters/<character-id>/accessories/head/*.png
books/<book-id>/story-bible/characters/<character-id>/accessories/face/*.png
books/<book-id>/story-bible/characters/<character-id>/accessories/body-back/*.png
books/<book-id>/story-bible/characters/<character-id>/accessories/body-front/*.png
books/<book-id>/story-bible/characters/<character-id>/accessories/held/*.png
books/<book-id>/story-bible/characters/<character-id>/accessories/attachments.json
books/<book-id>/story-bible/characters/<character-id>/previews/*.png
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

Character appearance layers use transparent PNGs. The canonical head, torso,
upper/lower arms, and upper/lower legs remain shared, immutable assets under
`assets/images/characters/rigs/humanoid_v1/`; generated character folders do
not contain replacement base geometry. Face features, front/back hair,
per-body-part clothing, garment extensions, and accessories are composed over
that rig.

The appearance manifest stores selected front hair, optional back hair,
per-style X/Y/scale fits, skin tone, face-set IDs, outfit IDs, and accessory
IDs. Saving `None` as back hair hides only that appearance layer; it does not
delete Short, Medium, Long, or generated catalog assets.

Each clothing overlay uses the exact matching body-part canvas and pivot, so it
moves with that limb. Long hair uses `hair/back.png` behind the head and torso,
while bangs and front locks use `hair/front.png` above the face. Loose skirts,
robes, capes, and coat tails use torso/hip-anchored extension layers rather
than malformed leg images.

Poses such as idle, talking, pointing, and walking are JSON transforms, so they
do not require new body pictures. Named custom poses are created in Sprite
Studio and saved in app-local storage. Built-in project poses remain under the
matching bundled rig folder. Fixed layer rules keep right limbs in front of
left limbs and upper arms in front of lower legs.

Held props store a hand anchor, grip pivot, scale, rotation offset, named layer
mode, and optional grip overlay. This lets a sword sit behind the gripping arm
while fingers or a guard render above it. See
[Generated Character Pipeline Plan](GENERATED_CHARACTER_PIPELINE_PLAN.md) and
[Sprite Studio plan](SPRITE_STUDIO_PLAN.md).

The bundled working rig is in
`assets/images/characters/rigs/humanoid_v1/`. Its approved neutral reference
uses an oversized chibi head and short body. The original full-body placement
remains the alignment reference; runtime parts are cropped and reconstructed
using their saved positions and pivots.

Gemini 3.1 Flash Image creates one fixed-layout character sheet containing
separated face details, front/back hair, and nine fitted clothing regions, plus
optional accessory components when required. The character sheet keeps the
canonical canvas and arrangement; its head accepts masked face details but no
generated skull, skin base, or anatomy.
StoryTale removes the flat green background, cuts the fixed cells with one
versioned crop manifest, hard-masks each generated layer, and composes it over
the shared rig locally.
Gemini never creates the runtime head or body. Reuse the accepted layers across
every chapter and volume. Cloudflare Workers AI remains the location and
chapter-background source.

See [Character Sheet V1 Plan](CHARACTER_SHEET_PLAN.md) for the canonical sheet,
local full-body proof, and output package.

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
