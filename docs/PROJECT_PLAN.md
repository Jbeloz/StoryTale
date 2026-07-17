# StoryTale Short Plan

## 1. Foundation - done

- StoryTale name, folders, docs, theme, navigation, and placeholders
- Small reusable UI that reads lists of dynamic data

## 1.1 Functional UI foundation - done

- All planned screens now have functional prototype routes or reusable sheets.
- One shared app shell owns the reusable four-item bottom navigation.
- Shared book cards, chapter rows, empty states, and image fallbacks use dynamic data.
- Missing artwork safely falls back to placeholders from `assets/images/ui/`.

## 2. Local EPUB Library - service integration next

- Upload `.epub` only
- Parse cover, book details, and chapters
- Save books and reading progress on the device
- Do not use Supabase yet

## 3. DeepL Translation

- Use target code `TL` for English-to-Filipino translation
- Use DeepL as the only translation provider
- Cache translations locally to save the 1,000,000-character allowance

## 4. Offline Voice Models

- Convert Meta MMS Tagalog TTS to ONNX and run it through `sherpa-onnx`
- Convert and test one selected RVC `.pth` voice as an ONNX voice pack
- Benchmark generation on the target Android phone
- Add four more voice packs after the first succeeds
- Assign the five local voices to the narrator and characters
- Prepare and cache chapter audio before Story Mode playback
- Highlight the currently spoken text

## 5. Chapter Story Mode

- Create one `ChapterStory` package for every chapter
- Add backgrounds, character sprites, voices, subtitles, movement, and sound
- Show a short moral after the chapter
- Save and reuse all chapter content locally

## 6. Sprite and Background Creation - Cloudflare setup done

- Use the private StoryTale Cloudflare Worker with Workers AI
- Start with `@cf/black-forest-labs/flux-1-schnell`
- Generate images once, review them, then store accepted files locally
- Keep Story Mode working with manually provided sprites
- Connect the Flutter image-generation screen in a later app phase

## Decisions still open

- Local database package
- Sprite style and licensing
- The five RVC models that successfully convert and pass mobile testing
- Minimum supported Android device after the first performance benchmark
