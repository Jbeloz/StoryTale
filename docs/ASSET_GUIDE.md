# StoryTale Asset Guide

## Bundled demo assets

```text
assets/books/               licensed demo EPUBs only
assets/images/backgrounds/  chapter backgrounds
assets/images/characters/   character sprites
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
books/<book-id>/book.epub
books/<book-id>/cover.webp
books/<book-id>/chapters/<chapter-id>.json
books/<book-id>/story/<chapter-id>.json
books/<book-id>/sprites/
books/<book-id>/audio/<chapter-id>/
```

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
