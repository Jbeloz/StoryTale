# StoryTale Short Plan

## 1. Foundation - done

- StoryTale name, folders, docs, theme, navigation, and placeholders
- Small reusable UI that reads lists of dynamic data

## 1.1 Functional UI foundation - done

- All planned screens now have functional prototype routes or reusable sheets.
- One shared app shell owns the reusable four-item bottom navigation.
- Shared book cards, chapter rows, empty states, and image fallbacks use dynamic data.
- Missing artwork safely falls back to placeholders from `assets/images/ui/`.

## 2. Local EPUB Library - import foundation done

- Pick and validate `.epub` files on Web and mobile
- Parse the cover, metadata, and cleaned chapter text locally
- Keep stable text-block IDs ready for chapter-by-chapter Gemini analysis
- Show the imported book in the existing Library, Reader, and Audio screens
- Save books and reading progress on the device
- Do not use Supabase yet

The next library step is device persistence, followed by series and volume
grouping. The test EPUB currently parses into 15 readable story sections.

## 3. DeepL Translation

- Use target code `TL` for English-to-Filipino translation
- Use DeepL as the only translation provider
- Cache translations locally to save the 1,000,000-character allowance

## 3.1 Gemini Story Analysis

- Use `gemini-3.5-flash` through a replaceable analysis service
- Send one cleaned chapter plus the compact approved story-bible registry
- Require structured JSON matching the `ChapterAnalysis` schema
- Validate source ranges, speaker IDs, and locked character designs locally
- Keep DeepL separate and use it only for translation

## 4. Offline Voice Models

- Convert Meta MMS Tagalog TTS to ONNX and run it through `sherpa-onnx`
- Convert and test one selected RVC `.pth` voice as an ONNX voice pack
- Benchmark generation on the target Android phone
- Add four more voice packs after the first succeeds
- Assign the five local voices to the narrator and characters
- Prepare and cache chapter audio before Story Mode playback
- Highlight the currently spoken text

## 5. Chapter Story Mode

- Add `Book -> Volume -> Chapter` organization with stable IDs
- Build a shared character/location story bible from per-chapter analysis
- Create one `ChapterStory` package for every chapter
- Preserve the complete chapter from its first to last source block
- Add backgrounds, character sprites, voices, subtitles, movement, and sound
- Store transparent body and expression-head sprite layers with fixed anchors
- Keep character appearance locked and reusable across every volume
- Show a short moral after the chapter
- Save and reuse all chapter content locally
- Prepare chapters on demand instead of generating an entire long series at once
- Keep background music on standby; it is not required for the MVP

Detailed phases, folder organization, schemas, rebuilding rules, and tests are
in [Animated Story Mode plan](ANIMATED_STORY_MODE_PLAN.md).

## 6. Sprite and Background Creation - Cloudflare setup done

- Use the private StoryTale Cloudflare Worker with Workers AI
- Start with `@cf/black-forest-labs/flux-1-schnell`
- Use Cloudflare Images foreground segmentation for transparent sprite output
- Generate images once, review them, then store accepted files locally
- Keep Story Mode working with manually provided sprites
- Connect the Flutter image-generation screen in a later app phase

## Decisions still open

- Local database package
- Sprite style and licensing
- The five RVC models that successfully convert and pass mobile testing
- Minimum supported Android device after the first performance benchmark
