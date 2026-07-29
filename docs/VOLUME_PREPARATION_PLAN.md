# StoryTale Volume Preparation Plan

## Goal

Import an EPUB once, analyze every story chapter in the volume, build one
consistent cast and asset catalog, and prepare all chapter Story Mode packages
without asking the reader to press **Prepare Chapter** repeatedly.

Normal e-book reading is available immediately after EPUB parsing. Animated
Story Mode becomes available chapter by chapter while one resumable background
job finishes the volume.

## Important boundary

StoryTale analyzes the whole volume as one coordinated job, but it does not send
the whole EPUB to Gemini in one request.

```text
EPUB
-> confirmed volume and chapter boundaries
-> cleaned chapters with stable source-block IDs
-> one validated Gemini analysis request per chapter
-> volume-wide merge
-> shared Story Bible and asset inventory
-> reusable sprites and backgrounds
-> one ChapterStory package per chapter
```

This keeps requests smaller, preserves exact chapter boundaries, supports
resume after failure, and prevents one bad response from invalidating the
entire book.

## Book, volume, and chapter rules

The hierarchy is `Book -> Volume -> Chapter`, but StoryTale must not assume that
many chapters means many volumes.

- One book may contain exactly one volume with any number of chapters.
- A long EPUB with dozens or hundreds of chapters remains one volume unless
  its metadata, navigation, headings, or the user confirms real volume
  boundaries.
- A box-set EPUB becomes multiple volumes only when clear source-backed
  boundaries exist.
- Separate EPUB files may be joined under one book as separate volumes after
  user confirmation.
- The file name, title number, chapter count, and genre are hints only; none of
  them may silently create or split volumes.
- If only one volume exists, the normal UI hides unnecessary volume controls
  and shows the chapter list directly.
- If boundaries are uncertain, normal reading still works while a simple
  confirmation screen waits for the user.

## Reader flow

1. The user imports an EPUB.
2. StoryTale immediately makes the normal reader available.
3. StoryTale shows **Prepare Animated Volume** with the chapter count and an
   estimated storage warning.
4. Starting it opens a small preparation status view inside the existing
   Animated Story Mode flow.
5. The job analyzes all story chapters in source order.
6. StoryTale merges names, aliases, characters, locations, animals, plants,
   props, and timeline facts into one volume-aware Story Bible.
7. Shared sprites and backgrounds are generated once and reused.
8. Every chapter receives its own scene, subtitle, camera, pose, dialogue, and
   moral package.
9. Ready chapters can be played while later chapters are still preparing.
10. When the volume finishes, every valid chapter shows **Story Mode Ready**.

The existing **Prepare Chapter** action becomes **Repair/Rebuild Chapter**. It
is used only when one chapter failed, became stale, was edited, or introduced a
missing asset after the volume job.

## Preparation stages

| Stage | Weight | Result |
| --- | ---: | --- |
| 1. Import and boundaries | 5% | EPUB metadata, volume number, chapter types, spine order, and stable IDs |
| 2. Clean chapter text | 10% | Ordered source blocks and hashes for every story chapter |
| 3. Analyze chapters | 25% | Characters, aliases, dialogue speakers, locations, plot beats, and summaries |
| 4. Merge Story Bible | 10% | One consistent volume roster, timeline, style guide, and unresolved list |
| 5. Plan shared assets | 5% | Unique character, non-human, prop, and location/state requirements |
| 6. Prepare shared assets | 20% | Approved reusable sprites, rigs, focus assets, and backgrounds |
| 7. Assemble chapters | 20% | Cutscenes, shots, poses, faces, camera, movement, subtitles, and moral |
| 8. Validate packages | 5% | Complete source coverage, valid IDs, files, fallbacks, and ready states |

The weights are for understandable progress, not a promise of exact time.
Elapsed time is always shown. An estimated time remaining appears only after
StoryTale has completed enough requests to calculate a useful average.

## Minimal preparation status UI

This is not a large admin dashboard. It uses the existing StoryTale cards,
buttons, typography, and spacing.

When the user taps **Animated Story** on a book:

- **Not started:** show the chapter count, a short explanation, estimated asset
  count/storage, and one **Prepare Animated Volume** button.
- **Preparing:** show one progress bar, the percentage, current stage, current
  chapter, `ready / total` chapters, elapsed time, and one Pause/Resume button.
- **Partly ready:** show the normal chapter list; ready chapters can open, and a
  small progress card remains above the list.
- **Complete:** open the normal Story Mode chapter list or resume the last
  chapter without showing the preparation card again.
- **Needs attention:** show one short error and a Retry button. Technical
  details stay collapsed under **View details**.

The main screen does not show large entity tables, asset counters, raw logs, or
many controls. A compact optional details sheet may show discovered subjects,
reused/generated assets, warnings, and the short timestamped event log when
the user asks for it.

The status view never displays API keys, raw hidden prompts, or
chain-of-thought.

## Volume job data

```text
VolumePreparationJob
- jobId
- bookId
- volumeId
- status
- currentStage
- currentChapterId
- overallProgress
- startedAt
- updatedAt
- elapsedSeconds
- estimatedRemainingSeconds
- chapterJobs
- entityCounts
- assetCounts
- warnings
- errors
- analysisVersion
- promptVersion
```

```text
ChapterPreparationJob
- chapterId
- sourceTextHash
- analysisStatus
- assetStatus
- assemblyStatus
- validationStatus
- progress
- retries
- lastError
- packageId
```

Allowed status values are `waiting`, `running`, `ready`, `needsReview`,
`failed`, `stale`, and `cancelled`.

## Names, aliases, and appearances

Each story subject receives a stable ID that does not depend only on its display
name.

```text
StoryEntity
- entityId
- kind
- canonicalName
- displayName
- aliases
- sourceEvidence
- firstAppearance: volumeId + chapterId + sourceBlockId
- chapterAppearances
- speakingChapters
- visualStates
- relationships
- approvedAssetIds
- needsReview
```

Rules:

- Repeated aliases merge into the same entity before image generation.
- An unnamed subject receives a provisional stable ID and can be renamed later
  without replacing its assets.
- Two people with the same name remain separate when source evidence or
  relationships conflict.
- A revealed identity can merge with an earlier provisional identity after
  validation.
- Gemini must return stable entity IDs from the compact Story Bible catalog.
- Display names used in subtitles come from the approved canonical name or the
  source-appropriate alias for that chapter.
- Every entity lists the chapters where it appears, first appears, speaks, or
  changes appearance.

## Reusable character and asset rules

StoryTale plans assets after all chapter analyses have been merged.

- A recurring main or side character is generated once for the volume.
- The same approved head, rig, face catalog, outfit, and voice mapping are
  reused in every chapter.
- A later chapter may add an outfit, injury, age, or story-required state, but
  it does not replace the locked base identity.
- Pose changes use Sprite Studio transform JSON; they do not generate another
  full character picture.
- Face changes use reusable eyes, nose, mouth, and detail parts.
- Important animals and creatures use approved whole sprites.
- Important plants and props use only the normal and plot-required states.
- One location/state background is generated once and reused by every matching
  cutscene.
- Decorative nouns that never speak, change, or receive story focus do not get
  their own generated asset.

When a later volume introduces a new entity, StoryTale adds only that entity
and its required assets to the existing book catalog.

## Chapter assembly

After the shared catalog is ready, each chapter is assembled without
regenerating its cast:

1. Preserve every cleaned source block exactly once and in order.
2. Group continuous events into cutscenes.
3. Select the approved location/state background.
4. Select zero to three approved character layers.
5. Select an approved pose, face set, facing, scale, depth, and movement.
6. Select a camera preset, transition, and short subtitle beat.
7. Add at most two important focus assets.
8. Save the moral separately from the original chapter text.
9. Apply safe no-character/background fallbacks for missing visual assets.
10. Validate and save a versioned `ChapterStory` package.

Camera, pose, movement, and layout choices come from the approved catalogs.
Gemini chooses IDs; it does not invent unsupported runtime behavior.

## Readiness rules

A chapter is **Story Mode Ready** when:

- its analysis matches the current source-text hash;
- every source block is covered exactly once and in order;
- referenced IDs belong to the same book and entity;
- required backgrounds are approved or have the documented fallback;
- character/focus layers use approved compatible assets or are safely hidden;
- every shot uses supported layout, pose, movement, camera, and transition IDs;
- subtitles and the chapter moral exist;
- the saved package passes schema and file validation.

Translation and offline voices may be prepared later. Missing optional audio
does not block subtitles-only Story Mode unless the user selected
**Require audio before ready**.

## Failure and resume

- Completed chapter analysis is cached by source-text hash.
- A failed chapter does not erase completed chapters.
- A failed image does not rerun Gemini text analysis.
- A replaced background updates only matching shots.
- A changed voice rebuilds only affected audio.
- Restarting the app resumes from the last saved stage and item.
- **Retry failed items** processes only failed or stale records.
- **Repair/Rebuild Chapter** reuses the volume Story Bible and approved assets.
- The original EPUB and approved assets are never removed automatically.

## Storage and cost controls

Full-volume preparation can take time, network usage, API quota, and device
storage. The app therefore:

- displays estimated image count and storage before starting;
- limits concurrent Gemini and Cloudflare requests;
- deduplicates assets by stable entity/location IDs and design fingerprints;
- generates assets only for narratively important subjects;
- allows Pause and Resume;
- supports **Analysis only** before any images are generated;
- uses **Prepare all chapters** as the default path: analyze, validate
  requirements, automatically generate missing reusable assets, and register
  deterministic successes without an approval click;
- shows a simple review list after preparation, while requiring attention only
  for invalid or failed items;
- lets the user remove generated chapter packages while retaining the EPUB,
  Story Bible, and approved reusable assets.

## First implementation fixture

Use the bundled Little Prince sample first:

1. Treat all of its demo chapters as one default volume.
2. Run one volume preparation job.
3. Confirm names and aliases merge into stable entities.
4. Confirm every entity lists its chapter appearances.
5. Confirm a recurring character and location are prepared only once.
6. Confirm Chapter 1 assembles from the shared catalog.
7. Confirm later demo chapters can become ready without regenerating the same
   assets.
8. Interrupt and resume the job.

The local `Mushoku_Tensei_-_Volume_09_Seven_Seas_Kobo.epub` remains the later
real-volume fixture. Do not run it until persistent volume storage, resumable
jobs, and explicit test approval are ready.

## Roadmap sequence

### Phase 6A - Volume preparation foundation

Status: **Completed on 2026-07-27 as an in-memory foundation.**

- [x] Add volume and chapter job models.
- [x] Add the minimal preparation status view and chapter-weighted progress.
- [x] Analyze all Little Prince chapters one by one.
- [x] Merge names, aliases, first appearances, chapter appearances, speaking
  chapters, and background requirements into one in-memory volume result.
- [x] Keep existing Story Mode assets and providers unchanged.
- [x] Add safe per-chapter fallback plus pause/resume between chapters.

The job currently treats each `BookData` record as its one implicit volume and
does not persist through an app restart. Explicit `VolumeData`, durable jobs,
source hashes, retries, and restart recovery remain Phase 8 work.

### Phase 6B - Shared foreground inventory

Status: **Completed on 2026-07-27.**

- [x] Derive only required animals, creatures, plants, and props from the
  merged volume inventory.
- [x] Create stable book/entity/variant asset IDs.
- [x] Track required, generated, approved, and rejected states.
- [x] Preserve review state when the same merged inventory is refreshed.
- [x] Show one minimal shared inventory under Animated Story preparation tools.

### Phase 6C - Foreground candidate generation

Status: **Completed on 2026-07-27.**

- [x] Generate Gemini image candidates only for required records, remove the
  magenta background locally, and retain the result as a transparent PNG with
  its stable inventory record.

### Phase 6D - Automatic asset preparation and validation

Status: **Completed on 2026-07-27.**

- [x] Repair missing chapter appearances before requirements are queued. A
  required Chair or Flower from Chapter 1 must show Chapter 1 rather than
  `0 chapters`.
- [x] Combine missing location backgrounds and required foreground variants
  into one deduplicated volume queue.
- [x] Start the queue automatically after analysis instead of requiring a
  Generate button for every item.
- [x] Generate sequentially and reuse ready assets so the three-request
  provider limit is not exceeded.
- [x] Move full image bytes out of SharedPreferences and large widget state.
  Use a session binary store until Phase 8 adds durable local asset storage.
- [x] Perform image decoding, chroma removal, metadata checks, and binary
  storage before the small UI state update to prevent the visible freeze after
  generation.
- [x] Validate format, dimensions, alpha transparency, entity ID, variant ID,
  stable asset ID, and chapter ownership.
- [x] Automatically mark and register deterministic successes as ready; no
  manual approval is required.
- [x] Keep failed or invalid items visible as `needsReview` with Retry while
  normal reading and safe Story Mode fallbacks continue.
- [x] Show one compact progress line with current item, ready count, failed
  count, and remaining count.

### Phase 6E - ChapterStory asset connection

Status: **Completed on 2026-07-28.**

- [x] Add a serializable `FocusAssetLayerData` record with stable `entityId`,
  `assetId`, `variantId`, placement, scale, depth, and movement. `ChapterStoryData`
  stores IDs only; the binary store owns the image bytes.
- [x] Build ready-only location and foreground catalogs from repository
  metadata plus the binary store. A metadata record with missing bytes is not
  ready for scene planning or playback.
- [x] Give Gemini only the ready catalog IDs and validate every returned ID.
  Require an exact location/background-state match and reject unrelated
  entities even when they look visually similar.
- [x] Assign the ready background ID for each matching location/state.
- [x] Add at most two source-supported foreground assets to
  `focusAssetLayers`; include only subjects present in the shot's source block.
- [x] Resolve background and transparent foreground bytes by ID in the
  visual-novel player, preserve foreground layer order, and keep large bytes
  outside widget and preferences state.
- [x] Remove unrelated prototype-human substitution. If an asset is missing,
  hide that layer and retain its subtitle/narration or use an object/location
  fallback.
- [x] Make the resolver book- and chapter-agnostic. Rebuild Chapter 1 only as
  the first fixture; Phase 9 runs the same connection for every analyzed
  chapter.
- [x] Automatically relink/rebuild the fixture after the automatic asset queue
  completes or when its Animated Story Mode opens. No Generate, Approve, or
  Attach action is required.
- [x] Add targeted fixtures: the rose uses the flower foreground instead of
  Heroine, the chair uses the chair foreground, the generated location is the
  stage background, unknown asset IDs fail validation, and missing bytes use a
  safe fallback without freezing the UI.

### Phase 6E.1 - Live Chapter 1 stabilization

Status: **Implemented; the user-run Chapter 1 acceptance gate is still
required before Phase 6F.**

This is a narrow repair and verification gate for the first connected chapter.
It does not expand asset connection to every chapter and it does not implement
the final beat-level character animation system.

- [x] Add a compact diagnostic trace for each expected foreground:
  Story Bible entity -> required variant -> automatically accepted metadata ->
  binary bytes -> ready catalog -> connected `focusAssetLayers` -> player byte
  lookup. Keep this diagnostic out of the normal reader UI.
- [x] Make reconnection deterministic after generation. Even when the second
  Gemini story-planning request fails, the safe source-preserving story must be
  passed through the connector and receive every ready, source-supported
  foreground.
- [x] Confirm the Chair and Flower records have the correct Chapter 1 and
  source-block ownership. Never attach them merely because an image is
  available.
- [x] Replace the current repeated demo passage with one short unique fixture:
  a background/sunset moment, a chair action, and a flower introduction, each
  appearing once and in source order. Keep it clearly identified as test
  content rather than the full published book.
- [x] Update the story-planning rules so a meaningful speaker, action, focus
  subject, location, or background-state change starts a new shot.
- [x] Keep a normal fixture shot to one to three short subtitle beats. If a
  source block is longer, preserve its exact words and order across additional
  shots instead of leaving many lines under one static composition.
- [x] Ensure the connector assigns the Chair only to a source-supported chair
  shot and the Flower only to a source-supported flower shot. The user-run
  acceptance check below confirms the generated Chapter 1 result.
- [ ] Verify the generated location remains the background while foregrounds
  use transparent PNG layers, correct depth, and safe placement above the
  subtitle area.
- [ ] Verify a manual refresh during the same preparation session reloads the
  connected artwork. Missing or corrupt bytes must hide only that asset and
  must not freeze playback.
- [x] Keep beat-specific talking faces, pose changes, action playback, and
  camera-trigger reactions assigned to Phase 9. This stabilization phase only
  improves useful shot boundaries and foreground connection.

Acceptance checklist before Phase 6F:

- [ ] Generated background appears in Chapter 1.
- [ ] Chair appears on the chair action and nowhere unrelated.
- [ ] Flower appears on the flower introduction and nowhere unrelated.
- [ ] The fixture no longer repeats the same passage.
- [ ] Normal shots contain no more than three short subtitle beats.
- [ ] Previous/Next crosses shot boundaries without skipping or changing text.
- [ ] Refresh and missing-asset fallback behave without a frozen screen.

### Phase 6F - Optional review and replacement

Status: **Completed on 2026-07-29.**

- [x] Show lightweight previews for automatically accepted assets.
- [x] Provide Retry, Regenerate, Replace, and Reuse without requiring normal
  approval.
- [x] Preserve the canonical asset ID when replacing its bytes so existing
  ChapterStory packages remain connected, then refresh affected previews.
- [x] Retry only failed or `needsReview` work; do not regenerate valid reused
  assets or block normal reading.
- [x] Keep manual attention only for invalid, failed, or visibly unsuitable
  results.

Valid foregrounds now show compact previews and keep their stable IDs when a
generated or user-selected PNG replaces their bytes. Background replacement
uses the same candidate-first behavior. A failed replacement never removes a
working asset, and Reuse discards only the candidate.

### Phase 7 - Shared book-specific humans

- Generate and approve one locked human identity and reusable rig per roster
  entry.
- Reuse it across every chapter and later volume.

### Phase 8 - Persistent books, volumes, and jobs

- Persist the original EPUB, source blocks, Story Bible, approved assets,
  volume jobs, chapter jobs, and progress.
- Replace the session binary store with durable generated-asset files and an
  indexed metadata repository containing stable ID, owner, variant, MIME type,
  dimensions, checksum, and status.
- Migrate valid session binaries atomically; mark missing or corrupt files not
  ready and queue only those files for safe regeneration.
- Restore ready backgrounds, foregrounds, ChapterStory packages, and
  interrupted queues after restart without unnecessary regeneration.
- Update files and metadata together during replacement or deletion, and
  remove only generated files proven to be orphaned.
- Resume after restart and group later EPUB volumes under the same book.

### Phase 9 - Prepare every ChapterStory package

- Assemble and validate all chapters from the shared catalogs.
- Replace the normal Prepare Chapter flow with readiness, repair, and rebuild
  actions.

### Phase 10 - Translation and offline audio

- Cache DeepL translations and prepared line audio.
- Update only translation/audio readiness without regenerating visuals.

### Phase 11 - Real-volume and release validation

- Run the deferred light-novel fixture with explicit approval.
- Validate volume 9 metadata, boundaries, names, reusable cast, interrupted
  preparation, storage, performance, and physical Android playback.
