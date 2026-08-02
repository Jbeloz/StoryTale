# StoryTale Short Plan

This is the short project overview. The authoritative current phase, dependency
order, completed work, and complete remaining-work checklist are in the
[Master Roadmap](ROADMAP.md).

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
- [x] Build typed, locally persisted per-book story bibles for humans, animals,
  creatures, plants, props, locations, and aliases
- [x] Extract safe entity candidates from each cleaned chapter
- [x] Review, correct, merge, delete, and approve local entity candidates
- [x] Automatically approve high-confidence, source-backed, conflict-free
  entities while keeping uncertain candidates pending
- [x] Normalize locations into specific background-ready places and keep broad
  settings as parent context
- [x] Derive an ordered set of required backgrounds from every chapter's real
  place and place-state changes
- [x] Reuse backgrounds for unchanged consecutive shots instead of generating
  one image per paragraph
- [x] Build the local location-background catalog, automatic validation,
  stable asset registration, and read-only result preview
- [x] Replace the square FLUX smoke test with `1024 x 576` visual-novel
  background generation and connect matching ready assets to cutscenes
- [x] Generate, validate, and register matching foreground assets automatically
- [ ] Create one final persistent `ChapterStory` package for every chapter
- Preserve the complete chapter from its first to last source block
- Add backgrounds, character sprites, voices, subtitles, movement, and sound
- Store transparent body and expression-head sprite layers with fixed anchors
- Keep character appearance locked and reusable across every volume
- Show a short moral after the chapter
- Save and reuse all chapter content locally
- Never substitute a prototype human actor for a missing animal, plant, or prop;
  use a no-character detail/background shot instead
- Prepare chapters on demand instead of generating an entire long series at once
- Keep background music on standby; it is not required for the MVP

Detailed phases, folder organization, schemas, rebuilding rules, and tests are
in [Animated Story Mode plan](ANIMATED_STORY_MODE_PLAN.md). Non-human subjects
and important objects follow the
[Story Bible Entity and Asset Plan](STORY_BIBLE_ENTITY_ASSET_PLAN.md).
Landscape backgrounds are connected. The current blocking implementation phase
is the locked-template human package described by the
[Generated Character Pipeline Plan](GENERATED_CHARACTER_PIPELINE_PLAN.md).

## 5.1 Sprite Studio

- [x] Rename the current Sprite Positioner to Sprite Studio
- [x] Keep the sprite canvas visible beside or above its transform inspector
- [x] Use one consistent alpha-aware selector for mouse, touchpad, and touch
- [x] Enforce the approved right/left limb and arm/leg layer rules
- [x] Add a bone overlay that uses the existing parent pivots for easier posing
- [x] Add a default catalog with Neutral, Talking, Happy, Sad, and Angry faces
- [x] Create and name custom poses starting from Neutral after bones and faces work
- [x] Save pose transforms and layers locally for Animated Story Mode

The complete final-editor plan is in
[Sprite Studio plan](SPRITE_STUDIO_PLAN.md).

## 6. Sprite and Background Creation

- Keep the ten approved local rig geometries (one head plus nine body pieces)
  immutable
- Use Gemini 3.1 Flash Image only for missing face, front/back hair,
  clothing-only, loose-garment, and accessory component sheets
- Keep the Gemini key in the private Worker, never in Flutter
- Send the locked description, exact component guide, and approved style
  references to preserve identity and alignment
- Send one canonical clothing-only guide whose head is reference-only and whose
  nine body cells keep exact left/right ownership, canvas size, and placement
- Remove green, cut the known cells using one versioned crop manifest,
  hard-mask them locally, and compose them over the shared rig
- Save front hair, optional back hair, per-style X/Y/scale fits, and skin tone
  once in the appearance manifest; `None` does not delete catalog hair
- Never regenerate a locked character for every chapter or volume
- Route sprites to Gemini and backgrounds to Workers AI through the private Worker
- Store accepted sprites and backgrounds locally
- Keep Story Mode working with manually provided artwork

The exact sheet, splitter, folders, and acceptance gate are in the
[Character Clothing Sheet Plan](CHARACTER_CLOTHING_SHEET_PLAN.md).

## Decisions still open

- Local database package
- Sprite style and licensing
- The five RVC models that successfully convert and pass mobile testing
- Minimum supported Android device after the first performance benchmark
