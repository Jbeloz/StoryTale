# StoryTale Generated Character Pipeline Plan

This plan defines how an analyzed book character becomes one reusable,
Sprite Studio-compatible character package for Animated Story Mode.

Status: **Phase 7G implemented. Phase 7H Story Mode binding is current.**

## 1. Why Phase 7G was required

The earlier Phase 7 prototype proved that StoryTale could call Gemini, remove a
green background, save stable IDs, and display one generated full-body image.
It did not by itself prove that the image was a usable generated rig.

The Phase 7G audit identified these specific gaps:

- The supplied `approved-head.png` and `approved-body.png` references already
  contain a brown-haired face and a navy/yellow outfit. Gemini follows those
  designs instead of receiving a blank Sprite Studio geometry template.
- Gemini creates one complete character image. It does not create the separate
  Sprite Studio head, torso, upper/lower arms, and upper/lower legs.
- The local splitter assigns pixels through broad rectangular X/Y regions.
  Pixel-perfect rejoining succeeds by construction, but it does not prove that
  each file contains the correct anatomical part.
- Generated part IDs and metadata do not yet use the exact runtime
  `SpriteRigDefinition` contract loaded by Sprite Studio.
- The generated head has one baked face. Character-specific eyes, nose, mouth,
  details, and reusable face sets are not produced.
- Talking, Pointing, and Walking are advertised in metadata but rendered by a
  separate hard-coded preview widget rather than the same pose JSON used by
  Sprite Studio.
- Book Characters shows only the master image. It cannot prove the separate
  parts, face changes, or pose changes.
- Chapter analysis happens before human generation, and only Chapter 1 receives
  a later connection pass. A fallback or stale story with no matching
  character layer therefore remains empty in Story Mode.
- Generated image bytes are session-only until Phase 8, so a refresh or restart
  can leave ready metadata without renderable character images.

Before Phase 7G, `Ready` meant **bytes exist**, not **the generated character is
ready for Sprite Studio**. Phase 7G resolves the character-package, validation,
proof, and Sprite Studio-loading gaps. Phase 7H intentionally owns the remaining
ChapterStory rebuild and Story Mode binding work. Durable generated-image storage
remains Phase 8.

## 2. Required result

Every important approved human receives one locked character package:

```text
books/<book-id>/characters/<character-id>/
|-- character-design.json
|-- manifest.json
|-- master/
|   `-- neutral-transparent.png
|-- rig/
|   |-- rig.json
|   `-- parts/
|       |-- head.png
|       |-- torso.png
|       |-- upper_arm_left.png
|       |-- lower_arm_left.png
|       |-- upper_arm_right.png
|       |-- lower_arm_right.png
|       |-- upper_leg_left.png
|       |-- lower_leg_left.png
|       |-- upper_leg_right.png
|       `-- lower_leg_right.png
|-- faces/
|   |-- profile.json
|   |-- head_base.png
|   |-- eyes/
|   |-- noses/
|   |-- mouths/
|   |-- details/
|   `-- sets.json
|-- poses/
|   |-- neutral.json
|   |-- talking.json
|   |-- pointing.json
|   `-- walking.json
`-- previews/
    |-- neutral.png
    |-- talking.png
    |-- pointing.png
    `-- walking.png
```

The same package is reused in every chapter and later volume. Poses are local
joint transforms; Gemini is never called again merely to make the character
talk, point, or walk.

## 3. Provider boundary

- Gemini `gemini-3.1-flash-image` creates character artwork.
- The private Cloudflare Worker is only the secure gateway that keeps the
  Gemini key out of Flutter.
- Cloudflare Workers AI continues to create landscape backgrounds, not human
  sprites.
- Automated tests use fake image responses and never spend Gemini quota.
- A valid first result is accepted once. There is no automatic retry loop.

The current code already routes `kind=sprite` to Gemini. The implementation
must preserve that route while changing the reference packet, generation
contract, validation, and runtime integration.

## 4. Phase 7G - Template-constrained character package

Status: **Implemented.** The locked design brief, blank reference packet,
Gemini master generation, local transparency cleanup, ten canonical parts,
runtime rig definition, modular face package, four canonical pose previews,
readiness validation, Book Characters proof views, and Sprite Studio loading
are now connected as one package.

### 4.1 Lock the design brief

Create one `CharacterDesignBrief` from the approved Story Bible entry:

- stable book and character IDs;
- age group, presentation, role, and selected actor profile;
- source-backed face, hair, skin, body, outfit, palette, and accessories;
- details that must remain consistent across chapters and volumes;
- forbidden details that Gemini must not invent; and
- selected voice ID, stored separately from visual appearance.

The brief is locked after successful generation. A later chapter may add an
alias or relationship, but it cannot silently redesign the character.

### 4.2 Replace the styled references

Create a geometry-only reference packet from the real Sprite Studio template:

1. blank assembled neutral humanoid;
2. blank aligned head base;
3. separated part/anchor guide;
4. simple StoryTale line and shading style guide.

Do not use a reference that already contains another character's hair, face,
or outfit. Gemini may change identity, hair, colors, clothes, and required
accessories while preserving the exact front-facing body proportions, canvas,
joint locations, and neutral stance.

### 4.3 Generate one neutral design master

Gemini receives the locked design brief and geometry-only references. It
returns exactly one complete front-facing neutral character on flat chroma
green with:

- the custom head, hair, skin, and identity;
- the complete outfit applied consistently across torso and limbs;
- both hands and feet visible;
- no scenery, shadow, text, extra subject, crop, or alternate pose; and
- the required Sprite Studio proportions and neutral joint alignment.

StoryTale removes only edge-connected green pixels locally.

### 4.4 Extract real rig parts

Replace broad rectangular splitting with template-aware masks and overlap
zones. The processor must:

- use the exact canonical part IDs listed in section 2;
- extract the correct anatomy and clothing for every part;
- preserve small hidden overlaps at shoulders, elbows, hips, and knees so
  rotation does not reveal holes;
- tightly crop each PNG while recording its original canvas position;
- store parent, pivot, size, rotation range, and fixed layer order in a real
  `rig.json`; and
- create the neutral composite through the normal Sprite Studio renderer.

The approved neutral composite must match the approved master within the
documented seam tolerance. Pixel-perfect equality alone is not enough.

### 4.5 Create the modular face package

The custom head must use the same face-layer contract as Sprite Studio:

```text
head base + eyes/eyebrows + nose + mouth + optional details
```

Required first-version sets:

- Neutral
- Talking
- Happy
- Sad
- Angry
- Surprised

Every generated face part keeps the exact character head canvas, eye spacing,
feature positions, line thickness, and transparent alignment. Talking changes
the mouth without replacing strong emotional eyes. A chosen starter actor
profile may guide the style, but the saved face assets belong to the book
character and must not show the starter actor's identity.

### 4.6 Reuse approved poses

The generated rig loads the same semantic pose contract as Sprite Studio:

- Idle/Neutral
- Talking
- Pointing
- Walking

The pose files contain transforms only. They do not contain generated images.
Generated characters must render through `SpriteRigView`, the normal rig
loader, the normal pose repository, and the normal modular-face compositor.
The separate hard-coded generated-human renderer is removed after migration.

## 5. Readiness validation

Status: **Implemented for the Phase 7G package gate.**

A generated character is `Ready` only when all checks pass:

- master decodes, has transparency, and uses the expected canvas;
- all ten canonical part files decode and contain visible pixels;
- every part overlaps its expected anatomical mask;
- no part is empty, swapped, clipped, or mostly occupied by another part;
- pivots and parent joints fall inside the allowed visible/overlap area;
- neutral reassembly has no missing clothing, exposed seams, or shifted parts;
- face layers use the correct canvas and preserve opaque eye whites and pupil
  highlights;
- all six face sets visibly differ where expected and remain aligned;
- all four pose composites render inside bounds and visibly differ from the
  neutral pose where expected;
- generated rig and pose JSON pass the existing Sprite Studio validators; and
- all stable asset IDs resolve to real bytes.

If any check fails, the character is `Needs attention` and StoryTale keeps the
safe no-character/subtitle fallback. It must never substitute an unrelated
prototype actor.

## 6. How the result will be confirmed

Status: **Implemented in Book Characters and Sprite Studio.**

Book Characters remains simple, but each character card gains four compact
views:

1. **Character** - approved neutral composite;
2. **Parts** - ten labeled transparent part thumbnails;
3. **Faces** - six composed face-set previews;
4. **Poses** - Idle, Talking, Pointing, and Walking composites.

It also shows:

- Gemini model/provider;
- rig ID and character ID;
- validation status;
- one `Open in Sprite Studio` action; and
- a short failure reason when a required part is invalid.

This is the required way to confirm that poses and faces exist. The current
single master preview cannot provide that proof.

## 7. Phase 7H - Story Mode binding proof

Status: **Current next phase.** This work was intentionally not folded into
Phase 7G.

After a character passes Phase 7G:

1. Register its real `characterId`, `rigId`, face profile/set IDs, pose IDs,
   outfit ID, asset IDs, and appearance lock in the Story Bible.
2. Invalidate any cached ChapterStory made before that character became ready.
3. Run the final catalog-constrained scene analysis and asset connection for
   every chapter, not only Chapter 1.
4. Map source-supported humans to their real generated IDs. Do not keep
   `default_actor`, `hero_actor`, or another unrelated starter actor.
5. Require a character layer when a ready human is the speaker or is performing
   a source-backed action. Environment-only and object-detail shots may
   intentionally contain no human.
6. Resolve the requested pose and face set through the same Sprite Studio
   repositories.
7. On each beat, apply the talking mouth to the active speaker while retaining
   strong emotional eyes.
8. If a requested pose or face is missing, use that same character's Neutral
   fallback. Hide only an invalid character.
9. Prove Chapter 1 renders the generated character, then prove a later chapter
   reuses the same locked identity without another Gemini character call.

## 8. Implementation order

1. [x] Correct the reference packet and canonical IDs.
2. [x] Add the character design brief and manifest contracts.
3. [x] Replace rectangular splitting with template-aware extraction and a real
   runtime rig exporter.
4. [x] Add modular generated face assets and sets.
5. [x] Route generated rigs through the normal Sprite Studio renderer.
6. [x] Add Parts, Faces, and Poses proof views to Book Characters.
7. [x] Strengthen readiness validation and quota-free tests.
8. [ ] **Phase 7H:** rebuild and reconnect every affected ChapterStory.
9. [ ] **Phase 7H:** prove generated-character playback in Chapter 1 and reuse
   in a later chapter.
10. [ ] **Phase 8:** add durable storage so the approved package survives
    refreshes and restarts.

## 9. Acceptance checklist

- [x] Gemini receives blank geometry references instead of a predesigned
  brown-haired character.
- [x] The result keeps the StoryTale template proportions but has the
  source-backed book character's own head, hair, outfit, and palette.
- [x] All ten canonical Sprite Studio parts are present and validated.
- [x] The generated runtime rig definition loads in Sprite Studio without a
  special renderer.
- [x] Six aligned modular face sets render on the custom head.
- [x] Idle, Talking, Pointing, and Walking previews visibly work.
- [x] Book Characters exposes the neutral, parts, faces, and poses proof.
- [x] The exact generated rig opens in Sprite Studio.
- [ ] Chapter 1 displays the generated character when the source requires it.
- [ ] A later chapter reuses the same identity and asset IDs.
- [ ] No fallback substitutes an unrelated starter actor.
- [x] Automated validation makes no external Gemini or Cloudflare image calls.
