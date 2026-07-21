# StoryTale

StoryTale is a local-first mobile EPUB library with DeepL translation, on-device AI voice models, and sprite-based chapter Story Mode.

## Current status

- Flutter project for Android, iOS, and Web
- Feature-first source folders under `lib/src`
- Prepared folders for EPUBs, sprites, backgrounds, audio, and movement data
- Dynamic placeholder screens for Library, Reader, and Story Mode
- Local-first architecture with no Supabase
- DeepL is the only planned translation API
- Offline Tagalog TTS and five ONNX character voice packs are planned for Android
- Cloudflare Workers AI generates chapter backgrounds only
- Gemini 3.1 Flash Image creates reviewed character sprite sheets and layers
- Real local EPUB selection, metadata, cover, and cleaned chapter parsing

Imported books currently stay in memory for the app session. Device persistence,
DeepL translation, Gemini analysis, TTS, sprite asset saving, and full Story
Mode playback are the next implementation phases.

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

- [Architecture](docs/ARCHITECTURE.md)
- [Short plan](docs/PROJECT_PLAN.md)
- [Requirements](docs/REQUIREMENTS.md)
- [App flow](docs/APP_FLOW.md)
- [Animated Story Mode plan](docs/ANIMATED_STORY_MODE_PLAN.md)
- [Environment setup](docs/ENVIRONMENT_SETUP.md)
- [Asset guide](docs/ASSET_GUIDE.md)
- [Cloudflare image generator](docs/CLOUDFLARE_IMAGE_GENERATOR.md)
- [UI concepts](docs/ui-concepts/README.md)
