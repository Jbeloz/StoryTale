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
assets/fonts/               licensed fonts
```

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

Full UI mockup screenshots remain in `docs/ui-concepts/ui/`. They are design references and must not be bundled into the app.
