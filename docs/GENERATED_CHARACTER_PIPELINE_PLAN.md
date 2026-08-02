# StoryTale Locked-Template Character Pipeline Plan

This is the authoritative plan for turning one approved book character into a
reusable Sprite Studio package for Animated Story Mode.

Status: **Planning correction complete. Phase 7G proved the package structure,
but its visual-fidelity gate failed. Phase 7G.1, the locked-template layered
composer, is current. Phase 7G.1A completed the actor hair and local skin-tone
foundation. Phase 7G.1A.1 appearance-default persistence is next, followed by
Phase 7G.1B generated appearance layers. Phase 7H Story Mode binding must wait
for the complete Phase 7G.1 gate.**

## 1. Decision

StoryTale will no longer ask Gemini to redraw a complete head and body.

The existing `humanoid_v1` head shape, body parts, joints, proportions, and
poses are immutable local assets. Gemini may create only transparent visual
layers that fit those assets:

- paired eyes and eyebrows;
- one nose;
- mouths and optional face details;
- front hair and back hair;
- clothing overlays attached to the matching body parts;
- optional garment extension layers;
- head, face, front, back, and held accessories; and
- story-supported weapons, tools, books, flowers, and other held props.

The result is a Gacha-style character assembled locally. It is not a generated
full-body picture that StoryTale tries to cut apart afterward.

## 2. What the current Phase 7G result actually does

The current implementation:

1. creates a source-backed design brief;
2. sends blank geometry references through the private Cloudflare Worker;
3. asks Gemini for one finished full-body character master;
4. removes the flat background locally;
5. normalizes that master to the canonical canvas;
6. divides the generated pixels into ten template-shaped regions;
7. overlays the selected modular face locally; and
8. renders the resulting regions with Sprite Studio pose transforms.

The ten output files are derived from one generated picture. They are not ten
independently designed parts, and the AI is still free to invent a different
skull, face area, torso silhouette, limbs, hair, and outfit before the local
split happens.

This explains why the current Little Prince preview looks like a separate
chibi illustration rather than the supplied Sprite Studio base. Local cropping
cannot restore the original geometry after Gemini has already redrawn it.

Phase 7G therefore proved that generation, local processing, package loading,
proof views, and poses can be connected. It did **not** prove exact visual
compatibility with the locked template.

## 3. Non-negotiable result

A generated human is ready only when:

- the canonical local head silhouette is unchanged;
- the canonical ten total rig-part silhouettes (one head plus nine body
  pieces) and joint pivots are unchanged;
- poses are reusable transform JSON, not generated pose pictures;
- expressions replace only aligned eyes, nose, mouth, and detail layers;
- hair, clothing, and accessories are separate assets;
- the same package is reused in every chapter and later volume;
- Story Mode can change expression, pose, facing, scale, and movement without
  another image-generation call; and
- no unrelated starter actor is substituted when a package is missing.

V1 supports the approved `humanoid_v1` chibi template. A future child, adult,
elder, or other body template must be a separately approved local rig with its
own geometry hash. Gemini must never invent a new runtime body template.

## 4. Locked local geometry

The following assets are owned by StoryTale and are never generated:

```text
humanoid_v1
|-- head
|-- torso
|-- upper_arm_left
|-- lower_arm_left
|-- upper_arm_right
|-- lower_arm_right
|-- upper_leg_left
|-- lower_leg_left
|-- upper_leg_right
`-- lower_leg_right
```

The visual alignment reference is
`docs/ui-concepts/ui/character_full_body_perfect_placement.png`. The actual
runtime authority is the extracted `humanoid_v1/base/` rig plus its masks,
anchors, and geometry hash. Gemini may receive fixed guides made from those
assets, but it must never reinterpret, enlarge, shrink, replace, or redraw
their silhouettes.

Each part keeps:

- its canonical alpha silhouette;
- original canvas position;
- parent part;
- pivot and attachment anchors;
- allowed rotation range;
- neutral transform;
- fixed anatomical layer policy; and
- a versioned geometry hash.

Skin tone is applied locally through rig-owned skin masks. It does not require
Gemini to redraw the body and does not spend a Gemini or Cloudflare request.

The first version provides a dropper-style color picker with a
saturation/value area, hue control, current-color swatch, hex field, and
Reset. Presets are shortcuts only: any valid opaque `#RRGGBB` color is allowed.
The chosen color is composited only through the head and nine body-part skin
masks. Original alpha, black outlines, soft shading, and joint edges remain
visible. Hair, face details, eye whites, pupil highlights, clothing, and
accessories are outside the skin masks and are never recolored by this control.

Skin tone belongs to the character appearance, not to a pose. Idle, Talking,
Pointing, Walking, every custom pose, and every chapter therefore share one
saved value. An invalid or missing value uses the selected actor's default
tone.

## 5. Character-specific visual layers

One character package combines the locked rig with these replaceable layers.

### 5.1 Face

The fixed head base remains visible. A character-specific face contains:

```text
paired eyes and eyebrows
+ one nose
+ one mouth
+ optional details
```

Required first-version assets:

- eyes/brows: Neutral, Happy, Sad, Angry, Surprised;
- nose: Default;
- mouths: Neutral, Talking, Smile, Sad, Angry Teeth; and
- optional reusable details: blush, wrinkles, scar, facial hair, freckles, or
  makeup only when supported by the story.

The six composed face sets are Neutral, Talking, Happy, Sad, Angry, and
Surprised. Talking reuses Neutral eyes and changes only the mouth unless a
strong emotion is active.

Paired eyes remain one image so spacing, gaze, white eye areas, pupils, and
highlights cannot drift independently. Face PNGs never include the head fill,
ear, hair, neck, or body.

### 5.2 Hair

Every hairstyle starts with two layers:

- `hair_back`: behind the head and body; long hair may extend down behind the
  torso; and
- `hair_front`: fringe, bangs, and front side locks above the face.

Both layers share the same head anchor and locked canvas. Optional
`hair_side` or `hair_tail` layers may be added later only when one back layer
cannot move correctly.

The five starter actor profiles each receive one complete default hairstyle:

- `default`;
- `hero`;
- `heroine`;
- `elder`; and
- `adult`.

An actor hairstyle is one catalog item containing both its fitted
`hair_front` and `hair_back` IDs. Selecting a hairstyle always switches the
pair together so a front from one design cannot accidentally use the back from
another. The current Short, Medium, and Long back-hair parts remain shared
alignment references and optional reusable choices; they are not substitutes
for the five complete actor hairstyle pairs.

Actor profiles do not create new body geometry. They provide a default face
profile, default hairstyle ID, and default skin tone for the same locked
`humanoid_v1` rig. A book character may start from one actor profile and then
store its own approved hairstyle and skin tone without changing that actor's
catalog.

### 5.3 Clothing

Fitted clothing is generated as an overlay for each matching body part:

```text
torso
upper_arm_left
lower_arm_left
upper_arm_right
lower_arm_right
upper_leg_left
lower_leg_left
upper_leg_right
lower_leg_right
```

Every overlay inherits its body part's transform and pivot. Rotating an arm
therefore rotates its sleeve and glove with it. Boots belong to the matching
lower-leg overlays.

Clothes may not replace the body silhouette. StoryTale clips fitted overlays
to the approved part mask plus a small documented seam allowance.

Loose silhouettes that cannot follow one limb use optional torso- or hip-
anchored extensions:

- `outfit_back`: cape, coat tails, long skirt back, or robe back;
- `outfit_front`: long skirt front, coat front, sash, or apron; and
- `body_front`: belt, badge, necklace, or chest decoration.

This prevents a cape or skirt from being incorrectly baked into an arm or leg.

### 5.4 Accessories and held items

Supported accessory groups:

- head: clips, headbands, hats, crowns, helmets;
- face: glasses, masks, eye patches;
- body back: cape, sheath, backpack, wings;
- body front: badge, necklace, belt detail, pouch;
- held item: sword, staff, gun, book, flower, shield, tool, or other
  source-supported prop; and
- optional effect: glow or simple impact mark, handled separately from the
  permanent character identity.

An accessory is generated only when the book supports it. It is not baked into
the head, body, hair, or pose.

## 6. Stable layer stack

Sprite Studio keeps anatomical ordering locked and exposes only approved
accessory slots. Back-to-front rendering is:

1. rear body accessory;
2. back hair;
3. back-side legs with their clothing overlays;
4. back-side arms with their clothing overlays;
5. torso base, torso clothing, and outfit-back/front extensions;
6. front-side legs with their clothing overlays;
7. held item in a behind-body or behind-gripping-arm slot;
8. front-side arms with their clothing overlays;
9. fixed head base;
10. face details, paired eyes/brows, nose, and mouth;
11. face accessory;
12. front hair;
13. head accessory;
14. held-item front or grip overlay; and
15. temporary effects.

The existing rule remains: right limbs render in front of matching left limbs
and upper arms render in front of lower legs. Mirroring flips the complete
character, not the semantic part IDs.

Clothing is a child visual of its body part, not a freely reordered rig part.
This keeps the sleeve, pants leg, glove, and boot attached during every pose.

## 7. Held-item attachment contract

Every held item stores:

- stable accessory and asset IDs;
- `hand_left` or `hand_right` anchor;
- grip pivot;
- X/Y offset;
- scale and rotation offset;
- optional pose-specific transform;
- named layer mode; and
- optional `grip_overlay` for fingers drawn above the handle.

Approved V1 layer modes:

- `behind_character`;
- `behind_gripping_chain` - behind the selected upper arm, lower arm, and
  hand, useful for a sword or staff;
- `behind_hand`;
- `front_of_hand`; and
- `front_overlay`.

Named modes are used instead of arbitrary global layer numbers. A sword can be
behind the right upper/lower arm while a small grip overlay appears above the
hand, making it look held. Two-handed grips are a later optional extension.

## 8. Catalog-first generation

StoryTale first searches an approved local catalog, then generates only a
missing visual layer.

The starter catalog should contain a small set of approved examples:

- face styles for Default, Hero, Heroine, Elder, and Adult;
- three to five front/back hairstyle examples per broad style;
- three to five clothing overlay sheets for common story roles;
- common head and face accessories; and
- common held props such as a book, flower, sword, staff, and shield.

The analyzer may select, recolor, or combine compatible approved layers.
Gemini is used when the Story Bible requires a design that the catalog cannot
represent.

Many uncontrolled sample images are not required. A curated set of three to
five approved examples per asset category is more useful because every sample
has already passed the same canvas, anchor, alpha, and layer rules.

## 9. Gemini asset requests

Gemini receives:

1. the locked character design brief;
2. the exact blank component guide or mask;
3. the closest approved style sample; and
4. only the story-supported details for that component.

It never receives permission to redesign the base head or body.

To control cost and alignment, V1 uses fixed-layout component sheets:

1. face-expression sheet for five eyes/brows, five mouths, and one nose;
2. hair sheet with one back-hair and one front-hair slot;
3. one clothing-only sheet aligned to the locked head-plus-nine-parts guide;
   the head is reference-only and the nine body slots contain only fitted
   garment pixels; and
4. accessory sheet only when the story requires accessories.

StoryTale splits each accepted sheet locally by one versioned crop manifest,
then applies canonical allowed/protected masks. The clothing sheet must retain
the guide's exact dimensions, arrangement, left/right ownership, and pure
green background. Gemini may not output another assembled body. This uses
about three core Gemini image calls per human, plus one optional accessory
call, rather than generating dozens of independent images.

If a sheet format proves less consistent than separate edits, the same
contract may use one call per component group. It may not fall back to a
complete generated head or body.

There is:

- no automatic regeneration loop;
- no regeneration after refresh;
- no per-chapter human generation;
- no image call merely to change pose or expression; and
- no hidden replacement of one character with another.

An invalid paid result is marked `Needs attention`. Review remains read-only
for normal users. A future project-owner repair action may be hidden behind the
existing development/admin flag.

## 10. Cloudflare and Gemini boundary

For character assets:

```text
Flutter
-> private Cloudflare Worker
-> Gemini image API
-> raw generated component sheet
-> local split, mask, validation, composition, and storage
```

Cloudflare does not design or redraw the character. It is the secure server-side
gateway that keeps the Gemini key out of the Flutter application, validates the
request, and forwards it to Gemini. Google recommends a backend proxy for
client applications because an API key embedded in web or mobile code can be
extracted.

Cloudflare Workers AI remains the generator for location backgrounds. Gemini
remains the generator for character component sheets.

The current Worker's shared `IMAGE_RATE_LIMIT` is configured by StoryTale at
three requests per 60 seconds, and the Flutter volume-preparation coordinator
adds another local three-artwork-requests-per-60-seconds gate. These are
application-defined limits, not required Gemini or Cloudflare image limits.
Phase 7G.1 will:

- remove or disable both small private sprite-component gates;
- allow one in-flight request per preparation job;
- queue remaining components sequentially;
- deduplicate by character design hash, template version, and component type;
- resume at the first missing component without repaying for completed work;
  and
- surface the real Gemini quota or billing error instead of replacing it with
  a generic Cloudflare message.

One-at-a-time generation is a reliability and duplicate-cost rule, not an
artificial per-minute quota.

No hosted route is literally unlimited. The Cloudflare account still has its
plan quotas, and Gemini enforces project/model RPM, IPM, daily, and spend-based
limits. StoryTale will not add another small shared bottleneck on top of those
provider limits.

Current official references:

- Cloudflare Workers limits:
  https://developers.cloudflare.com/workers/platform/limits/
- Cloudflare Rate Limiting binding:
  https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
- Gemini API rate limits:
  https://ai.google.dev/gemini-api/docs/rate-limits
- Gemini API key security:
  https://ai.google.dev/gemini-api/docs/api-key

## 11. Folder contract

The locked geometry stays shared. A book character stores only its appearance
layers and metadata:

```text
assets/images/characters/rigs/humanoid_v1/
|-- rig.json
|-- base/
|   |-- head.png
|   |-- torso.png
|   `-- <eight canonical limb PNGs>
|-- masks/
|-- anchors.json
`-- poses/
    |-- idle.json
    |-- talking.json
    |-- pointing.json
    `-- walking.json

assets/images/characters/actor_appearances/
|-- catalog.json
|-- default/
|   |-- appearance.json
|   `-- hair/<style-id>/{front.png,back.png}
|-- hero/
|   |-- appearance.json
|   `-- hair/<style-id>/{front.png,back.png}
|-- heroine/
|   |-- appearance.json
|   `-- hair/<style-id>/{front.png,back.png}
|-- elder/
|   |-- appearance.json
|   `-- hair/<style-id>/{front.png,back.png}
`-- adult/
    |-- appearance.json
    `-- hair/<style-id>/{front.png,back.png}

books/<book-id>/story-bible/characters/<character-id>/
|-- character-design.json
|-- appearance-manifest.json
|-- generation-trace.json
|-- face/
|   |-- eyes/
|   |-- noses/
|   |-- mouths/
|   |-- details/
|   `-- sets.json
|-- hair/
|   |-- back.png
|   `-- front.png
|-- outfits/<outfit-id>/
|   |-- parts/
|   |   |-- torso.png
|   |   `-- <eight canonical limb overlays>
|   |-- outfit-back.png
|   |-- outfit-front.png
|   `-- body-front.png
|-- accessories/
|   |-- head/
|   |-- face/
|   |-- body-back/
|   |-- body-front/
|   |-- held/
|   `-- attachments.json
`-- previews/
    |-- neutral.png
    |-- talking.png
    |-- pointing.png
    `-- walking.png
```

There is no generated `head.png`, `torso.png`, or generated base-limb folder in
the character package. Those IDs always resolve to the locked shared rig.

## 12. Small data contract

```json
{
  "characterId": "little_prince",
  "template": {
    "rigId": "humanoid_v1",
    "version": 2,
    "geometryHash": "locked"
  },
  "appearance": {
    "skinTone": "#F2D2B6",
    "actorProfileId": "hero",
    "hairStyleId": "hair.hero.default",
    "faceProfileId": "face.little_prince",
    "hairBackId": "hair.little_prince.back",
    "hairFrontId": "hair.little_prince.front",
    "clothingByPart": {
      "torso": "outfit.little_prince.torso"
    },
    "extensionLayerIds": [],
    "accessoryIds": []
  },
  "poseIds": ["idle", "talking", "pointing", "walking"],
  "validationStatus": "ready"
}
```

One attachment example:

```json
{
  "id": "sword",
  "anchorPartId": "lower_arm_right",
  "gripPivot": [0.45, 0.25],
  "rotationOffset": 0,
  "scale": 1,
  "layerMode": "behind_gripping_chain",
  "gripOverlayId": "sword.right_hand_grip"
}
```

## 13. Preparation progress and reuse

The existing volume-preparation screen remains minimal. Character preparation
reports these steps:

1. Lock character brief.
2. Select compatible base rig and catalog layers.
3. Prepare face components.
4. Prepare front/back hair.
5. Prepare clothing overlays.
6. Prepare required accessories.
7. Split and mask generated sheets.
8. Validate six faces and four poses.
9. Save the locked character package.
10. Register the stable IDs for later chapter binding.

Each completed step is cached by design hash. Closing the screen or losing the
connection resumes from the first unfinished step. The same assets are reused
throughout the book and later volumes.

## 14. Validation gate

A package is `Ready` only when:

- the expected rig ID, template version, and geometry hash match;
- the canonical head and body alpha masks are unchanged;
- generated face files contain no replacement skull, ear, head fill, hair, or
  body;
- face landmarks stay inside the approved position tolerance;
- eye whites and pupil highlights remain opaque;
- front/back hair align with the fixed head and do not cover forbidden face
  zones;
- every fitted clothing overlay matches its body-part mask and seam allowance;
- loose garments use approved extension layers rather than malformed limbs;
- all accessory anchors and named layer modes resolve;
- held items remain attached in Idle, Talking, Pointing, and Walking;
- all six face sets compose without shifting;
- all four pose previews remain inside bounds without exposed seams;
- no output contains scenery, text, extra people, duplicate limbs, or a
  generated replacement body; and
- every stable asset ID resolves to bytes.

If any check fails, StoryTale keeps the character out of Story Mode and uses
subtitles/audio or a source-appropriate no-character shot. It does not
automatically spend another API call.

## 15. Proof view

Book Characters remains read-only and gains these compact proof groups:

1. **Character** - locally composed Neutral preview;
2. **Layers** - face, hair, clothing, and accessories grouped by type;
3. **Faces** - six composed expressions;
4. **Poses** - Idle, Talking, Pointing, and Walking; and
5. **Details** - template ID/version/hash, Gemini model, generation trace,
   source-backed design brief, and validation result.

`Open in Sprite Studio` loads the same composed package. The preview must not
show a separate AI-created full-body master as the runtime character.

## 16. Roadmap order

### Phase 7G - Structural prototype

Status: **Implemented, but visual-fidelity gate failed.**

It proved one Gemini call, local transparency processing, canonical package
IDs, proof pages, Sprite Studio loading, and pose rendering. Its whole-character
master and post-generation splitting are now superseded.

### Phase 7G.1 - Locked-template layered composer

Status: **Current.**

Implementation order:

1. Freeze and version the canonical rig, alpha masks, anchors, and geometry
   hash.
2. **Phase 7G.1A:** add the five actor appearance records, fitted front hair,
   optional fitted back hair, and a default skin tone for Default, Hero,
   Heroine, Elder, and Adult.
3. **Phase 7G.1A:** add per-part skin masks, local RGB/hex tint composition,
   compact Actor/Hair/Skin controls, appearance persistence, and neutral
   fallbacks.
4. **Phase 7G.1A.1:** persist explicit no-back-hair selection and universal
   per-actor/per-style hair fits without deleting catalog choices.
5. Add the appearance-manifest and named layer/attachment contracts.
6. Approve and version `clothing_sheet_v1` with exact crop rectangles,
   allowed/protected masks, joint overlap, and anchors.
7. Change sprite generation from `master` to face, hair, clothing-only, and
   optional accessory component sheets.
8. Remove green, split by the fixed manifest, and hard-mask every component
   locally.
9. Compose the fixed base plus appearance layers in the normal Sprite Studio
   renderer.
10. Add the held-item anchor and approved relative layer modes.
11. Add preparation progress, design-hash reuse, and no-duplicate generation.
12. Remove or disable the private sprite route's shared three-per-minute
   StoryTale limiter while retaining sequential requests and provider errors.
13. Prove one Little Prince package matches the exact StoryTale head/body
   template in all six faces and four poses.
14. Mark the package ready only after every validation check passes.

### Phase 7H - Story Mode binding

Status: **Blocked by Phase 7G.1.**

After a package is ready:

1. register its character, rig-template, face-set, outfit, hair, accessory,
   attachment, pose, and asset IDs in the Story Bible;
2. invalidate ChapterStory data made before those IDs became ready;
3. rebuild every affected chapter, not only Chapter 1;
4. require the correct ready human when that human speaks or acts;
5. resolve face, pose, held item, facing, scale, and movement per beat;
6. use the same character's Neutral fallback when an optional face or pose is
   missing; and
7. prove a later chapter reuses the same appearance without another Gemini
   character call.

Durable files across full app restarts remain Phase 8.

## 17. Acceptance checklist

- [ ] Gemini is never asked for a replacement head or body.
- [ ] The original ten StoryTale rig geometries (one head plus nine body
  pieces) are byte/hash locked.
- [ ] A character changes through face, hair, clothing, tint, and accessory
  layers only.
- [ ] Default, Hero, Heroine, Elder, and Adult each have stable default front
  hair, an optional back-hair selection including `None`, and a default skin
  tone.
- [ ] The skin picker accepts any valid opaque RGB/hex color and recolors only
  approved skin-mask pixels without an image-generation request.
- [ ] Hair style and skin tone are appearance data shared by every pose,
  chapter, and later volume rather than duplicated pose data.
- [ ] An actor may save `None` as its back-hair default while all back-hair
  catalog assets remain available for other appearances.
- [ ] Front and back hair are separate and long back hair can extend behind the
  torso.
- [ ] Eyes/brows, nose, mouths, and details remain separately selectable.
- [ ] Clothing follows every rotated body part.
- [ ] The clothing sheet keeps the canonical size and arrangement, leaves its
  head cell empty, and is split locally by fixed rectangles.
- [ ] Loose garments use extension layers.
- [ ] Head, face, front, back, and held accessories have explicit anchors.
- [ ] A held sword can render behind the right arm with a grip overlay above
  the hand.
- [ ] Idle, Talking, Pointing, and Walking use transform JSON only.
- [ ] The app resumes missing components without generating completed ones
  again.
- [ ] Normal users see read-only results with no regenerate/replace controls.
- [ ] The private Worker does not impose the current shared three-per-minute
  sprite bottleneck.
- [ ] Provider quota and billing errors remain visible and no system claims
  unlimited external capacity.
- [ ] Book Characters proves Layers, Faces, and Poses on the locked template.
- [ ] Phase 7H does not start until the Little Prince proof passes.
