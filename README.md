# StoryTale

StoryTale is a local-first mobile EPUB library with DeepL translation, on-device AI voice models, and sprite-based chapter Story Mode.

## Current status

- Flutter project for Android, iOS, and Web
- Feature-first source folders under `lib/src`
- Functional reusable screens for Library, Reader, Audio, Sprite Studio, Story
  Bible review, background review, and visual-novel Story Mode
- Local-first architecture with no Supabase
- Real local EPUB selection, metadata, cover, and cleaned chapter parsing
- Gemini chapter analysis, semantic validation, persistent per-book Story
  Bibles, automatic entity approval, and location requirements
- Completed prototype Sprite Studio, starter modular faces, scene layouts,
  camera movement, character movement, and Story Mode playback
- Local generated-background catalog with review and stable asset registration

The current development phase is the final landscape visual-novel background
pipeline. The existing square Workers AI route is only a connectivity
smoke test. Imported books still remain in memory for the app session, DeepL
uses placeholder text, the mobile ONNX TTS runtime is not connected, and
book-specific foreground and character assets are not complete.

See the [master roadmap](docs/ROADMAP.md) for the only authoritative phase
status and development order.

## Run locally

```powershell
flutter pub get
.\tool\run_storytale.ps1
```

Put local keys in the ignored `.env` file. Flutter calls the private image
Worker; the Gemini API key stays in a Worker secret and is never bundled in the
app. DeepL and story-analysis credentials also remain outside Flutter.

For a browser preview:

```powershell
.\tool\run_storytale.ps1 -Device chrome
```

## Verify

```powershell
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Documentation

- [Master roadmap](docs/ROADMAP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Short plan](docs/PROJECT_PLAN.md)
- [Requirements](docs/REQUIREMENTS.md)
- [App flow](docs/APP_FLOW.md)
- [Animated Story Mode plan](docs/ANIMATED_STORY_MODE_PLAN.md)
- [Environment setup](docs/ENVIRONMENT_SETUP.md)
- [Asset guide](docs/ASSET_GUIDE.md)
- [Cloudflare image generator](docs/CLOUDFLARE_IMAGE_GENERATOR.md)
- [UI concepts](docs/ui-concepts/README.md)
