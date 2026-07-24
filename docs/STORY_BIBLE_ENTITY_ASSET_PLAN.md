# Story Bible Entity and Asset Plan

**Status: Parts 8A-8B implemented; entity extraction, local story bibles, and
candidate review are ready. Automatic entity approval and specific-location
normalization are planned before asset generation. The current player still
uses prototype actors.**

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
context and do not create a location entity. For the current demo, `Small
Planet` should be normalized to `Little Prince's home on the small planet`
because that is the chapter's active place.

Day, sunset, night, rain, damage, or seasonal changes are background states of
one stable `locationId`, not new locations. Repeated references such as `his
planet`, `the little planet`, and `home` should resolve to the same location
record when the source confirms they mean the same place.

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
- stateId
- stagePosition
- scale
- depth
- movementId
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
| Location | One approved background plus only required time/weather variants |

All approved assets are cached and reused across chapters and volumes. StoryTale
does not generate a new image for every scene.

## Generation ownership

- Gemini story analysis extracts and classifies entities.
- Gemini image generation creates reviewed foreground assets: humans, animals,
  creatures, plants, and props.
- Cloudflare Workers AI creates location backgrounds.
- StoryTale removes flat backgrounds locally when needed, validates
  transparency and dimensions, then assigns the final stable asset ID.
- No generated asset becomes available to scene planning until it is approved.

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

## Preparation workflow

1. Extract chapter entities with stable source references and confidence.
2. Resolve aliases against the existing book story bible.
3. Normalize a proposed location into a specific source-backed place or keep
   the broad setting as context.
4. Automatically approve a new candidate only when every deterministic check
   passes.
5. Let the user review uncertain, conflicting, or incomplete candidates.
6. Reuse an approved asset when one already exists.
7. Generate only the missing approved masters and required states.
8. Review and register the resulting asset IDs in the story bible.
9. Run Gemini scene planning with the updated approved catalog.
10. Validate that every visible layer matches its referenced entity.
11. Cache the validated chapter plan locally.

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

Still pending:

- Automatic approval for high-confidence, conflict-free entities
- Specific-location normalization and broad-setting context
- Entity-specific foreground asset generation and registration
- Generated location background catalog
- `focusAssetLayers` and entity-aware scene catalogs
- Replacing prototype actors in the final player

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
