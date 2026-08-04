# StoryTale Character Sheet V1, V2, and V3 Implementation Plan

Status: **Authoritative Phase 7G.1 plan. The V1 Flutter/Worker pipeline and the Phase 7G.1C enforcement are implemented locally, but no generated package has been accepted. V2 established exact Sprite Studio raster cells. Corrective Phase 7G.1B.R2 versions `character_sheet_v3`, which packs front hair plus separate Short, Medium, and Long back-hair cells into an efficient `4096 x 1024` landscape sheet. The checked-in guide uses the default actor and keeps heroine-compatible geometry. On 2026-08-04 the owner selected V3 as the future active contract. Migration, Worker changes, and a V3 provider request remain paused until the owner explicitly asks to continue.**

This document owns the exact character-sheet contract, implementation order,
validation gate, and handoff rules for Phase 7G.1B. The Master Roadmap still
owns global phase order.

## 1. Goal

StoryTale creates one coherent book character by asking Gemini to design the
appearance across a fixed sheet of separated parts. The AI must think about one
complete front-facing character, but it returns only the separated face, hair,
and clothing artwork in the approved sheet locations.

StoryTale removes the green background, cuts the fixed cells locally, protects
the immutable `humanoid_v1` anatomy, and reassembles the accepted layers into
the authoritative full-body character. The runtime never uses a separate
AI-drawn full-body master.

## 2. Locked terminology

- **Character sheet:** the one fixed-layout AI input/output containing the
  separated character-appearance regions.
- **Locked base:** the existing StoryTale head plus nine body pieces. These
  pixels, dimensions, pivots, anchors, masks, and geometry hash never change.
- **Appearance layers:** face details, front hair, optional back hair, nine
  fitted clothing overlays, and later optional accessories.
- **Assembled reference:** a local neutral mannequin composed from the locked
  rig and sent to Gemini only to explain how the separated pieces connect.
- **Full-body proof:** the character StoryTale assembles locally from the
  returned parts. It is validation output, not another generated body.

The old name `clothing_sheet_v1` is superseded by the versioned
`character_sheet_v1`, `character_sheet_v2`, and `character_sheet_v3`
contracts.

## 2A. Corrective Phase 7G.1B.R - exact Sprite Studio part contract

The native-source V1 sheet made the `1254`-pixel hair source canvases dominate
a `4096 x 4096` provider output even though Sprite Studio renders those hair
parts much smaller. V2 rasterizes the hair copies to the rig's actual render
size and uses the exact Sprite Studio canvas for every separated region:

| Region family | V2 transport cell | Runtime output |
| --- | --- | --- |
| selected back hair | `429 x 800` | `429 x 800` Sprite Studio raster |
| front hair | `429 x 438` | `429 x 438` Sprite Studio raster |
| head/face details | `357 x 367` | unchanged `357 x 367` head part |
| torso clothing | `165 x 234` | unchanged `165 x 234` torso part |
| each arm or leg piece | its exact native size | the same native canvas |

Only one `back_hair_selected` cell exists. The manifest maps
`short`, `medium`, `long`, or `none` to that slot while retaining every
original catalog asset. The source hair canvases remain unchanged, but the V2
guide and output use the same rounded raster dimensions as the rig renderer.
Every crop equals its recorded `outputCanvas`, so the future V2 processor must
not resize after extraction or alter rig geometry, pivots, anchors, or seams.

The deterministic local builder is `tool/generate_character_sheet_v2.dart`.
It creates the guide, masks, reference copy, hashes, and manifest without a
network request. Checkpoint `92e6633` marks the state immediately before this
correction. The V2 assets are review candidates only until the owner approves
the guide; runtime and Worker migration deliberately stop at that gate.

## 2B. Corrective Phase 7G.1B.R2 - efficient multi-hair catalog

V3 preserves V2's exact output canvases but changes the provider canvas to the
supported `4:1` `2K` landscape size, exactly `4096 x 1024`. This removes the
large unused lower area and restores all requested rear-hair choices in one
fixed sheet:

| Region family | V3 cells | Runtime output per cell |
| --- | --- | --- |
| back hair | separate Short, Medium, and Long cells | `429 x 800` each |
| front hair | one actor-specific cell | `429 x 438` |
| head/face details | one cell | `357 x 367` |
| torso clothing | one cell | `165 x 234` |
| arms and legs | eight separate cells | exact native Sprite Studio canvases |

The checked-in V3 guide and assembled reference use actor `default`, with
Medium as its preview selection. The manifest also records the heroine front
hair and heroine-specific Long rear-hair source. Default and heroine share the
same immutable `humanoid_v1` crop geometry, masks, anchors, seams, and runtime
part sizes; a heroine request changes only the source-backed actor brief and
actor-specific hair references.

The deterministic local builder is `tool/generate_character_sheet_v3.dart`.
It validates every cell against `rig.json`, rejects overlaps or out-of-canvas
cells, and creates the guide, masks, reference copy, hashes, and manifest
without a network request. V2 remains versioned as the exact-part checkpoint;
V3 is the owner-selected contract for the next migration, but is not yet the
active Flutter, Worker, or provider contract.

### V3 output-size and usage decision

The owner prefers `4096 x 1024` unless an officially supported smaller output
both reduces billed Gemini usage and preserves every exact native-size cell.
As checked on 2026-08-04, Gemini 3.1 Flash Image documents these `4:1` outputs:

- `1K` is `2048 x 512`;
- `2K` is `4096 x 1024`; and
- `4K` is `8192 x 2048`.

The V3 Long back-hair cell is `429 x 800`, so the `1K` canvas is only `512`
pixels tall and cannot hold the approved native cell without downscaling. That
would violate the no-post-extraction-resizing and exact Sprite Studio raster
contract. `2K` is therefore the smallest currently supported `4:1` tier that
fits the approved V3 layout. Billing is resolution-tiered and may change, so
re-check the official [Gemini image-generation dimensions](https://ai.google.dev/gemini-api/docs/image-generation)
and [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing)
immediately before any live request. Do not change tiers, repack cells, or run
a paid size experiment without renewed owner approval.

## 3. V1 source layout retained for rollback

The user-supplied `1611 x 720` PNG established the separated-parts idea, but it
scaled the hair down and omitted front hair. V1 replaced it with the assembled
repository guide at
`assets/images/characters/generation_templates/humanoid_v1/character_sheet_v1/guide.png`:

- canvas: exactly `4096 x 4096`;
- background: flat, exact `#00FF00` green with no visible cell borders;
- format: 24-bit RGB PNG;
- top row: Short, Medium, and Long back-hair cells, each preserving its native
  `1254 x 2150` canvas;
- lower-left: one front-hair cell preserving its native `1254 x 1254` canvas;
- lower-right: one head, one torso, and eight limb pieces at native size;
- orientation: front-facing, with fixed left/right ownership; and
- spacing and green padding are fixed by `crop_manifest.json`.

The three back-hair cells are reusable catalog slots. A character request
activates only its selected back-hair length; inactive alternatives stay green.
No provider or local processor may crop hair to visible pixels, resize a cell,
or move a cell inside the sheet.

## 4. Character-sheet region contract

| Region | AI may design | StoryTale accepts | Protected content |
| --- | --- | --- | --- |
| `head` | eyes, eyebrows, nose, mouth, and source-supported facial details | masked face-detail overlays | skull, ears, skin fill, head outline, and geometry |
| `torso` | shirt, armor, jacket, dress section, fabric, trim, and fitted torso details | torso clothing overlay | torso anatomy and base silhouette |
| `upper_arm_right` | fitted sleeve or armor | right upper-arm clothing overlay | arm anatomy and side ownership |
| `lower_arm_right` | sleeve continuation, glove, or bracer | right lower-arm/hand overlay | hand anatomy unless covered by an allowed glove |
| `upper_arm_left` | fitted sleeve or armor | left upper-arm clothing overlay | arm anatomy and side ownership |
| `lower_arm_left` | sleeve continuation, glove, or bracer | left lower-arm/hand overlay | hand anatomy unless covered by an allowed glove |
| `upper_leg_right` | trousers, skirt-underlay section, stocking, or armor | right upper-leg clothing overlay | leg anatomy and side ownership |
| `lower_leg_right` | trouser continuation, stocking, boot, or armor | right lower-leg/foot overlay | foot anatomy unless covered by allowed footwear |
| `upper_leg_left` | trousers, skirt-underlay section, stocking, or armor | left upper-leg clothing overlay | leg anatomy and side ownership |
| `lower_leg_left` | trouser continuation, stocking, boot, or armor | left lower-leg/foot overlay | foot anatomy unless covered by allowed footwear |
| `front_hair` | the character's front hairstyle and color | independent front-hair PNG | face-safe and slot boundaries |
| `back_hair` | optional rear hairstyle and color | independent back-hair PNG or explicit `None` | body-safe and slot boundaries |
| green gaps | nothing | nothing | every protected gap must remain green |

The AI may design the whole appearance coherently, but it may not add an
assembled body, scenery, text, labels, extra parts, or another person anywhere
on the returned sheet.

## 5. Canonical project files

```text
assets/images/characters/generation_templates/humanoid_v1/character_sheet_v1/
|-- guide.png
|-- assembled_reference.png
|-- allowed_regions.png
|-- protected_regions.png
|-- seam_allowances.png
|-- crop_manifest.json
`-- prompt_contract.md

assets/images/characters/generation_templates/humanoid_v1/character_sheet_v2/
|-- guide.png
|-- assembled_reference.png
|-- allowed_regions.png
|-- protected_regions.png
|-- seam_allowances.png
|-- crop_manifest.json
`-- prompt_contract.md

assets/images/characters/generation_templates/humanoid_v1/character_sheet_v3/
|-- guide.png
|-- assembled_reference.png
|-- allowed_regions.png
|-- protected_regions.png
|-- seam_allowances.png
|-- crop_manifest.json
`-- prompt_contract.md
```

- `guide.png` is the exact approved `4096 x 4096` layout assembled from native
  StoryTale rig and hair assets.
- `assembled_reference.png` is rendered locally from the neutral locked rig
  with the approved neutral-pose head offset applied to the whole head/hair
  group, so the jaw overlaps the torso neck opening instead of floating.
- `allowed_regions.png` identifies pixels where generated appearance artwork
  may survive.
- `protected_regions.png` identifies anatomy, gaps, and areas the provider may
  not replace.
- `seam_allowances.png` adds only the approved overlap around shoulders,
  elbows, hips, and knees.
- `crop_manifest.json` is the single authority for cell geometry and anchors.
- `prompt_contract.md` contains the exact provider instructions and exclusions.

The V2 exact-part checkpoint and V3 landscape candidate are locally complete,
but neither is an active Flutter asset contract. V1 remains unchanged for
rollback until the owner explicitly resumes and authorizes the V3 migration.

Widgets, services, tests, and Workers must read the versioned manifest instead
of repeating crop rectangles or guessing component boundaries.

## 6. Crop-manifest contract

`crop_manifest.json` stores:

- contract ID and version: `character_sheet_v1`;
- exact canvas width and height;
- expected MIME type and green key color;
- locked rig ID, template version, and geometry hash;
- one fixed crop rectangle for every region;
- canonical output canvas for every extracted layer;
- left/right ownership;
- parent part and attachment anchor;
- allowed, protected, and seam-mask references;
- layer role and default layer order;
- whether the region is required, optional, or explicitly nullable; and
- validation tolerances that are deterministic and versioned.

V2 additionally stores the `2K` provider image size, one selected back-hair
slot and its variant map, each exact Sprite Studio crop and output canvas, the
original source canvas for traceability, and a no-post-crop-resize policy.

V3 stores the `4:1` `2K` provider contract, three independent back-hair cells,
the default actor used by the checked-in guide, default/heroine source mapping,
and the same no-post-crop-resize exact-output policy.

The V3 guide/layout selection is approved. Changing any rectangle, mask,
anchor, output tier, or aspect ratio requires a new sheet version and renewed
owner approval.

## 7. Gemini input

One character-sheet request receives:

1. the exact canonical `guide.png`;
2. the local `assembled_reference.png` showing how the pieces connect;
3. the locked source-backed Story Bible character design brief;
4. selected actor/template, skin tone, face identity, and hair requirements;
5. outfit names, colors, materials, age, role, and source-supported details;
6. the region map with explicit left/right labels;
7. the allowed and protected rules; and
8. one approved StoryTale character-sheet example when available.

The request is fingerprinted by character identity, design brief, template
version/hash, skin tone, face/hair/outfit choices, provider, model, and sheet
version. An identical ready result is reused instead of generated again.

## 8. Gemini output rules

The V3 target contract requires one exact `4096 x 1024` PNG, one front-hair
cell, separate Short/Medium/Long back-hair cells, exact Sprite Studio part
canvases, flat green gaps, and no provider-added labels or borders. All hair
options must belong to the same character. The current V1 integration keeps
the following historical requirements until the owner resumes and the V3
migration is implemented:

The prompt must require Gemini to:

- first plan one visually coherent complete character;
- transfer that same face, hair, outfit, palette, materials, and line style to
  the separated sheet regions;
- return exactly `4096 x 4096` with the original arrangement;
- preserve the native `1254 x 1254` front-hair canvas and the native
  `1254 x 2150` selected back-hair canvas;
- leave the two unselected back-hair catalog cells green;
- keep pure `#00FF00` everywhere no accepted artwork is required;
- output appearance artwork only, not replacement anatomy;
- keep every item inside its assigned region and mask;
- keep right and left pieces in their original slots;
- preserve small approved joint overlaps for posing;
- leave genuinely unused clothing regions green;
- leave back hair empty/green when the approved choice is `None`; and
- output no assembled full-body panel, text, UI, scenery, labels, duplicate
  limbs, or extra character.

The model may design the character as a complete person conceptually. The only
accepted provider image remains the separated character sheet.

## 9. Local processing pipeline

After the provider returns an image, StoryTale performs these deterministic
steps locally:

1. Verify PNG/JPEG decoding, MIME type, and exact `4096 x 4096` dimensions.
2. Verify the sheet version and request fingerprint.
3. Reject unexpected non-green pixels in protected gaps.
4. Remove only the connected green background with controlled edge cleanup.
5. Cut every region using the fixed manifest rectangles.
6. Apply allowed, protected, and seam masks.
7. Discard any generated anatomy outside the accepted appearance masks.
8. Preserve the canonical output canvas, padding, anchor, and side ownership.
9. Save non-empty face, hair, and clothing layers as transparent PNG files.
10. Represent empty optional regions in metadata instead of saving blank PNGs.
11. Reassemble the neutral full-body proof over the untouched local base.
12. Apply the same layers to Idle, Talking, Pointing, and Walking.
13. Register the package only after every deterministic validation passes.

The processor never detects cells with AI, crops to visible content, resizes an
extracted V2 part, or asks the provider to repair one failed cell
automatically. Each V2 crop already equals the exact Sprite Studio
`outputCanvas`.

## 10. Full-character consistency gate

The local neutral proof is the first authoritative view of the complete
character. It must demonstrate that:

- the face, front hair, and back hair belong to the same identity;
- outfit colors, materials, patterns, and trim agree across all body pieces;
- sleeves and trousers continue cleanly across their joints;
- gloves and footwear attach to the correct hands and feet;
- left/right details are intentional and not swapped;
- exposed areas show the selected local skin tone;
- the locked head and body silhouettes remain unchanged; and
- the character still reads as the same person in all four built-in poses.

The assembled reference sent to Gemini is never accepted as output. The local
proof must be created from the actual extracted layers or the package fails.

## 11. Loose garments and accessories

Items that cannot follow one fixed body piece do not cross character-sheet
cells. They use optional later component groups:

- `outfit_back`: cape, robe back, long coat tail, skirt back;
- `outfit_front`: skirt front, apron, sash, coat front;
- `head_accessory`: hat, crown, helmet, headband, hair clip;
- `face_accessory`: glasses, mask, eye patch, facial jewelry;
- `rear_body_accessory`: sheath, backpack, wings, rear weapon; and
- `held_item`: sword, staff, book, flower, shield, tool, or story prop.

Only source-supported items are requested. Held items use named hand anchors
and approved behind-arm, behind-hand, or front-of-hand layer modes.

## 12. Output package

```text
books/<book-id>/story-bible/characters/<character-id>/appearance/
|-- appearance.json
|-- generation/
|   |-- character_sheet_source.png
|   |-- character_sheet_clean.png
|   |-- request.json
|   |-- response.json
|   `-- validation.json
|-- face/
|-- hair/
|   |-- front/
|   `-- back/
|-- outfits/<outfit-id>/
|   |-- outfit.json
|   `-- fitted/<nine optional clothing layers>
|-- extensions/
|-- accessories/
`-- previews/
    |-- neutral.png
    |-- talking.png
    |-- pointing.png
    `-- walking.png
```

Generated image bytes remain session-only until Phase 8 adds durable local
files. Stable IDs, ownership, manifest version, provider metadata, validation
state, and design hashes must still be recorded now.

## 13. Failure and cost rules

- Keep one sequential image request active.
- Reuse a valid matching design hash.
- Viewing a result never creates another request.
- Do not add an automatic regeneration loop.
- Do not silently retry a provider quota or billing failure.
- An invalid sheet becomes `needsAttention` and uses the safe locked-template
  fallback.
- Normal users receive a read-only result; management remains developer-only.

## 14. Implementation order

### Phase 7G.1B.1 - Contract and canonical assets — complete

1. Version the native-size assembled source as `character_sheet_v1/guide.png`.
2. Render the neutral assembled reference from the locked rig.
3. Measure and record all fixed crop rectangles.
4. Create allowed, protected, and seam masks.
5. Record anchors, output canvases, layer roles, and left/right ownership.
6. Write the exact prompt contract.
7. Add manifest-loading and contract-validation records.

Phase 7G.1B.1 completed without a paid provider request.

### Phase 7G.1B.R - V2 transport correction - local candidate complete

1. Preserve V1 and the locked runtime assets unchanged.
2. Create the `2048 x 2048` V2 guide with one selected back-hair slot at the
   rig's exact `429 x 800` raster size and front hair at `429 x 438`.
3. Use the exact Sprite Studio raster sizes for the head, torso, arms, and legs.
4. Regenerate allowed, protected, and seam masks deterministically.
5. Record the `2K` provider contract, hashes, variant mapping, and the rule that
   V2 crops are used without post-provider resizing.
6. Stop for owner visual approval before Flutter/Worker migration or Gemini.

The local candidate was generated after checkpoint `92e6633`. It made no
network or provider request. Owner guide approval is pending.

### Phase 7G.1B.R2 - V3 landscape catalog - local candidate complete

1. Preserve V1, V2, and all locked runtime/source assets unchanged.
2. Use the supported `4096 x 1024` (`4:1`, `2K`) provider canvas.
3. Include separate exact-size Short, Medium, and Long back-hair cells plus one
   exact-size front-hair cell.
4. Keep the head, torso, arms, and legs at their exact Sprite Studio rasters.
5. Record the default actor as the current guide/reference actor and retain the
   identical geometry plus actor-specific source mapping for a future heroine.
6. Regenerate masks, anchors, hashes, and the prompt deterministically.
7. Stop for owner approval before Flutter/Worker migration or Gemini.

V3 was generated locally without a network or provider request. It supersedes
V2 as the owner-selected future contract; V2 remains the saved exact-part
checkpoint. The approval gate is satisfied, but migration is paused at the
owner's direction and no provider request is authorized.

### Phase 7G.1B.2 - One-sheet generation — implemented locally

1. Add the character-sheet request/response contract to Flutter and the private
   Worker.
2. Send the guide, assembled reference, design brief, and strict rules.
3. Preserve provider/model/request/fingerprint metadata.
4. Keep sequential generation and design-hash reuse.
5. Surface real provider errors without automatic regeneration.

The V1 Flutter and Worker contracts are implemented and deployed. The first
owner-controlled request failed before packaging, no output was accepted, and
no automatic second request was made. V2 and V3 are not connected to either
side.

### Phase 7G.1B.3 - Local cutout and package builder — implemented locally

1. Validate and remove green locally.
2. Split fixed cells from the manifest.
3. Apply allowed/protected/seam masks.
4. Save transparent appearance layers and package metadata.
5. Compose the neutral full-body proof.
6. Reject geometry, slot, side, or seam violations.

The Flutter processor now verifies the contract and request fingerprint,
requires the exact `4096 x 4096` PNG, rejects artwork outside the allowed and
seam masks, preserves protected anatomy, cuts all 14 native-size cells, records
empty optional slots, registers stable session asset IDs and package metadata,
and composes the neutral proof over the locally tinted locked base. Invalid
packages become `needsAttention` and compose only the safe locked-template
fallback. No paid request was made while implementing this phase.

### Phase 7G.1B.4 - Pose proof and package review — implemented locally

1. Compose Idle, Talking, Pointing, and Walking from the same layers.
2. Add Character, Layers, Faces, Hair, Poses, and Details proof groups.
3. Keep the normal catalog read-only.
4. Mark the package ready only after the complete gate passes.

The local package builder now renders Idle, Talking, Pointing, and Walking PNG
proofs through the existing rig hierarchy and the same extracted appearance
layers. Each proof records stable session asset IDs, dimensions, visible-pixel
counts, and hashes. `poseProofValid` requires all four proofs to be valid and
distinct before the package can become `ready`. The Sheet screen exposes
read-only Character, Layers, Faces, Hair, Poses, and Details groups even before
generation; viewing or switching groups never calls the provider. No paid
request was made while implementing this phase.

The first live owner-controlled request was made only after checkpoint
`22f6a82` and Worker deployment `6c2c1427-1442-4101-b0fa-99a88d307293`. It
returned `Story service request failed` before Flutter received image bytes, so
it produced no package and does not satisfy this gate. The Character Sheet
request now leaves Gemini's output MIME override unset so the current
Interactions API can return its default PNG; safe provider failure messages are
also exposed. That fix is deployed as
`ab9b22c9-b94a-4923-ae33-26eb16dbc808`. A second paid request was not made.

### Phase 7G.1C - Exact-fidelity gate — implemented locally

Prove the Little Prince fixture keeps the exact StoryTale base geometry, one
stable identity, six faces, and all four poses. Phase 7H Story Mode binding
remains blocked until that proof passes.

The local processor now verifies the approved hashes for `rig.json` and all ten
runtime head/body assets before composition. Generated head details are
rejected if they cross the locked head alpha boundary. Neutral, Talking,
Happy, Sad, Angry, and Surprised are composed from one actor profile and one
design hash, stored as six read-only full-character proofs, and must all be
distinct and valid. The four pose proofs reuse that same identity and select
the matching face set. A matching ready design hash is reused before any
provider call. The private Worker no longer applies StoryTale's shared
three-per-minute limiter to sprite generation; Flutter still permits only one
character-sheet request at a time, rejects duplicates, never retries a paid
failure, and keeps real Gemini quota or billing errors visible.

This implementation was completed without a provider request or test run at
the project owner's direction. After the owner explicitly resumes work and the
V3 migration is complete, it still requires one controlled request and a
manual six-face/four-pose review pass. The sprite-limiter change is live in Worker
version `ed567efb-c4a9-4e76-ad32-f55a2e83d65a`.

## 15. Acceptance gate

- [x] The canonical guide is versioned at exactly `4096 x 4096`, with native
  front-hair and Short/Medium/Long back-hair canvases.
- [x] V1 and all original rig/hair assets remain unchanged behind checkpoint
  `92e6633`.
- [x] The local V2 candidate is exactly `2048 x 2048`, uses one selected
  back-hair slot, and makes every crop equal the exact raster canvas assembled
  by Sprite Studio.
- [x] The V2 guide, masks, manifest, prompt, hashes, and deterministic builder
  are versioned without a provider request.
- [x] The local V3 candidate is exactly `4096 x 1024`, uses the supported `4:1`
  `2K` provider shape, and includes front hair plus separate exact-size Short,
  Medium, and Long rear-hair cells.
- [x] V3 records actor `default` for the current guide and heroine-compatible
  geometry/source mapping without changing the locked rig.
- [x] The V3 guide, masks, manifest, prompt, hashes, and deterministic builder
  are versioned without a provider request.
- [x] The owner selects and visually approves the V3 guide/layout as the future
  active contract; implementation remains paused until a new request to proceed.
- [ ] Flutter and the private Worker consume V3 without silently falling back
  to V1 or making an automatic paid retry.
- [x] Every region has one reviewed crop, output canvas, anchor, role, and side.
- [x] Allowed, protected, and seam masks are versioned and deterministic.
- [ ] Gemini receives one coherent-character brief and returns only the
  separated sheet.
- [ ] No returned sheet contains an assembled body, extra person, text, UI, or
  scenery.
- [ ] The original head and nine body geometries remain unchanged.
- [ ] Face details are accepted without replacing the skull or skin base.
- [ ] Front and optional back hair align with the locked head.
- [ ] All nine fitted clothing layers align and follow their matching bones.
- [ ] Right and left pieces are never swapped.
- [ ] Empty regions reveal the selected local skin tone correctly.
- [ ] The locally assembled neutral character is visually coherent.
- [ ] The same identity and outfit pass Idle, Talking, Pointing, and Walking.
- [ ] Invalid output becomes `needsAttention` without automatic regeneration.
- [ ] A matching ready design hash prevents duplicate paid requests.
- [ ] Viewing the proof creates no provider request.

## 16. Phase handoff rule

Future implementation chats must start with the current Phase 7 section of
`ROADMAP.md`, then this document. They must update both documents together,
avoid live paid generation unless the project owner explicitly requests it,
and keep Phase 7H blocked until one generated package passes the complete
7G.1C proof.
