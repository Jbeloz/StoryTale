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
- Cloudflare Workers AI is the planned sprite/background image provider
- StoryTale image Worker deployed and verified with a real FLUX.1-schnell result

EPUB importing, DeepL translation, TTS, and Story Mode playback are placeholders for later phases.

## Run locally

```powershell
flutter pub get
.\tool\run_storytale.ps1
```

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
- [Asset guide](docs/ASSET_GUIDE.md)
- [Cloudflare image generator](docs/CLOUDFLARE_IMAGE_GENERATOR.md)
- [UI concepts](docs/ui-concepts/README.md)
