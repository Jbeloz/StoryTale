# StoryTale Complete Project Handoff

Last verified: **7 August 2026**

This document is the starting point for a new StoryTale chat. It summarizes
the product, implementation, data contracts, decisions, feedback, rejected
ideas, current limitations, and working method. It does not replace the
[Master Roadmap](ROADMAP.md): the roadmap remains the authority for phase
status and development order.

## 1. Project identity

| Item | Current value |
| --- | --- |
| Product name | **StoryTale** |
| Previous name | StoryWorld; rejected and renamed everywhere practical |
| Repository | [Jbeloz/StoryTale](https://github.com/Jbeloz/StoryTale) |
| Local workspace | `C:\Users\Houro\Desktop\IT Elect 4\storytale` |
| Author/student | **John Benedict S. Alejo** |
| Course | **IT Elect 4** |
| App type | Local-first Flutter EPUB library |
| Supported Flutter targets | Android, iOS, and Web prototype |
| Package/version | `storytale` / `0.1.0` |
| Main test book | **The Little Prince** fixture |
| Deferred generic EPUB fixture | `Mushoku_Tensei_-_Volume_09_Seven_Seas_Kobo.epub`; do not add title-specific rules |

## 2. Purpose and users

StoryTale helps students and English learners read user-owned English EPUB
books more easily and stay engaged. It combines a local e-book library,
English-to-Filipino translation, narration, and a chapter-based visual-novel
Story Mode in one mobile app.

Primary users:

- students who have difficulty understanding English words or passages;
- English learners who benefit from English/Filipino reading modes;
- readers who understand stories better with audio, subtitles, and visuals;
- users who want to import their own legal `.epub` files and keep them locally.

The MVP is educational and local-first. Normal reading must remain available
when AI, translation, asset generation, or Story Mode preparation fails.

## 3. Product requirements

### Library and reader

- Import **EPUB only**. PDF and Word import are not supported.
- Parse metadata, cover, spine/table of contents, chapter type, HTML, and
  readable text locally.
- Give every cleaned text block a stable source ID.
- Show Library, Search, Book Details, Reader, Now Reading, bookmarks, progress,
  reader settings, and placeholders when artwork is unavailable.
- Use Poppins throughout the app.
- Keep reading progress proportional to the chapter scroll position and reach
  100% at the end.
- Offer a scrolling reader and a page-by-page reader. `ChapterPaginator` packs
  source blocks into pages that fit the viewport, gives each illustration its
  own page, and never loses or duplicates text. One progress fraction serves
  both modes.
- Preserve the original English text on every service failure.

### Translation

- DeepL is the **only** translation provider.
- Translate English to Filipino/Tagalog using target code `TL`.
- Support English, Filipino, and dual-language reading.
- Cache translations by source-text hash and track usage to avoid duplicate
  requests.
- The current DeepL account screenshot showed **1,000,000 included characters
  per usage period**; this is account information, not a permanent product
  guarantee.
- Tell the user before book text is sent to DeepL.

### Narration and voices

- Provide chapter audio, narrator/character voice selection, progress,
  previous/next, seek, speed, and pitch controls.
- Final audio should work offline after preparation.
- Keep five roles: Narrator, Hero, Heroine, Adult/Deep, and Elder.
- Use one Tagalog on-device ONNX TTS base, then optional ONNX voice-conversion
  packs. Load only the active pack to limit memory use.
- Audio, subtitle beats, speaker identity, and highlighted text must stay
  synchronized.

### Animated Story Mode

- Story Mode is chapter-based and visual-novel-like, not generated video.
- A chapter is `Cutscene -> Shot -> Beat`; every source block must appear once,
  in order, without summarizing, omitting, duplicating, or rewriting it.
- Use short readable subtitles. A shot normally contains one to three short
  beats; meaningful changes create a new shot.
- Support zero, one, two, and three visible subjects; layouts, character
  mirroring, scale/depth, camera pan/zoom/drift/push/pull/snap/shake,
  transitions, and simple sprite movement.
- A new shot is required when speaker, meaningful action, focus subject,
  location, or background state changes. Individual dialogue beats may change
  face/talking mouth, pose action, and small camera reactions.
- Every chapter ends with an editable moral.
- Missing visual assets fall back to a relevant detail/background shot and
  subtitles/audio, never an unrelated prototype human.

### Security and cost

- Never commit `.env`, API keys, Worker tokens, raw credentials, or user books.
- Gemini keys remain in a private Cloudflare Worker secret, never in Flutter.
- The current compiled prototype client token is not acceptable for public
  release; add user authentication, quota controls, and spending limits first.
- Viewing an already generated asset must never trigger another paid request.
- User-facing asset catalogs are read-only. Regenerate, replace, upload,
  discard, and retry controls remain implemented only behind a disabled
  developer flag.

## 4. Main user flow and screens

```text
Splash/onboarding
-> Library
-> import EPUB or open book
-> Book Details
-> Reader / Translation / Audio / Animated Story
-> whole-volume preparation when Story Mode is not ready
-> Story Bible and read-only prepared asset results
-> chapter visual-novel playback
-> moral
```

Implemented or scaffolded screens include:

- onboarding and splash;
- Library, Add Book, Search, Book Details, and Now Reading;
- Reader, translation mode, reader settings, and chapter progress;
- Audio Book, voice manager, chapter audio preparation, and downloads;
- Profile, settings, help, and about;
- Animated Story preparation/status, Story Bible, Location Backgrounds,
  Foreground Assets, and Book Characters;
- Sprite Studio; and
- visual-novel Story Mode, contents, settings, and moral.

The shared bottom navigation is **Library / Now Reading / Audio / Profile**.
Screens should use reusable components, dynamic data, simple code, and image
placeholders instead of copying whole page implementations.

## 5. Architecture and provider boundaries

```text
EPUB parser
-> cleaned chapter text and stable source blocks
-> one Gemini structured-analysis request per chapter
-> merged book/volume Story Bible
-> required background, foreground, and human catalogs
-> validated generated assets
-> Gemini semantic cutscene/shot/beat plan
-> Flutter validation and deterministic fallback
-> optional cached DeepL Filipino text
-> optional prepared offline audio
-> local ChapterStory package
-> visual-novel player
```

Flutter owns source coverage, stable IDs, exact coordinates, bone transforms,
layer order, timing limits, file/storage state, provider validation, and safe
fallbacks. Gemini chooses only approved semantic IDs and must not send raw
pixel coordinates or invent assets.

### Configured services

| Responsibility | Current provider/choice |
| --- | --- |
| App data | Local device first; no Supabase in the MVP |
| Translation | DeepL only, target `TL` |
| Story analysis | Gemini `gemini-3.5-flash`, structured JSON |
| Sprite appearance components | Gemini `gemini-3.1-flash-image` through the private Worker |
| Visual-novel backgrounds | Cloudflare Workers AI `@cf/stabilityai/stable-diffusion-xl-base-1.0`, `1024 x 576` |
| Secure gateway | `https://storytale-image-worker.jbalejoshift0928.workers.dev` |
| Runtime UI | Flutter |

The Cloudflare Worker is a secure tunnel and validator for Gemini sprite and
analysis requests; Cloudflare does not design those sprite components.
Workers AI creates the backgrounds. No hosted service is unlimited: Cloudflare
and Gemini provider quotas and billing still apply.

### Local environment variables

The ignored `.env` follows `.env.example`:

```dotenv
DEEPL_API_KEY=
GEMINI_API_KEY=
GEMINI_MODEL=gemini-3.5-flash
GEMINI_IMAGE_MODEL=gemini-3.1-flash-image
CLOUDFLARE_IMAGE_URL=https://storytale-image-worker.jbalejoshift0928.workers.dev
CLOUDFLARE_IMAGE_TOKEN=
```

Do not place actual values in documentation or chat.

## 6. EPUB, books, volumes, and preparation

The importer currently supports an EPUB that may contain one chapter or many
chapters. A light novel title does not imply one chapter per volume. Future
data must explicitly support:

```text
Book
-> one or more Volumes
-> one or more Chapters per Volume
-> stable source blocks per Chapter
```

Whole-volume preparation means processing **all chapters**, but still sending
one bounded Gemini analysis request per chapter. Results are merged into one
canonical Story Bible so recurring names, appearances, voices, places, and
assets are reused. The per-chapter Prepare action becomes a repair/rebuild
fallback for stale or failed chapter packages; users should not manually
generate the same main character or background for each chapter.

Volume preparation already exposes progress, current stage/chapter, elapsed
time, ready counts, Pause/Resume, Retry, and collapsed details. Its job and
large generated bytes are still session-only until Phase 8.

## 7. Story Bible and generated assets

The Story Bible supports six entity types: `human`, `animal`, `creature`,
`plant`, `prop`, and `location`. It stores canonical names, aliases, first and
later appearances, source evidence, chapter appearances, voice/actor/rig/face
links, confidence, approval, and asset ownership.

- High-confidence, conflict-free, source-backed entities are automatically
  approved.
- A location must describe a usable physical place, not a broad concept such
  as only “small planet.” It includes parent setting and meaningful state.
- A chapter may require multiple locations and multiple states of the same
  location.
- Repeated plants/props/animals/creatures use one stable asset record and only
  plot-required variants.
- The first valid generated result is automatically accepted. Invalid results
  become `needsReview` and use a safe fallback; the reader does not approve or
  regenerate assets.

### Background contract

- Exact key: `locationId + backgroundStateId`.
- Output: valid `1024 x 576` landscape image and correct MIME type.
- One continuous grounded environment with visible foreground, middle ground,
  distant background, stage surface, landmarks, and open left/center/right
  character lanes.
- Keep essential detail outside the subtitle-safe bottom area.
- Exclude people, text, UI, portraits, isolated objects, miniature dioramas,
  floating islands, and square compositions.

### Foreground contract

- Whole relevant animals, creatures, plants, and props on a removable flat
  background, converted locally to transparent PNG.
- Store stable entity, variant, asset, chapter ownership, dimensions, and
  readiness metadata.
- Up to two source-supported foreground focus layers may appear in a shot.
- Prepared Chair and Flower fixtures are connected only to the relevant
  Chapter 1 actions; they are not permanent title-specific logic.

## 8. Sprite Studio and character system

### Locked rig

The canonical `humanoid_v1` has **10 total immutable geometry parts**:

1. head;
2. torso;
3. left upper arm;
4. left lower arm/hand;
5. right upper arm;
6. right lower arm/hand;
7. left upper leg;
8. left lower leg/foot;
9. right upper leg; and
10. right lower leg/foot.

The rig owns pivots, bones, hitboxes, alpha masks, layer rules, and a geometry
hash. Gemini must never replace or reshape these runtime parts. Existing pose
IDs are Idle/Neutral, Talking, Pointing, and Walking; users may create named
additional poses from the neutral base.

Sprite Studio supports alpha-aware selection, touch/mouse/touchpad, drag,
numeric X/Y/rotation, zoom, hitboxes, bone controls, layers, Undo/Redo,
session saving, and project-default pose saving. Hair moves with the head but
can also be selected and adjusted independently. Clicking empty stage space
clears selection.

### Actor templates and faces

The five actor templates are:

| Actor ID | UI name | Purpose |
| --- | --- | --- |
| `default` | Default | neutral general character |
| `hero` | Hero | bright, alive protagonist energy rather than expressionless |
| `heroine` | Heroine | soft/cute heroine baseline |
| `elder` | Elder | older face/details; face layers must remain centered |
| `adult` | Adult | renamed from the Deep Voice visual actor; uses `adult_deep` face profile |

Narrator is an audio role, not a visible actor template.

Faces are modular layers: eyes/eyebrows, nose, mouth, and details. Standard
semantic sets are Neutral, Talking, Happy, Sad, Angry, and Surprised. The
Default catalog also contains a Crying test set generated through Gemini.
Expressions must preserve approved eye placement and white eye highlights;
strong emotions keep their expression while neutral speech may temporarily
use the talking mouth.

### Hair and skin

- Front hair and back hair are separate PNG layers.
- Back hair supports `None`, Short, Medium, and Long. `None` is a real saved
  choice and must not delete other catalog options.
- Every actor/style needs reusable X/Y/scale fit data. Do not hard-code a
  one-off layout in the renderer.
- Changing the head moves both hair layers; selecting a hair layer adjusts
  that layer only.
- Skin tone is a local opaque `#RRGGBB` color applied to the head and all nine
  body parts through rig-owned masks. It must preserve alpha, shading, facial
  detail, white eyes/highlights, hair, and clothing. Outlines change
  coherently; near-white skin keeps a visible gray outline.
- Skin recoloring must make no Gemini or Cloudflare request.

Phase 7G.1A.1 now stores one complete appearance per actor: stable front-hair
ID, optional back-hair ID including explicit `None`, skin tone, and separate
per-style X/Y/scale fits. Switching actor templates restores the saved actor
appearance instead of resetting it to the catalog defaults. The previous
single-active-actor JSON shape migrates into the new manifest safely.

### Canonical character-sheet plan

The V4 one-sheet contract is retired. The authoritative current plan is
`docs/CHARACTER_V5_PLAN.md`: V5 keeps the immutable `humanoid_v1` head and nine
body pieces, applies skin and faces locally, and generates only reusable hair
or clothing overlays. V5-0 through V5-2 are implemented locally.

The current V5-3 work unit adds three deterministic 1K green-screen reference
sheets under
`assets/images/characters/garment_guides/humanoid_v1/v5_groups/`:

1. `legs_1k_reference.png` — left column is left upper/lower leg; right column
   is right upper/lower leg.
2. `arms_1k_reference.png` — left column is left upper/lower arm; right column
   is right upper/lower arm.
3. `torso_1k_reference.png` — one centered torso reference.

Each canvas is `1024 x 1024`, and every source part is copied at its exact
native runtime size. These are reference guides only; they are not generated
garments, are not registered in Flutter, and no provider request has been made.
The remaining gate is the offline reply-to-separator-to-garment test, followed
by one explicit owner-approved legs request if the test passes.

The local legs review fixture is saved under
`assets/images/characters/garment_fixtures/v5/legs/`. It contains a
`1024 x 1024` green-screen sheet plus four transparent overlays: navy leggings
for the upper legs and navy leggings with brown shoes for the lower legs. Every
overlay is clipped to its corresponding immutable leg alpha mask, so it cannot
overlap the original silhouette. It is a fixture for owner review, not a
provider result or a Flutter registration.

A second flat-color Gacha-style revision is saved under
`assets/images/characters/garment_fixtures/v5/legs_gacha_v2/`. It uses solid
purple leggings and solid pink shoes with no shadows, highlights, gradients,
or added outlines. The original navy-and-brown fixture remains unchanged for
comparison; both versions are clipped to the same locked leg masks.

A quality shoe revision is saved under
`assets/images/characters/garment_fixtures/v5/legs_gacha_v3_quality/`. It keeps
the purple leggings, adds a dark flat shoe body, two pink straps, a purple toe
panel, and a light sole, then reapplies the original outer outline pixels. It
has no gradients and remains clipped to the original leg alpha masks.

<!-- Historical V1-V4 sheet notes follow; V5 above is current.
The current implemented provider path still uses fixed `character_sheet_v1`.
V2 established the exact Sprite Studio output-canvas mapping. Corrective Phase
7G.1B.R2 has versioned `character_sheet_v3`; on 2026-08-04 the owner selected
V3 as the future active contract. V3 keeps the same coherent-character method
while using an efficient landscape hair catalog:

1. StoryTale will supply one locked `4096 x 1024` (`4:1`, `2K`) guide with one
   `429 x 438` front-hair cell; separate Short, Medium, and Long `429 x 800`
   back-hair cells; and exact native Sprite Studio head/body cells.
2. The checked-in guide and assembled reference use actor `default`. The same
   immutable geometry and manifest support a future heroine brief with the
   recorded heroine-specific hair sources.
3. Gemini returns only separated masked face details, the coherent hair
   catalog, and nine fitted clothing regions; it does not return another
   assembled body.
4. StoryTale removes the flat green locally.
5. StoryTale cuts fixed, versioned rectangles using a crop/anchor manifest; it
   does not ask AI to detect part boundaries.
6. Each region is hard-masked against allowed, protected, and seam masks.
7. Face, hair, and clothing layers are composed locally over the unchanged
   head and nine body pieces.
8. One outfit is reused for every pose by following the same bones.

V1, V2, and all original hair/rig assets remain unchanged behind their
checkpoints. The V3 guide, masks, manifest, prompt, hashes, and offline builder
are versioned in GitHub, but Flutter and the Worker have not been migrated and
no V3 Gemini request has been made. The guide/layout selection gate is approved;
migration and provider work are paused until the owner explicitly asks to
continue.

The preferred provider output remains `4096 x 1024` (`4:1`, `2K`). The current
supported smaller `4:1` tier is `2048 x 512` (`1K`), which cannot contain V3's
`429 x 800` Long back-hair cell at native size. Use a smaller output only if a
future official Gemini option both reduces billed usage and preserves every
exact V3 cell without resizing. Re-check official generation dimensions and
pricing before the one controlled request; do not spend a request merely to
compare sizes.
-->

Accessories use named anchors and relative layer modes such as behind arm,
behind hand, or front of hand. A held sword may be partly behind the arm and
have a small grip overlay above the hand. Only source-supported accessories
are generated.

## 9. Audio decisions and current prototype

Device-installed Android TTS was rejected as too robotic. The intended mobile
pipeline is a lightweight Tagalog TTS model converted to ONNX and run through
the selected Flutter-compatible runtime, with optional ONNX RVC voice
conversion. Raw `.pth` and `.index`/`.model` files cannot run directly inside
Flutter and are development inputs only.

Current development voice files and defaults are:

| Role | Current raw model | Pitch |
| --- | --- | --- |
| Narrator | `DailyDoseOfInternet.pth` | 0 |
| Heroine | `Suika Ibuki (The Memories of Phantasm).pth` | +16 |
| Hero | `maki.pth` | +16 |
| Adult/Deep | `TheRock.pth` | 0 |
| Elder | `OldManTyree.pth` | 0 |

Raw pairs live under `models/voices/raw/<role>/`. Prepared playback manifests
are fingerprinted so changing a raw model or pitch invalidates stale audio.
The repository currently contains placeholder model-pack folders under
`assets/models`; final ONNX runtime integration and mobile benchmarks are not
complete. Voice-model licensing must be checked before distribution even if
the academic prototype is educational.

## 10. Current data records and storage

There is **no server database and no selected local database package yet**.
These are current Dart/domain records or serialized local records, not SQL
tables.

### Reader records

- `ChapterTextBlock`: stable `id`, exact cleaned `text`.
- `ChapterData`: ID, title, original text, chapter type, source blocks,
  optional translated text, progress, bookmark.
- `BookData`: ID, title, author, language, description, tags, chapters, cover
  path/bytes, source filename, progress, last-opened time.
- `VoiceProfileData`: ID, name, role, model path, preparation status.
- `ReaderSettingsData`: text size, font, theme, line spacing, language mode,
  reading mode (`scroll` or `page`).

### Story records

- `StoryBeatData`: beat ID, speaker ID, exact original text, source-block IDs,
  Filipino text, audio asset ID, action ID.
- `StoryCameraPlanData`: preset, target, optional trigger beat.
- `StoryFocusAssetLayerData`: entity/asset/variant IDs, position, scale, depth,
  movement.
- `StoryCharacterLayerData`: character/rig/pose/face/profile/set/outfit IDs,
  position, scale, facing, depth, movement, speaking state.
- `StoryShotPlanData`: layout/background, beats, character/focus layers,
  camera, transition, optional background path.
- `StoryCutsceneData`: location, state/time, ordered shots.
- `ChapterStoryData`: chapter ID, moral, cutscenes, preparation status.
- `StoryBackgroundRequirementData`: exact `locationId::stateId` key.

### Story Bible and catalog records

- `StoryEntityData` and `BookStoryBibleData`: typed entities, aliases, source
  evidence, chapter links, approvals, identity locks, actor/voice/asset links,
  location briefs, and unresolved issues.
- `StoryBackgroundAssetData`: location/state ownership, prompt/brief metadata,
  dimensions, MIME, asset ID, status, and replacement metadata.
- `StoryForegroundAssetData`: entity/variant ownership, chapter links,
  transparent result metadata, status, and replacement metadata.
- `StoryHumanAssetData` and `StoryHumanRigMetadata`: stable human identity,
  design brief, package/part metadata, rig, pivots, faces/poses, readiness.
- `StoryAnalysisCharacter`, `StoryAnalysisLocation`, and
  `StoryAnalysisCatalog`: approved semantic IDs exposed to Gemini.
- `ChapterPreparationJobData` and `VolumePreparationJobData`: job state,
  chapter progress/errors, stage, counts, elapsed time, queue label, and events.

### Sprite records

- `SpriteRigDefinition`, `SpriteRigPart`, `SpriteRigPose`,
  `SpritePartTransform`, `SpriteLayerPolicy`, and `SpriteBone`.
- Local face profiles, parts, sets, and catalog records.
- `SpriteHairFit`: X, Y, and scale.
- `SpriteAppearanceSelection`: selected actor, selected back-hair style, skin
  tone, and actor/style fit map.
- `SpriteActorAppearance` and `SpriteHairStyle`: built-in actor/hair catalog
  entries.

### Current local storage keys

Small JSON metadata uses SharedPreferences:

- `storytale.library.v1.imported_books`
- `storytale.library.v1.reading_state`
- `sprite_studio.face_profiles.v1`
- `sprite_studio.<rigId>.custom_poses`
- `sprite_studio.<rigId>.appearance`
- `storytale.story_bible.v1.<bookId>`
- `storytale.background_catalog.v1.<bookId>`
- `storytale.foreground_catalog.v1.<bookId>`
- `storytale.human_catalog.v1.<bookId>`

`LibraryRepository` owns the two library keys. `imported_books` holds the full
imported book records, chapters, and stable source blocks, and is written only
on import or removal. `reading_state` holds per-book and per-chapter progress,
bookmarks, cached translated text, the current position, and reader settings for
**both** bundled and imported books; it is written on a 600 ms debounce because
reading progress changes on every scroll frame. Both are restored by
`StoryTaleController.restore()` at startup.

Parsed chapters are stored rather than raw EPUB bytes, because the web preview
keeps these values in browser local storage, which holds only a few megabytes in
total. A failed write sets `StoryTaleController.libraryStorageFailed` and is
logged; it never throws and never loses the in-memory session.

`ReaderImageCodec` shrinks artwork once at import: covers to 600 px wide JPEG and
chapter illustrations to 800 px. The repository fixture's 1.9 MB cover becomes
about 153 KB, and its fifteen illustrations total about 1.7 MB.
`LibraryRepository.imageByteBudget` (1.8 MB) then caps how much artwork the
whole library may store, spent in reading order. An illustration past the budget
keeps its ID and position but stores no bytes, and the reader draws a
placeholder instead. Chapter text, progress, and covers are never dropped for
artwork.

That fixture therefore consumes nearly the entire budget on its own: one
illustrated light novel keeps all of its artwork, and a second one will mostly
fall back to placeholders. This is the expected ceiling until Phase 8 adds real
file storage.

Generated image bytes still use a session-only `StoryAssetBinaryStore`, and
volume jobs and original EPUB bytes remain session-oriented. Therefore an app
restart still loses preparation progress and generated binary images. Phase 8
must add durable local files plus an indexed database, atomic metadata/file
updates, checksums, migrations, interrupted-job recovery, and safe orphan
cleanup.

## 11. Development status

The [Master Roadmap](ROADMAP.md) is authoritative. As of this handoff:

| Phase | Status | Meaning |
| --- | --- | --- |
| 0 Foundation/UI | Done | shell, theme, navigation, reusable screens |
| 1 EPUB import | Mostly done | durable books, artwork, scroll and page reading; EPUB bytes/volumes/database missing |
| 2 Sprite Studio | Prototype done | rig/poses/bones/layers/five faces work |
| 3 Visual-novel runtime | Prototype done | layouts/camera/motion/Gemini contract work with fixtures |
| 4 Story Bible | Done | entities, auto-approval, location requirements |
| 5 Backgrounds | Done | generated landscape catalog resolves in playback |
| 6 Volume/foregrounds | Done | resumable session job, assets, live Chapter 1 fixture |
| 7 Book-specific humans | **Current** | exact-template layered appearance is not complete |
| 8 Persistence/volumes | Planned | begins after Phase 7 gates |
| 9 Final ChapterStory builder | Planned | generic all-chapter packages and beat actions |
| 10 DeepL/offline audio | Planned | real translation and mobile ONNX audio |
| 11 Release validation | Planned | physical Android, failures, accessibility, storage |

### Current thread — read this first

On 4-5 August 2026 the owner **paused Phase 7** and approved a narrow reader
detour so the Week 4 Local EPUB reader milestone (16 August) is demonstrable.
That detour is complete and committed on `master`:

| Commit | Work |
| --- | --- |
| `555f07c` | offline hash guard over `character_sheet_v1/v2/v3` and the locked rig |
| `36676e2` | imported books, chapters, progress, bookmarks, and settings survive a restart |
| `2acfe37` | covers shrunk so they persist; chapter illustrations shown inline with tap-to-zoom |
| `d9e1895` | artwork recovered from pages the contents omit, 7 of 16 images to 15 of 16 |
| `c94eae4` | page-by-page reading mode beside the scrolling reader |

Each of those passed targeted automated validation, but **the owner has not yet
manually verified any of the reader detour**: durable books across a restart,
covers, inline illustrations, and page mode are implemented and tested in code,
not owner-accepted. Expect that verification to happen before or alongside the
next task, and treat a reported reader defect as likely real. None of these
commits has been pushed; `master` is ahead of `origin/master`.

**Phase 7 is paused, not abandoned.** It is parked exactly where `555f07c` left
it, with the V3 migration checklist recorded in
[Character Sheet Plan](CHARACTER_SHEET_PLAN.md) under "V3 migration surface".

### Sprite Studio test failure cleared, 5 August 2026

On 5 August 2026 the owner chose to clear the long-standing Sprite Studio test
failure before resuming Phase 7, so the pending manual 7G.1A.1 verification
happens on a clean screen and a green suite. Both root causes were found by
measurement, and neither was what the failure text suggested:

1. **The AppBar overflow was a two-sources-of-truth bug, not a title problem.**
   The overflowing `RenderFlex` was the toolbar's *trailing* slot. Sprite Studio
   chose its action layout from `MediaQuery.sizeOf(context).width` while its body
   chose from `LayoutBuilder` constraints. Under `setSurfaceSize` those two
   disagree — MediaQuery still reported the unresized view — so the page rendered
   the wide `Review Story Artwork` text button inside a 390-pixel toolbar. The
   page now takes both decisions from one outer `LayoutBuilder`.
2. **`face-neutral` was missing because the shipped default actor is Adult.**
   `assets/images/characters/rigs/humanoid_v1/appearance.json` sets
   `"actorId": "adult"`, whose face profile is `adult_deep`, so every chip key is
   `face-adult_deep-*`. The test had silently assumed the Default actor. The test
   now seeds that appearance key with `{"actorId":"default"}` instead.

**The shipped Adult default was deliberately left alone** — changing it would
alter what the owner sees on the exact screen they are about to verify. The
checked-in `poses/neutral.json` likewise still carries
`"faceProfileId": "adult_deep"`; it is harmless because the appearance record
overrides it at load, but it is redundant state copied into a pose and is worth
removing when Phase 7G.1A.1 is next touched.

`flutter test` is now **150 passing, 0 failing** and `flutter analyze` reports
no issues. The locked rig, every versioned character sheet, and
`test/character_sheet_contract_test.dart` were not touched.

### Translation and CRUD pulled forward, 5 August 2026

Later the same day the owner paused the Phase 7 thread again and asked for two
things: working DeepL translation using the existing `DEEPL_API_KEY`, and CRUD in
the app — specifically translation CRUD and editing an uploaded EPUB. This is
ahead of the roadmap, where translation is Phase 10; it is the owner's call and
`docs/ROADMAP.md` Phase 10 now records what landed early.

What shipped:

- **Real DeepL translation.** `translateChapter` was a hardcoded Little Prince
  Tagalog paragraph, which also broke the no-book-specific-behaviour rule. It now
  calls DeepL for real. Verified against DeepL's docs that Tagalog is target code
  `TL`.
- **Translation CRUD** on `StoryTaleController`: `translateChapter` (create,
  cached so reopening a book costs no quota), `retranslateChapter` (update),
  `deleteTranslation` (delete). Per-chapter status and the **real** provider
  error are exposed; nothing retries automatically.
- **Book Update.** The library's "Edit metadata" row was a placeholder snackbar;
  it is now a real dialog for title, author, language, and description. With
  import, the library list, and "Remove from library", books have full CRUD.
- **A local DeepL proxy.** `tool/pose_admin_server.dart` gained `POST /translate`
  and `tool/run_storytale.ps1` passes `DEEPL_API_KEY` into that process only.

Two limits to know:

- **The key is never in the web bundle** — it lives in the local proxy process.
  That is deliberate: DeepL sends no CORS headers so a browser cannot call it
  directly, and a bundled key would be readable in devtools.
- **Translation is dev-only right now.** On a physical Android device
  `127.0.0.1:52828` is the phone, not the PC. The Worker route fixes that and is
  not built.

No live DeepL request was made while implementing this; all tests use a fake
client. The first real request is the owner's to trigger in the app.

### character_sheet_v4 built, 5 August 2026

The owner asked whether a `1K` `2048 x 512` sheet was possible. It is not, for
two independent reasons, and checking turned up a bigger problem:

1. **`4:1` is not a documented provider aspect ratio.** The documented set is
   `1:1, 3:2, 2:3, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9`. **V3 is `4096 x 1024`,
   exactly `4:1`, so the owner-approved sheet may not be requestable.** The
   earlier note in `CHARACTER_SHEET_PLAN.md` claiming documented `4:1` tiers was
   wrong and has been corrected. Caveat: the ratio list appeared under a section
   naming Gemini 3.1 Flash *Lite* Image, while `.env.example` configures
   `gemini-3.1-flash-image`. Confirm before spending on V3.
2. **The cells do not fit `2048 x 512` anyway.** The back-hair cell is `800`
   pixels tall against a `512`-tall canvas, and all 12 cells need `1,478,789`
   px² against the canvas's `1,048,576` px².

`character_sheet_v4` was built as the `1:1` answer: `1024 x 1024` at `1K`, one
`back_hair_selected` cell matching V2's contract, nine fitted-clothing cells,
native-size crops, an `18` pixel green gap, and cells grouped by side because
side ownership is a contract rule. Cost is `$0.067` versus V3's `$0.101`, and
cell fill rises from V2's `18.9%` to `75.6%` with pixel-identical cells, so more
of the model's fixed token budget lands on content that is kept.

The `18` pixel gap was found by search, not by hand: this cell set packs at `18`
and fails at `20`. A first hand layout was rejected by the builder's own margin
check, and the automatic packer's result was rejected for interleaving left and
right cells. Both the builder and `test/character_sheet_contract_test.dart`
re-prove the geometry, and the test also records why `0.5K` is impossible.

V4 was then refined three times on 5–6 August 2026, all local and free:

- **One guide per rear-hair length.** `guide_default_short.png`,
  `guide_default_medium.png`, and `guide_default_long.png`. Only the
  `back_hair_selected` cell differs; cells, masks, anchors, and seams are
  identical. The manifest records `guideByBackHairId`, a separate
  `guideVariantSha256` map so the six required contract hashes keep their exact
  shape, and `backHairSourceByIdForActor` keyed by actor. One request produces
  one length, so several lengths for one character means several requests with a
  byte-identical brief, outfit, and palette.
- **A cell is a container, not a target.** Every region publishes
  `referenceContent` with the bounds and coverage its template artwork occupies,
  and the rear-hair variants publish `referenceContentByBackHairId`. Body cells
  sit at 95–100% and front hair at 88%, but the rear-hair cell is sized for the
  longest style, so telling a provider to fill it would return oversized hair.
  Both hair cells are `100%` allowed and `0%` protected, so nothing else
  constrains them. The prompt contract states the rule and the per-length table.
- **Limbs split into two blocks, and hair widths matched.** Eight similar pale
  cells in one row invite the provider to confuse them, so legs now sit lower
  left and arms lower right, split by a `42` pixel channel. That is mirrored from
  the owner's sketch because geometry forces it: the tallest leg cell is `156`
  pixels and only `147` is free under the head column against `170` under the
  back-hair column. Rear hair was visibly narrower than front hair because its
  source PNG carries more transparent padding, so the artwork is enlarged
  **inside its unchanged `429 x 800` cell** by `1.0761` until the widths match
  (`425` against `424`). The scale is derived from the drawn cells at build time,
  not hardcoded, and is capped so the long style still fits. The rig box, the
  locked geometry, and every recorded hash are untouched.

One trap worth remembering: `image.drawImage` shrinks a source larger than its
destination back down to fit unless `dstW` and `dstH` are passed explicitly. That
silently undid the first enlargement attempt, and only measuring the result
caught it.

V1, V2, and V3 are untouched behind their hashes. **V4 is a local candidate
only** — not registered with Flutter, the Worker, or the provider, and no
provider request was made. It shares V3's migration surface.

Owner decisions still open: review the V4 guide, and choose whether V4 replaces
V3 as the migration target.

### The head-source mismatch is fixed, 6 August 2026

This was the item recorded below as "the sheet points at the wrong one". It was
unblocked, free, and needed whichever way the faces question goes, so it was done
while both owner gates stayed open. Measuring it turned up more than the note
described.

**The head was the only cell that had ever drifted.** Every other region's
`sourceAsset` already equalled its `rig.json` part asset. `base/head.png` is
`357 x 367`, trimmed to its own artwork, with a face drawn on it;
`faces/head_base.png` is the `1254 x 1254` faceless locked part the rig fits into
the same `357 x 367` box. Fitted, the runtime head's content is `325 x 344` at
`(16, 6)` — strictly inside the old one and about 14% smaller by area. The
shipped `assembled_reference.png` was already rendered from the faceless head, so
one request showed the provider two different heads.

**It was also a hard runtime bug, not only a cosmetic one.**
`_buildProofArtwork` required each region's locked asset to already equal the
region canvas, which is true for the nine trimmed body parts and false for the
head, so packaging threw *"The locked head base asset has invalid geometry."*
before reading a single generated pixel. Nothing caught it: **no test touched
`CharacterSheetProcessor` at all**, and the one owner-controlled request returned
a Worker 502 before reaching that code.

What changed:

- **The V4 generator takes every cell's artwork from the rig part**, so a cell
  cannot drift from the runtime again. The build prints each correction it makes;
  it printed exactly one.
- **The head cell's metadata moved with its artwork** through one build-time
  remap derived from the two content bounds: the allowed face-detail window, the
  protected area rebuilt as *cell minus allowed* (V1's measured convention in
  this cell), and the anchors, now `(179.3, 345.76)`.
- **The head's seam marker is painted from its own anchor.** A second inherited
  defect: nine of the ten body cells mark their seam exactly at their anchors,
  and the head marked none of its `181` pixels there, leaving the marker on green
  left of the neck. Fixed in V4 only.
- **The processor fits a locked asset to its region canvas**, mirroring
  `_scaledHairArtwork`, which already did this for the two hair parts.
- **`test/character_sheet_processor_test.dart`** is the first test to exercise
  that class. Both of its cases reproduce the exact throw when the fix is
  reverted.

V1, V2, and V3 are untouched behind their approved hashes — V3 is owner-approved
artwork — and the contract test now records their head mismatch as an explicit
expectation so it stays visible. V1's allowed window was measured to sit inside
the smaller runtime head too, so the processor fix changes nothing about what V1
*accepts*; it only stops the throw. All three V4 guides and all six V4 hashes
changed, so any earlier review of the V4 head cell is superseded. `flutter test`
was **199 passing, 0 failing** at that point and `flutter analyze` reported
no issues.

### V4 is the active contract, 6 August 2026

The owner asked what the `1K` sheet actually changes and whether Sprite Studio
has to start using V4's images, then approved the migration. Two clarifications
worth keeping, because the question will recur:

- **`1K` did not shrink the parts.** V4's canvas is `1024²` instead of `4096²`,
  but the cells inside it are the same size — head `357 x 367`, torso
  `165 x 234`, every limb — in V1, V2, V3, and V4 alike. The canvas shrank by
  deleting green. The only cells that ever shrank are the two hair cells, and
  that happened at **V2**: front hair `1254²` to `429 x 438`. That was
  deliberate, because the rig draws hair into exactly a `429 x 438` box, so the
  extra source pixels were discarded at render time anyway.
- **Sprite Studio does not switch to V4 images.** The locked template — the rig,
  the ten hash-locked parts, the local hair catalog, the modular faces, and
  `appearance.json` — is what Sprite Studio shows, and V4 does not touch it. V4
  changes only which sheet the provider is asked to fill and how the result is
  cut up. Making a generated character appear in Sprite Studio and across
  chapters is Phase 7H, and the wiring already exists:
  `StoryHumanAssetData.partBytesById` feeds `SpriteRigView(partBytes:)`.

Eleven changes landed. The recorded checklist had six; tracing the code found
five more, and three of those would have wasted a paid request rather than
failed cleanly:

1. **The Worker still asked Gemini for `4K`.** That line, not the manifest, is
   the cost lever. Left alone V4 would have cost `$0.151` *and* returned a
   canvas the contract rejects.
2. **V4's prompt contract had no `{{...}}` tokens at all**, so `buildPrompt`
   would have sent the specification verbatim — no name, brief, skin tone,
   outfit, or rear-hair selection. A paid request for a generic character.
3. **`selectedBackHairRegion()` returned V1's region IDs**, so V4's single
   `back_hair_selected` cell would never have been extracted.
4. **V4 has three guides and both sides assumed one.** Flutter now sends the
   variant matching the requested length with that variant's hash, and the
   Worker checks the upload against both the declared hash and its approved set.
5. **Guides exist for actor `default` only.** Each actor has its own front hair,
   so each needs generated, checked-in, hashed guides. Free and offline; not
   done because no other actor is requested yet.

The full table is in [Character Sheet Plan](CHARACTER_SHEET_PLAN.md), "Migration
to V4". `flutter test` is **204 passing, 0 failing**; `flutter analyze` and the
Worker's `tsc --noEmit` are clean.

**Deployed on 6 August 2026 at the owner's explicit request** as Worker version
`964439e3-4a04-48c2-9b30-a68d176fc604`. Flutter and the live Worker are both on
V4. `GET /health` reports `authConfigured` and `geminiConfigured`, and the
sprite route rejects an unauthenticated call with 401.

**The first live V4 request was made on 6 August 2026 and failed on format.**
Gemini returned a `1024 x 1024` **image/jpeg**; the Worker rejected it with a 502
before packaging, so the request was billed and produced nothing usable. It was
not retried.

**The sheet is JPEG now, because the provider offers nothing else.** Two live
requests settled it. With `mime_type` unset the provider returned JPEG, so the
recorded belief that Gemini defaults to PNG was wrong. Asking for `image/png`
then returned HTTP 400: *"The value 'image/png' is not supported for
'response_format.mime_type'. Supported values: 'image/jpeg'."* So the other half
of that belief — that the schema only enumerates JPEG — was right, and the
published documentation showing `image/png` is wrong for this endpoint. A 400 is
rejected before generation, so only the first request was billed.

JPEG was then measured rather than feared. Re-encoding the V4 guide and
re-running the mask validation offline moved the "pixels outside the approved
masks" count by about **90 out of 1,048,576**, because the background test is
tolerant (`green >= 160 && green >= red+40 && green >= blue+40`) rather than
exact. The exact `#00FF00` count does collapse, from 625,270 to roughly 10,000,
but that only drives a secondary removal path and a metric; the primary removal
is a connected-background flood fill on the same tolerant test. The processor
tests now use a JPEG fixture and their exact pixel-count assertions still hold.

`canvas.mimeType` is `image/jpeg`, and one test asserts the format asked for,
accepted, and declared are the same value. Deployed as
`1e29b40a-8a56-45b8-8d73-caed666ddf41`.

**What the failures proved:** the whole chain runs — Flutter picks the guide
variant, the Worker accepts the V4 contract and the guide hash, Gemini answers,
and validation catches a bad result before packaging. The `1K` tier is confirmed
exactly `1024 x 1024`.

### The validator could not have accepted any compliant sheet

Found on 2026-08-06 while simulating a reply offline, after two paid requests had
been spent discovering problems that were all reproducible for free.

`_unexpectedGapPixels` counted **every** non-background pixel outside
`allowed && !protected` as a violation. But the prompt tells the provider to
*preserve* the protected pixels, so a compliant sheet returns them. Measured
against the untouched guide that was **77,653 pixels**, so no correct sheet could
ever have passed. `_cleanRegion` rejected the same pixels a second time.

The counter conflated two unrelated failures, which is why it could not be tuned.
They are now separate:

- **Stray pixels** — content in the green padding between cells, which belongs to
  no cell. Zero tolerance; nothing legitimate is ever drawn there.
- **Protected drift** — protected pixels that no longer match the guide. This is
  the Phase 7G failure, where the provider redrew the body instead of dressing
  it, and it is a matter of degree.

Drift needs a tolerance because the provider only emits JPEG. Measured on the V4
guide at quality 95, ringing against the black line art reaches a per-channel
delta of **97**, so "preserved exactly" is unachievable. At a delta of 64 only 92
pixels differ, **0.06% of the locked area**, so the budget is 1% — a sixteenfold
margin that still catches a redraw.

### The pipeline is now proven offline

`test/character_sheet_end_to_end_test.dart` builds a sheet shaped like a
compliant reply — the guide with its artwork recoloured inside the allowed
windows, JPEG encoded — and runs the real processor over it. It reaches a fully
valid package with six face proofs and four pose proofs. Three companion cases
prove the guards still bite: a redrawn head and torso, content in the padding,
and a rear-hair cell that should have stayed green.

One trap the simulation caught: filling a whole cell rather than recolouring its
artwork returns a solid rectangle of "hair" that covers the face, and the six
face proofs stop being distinct. That is exactly what the prompt contract's "a
cell is a container, not a target" rule exists to prevent.

### The request layer had no test, and that cost a third request

The third live request returned a correct `1024 x 1024` JPEG and Flutter rejected
it with *"Gemini returned 1024x1024 image/jpeg; StoryTale requires one 1024x1024
image/jpeg."* The message read from the contract while the condition beside it
still hardcoded `image/png`: an edit that changed the text and not the test.

The processor tests could not catch it because they start after this point.
`test/character_sheet_request_test.dart` now drives the real
`StoryArtworkService` against a faked Worker and covers the whole
request/response layer: the JPEG is accepted, the guide variant uploaded matches
the requested length and the declared hash, a wrong format is refused, and a
reply belonging to another request is refused. Three of its four cases fail if
the hardcoded `image/png` is restored, which was checked rather than assumed.

A sweep of the character-sheet path for other values the contract should own
found none left. The Worker's hand-copied constants — contract ID, version,
geometry hash, canvas, requested tier, MIME type, rear-hair region, and the three
guide hashes — are all now compared against the manifest by
`test/character_sheet_contract_test.dart`.

**A fourth controlled request is the owner's to trigger.** Nothing about the real
sheet's *content* has been seen yet — only that the plumbing and the validator
now agree on what a good sheet looks like.

A test now parses `cloudflare/image-worker/src/index.ts` and compares its
contract ID, version, geometry hash, canvas, requested tier, and three guide
hashes against the manifest, so a hand-copied constant cannot drift into a 409
after the money is committed.

### The first real V4 sheet, and what Gemini gets wrong — 6 August 2026

**Start here. This is the open problem.** Everything below the plumbing is now
working; what remains is the artwork the provider draws.

The pipeline delivered. Gemini returned a `1024 x 1024` JPEG, `517 KB`, cut into
layers, and the package built. The character is recognisably the brief — golden
hair in both hair cells, a blue coat in the torso cell, cream trousers, brown
boots, and the head left bald and faceless as asked.

Recorded validation from that run:

| Measure | Value |
| --- | --- |
| Stray pixels in the padding between cells | **21,459** |
| Locked geometry repainted | 4.11% |
| Locked area drawn over inside cells | 1.81% |
| Rejected by cell | `lower_arm_right` 746, `head` 477, `lower_arm_left` 379, `torso` 317, `lower_leg_left` 243, `upper_leg_left` 192 |

**Read those numbers in proportion.** The padding is `256,187` px of the
`1,048,576` canvas, so `21,459` stray pixels means **8.4% of the gap area has
artwork in it**. That single number dwarfs everything else: the per-cell
rejections total about `2,354`, an order of magnitude smaller. The earlier
50.69% drift was a worse sheet, not a worse rule — the same validator scored this
one at 4.11%.

**So the diagnosis is not "the provider redrew the body". It is "the provider
re-laid-out the sheet."** Comparing the returned sheet against
`guide_default_medium.png`, the lower half does not match cell for cell: the
template carries one row of eight limb cells, four legs left and four arms right,
and the reply reorganises that area and draws garment objects — boots in
particular — as free-standing items rather than as clothing painted onto each
limb silhouette in its own cell. Anything drawn between cells lands in the
padding, which is exactly what the stray count measures.

**That makes it a prompt problem, not a validator problem.** Do not loosen the
stray-pixel rule to make this pass; content in the gap is precisely the failure
the gap exists to catch, and a layer cut from a shifted cell is the wrong pixels.

Concrete changes to try in `character_sheet_v4/prompt_contract.md`, in
descending order of likely effect:

1. **Say it is an edit, not a drawing.** The output must be the supplied guide
   with paint added and nothing moved. State that the number, position, and size
   of separate shapes must not change.
2. **Forbid free-standing garments.** Each cell holds exactly one body part;
   clothing is painted onto that part, following its silhouette. A boot is not a
   boot-shaped object placed near a leg, it is paint on the lower-leg cell.
3. **Name the gap explicitly as untouchable**, with the pixel figure, and say
   that any mark there voids the result.
4. Consider whether the white body silhouettes read as "empty slots to fill".
   Skin-toned parts may invite dressing rather than replacing; that is a guide
   change and needs a rebuild plus new Worker hashes, so try the wording first.

Re-running after a prompt edit **does** cost a new request: nothing about the
returned sheet is reusable once the prompt changes. Budget one request per prompt
iteration. Note the fingerprint itself does *not* move — see the correction in
the next section, which matters for the in-tab cache.

**Cost so far: five billed requests, roughly `$0.34`.** Four were mine — three
plumbing defects reproducible offline, and one legacy-path run after an app
restart reset the mode selector. Only the fifth bought information about the
artwork.

### The V4 prompt was rewritten to paint in place — 6 August 2026

Done offline, no request made. Reading the request path first turned up three
reasons the provider **could not** have complied, which matter more than any
wording weakness:

1. **`crop_manifest.json` was never sent.** `story_artwork_service.dart` uploads
   exactly five references — guide, assembled reference, and the three masks —
   and the Worker enforces "exactly five". But the prompt listed the manifest as
   required input 6 and then deferred to it four times, for the crop
   coordinates, the cell IDs, and the `referenceContent` bounds. **The model had
   never been given a single coordinate.** Asked to preserve a layout it could
   not read, it re-derived one. That is the best available explanation for the
   re-layout, better than "the wording was too weak".
2. **The five images arrive unnamed.** `generateSprite` appends them as bare
   image parts after the text; the multipart filenames never reach Gemini. The
   prompt referred to them only as `allowed_regions.png` and so on, so mapping a
   name to a picture was guesswork.
3. **Three token names in the prompt did not exist** — `BACK_HAIR_SELECTION`,
   `CHARACTER_BRIEF`, `OUTFIT_BRIEF`, left over from an older contract. The real
   tokens are the `{{...}}` fields in `promptFields`.

What the contract now says, in the order it says it: this is an **edit of image
1** and twelve shapes go in and twelve come out at the same pixels; the five
images identified by position; **the twelve cell rectangles inlined as text**;
the gap named as `256,187` pixels that void the result if marked; and clothing
defined as paint on a body part, with a boot called out explicitly as paint on
`lower_leg_*` rather than a boot-shaped object. A six-point self-check closes it.

The rectangles are checked against `crop_manifest.json` rather than trusted:
all twelve match, as does the gap figure.

**The size cap is the binding constraint and was previously unguarded.** The
Worker caps character-sheet prompts at `12,000` characters. The old contract was
`9,226` before substitution, so this had to be a rewrite that trims as much as it
adds, not an append; the result is `8,869`, about `9,300` once a typical brief is
substituted. Legacy prose paid for the additions: the V3 comparison, the
future-actor and heroine policy, and StoryTale's own multi-length workflow, none
of which are instructions for painting this image.
`test/character_sheet_prompt_test.dart` now fails if a built prompt crosses the
cap, so the next editor finds out in `flutter test` rather than at the Worker.
The one unbounded input is `sourceDescription`, which would need to exceed
roughly `2,800` characters to overflow; that failure is a free 400, not a bill.

Only `assetSha256.promptContract` in the manifest changed with it. Nothing else
in the manifest derives from the prompt, the guide bytes are untouched, and the
Worker holds only guide and geometry hashes — **so there is no Worker change and
no redeploy.**

**One correction to the note above, which matters before the next test.** The
request fingerprint contains the *guide* hash, not the manifest hash, and a
prompt edit changes neither. So a prompt edit does **not** invalidate the
in-memory cache: within a browser tab that has already generated, re-pressing
Generate returns the old sheet. Reload the tab before testing the new prompt.

Nothing here is verified. A prompt's effect cannot be unit-tested, and the guide
rebuild — handoff item 4, whether the white silhouettes read as "empty slots to
fill" — was deliberately left alone, because changing the wording and the guide
in the same request would make the result uninterpretable.

### The sixth request: the re-layout is fixed, and what replaced it — 6 August 2026

The rewrite worked, and by a wide margin.

| Measure | Fifth request | Sixth request | Gate |
| --- | --- | --- | --- |
| Stray pixels in the padding | `21,459` | **`129`** | must be `0` |
| Locked geometry repainted | 4.11% | **2.71%** | 1% |
| Locked area drawn over inside cells | 1.81% | **1.74%** | 1% |

**Stray pixels fell by a factor of 166.** The provider now keeps the layout: the
cells stay where they are and the limb blocks are no longer reorganised. Inlining
the twelve rectangles was the fix, and the diagnosis that it could not read a
manifest it was never sent is confirmed rather than merely plausible.

What the sheet got wrong is a different failure, and measuring the masks explains
why the prompt could not have prevented it:

| Cell | Allowed | Protected | Green inside the cell |
| --- | --- | --- | --- |
| `back_hair_selected` | **100%** | **0%** | 57.0% |
| `front_hair` | **100%** | **0%** | 57.5% |
| `head` | 18.4% | 81.6% | 29.9% |
| body cells | 57-87% | 22-54% | 14-45% |

**The two hair cells are wholly unprotected and more than half empty.** There are
`374,553` green pixels *inside* cells — more than the `256,187` px padding. The
masks therefore permit painting in all of it, and the provider did: it drew a
blue hood around the front hair, and **a spare pair of arms into the empty lower
half of the rear-hair cell**, which `cropToVisiblePixels: false` then cut into the
rear-hair layer. Only prose forbade either, and the prose said "do not fill a cell
to its edges", which is not the same instruction as "do not add a second object".

The drift has a matching structural explanation. Measured against guide
luminance, the protected mask on every body cell covers **the dark outline and
its anti-aliased edge band, and 0% of the pale interior**:

| Cell | Protected px | Of which line art or edge |
| --- | --- | --- |
| `head` | `106,977` | 39% (the rest is protected face fill) |
| `torso` | `8,448` | 100% |
| eight limbs | `33,254` total | 100% |

So the limbs hold 22% of the protected area but contributed roughly `2,062` of the
`2,587` rejected pixels: the provider re-inks each limb outline while dressing it.
The budget is 1% of `148,679`, so `1,487` pixels, against `4,029` drifted.

The contract now carries four rules aimed at exactly these:

1. **Green inside a cell stays green** — it is not free canvas, with the rear-hair
   cell's empty lower part named explicitly.
2. **One shape per cell** — never a second object, and the hair cells take hair
   only, with hood, cowl, hat, collar, and scarf named.
3. **The outline is locked; paint inside it** — do not re-ink, thicken, recolour,
   or redraw an outline, and do not reshape a part to suit a garment.
4. **Do not restyle the hair** — recolour and shade the shape that is there,
   simple cel shading rather than many dark streaks. This one answers the owner's
   "graspy, lots of dark" note and is the only one of the four not backed by a
   measurement.

Trimming paid for it again: `9,822` characters, about `10,220` built, against the
`12,000` cap.

**Whether rules 1 to 3 are enough is unknown, and there is a fallback if they are
not.** Both failures are permitted by the masks, so the durable fix is a mask
change — protecting the empty region of the hair cells, which would make the hood
and the spare arms *rejected* rather than merely discouraged. That is a guide and
mask rebuild with new hashes and a Worker redeploy, so wording gets one more try
first.

### The seventh sheet, and why the fix moved from the prompt to the mask — 7 August 2026

The seventh sheet went **one for two**. The hood is gone: `front_hair` came back
as hair only, and the hair is cleaner and less streaked. But two garment-shaped
objects still sit in the empty lower half of `back_hair_selected`, where the
guide is flat green.

That is the pattern across three sheets. **Prompting wins where the offence has a
name and loses where the model has a large permitted empty area to use.** "A hood
is not hair" is checkable. "Green inside a cell stays green" is not.

**The decisive finding is that neither defect was ever measured.** Traced through
`character_sheet_processor.dart`:

- `_measureSheet` counted a pixel as stray only if it was not protected, not
  background, **not allowed**, and not seam. Both hair cells were 100% allowed,
  so the hood and the objects hit `if (_isWhite(allowed…)) continue`.
- `_cleanRegion` keeps any pixel where `allowedPixel && !protectedPixel` — true
  for both — so they were **kept in the layer** and counted as `visiblePixels`.

So they tripped no gate, shipped into the hair layers, and the only detector in
the system was the owner looking at a screenshot. **Prompt iteration against a
defect nothing measures cannot converge**, which is the real answer to "will this
take forever".

Three changes, all offline, no request bought to build or prove any of them:

1. **Every returned sheet is now saved to disk.** `POST
   /character-sheet-diagnostics` on the existing pose admin server writes the
   sheet exactly as returned, the prompt that bought it, and the full validation
   report to `diagnostics/character_sheets/<stamp>_<requestId>/`, which is
   git-ignored. It also fires when the processor throws, because a sheet that
   breaks the processor is the most useful one to keep. It never fails a run: the
   result is already paid for, so an offline admin server must not turn it into
   an error. Before this, seven paid sheets left nothing behind but screenshots.
2. **The allowed window in a hair cell is now the hair silhouette**, grown by a
   `16` px margin, instead of the whole cell. That excludes `147,055` px in
   `back_hair_selected` and `65,430` px in `front_hair` — `212,485` px of
   formerly free canvas — while leaving `215` px of clearance below the medium
   silhouette, far more than the objects needed. Anything drawn there is now
   dropped from the layer by the existing `_cleanRegion` logic **whatever the
   provider does**, with no prompt compliance required.
3. **Stray is split into two measures**, because change 2 would otherwise turn
   one stray hair wisp into a total failure. Content in the **padding** stays
   zero-tolerance: it crossed a cell boundary, so a neighbouring layer is already
   contaminated. Content **inside a cell but outside its own window** is
   `overspillPixels`, removed from the layer and judged against
   `overspillBudget`, 0.5% of the paintable area.

**The overspill budget was measured, not guessed.** Re-encoding the untouched
guide as JPEG at quality 95 — the only format the provider emits — puts **zero**
pixels outside the windows, because the 16 px margin already absorbs the ringing.
Unlike the drift budget, none of it is a compression allowance; all of it is
headroom for a character's hair differing from the template's.

**One mask is not enough**, and missing that would have made this a half-fix. The
three rear-hair silhouettes fill `404`, `546`, and `784` px of the same `800`-tall
cell, so there is now **one allowed mask per length**, selected by
`selection.allowedRegionsFor(backHairId)` exactly as the guide is by `guideFor`.
The service uploads the matching variant and the processor validates against the
same one. `assets.allowedRegions` points at the medium file rather than a
duplicate canonical copy, mirroring `assets.guide`.

**Correcting what this document said yesterday: a mask change needs no Worker
redeploy.** The Worker hash-checks `references[0]` against `guide_sha256` and
holds no mask hash, and the request fingerprint carries the guide hash. Verified
after regenerating: all three guides, the protected mask, the seam mask, and the
assembled reference are **byte-identical**, so only `assetSha256.allowedRegions`
and the new `allowedVariantSha256` map moved.

`test/character_sheet_end_to_end_test.dart` now paints a garment into the empty
part of the rear-hair cell and asserts it is counted **and** absent from the
layer; the blob is `19,200` px and entirely outside the new window, where under
the old whole-cell mask every one of those pixels would have been kept. A
companion case proves a compliant sheet still passes the new rule. 218 tests pass.

### Every leg layer is a boot — 7 August 2026

**The diagnostics save paid for itself on its first run.** The eighth sheet is on
disk, so this section is measured from pixels rather than read off a screenshot,
and it is kept as `test/fixtures/eighth_live_sheet.jpg` so it can be re-measured
for free forever.

**Every one of the four leg cells holds a complete leg — trouser thigh *and*
boot — drawn about `310` px tall and bottom-aligned in a cell only `140-156` px
tall.**

| Cell | Cell rows | Artwork starts | Above the cell | Inside the cell |
| --- | --- | --- | --- | --- |
| `upper_leg_right` | 836-986 | y 676 | 12,359 px | 85% boot-brown, 2% trouser-cream |
| `lower_leg_right` | 836-992 | y 676 | 12,745 px | 82% boot-brown, 3% trouser-cream |
| `upper_leg_left` | 836-977 | y 676 | 11,751 px | 82% boot-brown, 3% trouser-cream |
| `lower_leg_left` | 836-976 | y 675 | 12,687 px | 83% boot-brown, 2% trouser-cream |

The cell captures only the bottom of the drawn leg, which is the boot. **So every
extracted leg layer is a boot and nothing else.** This also closes an older
mystery: the "spare arms" seen in the rear-hair cell across three sheets were
never limbs, they were the **trouser thighs** floating above the leg cells.

**The arms are not doing what they appear to.** Measured before changing
anything, because a paid request should not be spent on a misdiagnosis: the upper
arms are 69-70% sleeve blue with **no** trim band, and the sleeve colour continues
across the elbow. There is no break at the joint. The sleeve simply ends
mid-forearm at a gold cuff, at 47-51% of the lower-arm cell height, leaving
forearm and hand bare — a fair reading of a brief that says "a long blue coat" and
never states sleeve length. **That is an outfit-brief matter, not a contract
defect**; say "sleeves to the wrist" in the request. No code changed for the arms.

**A metric bug from the previous change, now fixed.** `_cleanRegion` counted a
pixel as `rejectedPixels` whenever it failed `(allowed && !protected) || seam`.
Once the hair windows were narrowed that included overspill in cells holding
**zero** protected pixels, and the total was still divided by
`protectedTotalPixels` and reported as damage to locked geometry. The same 47,708
pixels were counted twice. Separating them moves that measure from **37.47% to
5.38%** on this sheet, which is the real figure for pixels that touched protected
geometry. `rejectedPixelsByRegion` is now protected damage only, and
`overspillPixelsByRegion` sits beside it.

**Misplaced pixels now report where they are, not which cell they fell into.**
The plan called for attributing overspill to the nearest cell; that turned out to
be a no-op, because the trouser legs land *inside* `back_hair_selected`'s
rectangle, so its distance is zero and it stays the answer. The errors now carry a
bounding box instead. On this sheet it reads `(26,675) to (418,845)` — the strip
between the hair and the leg cells, which names the defect directly.

The contract gained a **"A limb shape is one segment, not a whole limb"** section:
the eight limb shapes named left to right, the rule that nothing painted may be
larger than the shape it sits on, the `118-156` px heights, and the self-check
"a trouser and a boot in the same shape means a whole leg was drawn". `10,513`
characters against the `12,000` cap, paid for by trimming the head, seam, and gap
sections.

`test/character_sheet_live_sheet_test.dart` replays the real sheet through the
real processor. Every other character-sheet test builds its own input, which
proves the rules but not that they describe what the provider does. 221 tests pass
and no PNG changed, so the masks and guides are untouched.

### Faces are an unsolved design question, 6 August 2026

The owner raised this before clearing the chat and it is **not yet decided**. The
findings below come from reading the code; do not re-derive them. The head-source
half of this question is now fixed, as recorded above.

**Two face mechanisms exist, and the processor already combines them.**

`_buildFaceArtwork` in `character_sheet_processor.dart` takes the extracted head
layer as a base and, for each of the six expressions in
`_requiredFaceExpressions`, overlays a composition built from the **local**
modular parts under `assets/images/characters/face_profiles/<profileId>/`
(`eyes/`, `noses/`, `mouths/`, `details/`, assembled through `sets.json`). So
today:

- eyes, nose, and mouth come from **shared local parts**, identical for every
  character on that profile;
- the provider contributes only what fits the head cell's allowed window, which
  is **21.4% allowed against 78.6% protected**;
- the six expressions work precisely *because* they are local, not generated.

**The open decision.** Since face parts are shared, two different book characters
on the same profile have the same eyes and mouth. Character identity currently
comes from hair, clothing, skin tone, and that small detail window. If
book-specific faces are wanted, the natural fit for the existing architecture is
a **face component sheet** generating per-character parts into a new
`face_profiles/<characterId>/` directory, leaving `sets.json` and the six
expressions intact.

Nothing about the head-source fix decides this. The V4 prompt contract now states
plainly what the pipeline does today — the head is faceless, the provider must
not draw eyes, nose, or mouth, and the allowed window is for character-specific
skin detail — which is the accurate description under either answer.

The sizing problem that makes this non-trivial, recorded so it is not
rediscovered: face parts are full-canvas `1254 x 1254` PNGs, so the roughly
fourteen of them cannot be packed into a `1K` sheet without introducing per-part
crop rectangles. Designing that is a planning task in its own right.

**The next task is the first controlled V4 request.** Flutter and the deployed
Worker are both on V4, so the path is open. Sprite Review, character-sheet mode,
roughly `$0.067`. Nothing retries automatically, and provider success alone is
not acceptance: the package, six-face, and four-pose gates still apply.

The pending manual Phase 7G.1A.1 actor/pose/reload verification is still open
and still the owner's to perform. It is independent of the deployment; nothing
in the V4 migration touched the local appearance path it exercises.

Do not make a Gemini or other paid request, and do not deploy the Worker,
without the owner's explicit approval for that exact action.

These reader limits are **deliberate and documented**, not defects to
re-investigate: the roughly 1.8 MB library image budget, page position being
restored approximately through the progress fraction, and text on pages the
table of contents omits being unreachable because chapters come from the EPUB
navigation.

Two live details that are not in Git history:

- `.claude/settings.json` is **intentionally uncommitted**. The harness rewrote
  it when permission prompts were accepted; it added an `allow` list and
  reordered keys while keeping every protective entry. Leave it to the owner.
- A web preview **is** running on port `52827` as of 5 August 2026. Check before
  launching another, and replace rather than duplicate it.

`test/sprite_rig_test.dart` "Sprite Studio has responsive editing and undo redo"
had been failing since before this thread. It was fixed on 5 August 2026; see
"Sprite Studio test failure cleared" above.

### Exact current and next work

**V4 is retired. The ninth request was never made.** On 2026-08-07 the owner
stopped the one-sheet approach after eight billed sheets produced no usable
character. Do not resume it, and do not spend a request testing the "a limb shape
is one segment" wording — that edit is now dead code awaiting deletion.

**Why, in one line:** every prompt fix corrected the defect it targeted and
exposed a new one — re-layout, then a hood on the hair and spare limbs in empty
cell space, then every leg cell holding a whole leg so every extracted leg layer
was a boot. One request drawing twelve interdependent cells has twelve ways to
fail, and one bad cell wastes the sheet. That is structural, not verbal.

**Phase V5-0.5 is done: image generation is provider-neutral.** Sprite requests
now resolve a provider from the `IMAGE_PROVIDER` var through
`cloudflare/image-worker/src/providers/registry.ts`, so moving between Gemini,
OpenAI, or anything else is a var change and a redeploy. Three things about it
are worth not rediscovering:

- **Flutter needed no change.** `_generate` already read the provider from the
  `X-Image-Provider` header and already accepted PNG, JPEG, and WebP, so the app
  never learns who answered and a provider switch never needs an app release.
- **The Worker has tests now** — its first, 14 of them, including one that
  reproduces the old per-mode size ternaries verbatim and compares them to the
  new table. That guard was proven to fail before it was trusted: changing the
  `body-pose` tier from `512` to `1K` breaks two tests. Run them with
  `npm test` in `cloudflare/image-worker`.
- **The `1K` tier assertion moved.** `character_sheet_contract_test.dart` used to
  regex the ternary in `index.ts`; it now reads
  `providers/types.ts` and `providers/gemini.ts`. It still compares the billed
  tier and the requested format against the manifest.

One intentional wording change: the character-sheet canvas rejection now says
`google-gemini returned ...` rather than `Gemini returned ...`, because that
check is StoryTale's rule and applies to every provider.

**V5-0 is done: the one-sheet path is gone.** The contract, generation request,
processor, package, three build tools, five test files, the V4 assets, the
Worker's `character-sheet` mode and its constants, and the Sheet mode in Sprite
Review were all removed on 2026-08-07. `flutter analyze` is clean, `flutter test`
is **130 passing, down from 221** — the drop is the character-sheet tests, which
existed only to guard the retired contract.

Two things not to rediscover:

- **The diagnostics endpoint survived on purpose.** `tool/pose_admin_server.dart`
  still serves `/character-sheet-diagnostics` and writes to
  `diagnostics/character_sheets/`. Only the Flutter caller went, because it was
  typed against the V4 result. V5-3 adds a new caller rather than a new server.
- **`character_sheet_v1/` is still registered in `pubspec.yaml`**, deliberately,
  as the documented rollback until V5-3 proves the new path. It is the last V4-era
  thing left and it goes in the commit that proves V5 works.

**V5-1 is done: clothing renders on the character.** A `SpriteGarmentLayer` per
rig part carries bytes, a fit, and the request that produced it; Sprite Studio
has a Clothing section on the selected part with across / up-and-down / size
controls and a clear; and a checked-in fixture tunic proves the whole path with
no provider and no cost. `flutter test` is **137 passing**.

Things not to rediscover:

- **The overlay-not-replacement rule is load-bearing, and now tested for real.**
  `_canTint` refuses to tint a part whose pixels came from `partBytes`, so
  putting clothing there would silently kill the skin-tone picker. The test
  counts images and requires that dressing a part *adds* a memory-backed image
  while the asset-backed count holds — a replacement keeps the total the same
  and would slip past a naive check. It was proven by breaking it on purpose.
- **Garment bytes live as base64 inside the appearance record.** That is why
  they survive a reload with no admin server. Revisit it if a character ever
  wears many large layers; it is fine at part scale.
- `SpriteHairFit` is now a typedef for `SpritePartFit` — hair and clothing need
  the same three numbers. No call site or persisted key changed.

**V5-2 is done: a generated sheet can be cut up and worn.**
`data/sprite_garment_separator.dart` turns green to transparent through the
existing `removeGreenBackground`, finds eight-connected components, drops
specks, crops each to its own bounds, and returns them in reading order.
Sprite Studio's Clothing section has **Load garment image**, which runs a picked
file through it and shows every piece to choose from. `flutter test` is **145
passing**.

**This is the change that retires V4's hardest requirement.** V4 demanded
pixel-exact cells and the provider would not hold them. The separator finds
pieces by connectedness, so a sheet only has to keep them **apart** — prompts
should ask for separation and never for coordinates.

Measured on the real eighth V4 sheet rather than assumed: a twelve-cell sheet
yields **18** pieces at the default threshold. The extras are the floating
trouser thighs the handoff used to call "spare arms", plus the hair's detached
ahoge strands. **Connected components find topological pieces, not semantic
ones** — a detached strand is its own piece, and that is correct behaviour, so
prompts must ask for connected shapes. A test pins it so nobody converts it into
a merge later.

**Check port `52827` before launching a preview.** A stale `flutter run` from an
earlier session was still serving there on 2026-08-07 and would have shown the
old bundle after a reload. Replace it rather than adding a second one.

What V5 changes, so the shape is clear without reopening the plan:

- **Skin and faces stop being generated.** Skin is the existing local tint, faces
  are the five existing profiles. Free.
- **Hair becomes a catalog** generated once and reused by every character, in one
  format shared with Sprite Studio.
- **Clothing is generated per character in small groups** — legs, arms, torso —
  so a failure costs one group at `$0.0336` rather than the whole sheet.
- **Nothing generated contains skin or replaces a body part.** Garments render as
  an overlay above the part, which is what keeps the local skin tint working.

**Most of V5 already exists**; section 4 of the plan lists it against file and
line. In particular `SpriteRigView` already takes a per-part `partBytes` override
and already overlays the face on the head, `SpriteLayerProcessor` already turns
green into transparency and crops to bounds, and the Worker already carries
per-part sprite modes that only dev tools call. V5 is a regrouping, not a
rewrite.

**The V4 measurements are not lost.** The eighth sheet stays in
`diagnostics/character_sheets/`, and `CHARACTER_SHEET_PLAN.md` keeps the measured
findings that justify the retirement. Both are evidence, not dead weight.

**Restart the app, do not just reload the tab.** Prompt and mask edits change
assets, and a running `flutter run -d web-server` keeps serving the bundle it
started with. Neither changes the request fingerprint. Reloading alone can
therefore spend a request re-sending the previous contract and look like a result.

After the run, the sheet, prompt, and report are in
`diagnostics/character_sheets/`. Read them rather than a screenshot.

Two things that make iterating cheaper, both worth knowing before touching
anything:

- **Within one browser tab, re-pressing Generate is free.** `generateCharacterSheet`
  caches the result by request fingerprint and returns it regardless of validity,
  so local processing can be re-run as often as needed. Reloading the tab loses
  it, and so does changing the guide or the geometry, whose hashes are part of
  the fingerprint. **Editing the prompt does not**, so reload the tab after a
  prompt change or you will re-inspect the old sheet.
- **The testing switch on Sprite Review skips the six face and four pose
  compositions**, which is most of the run cost. It is on by default and a
  package built with it can never be accepted; turn it off for an acceptance run.

Older phase history follows.

1. **Implemented: Phase 7G.1A.1** — per-actor front hair, optional back hair
   (`None` included), skin tone, and each style's X/Y/scale fit now restore and
   persist across actor/pose changes. Owner manual verification is pending.
2. **Completed: Phase 7G.1B.1** — the native-size `4096 x 4096`
   `character_sheet_v1` guide, neutral reference, complete crop/anchor
   manifest, masks, hashes, prompt contract, and Flutter contract loader are
   versioned without making a paid provider request.
3. **Implemented locally: Phase 7G.1B.2** — Flutter and the private Worker share
   one hash-checked, fingerprinted, sequential five-reference 4K request and
   response contract. It preserves provider/request metadata and never retries
   a paid failure automatically. The Worker was deployed on 2026-08-02. The
   first owner-controlled request returned a Worker 502 before packaging; no
   output was accepted. The Gemini response-format compatibility fix is now
   deployed as `ab9b22c9-b94a-4923-ae33-26eb16dbc808`, and a second paid request
   was deliberately not made without renewed owner approval.
4. **Implemented locally: Phase 7G.1B.3** — Flutter verifies the fixed contract,
   request fingerprint, exact PNG canvas, protected gaps, side ownership, and
   seam limits; removes green; cuts all 14 manifest cells; records transparent
   session layers and stable package metadata; and assembles the neutral proof
   over the untouched locked base. Invalid output becomes `needsAttention` and
   uses the safe template fallback. No paid request was made.
5. **Implemented locally: Phase 7G.1B.4** — the same extracted layers now
   compose Idle, Talking, Pointing, and Walking through the existing rig
   hierarchy. Four preview PNGs receive stable session IDs, hashes, and
   validation metadata; Character, Layers, Faces, Hair, Poses, and Details are
   read-only review groups; and `ready` requires the full four-pose gate. The
   first accepted owner-controlled generated package remains pending.
6. **Latest local corrective candidate: Phase 7G.1B.R2** -
   `character_sheet_v3` is a `4096 x 1024` landscape exact-part contract with
   front hair plus separate Short/Medium/Long back-hair cells, exact body cells,
   default actor preview data, and heroine-compatible geometry/source mapping.
   It made no provider request.
7. **Owner decision recorded:** V3 is selected and visually approved as the
   future contract. Do not connect V3 to Flutter/Worker or spend another Gemini
   request until the owner explicitly asks to resume implementation.
8. **Implemented locally: contract regression guard** —
   `test/character_sheet_contract_test.dart` verifies all three versioned sheets
   offline: declared canvas versus real guide/mask pixels, recorded SHA-256
   values versus the on-disk assets, the `rig.json` and ten locked head/body
   hashes, fixed-crop rules, per-version region sets, exact output canvases,
   in-canvas non-overlapping cells, and existing rig sources. It also proves
   V3's `4:1` `2K` shape, its three native back-hair cells, and that its region
   IDs match V1. The exact remaining V3 migration surface is recorded in
   [Character Sheet Plan](CHARACTER_SHEET_PLAN.md). No asset was registered, no
   runtime behavior changed, and no provider request was made.
9. **Implemented locally: Phase 7G.1C** — the V1 package now verifies the approved
   rig and ten head/body asset hashes, rejects generated face pixels outside
   the locked head, produces six distinct expression proofs plus four
   face-aware pose proofs, and reuses a matching ready design hash before any
   provider request. The private sprite route's shared three-per-minute
   bottleneck is removed while Flutter keeps one sequential request,
   deduplication, no automatic retry, and real provider quota errors. This was
   implemented without a paid request or test run. After the owner resumes V3
   migration, one controlled 2K request and owner proof acceptance are still
   required. The Worker portion is deployed as version
   `ed567efb-c4a9-4e76-ad32-f55a2e83d65a`.
10. **Then: Phase 7H** — register the validated character package and rebuild
   every affected ChapterStory so the correct human appears across chapters
   and volumes.
11. Continue with Phases 8–11 in roadmap order.

Do not start persistence, final Story Mode binding, or audio integration before
their roadmap gates unless a blocking defect requires a narrow fix.

## 12. Known unfinished work and defects

### Immediate character issues

- The Phase 7G whole-character Little Prince result is a rejected structural
  prototype: Gemini redrew the skull/body, and splitting it could not recover
  exact StoryTale geometry.
- V1, V2, and V3 still draw their `head` cell from the faced `base/head.png`
  rather than the locked `faces/head_base.png` the rig composes. They are left
  that way on purpose, behind their approved hashes; only V4 is corrected. Any
  migration to V1/V2/V3 would carry the defect forward.
- Phase 7G.1A.1 per-actor appearance persistence is implemented; the project
  owner still needs to perform the documented manual actor/pose/reload check.
- Book-specific humans are not yet connected to every Story Mode chapter;
  Phase 7H is intentionally blocked.
- The clothing/accessory component-sheet pipeline is documented but not
  implemented.

### Persistence and reading

- Imported books, chapters, source blocks, reading progress, bookmarks, reader
  settings, covers, and chapter illustrations within the image budget now
  survive a restart. Original EPUB bytes, preparation progress, and generated
  sprite/background images still do not.
- Browser local storage is only a few megabytes, so a library of several large
  light-novel EPUBs can exceed it. The write fails softly and the session keeps
  working, but the durable fix is Phase 8 file storage.
- Chapters still come from the EPUB navigation, so an unlisted page is not a
  chapter and its text is not readable. Only its artwork is recovered, by
  handing it to the chapter it precedes. The fixture yields 15 of its 16 images,
  the sixteenth being the cover.
- Stored illustrations are lossy display copies, not archival originals.
- Page mode restores a position through the progress fraction, so after a
  re-flow the reader returns to the right area rather than the exact word. Page
  counts also differ between web and Android because `TextPainter` measures the
  real font.
- Book IDs are time-based (`book-${microsecondsSinceEpoch}`), so importing the
  same file twice creates two library entries. Content-hash IDs and dedupe
  belong with Phase 8.
- `Book -> Volume -> Chapter` and grouping/migration are missing.
- The local database package is undecided.
- Durable generated files, checksums, cleanup, and interrupted job recovery are
  missing.

### Story packages

- The current Story Mode uses fixtures/prototypes; the generic final
  ChapterStory builder for every prepared imported chapter is Phase 9.
- Beat-level talking face, pose/action, camera trigger, audio timing, and exact
  full-chapter coverage still need final package binding.
- The Little Prince Chair/Flower/background sequence is a deterministic test,
  not the final story output for all chapters.

### Translation and audio

- DeepL text translation is real as of 5 August 2026, but only through the local
  dev proxy. On a physical Android device `127.0.0.1:52828` is the phone itself,
  so translation does not work there. A Worker `/translate` route is the durable
  cross-platform fix and is not built.
- Translations are cached per chapter and persist, but there is no usage counter
  and no cache keyed by source-text hash, so editing a chapter's source would
  not invalidate its translation.
- The mobile Tagalog ONNX TTS and voice-conversion runtime are not connected.
- The five current raw voice models need conversion, licensing review,
  physical-device testing, memory benchmarks, and quality approval.

### Known failing checks

- **None.** As of 6 August 2026 `flutter test` reports **213 passing, 0 failing**
  and `flutter analyze` reports **no issues**. The `sprite_rig_test.dart` failure
  and the `unnecessary_import` info were resolved on 5 August; see section 11.
- `dart format --set-exit-if-changed lib test` **rewrites files instead of only
  reporting them**. It currently reformats three unrelated pre-existing files:
  `lib/src/generated/voice_manifest.g.dart`,
  `test/story_generated_human_view_test.dart`, and
  `test/visual_novel_background_brief_test.dart`. Run it deliberately, then
  restore anything outside the current phase scope before committing.

### Release and documentation

- Physical Android performance, storage, battery, accessibility,
  reduced-motion, failure, and multi-volume tests remain.
- Public Worker authentication, per-user quotas, and spend limits remain.
- The roadmap's late “Complete remaining-work checklist” still has unchecked
  background/foreground boxes that conflict with the **Done** Phase 5/6
  sections. Until reconciled, trust the roadmap summary and detailed phase
  sections, not those stale duplicate boxes.
- One architecture diagram historically described “one head + 10 body parts.”
  The canonical rule is **10 total parts: one head plus nine body parts**.

## 13. Decisions already made

- Name the app StoryTale, not StoryWorld.
- Local-first MVP; no Supabase yet.
- User book upload is EPUB-only.
- DeepL is the only translation service.
- Gemini analyzes cleaned chapters separately and results merge into a volume
  Story Bible; do not send an entire long book in one request.
- Prepare a whole volume automatically; use per-chapter preparation only for
  repair/rebuild.
- Keep recurring character identity and appearance stable across chapters and
  future volumes.
- Auto-accept valid generated assets; normal readers only review results.
- Use Cloudflare Workers AI for landscape backgrounds and Gemini for locked
  sprite appearance components.
- No video generation. Use reusable sprites, poses, camera, transitions, and
  small movements.
- Story Mode is a visual novel with varied shots, not one small static actor
  moving left/middle/right.
- Use a locked local rig and generate overlays/components only.
- Keep head/face/body/hair separable; front/back hair are independent.
- Use a minimal expression catalog rather than dozens of talking/emotion
  combinations.
- Adult is the visible actor name previously called Deep Voice. Keep
  Adult/Deep as the corresponding audio role.
- Narrator has a voice but is not an actor template.
- Background music is optional/standby and does not block the MVP.

## 14. Rejected or deferred ideas and why

| Idea | Decision and reason |
| --- | --- |
| StoryWorld name | Rejected; use StoryTale |
| Supabase first | Deferred; local-first MVP avoids unnecessary backend scope |
| PDF/Word upload | Rejected; EPUB only |
| Grok/Seedance/video generation | Rejected/deferred; cost, quota, consistency, and unnecessary video scope |
| Cloudflare-generated character sprites | Rejected after poor exact-reference fidelity; Cloudflare generates backgrounds |
| Device-installed Android TTS | Rejected as too robotic/inconsistent |
| Run `.pth`/`.index` directly in Flutter | Not feasible; development models must become mobile ONNX/prepared assets |
| Generate one complete character and split it | Rejected; the generator already changes head/body geometry |
| Generate every body part separately | Rejected; inconsistent shape, style, and joints |
| Generate one full character image for every pose | Rejected; quota-heavy and visually inconsistent |
| Ask AI to find/cut component cells | Rejected; use one fixed versioned crop manifest |
| Require back hair for every actor | Rejected; explicit `None` must be valid and persistent |
| Reader-facing regenerate/replace/upload controls | Hidden/deferred; accidental clicks waste API quota and override auto-accepted assets |
| Square/floating-island background | Rejected; visual-novel landscape environment with stage lanes required |
| Large expression matrix | Rejected; use neutral/talking/happy/sad/angry/surprised plus rare needed sets |
| Analyze/generate everything again per chapter | Rejected; prepare the whole volume and reuse canonical assets |
| Static same actor and shot for many lines | Rejected; actions, speakers, subjects, and locations drive new shots |
| Substitute a generic human for an unavailable subject | Rejected; show a relevant object/location or no character |
| Let Gemini control raw pixels, bones, timing, or arbitrary IDs | Rejected; Flutter owns deterministic runtime rules |

## 15. Academic requirements and project-owner directions

The following assignment requirements and project-owner directions apply:

- Week 1 proposal must briefly state the core concept, target audience, and
  primary functionality.
- The submitted wireframe should contain three to five screens showing the
  main user flow, even though the full design catalog contains more screens.
- Week 3 deliverables are a detailed timeline/Gantt chart, milestones and
  deliverables, risk/contingency plan, and Week 2 presentation.
- Keep the proposal and explanations short, simple, correct, and focused on
  required deliverables.
- Keep Flutter code small, reusable, dynamic, and component-based.
- Use simple UI; do not create a heavy preparation dashboard.
- Do not claim unfinished APIs, persistence, final Story Mode, or audio as
  complete merely because the screen exists.
- The Add Book mockup that says EPUB/PDF is incorrect; implementation remains
  EPUB-only.
- Some historical UI images still contain “StoryWorld”; implementation and
  current documents must say StoryTale.
- Generated backgrounds must look like usable visual-novel settings, not
  isolated art objects.
- Characters must retain the StoryTale template proportions and remain
  reusable/posable rather than become unrelated AI illustrations.
- Let the project owner perform manual UI testing unless the prompt explicitly
  asks Codex to test.

Existing academic artifacts:

- `project-management/week3/StoryTale_Project_Timeline_Gantt.pdf`
- `project-management/week3/StoryTale_Milestones_and_Deliverables.docx`
- `project-management/week3/StoryTale_Risk_Assessment_and_Contingency_Plan.docx`
- `project-management/week3/StoryTale_Week2_Progress_Presentation.pptx`

Academic schedule (not the same as live engineering status):

| Milestone | Target |
| --- | --- |
| Proposal and wireframes | Week 1 / 26 Jul 2026 |
| Flutter foundation | Week 2 / 2 Aug 2026 |
| Local EPUB reader | Week 4 / 16 Aug 2026 |
| Translation/audio prototype | Week 6 / 30 Aug 2026 |
| Story analysis and asset catalogs | Week 8 / 13 Sep 2026 |
| Animated Story Mode prototype | Week 9 / 20 Sep 2026 |
| Testing | Week 10 / 27 Sep 2026 |
| Final system and presentation | Week 11 / 4 Oct 2026 |

## 16. Risks and safe fallbacks

- **API cost/quota:** reuse by stable design hash, send sequential requests,
  avoid automatic regeneration, and surface the real provider error.
- **AI inconsistency:** immutable rig, structured schema, approved IDs, fixed
  crop manifest, hard masks, deterministic validation, and safe fallbacks.
- **Lost local data:** Phase 8 durable files/database, atomic writes,
  checksums, migrations, and resumable jobs.
- **Large models/mobile performance:** load one active voice pack, benchmark on
  physical Android, and allow download/delete later.
- **EPUB variation:** stable parser/source blocks, boundary review, fixtures,
  and never hard-code a title.
- **Schedule growth:** protect the MVP. Reading remains useful without advanced
  Story Mode; music and polish are deferrable.
- **Licensing:** verify EPUB, generated-art, fonts, sprites, and voice-model
  rights before distribution.

## 17. Important files and folders

| Path | Responsibility |
| --- | --- |
| `AGENTS.md` | shared safety, coordination, validation, and handoff contract for every coding agent |
| `CLAUDE.md` | concise Claude Code entry point that imports the shared agent contract |
| `.claude/settings.json` | shared Claude permissions that protect secrets and disable unsafe bypass modes |
| `StoryTale.code-workspace` | canonical VS Code workspace for opening this checkout with Claude, Dart, and Flutter recommendations |
| `docs/ROADMAP.md` | only source of truth for current/next phases |
| `docs/ARCHITECTURE.md` | providers, boundaries, folders, and data flow |
| `docs/REQUIREMENTS.md` | product acceptance requirements |
| `docs/APP_FLOW.md` | user navigation and failure flow |
| `docs/ANIMATED_STORY_MODE_PLAN.md` | preparation and playback design |
| `docs/VOLUME_PREPARATION_PLAN.md` | whole-volume job, reuse, and repair |
| `docs/STORY_ANALYSIS_CONTRACT.md` | allowed Gemini schema and validation |
| `docs/ANIMATED_STORY_SCENE_LIBRARY.md` | allowed layouts, camera, motion, transitions |
| `docs/STORY_BIBLE_ENTITY_ASSET_PLAN.md` | entity, approval, asset, and fallback rules |
| `docs/VISUAL_NOVEL_BACKGROUND_PLAN.md` | background brief and generation contract |
| `docs/SPRITE_STUDIO_PLAN.md` | rig/pose editor behavior |
| `docs/MODULAR_FACE_SYSTEM_PLAN.md` | face parts and set behavior |
| `docs/FIXED_HAIR_SLOT_PLAN.md` | front/back hair fitting and `None` |
| `docs/GENERATED_CHARACTER_PIPELINE_PLAN.md` | exact-template layered human pipeline |
| `docs/CHARACTER_SHEET_PLAN.md` | authoritative Phase 7G.1B character-sheet, local composition, crop/mask, and acceptance contract |
| `assets/images/characters/rigs/humanoid_v1/` | canonical rig, poses, faces, hair, appearance |
| `assets/images/characters/face_profiles/` | Default/Hero/Heroine/Elder/Adult modular faces |
| `models/voices/raw/` | development RVC `.pth` and index/model pairs |
| `assets/models/` | eventual mobile-ready TTS/voice packs; currently placeholders |
| `cloudflare/image-worker/` | private analyzer/sprite/background Worker |
| `lib/src/features/animated_story/` | Story Bible, catalogs, prep, Sprite Studio, player |
| `lib/src/shared/models/storytale_models.dart` | core book/reader/story records |
| `tool/run_storytale.ps1` | canonical local launcher |

Main Flutter dependencies: `epubx`, `file_picker`, `html`, `http`, `image`,
`audioplayers`, `shared_preferences`, and Poppins font assets.

## 18. Running and verification

### Canonical VS Code and Claude Code entry

Open `StoryTale.code-workspace` from this repository instead of selecting a
StoryTale folder from VS Code's recent-project history. On this PC, the
canonical checkout is:

```text
C:\Users\Houro\Desktop\IT Elect 4\storytale
```

The repository versions `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json`, and
the VS Code extension recommendations. Claude Code must start at the repository
root, obey the normal permission prompts, read this handoff and the current
roadmap section, and stop at the documented phase gate. Codex and Claude must
not edit the same checkout concurrently; use separate worktrees if parallel
work is ever required.

The tracked Claude permission policy prevents access to local secret files,
requires confirmation for network and Git publication actions, blocks common
destructive Git cleanup and force-push commands, and disables bypass/auto
permission modes. Secrets remain local and ignored.

**Checked again on 5 August 2026: a web host *is* listening on port 52827.**
Check the port before launching another host and replace rather than duplicate
it. The earlier note in this section claimed nothing was running; that was stale.

Stable web-server preview:

```powershell
& "C:\Users\Houro\Desktop\IT Elect 4\storytale\tool\run_storytale.ps1" -Device web-server -Port 52827
```

Open `http://127.0.0.1:52827/`.

Other launcher forms:

```powershell
.\tool\run_storytale.ps1 -Device chrome
.\tool\run_storytale.ps1 -Device android
.\tool\run_storytale.ps1 -Device <flutter-device-id>
.\tool\run_storytale.ps1 -Device build-web
```

When an interactive Flutter run is active, use `r` for hot reload and `R` for
hot restart. A static `build/web` preview requires rebuilding and refreshing.

Targeted automated verification commands:

```powershell
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

The project owner normally performs the manual visual test. Codex should
finish the implementation and explain exactly what changed and what the owner
should observe; it should not consume time/API quota on manual generation
unless explicitly requested.

## 19. The “as usual” working agreement

When the user says **“Proceed with only the next roadmap phase as usual”**, it
means all of the following:

1. Read this handoff and the relevant part of `ROADMAP.md`; reuse existing
   context and do not re-audit the whole repository.
2. Confirm the exact current phase and inspect only its targeted files.
3. Make a safe Git checkpoint **before implementation**. Include only intended
   changes; preserve unrelated dirty files and never reset the user's work.
4. Implement exactly one roadmap phase/subphase with small, simple, reusable,
   dynamic code and no book-title-specific behavior.
5. Update `ROADMAP.md` and every directly affected plan in the same work unit.
6. Use targeted automated validation only. The user handles manual UI testing
   unless they explicitly ask Codex to do it.
7. Update the existing web preview on port `52827` and use a cache-busted URL
   when a preview is requested. If the user asked to keep it stopped or asked
   for no preview/testing, obey that instead.
8. Stop after reporting these sections: **Results**, **Testing instructions**,
   **Missing work**, and **Next phase**. If the prompt says “no testing
   instructions,” omit that section instead of interpreting it as permission
   to test.
9. Do not silently continue into the next phase.

Hard boundaries override “as usual.” Examples: `no code changes`, `planning
only`, `no testing`, `do not update the preview`, or an exact-file-only request.

Recommended prompt for a new chat:

> Read `docs/PROJECT_HANDOFF.md` and the current section of
> `docs/ROADMAP.md`. Proceed with only the next roadmap phase as usual. Reuse
> the existing context, do not review the entire repository again, make a safe
> checkpoint first, use targeted validation only, update the existing web
> preview unless I say not to, and stop after reporting results, testing
> instructions, missing work, and the next phase.

Short resume prompt after clearing a chat:

> Read `docs/PROJECT_HANDOFF.md`, section 11 "Current thread" first, then the
> current section of `docs/ROADMAP.md`. Continue from there as usual.

As of 6 August 2026 the next work unit is the **free `character_sheet_v4`
round-trip**: feed `guide_default_medium.png` back through
`character_sheet_processor.dart` as if it were the provider's reply and confirm
it cuts, masks, validates, and composes four poses. That proves the whole
pipeline for `$0.00` and leaves provider art quality as the only unknown. After
it, decide the faces direction recorded in section 11. Do not make a paid
request before both are done.

Clearing a chat is safe **because these documents are the memory**. Keep them
current at the end of every work unit and no context is lost when a session
ends. If a session is cleared mid-task, the next one starts from the last
recorded state, so record status before stopping rather than after.

## 20. Handoff rules for future chats

- Start with this file, then the roadmap, then only the plan owned by the
  current phase.
- Inspect the real Git status before editing. The workspace may intentionally
  contain uncommitted user changes.
- Do not treat a visible UI as proof that its provider or persistence is done.
- Do not mark a phase complete until its acceptance gate passes.
- Do not expose secrets or automatically make paid generation calls.
- Do not regenerate a recurring character or asset when a matching stable
  ready record exists.
- Do not overwrite the locked human template with an AI-generated body.
- Do not hard-code The Little Prince or the deferred light-novel fixture.
- Keep current documents named StoryTale even if historical images say
  StoryWorld.
