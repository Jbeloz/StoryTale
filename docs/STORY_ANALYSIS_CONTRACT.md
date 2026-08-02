# StoryTale Story Analysis Contract

## Purpose

Gemini plans a chapter, but Flutter owns every screen, coordinate, animation,
duration, and safety limit.

```text
EPUB blocks + approved catalog
-> private Cloudflare Worker /analyze
-> Gemini JSON Schema output
-> Worker semantic validation
-> Flutter semantic validation
-> ChapterStoryData
-> existing Animated Story Mode
```

## Input

One request contains:

- one chapter ID and title;
- stable, ordered source blocks;
- approved characters and their character-package, rig-template, pose,
  face-profile, face-set, front/back hair, clothing-by-part, accessory,
  held-item, and attachment IDs;
- approved animals, creatures, plants, and prop assets in the next contract
  revision;
- approved location IDs and their available background-state IDs;
- the fixed StoryTale layout, camera, transition, staging, and movement IDs.

Gemini never receives permission to invent an asset ID or control raw pixels,
joint coordinates, anatomical layer order, attachment offsets, grip pivots,
timing, easing, zoom, scale values, depth values, or movement distance.
During asset planning, Gemini may return a source-backed semantic appearance
brief such as garment type, palette, material, hair description, and required
accessories. It never returns sheet dimensions, crop rectangles, masks, pivots,
or per-part placement; those come from the versioned StoryTale template.

For a human layer, Gemini returns approved semantic IDs only:

```text
characterId
characterPackageId
rigTemplateId
poseId
faceProfileId
faceSetId
hairBackId
hairFrontId
clothingByPart IDs
accessoryIds
optional heldItemId and attachmentId
stagePositionId
facingId
scaleId
depthId
movementId
```

Flutter resolves all coordinates, transforms, relative layer modes, and
attachment data from the locked rig and approved package records.

## Output rules

- Preserve every source block without translation, summary, rewriting,
  duplication, omission, or reordering.
- A long block may become several short subtitle beats, but all segments keep
  the same source-block ID and must rejoin to the original text.
- Show at most three approved characters.
- Use inward-facing characters for normal conversations.
- Keep at least half the shots on a static camera.
- Do not use moving cameras more than twice in a row.
- Do not repeat identical framing more than twice in a row.
- Use an empty background or detail cutaway when the catalog has no safe pose.
- Never substitute an unrelated human for an animal, creature, plant, or prop.
- Use only compatible IDs owned by the same approved character package and
  locked rig template.
- A held item must use an approved attachment ID and named layer mode; Gemini
  must not describe a custom Z-order or hand offset.
- Assign each cutscene a specific source-backed location and background state.
- Include every explicit place transition in source order.
- Reuse the same background when consecutive shots stay in the same place and
  state.
- Never invent an extra place only to make the chapter look more varied.

DeepL remains the only Filipino translation provider.

## Failure behavior

StoryTale rejects the plan if either validator finds changed text, an unknown
ID, an invisible camera target, an invalid trigger beat, too many characters,
or missing source coverage. The chapter still opens with the safe local
preview plan and the preparation screen explains that fallback.

## Character-package reuse and current gate

A ready human package is prepared once per character design hash and
rig-template version. Every matching chapter and later volume receives the same
stable package, face, hair, clothing, accessory, attachment, and pose IDs.
Chapter analysis never requests a new image merely because a character appears
again.

Phase 7G proved the package-loading path, but its full-body generated master did
not preserve the StoryTale template closely enough. Phase 7G.1 replaces that
approach with fixed local head/body geometry plus one canonical separated
character sheet and optional accessory layers. StoryTale cuts the face, hair,
and clothing cells locally and reuses them for every pose. Phase 7H,
which binds book humans into
all affected ChapterStory packages, is blocked until the Phase 7G.1 visual and
structural gate passes.

See [Character Sheet V1 Plan](CHARACTER_SHEET_PLAN.md) for the
image-generation boundary that follows this semantic contract.

## Current limitation

The approved catalog is currently the five bundled prototype actors and the
bundled rose-garden background. That is why the demo may show Heroine or another
prototype beside text about a flower: the player has no approved plant/focus
asset yet. This proves the scene pipeline, not final story-to-visual accuracy.

Imported EPUB text already uses the same contract. Typed entity extraction and
persistent per-book story bibles are connected to chapter preparation.
StoryTale now automatically approves only high-confidence, source-backed
entities with no unresolved notes. Uncertain candidates stay pending and
cannot assign their own assets.

The candidate review UI now supports approval, correction, merging, and
deletion. Location extraction must return a specific background-ready place,
such as `Little Prince's home on the small planet`, rather than a broad setting
such as `Small Planet`. This is an example, not a title-specific rule. Every
imported story uses the same source-evidence checks. Broad settings remain
context or a parent setting.

Chapter analysis now stores an approved location ID and background-state ID on
every ordered cutscene. StoryTale deduplicates those pairs in first-use order
to form the chapter's background requirements. A real place or meaningful
place-state change may require another background; unchanged shots reuse the
same pair. The number of backgrounds is driven by the chapter, not fixed to one
and not padded to a target count.

Entity approval only makes a subject eligible for generation. Generated art
must pass deterministic validation and receive a stable registered asset ID
before it can enter scene planning. Normal users inspect these results in a
read-only catalog; provider retry and replacement controls stay hidden behind
the disabled developer flag.

Required `1024 x 576` visual-novel backgrounds and source-supported
animal/plant/prop foregrounds are generated, validated, registered, and
resolved by stable ID. The global current work is Phase 7G.1A.1 appearance
persistence, followed by the locked-template layered human package. Until that
package passes its face-and-pose fidelity gate and Phase 7H binds it, Story
Mode continues to use the safe prototype/fallback human path. See the
[Story Bible Entity and Asset Plan](STORY_BIBLE_ENTITY_ASSET_PLAN.md).
See the [Master Roadmap](ROADMAP.md) for the authoritative order.
