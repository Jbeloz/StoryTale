# StoryTale Architecture

## Simple flow

```mermaid
flowchart LR
    A["Upload EPUB"] --> B["EPUB Parser"]
    B --> C["Local Library"]
    C --> D["Chapter Reader"]
    D --> E["DeepL Translation"]
    E --> F["Cached Filipino Text"]
    D --> G["Local ChapterStory Data"]
    F --> G
    G --> M["Offline Tagalog TTS"]
    M --> N["Selected ONNX Voice Pack"]
    N --> O["Cached Chapter Audio"]
    G --> H["Story Mode Player"]
    O --> H
    H --> I["Sprites + Movement + Voices + Moral"]
    J["Cloudflare Image Worker"] --> L["Workers AI - FLUX.1-schnell"]
    L --> K["Saved Local Images"]
    K --> G
```

## Main parts

| Part | Short purpose |
| --- | --- |
| Flutter app | Shows dynamic books, chapters, reader, and Story Mode screens. |
| EPUB importer | Accepts `.epub` only and extracts cover, title, author, and chapters. |
| Local storage | Saves EPUBs, progress, translations, chapter data, sprites, and settings on the device. |
| DeepL service | The only translation API. It translates English chapter text into Filipino. |
| Offline TTS engine | Runs a Tagalog ONNX TTS model inside the app without depending on Android voices. |
| Tagalog base model | Uses the Meta MMS Tagalog model, converted to ONNX, to create correctly pronounced source audio. |
| Voice packs | Stores five selected RVC voices as ONNX models installed with the app. Only the active voice is loaded into memory. |
| Audio generator | Creates narration in the background and caches completed chapter audio for smooth playback. |
| ChapterStory data | Stores the sprites, dialogue, movements, sounds, and moral for one chapter. |
| Story Mode player | Moves sprites over backgrounds while playing voices, subtitles, and sound effects. |
| Cloudflare Image Worker | Private, rate-limited endpoint that creates a sprite or background without exposing Cloudflare account credentials. |
| Workers AI | Runs `@cf/black-forest-labs/flux-1-schnell` and returns a JPEG for local storage. |

## Dynamic chapter data

Every chapter can have one `ChapterStory` object:

```text
ChapterStory
- chapterId
- title
- moral
- characters: name, sprite, voiceId
- scenes: background, speaker, subtitle, movement, soundEffect, audioClip
```

The UI reads this data, so we do not create a separate Flutter screen for every book or chapter.

## Chosen setup

| Need | Choice |
| --- | --- |
| App data | Local device storage first; no Supabase |
| Translation | DeepL API only |
| DeepL allowance | Current account shows 1,000,000 included characters per usage period |
| Filipino target code | `TL` |
| TTS runtime | `sherpa-onnx` / ONNX Runtime inside Flutter |
| Tagalog voice | Meta MMS Tagalog TTS converted to ONNX |
| Character voices | Five selected RVC `.pth` models converted to `.onnx` voice packs |
| Voice processing | On-device, generated before playback, then cached locally |
| Story Mode | Sprites and simple movements |
| Image creation | Cloudflare Workers AI with FLUX.1-schnell |
| Image storage | Save accepted sprites and backgrounds on the device |

## On-device voice flow

```text
Story text
-> optional cached DeepL Filipino translation
-> offline Tagalog TTS model
-> selected RVC ONNX voice pack
-> local audio file
-> Story Mode playback
```

- Voice-Models.com `.pth` files cannot run directly in Flutter; every selected model must pass ONNX conversion and a sound test first.
- The app installs five named voice packs: narrator, heroine, hero, deep character, and elder/extra.
- Generate audio sentence by sentence as a background chapter-preparation job.
- Load one character voice at a time and unload it after its lines are generated.
- Save generated audio so replaying a chapter does not rerun the models.
- If voice preparation fails, normal reading and subtitles remain available.
- Start by proving one voice on the target Android phone, then add the remaining four after measuring speed, memory, storage, and sound quality.

The planned offline runtime is [sherpa-onnx](https://k2-fsa.github.io/sherpa/onnx/flutter/pre-built-app.html). The Tagalog base is [Meta MMS Tagalog TTS](https://huggingface.co/facebook/mms-tts-tgl). RVC voice packs use the project's [ONNX exporter](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI/blob/main/infer/modules/onnx/export.py).

## DeepL setup

DeepL supports Tagalog through API target code `TL`. StoryTale sends translation requests only when online, then caches the result. DeepL remains the only translation provider.

## Local-first rule

```text
lib/src/features/    feature UI and logic
lib/src/shared/      reusable dynamic widgets
assets/models/tts/   bundled offline Tagalog TTS files
assets/models/voices/ five converted ONNX voice packs
assets/              bundled demo sprites, backgrounds, and sound
app local storage/   uploaded EPUBs and generated chapter content
docs/                short project decisions
```

DeepL remains the only translation provider. Cloudflare Workers AI is the separate image provider. Do not commit the DeepL key or the image Worker token. A token inside a mobile build is acceptable only for a private prototype because compiled app values can be extracted; a released app needs user authentication and stronger abuse controls.

See [Cloudflare image generator](CLOUDFLARE_IMAGE_GENERATOR.md) for the setup and test flow.
