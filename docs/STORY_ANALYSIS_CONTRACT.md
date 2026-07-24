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
- approved characters and their rig, pose, face-profile, and face-set IDs;
- approved background IDs; and
- the fixed StoryTale layout, camera, transition, staging, and movement IDs.

Gemini never receives permission to invent an asset ID or control raw pixels,
joint coordinates, timing, easing, zoom, or movement distance.

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

DeepL remains the only Filipino translation provider.

## Failure behavior

StoryTale rejects the plan if either validator finds changed text, an unknown
ID, an invisible camera target, an invalid trigger beat, too many characters,
or missing source coverage. The chapter still opens with the safe local
preview plan and the preparation screen explains that fallback.

## Current limitation

The approved catalog is currently the five bundled prototype actors and the
bundled rose-garden background. Imported EPUB text already uses the same
contract, but character extraction, persistent per-book story bibles, generated
character rigs, and generated chapter background catalogs are the next work.
