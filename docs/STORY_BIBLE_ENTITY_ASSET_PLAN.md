# Story Bible Entity and Asset Plan

**Status: Story Bible extraction, automatic approval, final landscape
backgrounds, shared foreground requirements, automatic validated asset
preparation, ChapterStory connection, and optional asset replacement are
implemented. Book-specific human generation follows next. See the
[Master Roadmap](ROADMAP.md).**

## Purpose

StoryTale must understand what a story subject is before choosing an image.
A human actor must never stand in for a flower, animal, creature, or object just
because that is the only available sprite.

```text
Cleaned chapter blocks
-> Gemini entity extraction
-> merge candidates into the book story bible
-> automatically approve reliable source-backed entities
-> review only uncertain or conflicting entities
-> generate or reuse approved assets
-> Gemini scene planning using only those approved IDs
-> validated Animated Story Mode
```

## Entity types

| Kind | Examples | Visual treatment |
| --- | --- | --- |
| `human` | prince, heroine, elder, merchant | Modular character rig, face sets, outfits, poses, and voice |
| `animal` | fox, wolf, horse, bird | Transparent character sprite; whole-sprite movement first, optional rig later |
| `creature` | dragon, spirit, monster | Transparent character sprite with only story-required states |
| `plant` | rose, magic tree, flower | Transparent focus asset with story-required states such as bloom or wilt |
| `prop` | chair, letter, sword, key | Transparent focus asset with only important state variants |
| `location` | prince's home, forest clearing, castle throne room | Reusable Cloudflare background variants |

The narrator is not a visible entity unless the book explicitly contains a
separate narrator character.

## Story-bible record

Every recurring or visually important subject receives a stable record:

```text
StoryEntity
- entityId
- kind
- canonicalName
- aliases
- description
- relationships
- firstSeenVolumeId and firstSeenChapterId
- recurring
- importance: background, supporting, or focus
- speaker: true or false
- voiceId (only when it speaks)
- approvalState: approved or pending
- approvalMode: automatic or manual
- approvalReason
- lockedAppearance
- assetIds
- unresolvedNotes
- parentSetting (locations only)
- backgroundBrief (locations only)
```

Aliases always resolve to the same `entityId`. A later volume may add a new
alias, relationship, outfit, age state, or object state, but it cannot silently
replace an approved design.

## Automatic entity approval

Entity approval means that the subject may enter the book Story Bible and
become eligible for matching asset generation. It does not approve generated
artwork.

A new entity is approved automatically only when all of these checks pass:

1. Confidence is at least `0.85`.
2. Every referenced source block exists and directly supports its name and
   kind.
3. The candidate has a canonical name, kind, and source-backed description.
4. Alias resolution finds no duplicate, kind conflict, or competing ID.
5. `unresolvedNotes` is empty.
6. The subject speaks, recurs, changes state, becomes a clear visual focus, or
   is a specific reusable place.
7. A location also passes the background-ready location rules below.

A candidate remains pending when confidence is lower, identity or kind is
ambiguous, aliases conflict, details are unsupported, or a possible duplicate
needs review. The Story Bible screen keeps manual approve, edit, merge, and
delete controls for these exceptions.

Entity approval and artwork approval are separate:

- automatic entity approval may queue the correct asset type;
- generated art must still be reviewed before its asset ID and appearance are
  locked; and
- an automatically approved entity without approved art must use the safe
  fallback, never an unrelated asset.

## Background-ready locations

A `location` is a specific, visually stageable place where a scene can occur
and which can be reused as a background. It must answer: **Where can the
characters visibly be right now?**

Broad world or setting nouns are context, not standalone locations. Words such
as `planet`, `world`, `kingdom`, `country`, `forest`, or `ocean` become a
`parentSetting` unless the chapter supports a concrete place inside them.

| Too broad | Background-ready location |
| --- | --- |
| Small Planet | Little Prince's home on the small planet |
| Kingdom | King's throne room |
| Forest | Forest clearing beside the cottage |
| Ocean | Rocky shore at the edge of the ocean |

The analyzer must not invent detail just to make a name more specific. If the
text only mentions a distant kingdom and no scene occurs there, keep it as
context and do not create a location entity.

This rule is story-independent. It uses the chapter's source blocks, not a
hard-coded title, character, or sample location. For example:

- a scene happening at a character's home on a planet may become `Little
  Prince's home on the small planet`;
- a scene happening inside a castle may become `King's throne room`;
- a journey moving from a house to a road and then a school creates three
  specific locations; and
- a mentioned country that is never visited remains parent context only.

Day, sunset, night, rain, damage, or seasonal changes are background states of
one stable `locationId`, not new locations. Repeated references such as `his
planet`, `the little planet`, and `home` should resolve to the same location
record when the source confirms they mean the same place.

### Multiple backgrounds within one chapter

A chapter does not have one fixed background. It has one ordered background
assignment per cutscene:

```text
Chapter
-> Cutscene 1: locationId + backgroundStateId
-> Cutscene 2: locationId + backgroundStateId
-> Cutscene 3: locationId + backgroundStateId
```

Start a new cutscene background when the source clearly changes:

- physical place, such as bedroom to street;
- interior or exterior area, such as castle gate to throne room;
- meaningful time, weather, season, or condition of the same place; or
- story event after which the place is visibly transformed.

Do not change backgrounds only to create artificial variety. Consecutive shots
in the same place and state reuse the same approved asset while camera framing,
character positions, focus assets, and movement provide visual variation.

The analyzer returns every distinct required pair of `locationId` and
`backgroundStateId` in source order. StoryTale generates or reuses one approved
background for each distinct pair, then caches it for later chapters and
volumes. A chapter with one real setting may correctly use one background; a
chapter that visits several places must represent all supported transitions.

## Runtime layer types

Keep the current `characterLayers` for speaking or acting subjects:

- Human characters use their approved modular rig.
- Important animals and creatures may also be character layers, but use their
  own compatible rig or transparent whole-sprite asset.
- A non-humanoid entity never uses `humanoid_v1`.

Add a small `focusAssetLayers` collection for non-speaking plants and props:

```text
FocusAssetLayer
- entityId
- assetId
- variantId
- stagePosition
- scale
- depth
- movement
```

The first version needs at most two focus assets in a shot. Flutter owns their
coordinates, scale limits, movement distances, and timing.

## Minimum assets

Do not generate a large catalog for every noun in a book. Generate only an
entity that is recurring, speaks, changes state, or becomes a clear visual
focus.

| Entity | Minimum first-version assets |
| --- | --- |
| Human | One approved master, modular parts, Neutral face, and compatible fallback pose |
| Speaking animal/creature | One transparent full-body neutral sprite and one talking state |
| Important silent animal | One transparent full-body neutral sprite |
| Plant | One transparent normal state plus only plot-required states |
| Prop | One transparent normal state plus only plot-required states |
| Location | One approved background for each source-required place state |

All approved assets are cached and reused across chapters and volumes. StoryTale
does not generate a new image for every scene.

## Generation ownership

- Gemini story analysis extracts and classifies entities.
- Gemini image generation creates reusable foreground assets: humans, animals,
  creatures, plants, and props.
- Cloudflare Workers AI creates location backgrounds.
- StoryTale removes flat backgrounds locally when needed, validates
  transparency and dimensions, then assigns the final stable asset ID.
- Deterministically valid generated assets become ready automatically. Failed
  or invalid results use a safe fallback and remain available for retry.

## Mandatory analyzer rules

1. Use only an asset whose `entityId` matches the story subject.
2. Never represent an animal, creature, plant, or prop with an unrelated human.
3. A flower line may use its approved plant asset, an `object_detail` shot, or
   an empty background shot; it must not use `heroine_actor`.
4. A speaking animal uses its own character ID, sprite, and voice mapping.
5. A one-off background noun does not automatically require image generation.
6. If an important asset is missing, hide character layers and continue with
   subtitles, narration, a background/detail shot, and optional SFX.
7. Never invent an entity, asset, state, rig, pose, or background ID.
8. Preserve all chapter source blocks exactly and in order.
9. Create a location only for a specific source-backed place where a scene can
   occur; store broad settings as context.
10. Reuse one location ID across time and weather variants.
11. Assign every cutscene a source-backed `locationId` and
    `backgroundStateId`.
12. Represent every explicit place transition, but never invent a transition
    just to increase the number of backgrounds.

## Preparation workflow

1. Extract chapter entities with stable source references and confidence.
2. Resolve aliases against the existing book story bible.
3. Normalize a proposed location into a specific source-backed place or keep
   the broad setting as context.
4. Map ordered plot beats to their specific place and background state.
5. Build the chapter's distinct required-background list from those mappings.
6. Automatically register a generated asset when its source requirement,
   stable entity/variant ownership, format, dimensions, and transparency pass
   every deterministic check. Normal preparation requires no approval click.
7. Let the user inspect generated results without exposing retry or replacement
   controls in the normal app.
8. Reuse an approved asset when one already exists.
9. Generate only the missing approved masters and required states.
10. Register deterministic successes in the story bible automatically. Retain
    regeneration and replacement only behind the disabled developer flag for a
    possible future administration flow.
11. Run Gemini scene planning with the updated approved catalog.
12. Validate that every visible layer matches its referenced entity.
13. Cache the validated chapter plan locally.

## Implementation status

Implemented:

- Typed `StoryEntity` and per-book story-bible models
- Local story-bible persistence
- Alias-aware candidate merging that preserves approved designs and assets
- Private Worker `/entities` endpoint using Gemini structured output
- Source-block, kind, confidence, candidate-approval, and asset-safety checks
- Chapter preparation saves extracted candidates before scene planning
- Story Bible review grouped by people, animals, creatures, plants, props, and
  locations
- Local approve/pending, edit, merge, and delete actions
- Safe type correction before assets exist
- Local automatic approval for high-confidence, source-backed entities without
  unresolved notes
- Specific scene-location fields: parent setting, background brief, and
  background-ready location status
- Safe replacement of an unlocked broad location with a supported specific
  scene place while retaining the former name as an alias
- Ordered, deduplicated chapter background requirements using
  `locationId::backgroundStateId`
- Local generated-background records with stable asset IDs
- Cloudflare background generation for approved specific locations
- Automatic background validation and registration, with a read-only user
  catalog
- Approved background asset IDs registered back onto their location entities
- Required animal, creature, plant, and prop inventory records generated
  through Gemini as reusable transparent PNG candidates
- Generated foreground assets retain stable entity, variant, and chapter
  ownership; valid images are registered automatically and invalid images are
  marked `needsReview`
- One sequential, deduplicated volume queue prepares missing backgrounds and
  foreground variants while respecting the provider request limit
- Generated bytes use a session binary store rather than SharedPreferences
- Ready-only scene catalogs expose exact stable background and foreground IDs
  to Gemini after generation
- Chapter 1 is reconnected after the asset queue, with exact location/state
  backgrounds and at most two source-supported foreground layers
- Story Mode resolves image bytes by stable ID, renders transparent focus
  layers by placement/depth/movement, and never substitutes an unrelated human
- Asset result catalogs show compact previews while Retry, Regenerate, Replace,
  Replace PNG, Reuse, and Discard remain hidden behind one disabled developer
  flag; the preserved management path keeps canonical IDs stable if restored
  later

Still pending:

- **Phase 7:** generate reusable book-specific human masters and modular rigs
- **Phase 8:** replace the session binary store with durable asset files,
  integrity metadata, restart recovery, and orphan-safe cleanup

## Safe fallback

If any entity or asset is unresolved, normal reading and audio still work.
Animated Story Mode must prefer:

1. an approved matching asset;
2. a no-character `object_detail` or location shot;
3. the book's default background;
4. subtitles and narration only.

It must never select the closest-looking unrelated actor.

## Validation fixtures

Before connecting real generated assets, add these deterministic cases:

- A rose line produces a plant focus or empty detail shot, never Heroine.
- A speaking fox resolves to one stable animal character across chapters.
- A sword uses a prop asset and never receives a human face or voice.
- Two aliases for one character resolve to the same ID.
- A missing animal image hides the layer while its dialogue or narration stays.
- Importing a later volume reuses the approved fox, rose, and location assets.
- A high-confidence, source-backed flower is automatically entity-approved.
- A conflicting alias or uncertain kind remains pending.
- `Small Planet` is not kept as the final background location; the supported
  active place becomes `Little Prince's home on the small planet`.
- A mentioned kingdom with no scene there remains context, not a location.
- Sunset and night reuse one location ID with different background states.
- Automatic entity approval never automatically accepts generated artwork.
- A house-to-road-to-school chapter uses three ordered locations.
- A castle-gate-to-throne-room chapter uses two specific locations under one
  castle parent setting.
- Two consecutive dialogue shots in one unchanged room reuse one background.
- A forest chapter with a later cave scene cannot use the forest background for
  the cave.
- A chapter that genuinely stays in one room is not forced to invent another
  background.
