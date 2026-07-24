# Story Bible Entity and Asset Plan

**Status: planned next; the current player still uses prototype actors.**

## Purpose

StoryTale must understand what a story subject is before choosing an image.
A human actor must never stand in for a flower, animal, creature, or object just
because that is the only available sprite.

```text
Cleaned chapter blocks
-> Gemini entity extraction
-> merge candidates into the book story bible
-> review important or uncertain entities
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
| `location` | small planet, forest, castle | Reusable Cloudflare background variants |

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
- approved
- lockedAppearance
- assetIds
- unresolvedNotes
```

Aliases always resolve to the same `entityId`. A later volume may add a new
alias, relationship, outfit, age state, or object state, but it cannot silently
replace an approved design.

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

## Preparation workflow

1. Extract chapter entities with stable source references and confidence.
2. Resolve aliases against the existing book story bible.
3. Add genuinely new items as candidates, not approved assets.
4. Let the user review uncertain, recurring, or important candidates.
5. Reuse an approved asset when one already exists.
6. Generate only the missing approved masters and required states.
7. Register the resulting IDs in the story bible.
8. Run Gemini scene planning with the updated approved catalog.
9. Validate that every visible layer matches its referenced entity.
10. Cache the validated chapter plan locally.

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

