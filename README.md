# StoryTale

StoryTale is a local-first mobile EPUB library with DeepL translation, on-device AI voice models, and sprite-based chapter Story Mode.

## Current status

- Flutter project for Android, iOS, and Web
- Feature-first source folders under `lib/src`
- Functional reusable screens for Library, Reader, Audio, Sprite Studio, Story
  Bible review, generated-asset catalogs, and visual-novel Story Mode
- Local-first architecture with no Supabase
- Real local EPUB selection, metadata, cover, and cleaned chapter parsing
- Gemini chapter analysis, semantic validation, persistent per-book Story
  Bibles, automatic entity approval, and location requirements
- Completed prototype Sprite Studio, starter modular faces, universal fitted
  hair controls, scene layouts, camera movement, character movement, and Story
  Mode playback
- Local generated-background catalog with automatic validation, stable asset
  registration, and read-only result previews

The current development phase is the locked-template character pipeline. Each
actor now saves and restores its own front hair, optional back hair including
`None`, skin tone, and universal per-style X/Y/scale fits. The canonical
V1 character-sheet guide, neutral reference, masks, crop/anchor manifest,
prompt contract, and Flutter contract loader are complete. Flutter and the
private Worker now share one controlled, fingerprinted 4K V1 request with
five hash-checked references and no automatic paid retry. The local package
builder now removes green, cuts the fixed manifest cells, applies the allowed,
protected, and seam masks, stores transparent session layers and metadata, and
assembles the neutral full-body proof without redrawing the runtime head or
body. The same accepted package now composes read-only Idle, Talking, Pointing,
and Walking proofs and exposes Character, Layers, Faces, Hair, Poses, and
Details review groups. V3 remains the owner-selected exact-size `4096 x 1024`
(`4:1`, `2K`) fallback. The latest local-only V4 experiment uses a true
`2048 x 512` (`4:1`, `1K`) transport sheet with front hair plus separate Short,
Medium, and Long back-hair slots. Every transport cell is uniformly `58%` of
its V3 runtime canvas and maps back to the exact Sprite Studio output size. The
checked-in guide uses the default actor and retains heroine-compatible source
mapping. Owner visual approval of V4 is pending; Flutter, the Worker, and
Gemini still use V1, and no V4 provider request is authorized yet.
Imported books still remain in memory for the app session,
DeepL uses placeholder text, the mobile ONNX TTS runtime is not connected, and
final book-specific layered characters are not complete.

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

- [Complete project handoff](docs/PROJECT_HANDOFF.md)
- [Master roadmap](docs/ROADMAP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Short plan](docs/PROJECT_PLAN.md)
- [Requirements](docs/REQUIREMENTS.md)
- [App flow](docs/APP_FLOW.md)
- [Animated Story Mode plan](docs/ANIMATED_STORY_MODE_PLAN.md)
- [Environment setup](docs/ENVIRONMENT_SETUP.md)
- [Asset guide](docs/ASSET_GUIDE.md)
- [Cloudflare image generator](docs/CLOUDFLARE_IMAGE_GENERATOR.md)
- [Generated character pipeline](docs/GENERATED_CHARACTER_PIPELINE_PLAN.md)
- [Character sheet V1](docs/CHARACTER_SHEET_PLAN.md)
- [UI concepts](docs/ui-concepts/README.md)
