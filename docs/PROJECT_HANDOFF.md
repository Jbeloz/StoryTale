# StoryTale Complete Project Handoff

Last verified: **2 August 2026**

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
- `ReaderSettingsData`: text size, font, theme, line spacing, language mode.

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

- `sprite_studio.face_profiles.v1`
- `sprite_studio.<rigId>.custom_poses`
- `sprite_studio.<rigId>.appearance`
- `storytale.story_bible.v1.<bookId>`
- `storytale.background_catalog.v1.<bookId>`
- `storytale.foreground_catalog.v1.<bookId>`
- `storytale.human_catalog.v1.<bookId>`

Generated image bytes currently use a session-only `StoryAssetBinaryStore`.
Imported books, volume jobs, and original EPUB bytes are also session-oriented.
Therefore an app restart can lose imported library state, preparation progress,
and generated binary images even when small catalog metadata remains. Phase 8
must add durable local files plus an indexed database, atomic metadata/file
updates, checksums, migrations, interrupted-job recovery, and safe orphan
cleanup.

## 11. Development status

The [Master Roadmap](ROADMAP.md) is authoritative. As of this handoff:

| Phase | Status | Meaning |
| --- | --- | --- |
| 0 Foundation/UI | Done | shell, theme, navigation, reusable screens |
| 1 EPUB import | Partial | session import works; persistence/volumes missing |
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

### Exact current and next work

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
- Phase 7G.1A.1 per-actor appearance persistence is implemented; the project
  owner still needs to perform the documented manual actor/pose/reload check.
- Book-specific humans are not yet connected to every Story Mode chapter;
  Phase 7H is intentionally blocked.
- The clothing/accessory component-sheet pipeline is documented but not
  implemented.

### Persistence and reading

- Imported EPUBs and reading/bookmark/preparation progress do not survive all
  restarts.
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

- DeepL UI currently uses placeholder behavior; real service/cache/usage
  integration is missing.
- The mobile Tagalog ONNX TTS and voice-conversion runtime are not connected.
- The five current raw voice models need conversion, licensing review,
  physical-device testing, memory benchmarks, and quality approval.

### Known failing checks (pre-existing, found 4 August 2026)

- `flutter test` reports 123 passing and **1 failing**: `test/sprite_rig_test.dart`
  "Sprite Studio has responsive editing and undo redo". It throws an AppBar
  `RenderFlex overflowed by 90 pixels` from
  `lib/src/shared/widgets/storytale_components.dart` and then finds no
  `face-neutral` key. This predates the contract regression guard and is
  unrelated to it; it reproduces when that file runs alone.
- `flutter analyze` reports one info-level `unnecessary_import` for
  `dart:typed_data` in
  `lib/src/features/animated_story/data/character_sheet_package.dart`.
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

The web preview was checked before this handoff. **Port 52827 was not running,
the open StoryTale tabs showed connection errors, and the browser-control
session was released. No StoryTale web host was left running.**

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
