# Character V5 Plan — separate parts, local skin, reusable hair

Status: **Current. This file replaces `CHARACTER_SHEET_PLAN.md` as the active
plan.** Approved by the owner on 2026-08-07. V5-0 through V5-2 are complete;
V5-3 now has deterministic 1K legs, arms, and torso reference sheets, while
the end-to-end clothing-generation gate remains open.

This is the one document to read before working on generated characters. It
carries the phases, the checklists, what to delete, and what must not be deleted.

---

## 1. Why V4 was stopped

V4 asked one image request to draw twelve body-part cells on one sheet. Eight
billed sheets never produced a usable character.

| Sheet | What was fixed | What broke instead |
| --- | --- | --- |
| 5th | — | the provider re-laid-out the lower half; `21,459` stray pixels in the padding |
| 6th | layout pinned with exact cell rectangles | stray pixels fell to `129`, but a hood appeared on the hair and spare limbs filled empty cell space |
| 8th | hair windows narrowed | every leg cell held a **whole leg**, so every extracted leg layer was a boot and nothing else |

**The lesson is structural, not verbal.** One request drawing twelve
interdependent cells has twelve ways to fail, and one bad cell wastes the whole
sheet. More prompt wording was not going to fix that.

V5 changes the unit of work: each request draws few parts, a failure costs only
that request, and most of the character is not generated at all.

---

## 2. What V5 is, in one page

| Part of the character | Where it comes from in V5 | Cost |
| --- | --- | --- |
| **Skin** | local tint in Sprite Studio; story analysis picks the tone | free |
| **Face** | the five existing local profiles (`default`, `hero`, `heroine`, `elder`, `adult_deep`) | free |
| **Hair** | generated **once** into a shared catalog, reused by every character | one-time |
| **Clothing** | generated per character, in small groups: legs, arms, torso | ~3 requests |

Three rules that follow from this:

1. **Generated output never contains skin.** A garment layer is clothing only,
   drawn over the body part. The skin underneath stays local and stays tintable.
2. **Generated output is never a body part.** The rig geometry is untouched. A
   garment sits on top of a part; it does not replace it.
3. **Hair is a catalog, not per-character output.** Sprite Studio and generation
   use the same single hair format.

---

## 3. The money

Read this before assuming "more requests" is cheaper. It is not, on its own.

| Approach | Requests per character | At `$0.067` | At `$0.0336` |
| --- | --- | --- | --- |
| V4, one sheet | 1 | `$0.067` | `$0.034` |
| V5 with every part separate | 12 | `$0.80` | `$0.40` |
| **V5 with three clothing groups** | **3** | `$0.20` | **`$0.10`** |

Per character, V5 is **not** cheaper than a V4 sheet that works. The savings come
from three other places, and they are real:

- **A failure costs one group, not the sheet.** Legs wrong? Re-request legs for
  `$0.0336`. Under V4, fixing the legs also re-rolled the hair, torso, and arms
  that were already right. Eight sheets at `$0.067` is `$0.54` spent that way.
- **Most of the character stops being bought.** Skin free, faces free, hair paid
  for once and reused forever.
- **A cheap model becomes safe** once each request has one small job.

### The model

`GEMINI_IMAGE_MODEL` in `cloudflare/image-worker/wrangler.jsonc` already drives
every sprite mode, so changing it is one line plus a redeploy.

| Model | Per `1024x1024` | Notes |
| --- | --- | --- |
| `gemini-3.1-flash-image` (current) | `$0.067` | what V4 spent |
| `gemini-3.1-flash-lite-image` | `$0.0336` | **planned starting point**, config-only change |
| OpenAI GPT Image 1 Mini Low | `$0.005` | cheapest; needs the OpenAI adapter |

**The seam is built (V5-0.5), so switching is now config.** `IMAGE_PROVIDER` and
`GEMINI_IMAGE_MODEL` in `wrangler.jsonc` plus a redeploy — no app release, and
the Flutter side never learns which provider answered.

**OpenAI is deferred, not rejected.** It would put a character at ~`$0.015`, but
it needs a new key and an adapter, which is Phase V5-7. `AGENTS.md` no longer
blocks it: the product boundary was restated as provider-neutral image
generation on 2026-08-07.

**Verify transparent-PNG support before adopting any new provider.** Gemini
returns JPEG only, so V5's separator chroma-keys green away. A provider that
returns real alpha would let that step be skipped, which changes the pipeline and
not just the bill. `ProviderCapabilities.supportsTransparentOutput` is where that
answer is recorded.

---

## 4. What already exists — reuse, do not rebuild

Most of V5 is already in the codebase. This is why V5 is a regrouping, not a
rewrite. **Check this table before writing anything new.**

| What V5 needs | What already does it | File |
| --- | --- | --- |
| Per-part image override on the live character | `SpriteRigView(partBytes: …)` | `widgets/sprite_rig_view.dart:214` |
| A place to draw a garment over a part | the `Stack` in `_partArtwork`, where the face already overlays the head | `widgets/sprite_rig_view.dart:165` |
| Skin tint that must stay under the garment | `_skinColorMatrix`, `_canTint` | `widgets/sprite_rig_view.dart:214` |
| Green → transparent | `SpriteLayerProcessor.removeGreenBackground` | `data/sprite_layer_processor.dart:624` |
| Crop a piece to its own bounds | `_PixelBounds` + `image.copyCrop` | `data/sprite_layer_processor.dart:412` |
| Offset X / Y / scale per part | `SpriteHairFit`, `hairFitForPart`, `withHairFitForPart` | `data/sprite_appearance.dart:6, 135, 142` |
| Saving appearance per actor | `SpriteAppearanceSelection`, `SpriteAppearanceRepository` | `data/sprite_appearance.dart:58, 414` |
| The UI section to extend | `_appearanceSelector()` | `presentation/sprite_positioner_page.dart:579` |
| Twelve parts, parents, sizes, z-order | `rig.json` — `front_hair` z50 and `back_hair` z4 already parent to `head` | `assets/images/characters/rigs/humanoid_v1/rig.json` |
| Per-part request modes on the Worker | `front-hair`, `face-layer`, `body-pose`, `head-design`, `head-expression` | `cloudflare/image-worker/src/index.ts:35` |
| Saving a raw reply for offline study | `diagnostics/character_sheets/` + admin endpoint | `presentation/story_pages.dart:939` |

The Worker's per-part modes already exist and are currently called only by dev
tools in `tool/`. V5 promotes that path instead of inventing a new one.

### Rig sizes V5 must respect

Parts are small. Do not design around `1024` canvases for a `67x118` arm.

```
back_hair  429x800    front_hair 429x438   head 357x367   torso 165x234
upper_leg_right 94x150   lower_leg_right 84x156
upper_leg_left  85x141   lower_leg_left  88x140
upper_arm_right 67x118   lower_arm_right 77x145
upper_arm_left  78x128   lower_arm_left  86x129
```

---

## 5. Phases and checklists

Every phase ends with **something visible in Sprite Studio** on port `52827`.
No phase before V5-3 costs any money.

### V5-0 — Retire V4, keep what V5 needs *(done, 2026-08-07)*

- [x] Deleted everything in the "Delete" list in section 6
- [x] Confirmed nothing in the "Keep" list was touched
- [x] `flutter analyze` — **no issues**
- [x] `flutter test` — **130 passing, down from 221**. The drop is the five
      character-sheet test files, ~91 tests that existed only to guard the
      retired contract. Nothing else lost coverage.
- [x] Worker: 14 tests still passing, `tsc` clean, `deploy:dry` **61.83 KiB**,
      down from 65.13
- [x] Only three mentions of the old name survive, all deliberate: two comments
      recording the retirement, and the V1 rollback registration in `pubspec.yaml`

**Facts worth keeping:**

- **Sprite Review now opens on the legacy Sprite mode.** The Sheet segment is
  gone, so the mode selector has two options rather than three. That page has no
  V5 path yet — V5-1 gives it one.
- **The diagnostics endpoint survived**, as planned. `tool/pose_admin_server.dart`
  still serves `/character-sheet-diagnostics` and still writes to
  `diagnostics/character_sheets/`. What was deleted is only the *Flutter caller*,
  which was typed against the V4 result. **V5-3 must add a new caller** — the
  server half is already there, and saving the reply before validating is what
  makes a bad group free to study.
- `test/fixtures/eighth_live_sheet.jpg` went with its test. The eighth sheet is
  still in `diagnostics/character_sheets/` if it is ever needed again.
- The `character-sheet` mode is gone from the Worker's `SpriteMode` union, so the
  per-mode spec table and its tests cover seven modes now, not eight.

### V5-0.5 — The provider seam *(done, 2026-08-07)*

Any image API can be swapped in by configuration. Built before V5-3 so every
later phase is written against a neutral interface.

- [x] `src/shared.ts` — helpers that belong to no provider
- [x] `src/providers/types.ts` — the interface, `ProviderCapabilities`, and
      `SPRITE_REQUEST_SPEC_BY_MODE` replacing two ternary chains
- [x] `src/providers/gemini.ts` — the old `generateSprite`, moved unchanged
- [x] `src/providers/registry.ts` — config routing, loud failures
- [x] `IMAGE_PROVIDER` var; optional `IMAGE_PROVIDER_BY_MODE` for per-mode routing
- [x] The Worker's **first tests**: 14 in `test/providers.test.ts`
- [x] `AGENTS.md` product boundary restated as provider-neutral

**Facts worth keeping:**

- **The Flutter app needed no change at all.** `_generate` already reads the
  provider from the `X-Image-Provider` header and accepts PNG, JPEG, and WebP.
  Switching provider is a var plus a redeploy — never an app release.
- **The client cannot choose the provider.** Selection is Worker config only, so
  the app can never pick what the owner is billed for.
- **A missing key or unknown name fails loudly**, never falling back to another
  paid provider.
- Adding a provider is now one file plus a secret plus a var.

### V5-1 — The garment layer *(done, 2026-08-07 — no provider, no cost)*

- [x] `SpriteGarmentLayer`: part id, bytes, fit, source request id
- [x] Per-actor garment map on `SpriteAppearanceSelection`, same shape as
      `hairFits`, through the same repository
- [x] Rendered as an **overlay above the part** in `_partArtwork`
- [x] **Not** a `partBytes` replacement — see the guard below
- [x] "Clothing" section in Sprite Studio, on the selected body part, with
      across / up-and-down / size controls and a per-part clear
- [x] `assets/images/characters/garment_fixtures/tunic_fixture.png`, built by
      `tool/generate_garment_fixture.dart`
- [x] 7 tests in `test/sprite_garment_test.dart`; suite now **137 passing**

**Facts worth keeping:**

- **The overlay-not-replacement rule now has a test that actually catches a
  breach.** Counting images is not enough on its own: dressing the torso must
  *add* one memory-backed image while the asset-backed count stays the same. A
  replacement keeps the total identical and would pass a naive check. Proven by
  temporarily making it a replacement — the test failed with `Expected: <12>,
  Actual: <11>` — then restored.
- **Why it matters beyond tidiness:** `_canTint` in `sprite_rig_view.dart`
  refuses to tint a part whose pixels came from `partBytes`. Putting clothing
  there would silently disable the skin-tone picker, which is the thing V5
  promised stays local and free.
- **Garment bytes persist as base64 inside the appearance record**, so they
  survive a reload without the admin server running. Fine at this size — a part
  garment is a few KB — but it is the thing to revisit if a character ever wears
  twelve large layers.
- A corrupt stored garment is **dropped, not thrown**: the rest of the
  appearance still loads and the character still renders.
- `SpriteHairFit` is now a typedef for `SpritePartFit`. Same three numbers,
  shared by hair and clothing; every existing call site is untouched and the
  persisted keys did not change.

**Gate met:** a fixture garment goes on the selected part in Sprite Studio,
renders on the character over the tinted skin, moves and resizes with the
sliders, and is still there after a reload.

### V5-2 — The separator *(done, 2026-08-07 — no provider, no cost)*

The chopper: one generated image in, one PNG per piece out.
`data/sprite_garment_separator.dart`.

- [x] Green → transparent through the existing `removeGreenBackground`
- [x] Eight-connected components of visible pixels
- [x] Specks below `minimumVisiblePixels` dropped
- [x] Each component cropped to its own bounds, one PNG each
- [x] Ordered **top row first, then left to right**, matching how the prompt
      asks for the pieces to be drawn
- [x] **Load garment image** in Sprite Studio's Clothing section, with a picker
      showing every piece found
- [x] 8 tests; suite now **145 passing**

**Why this removes V4's hardest requirement.** V4 demanded pixel-exact cells and
the provider would not hold them — most of eight wasted sheets. The separator
finds pieces by connectedness, so the sheet only has to keep them **apart**.
Prompts should ask for separation, never for coordinates.

**Measured on the real eighth V4 sheet** (a JPEG, all its artifacts intact) —
this is the useful part, and it is why the tests look the way they do:

| Threshold | Pieces found |
| --- | --- |
| 64 (default) | 18 |
| 2,000 | 16 |

The twelve-cell sheet gives **18** pieces, and the extras are informative:

- the two `190x198` blobs at `y 612` are the **floating trouser thighs** the
  handoff called "spare arms" — the separator finds them cleanly, so a
  mislaid piece becomes something the owner can pick up rather than lose
- two ~`420 px` specks near the top are the hair's **ahoge strands**, which are
  detached from the main mass

**The limitation, stated plainly: connected components find *topological*
pieces, not *semantic* ones.** A detached strand is its own piece. That is the
separator working correctly — quietly merging nearby blobs would just as easily
glue two garments together — so **the prompt must ask for connected shapes**.
A test pins this behaviour so nobody later "fixes" it into a merge.

Threshold guidance: the default `64` keeps everything real on that sheet.
Raising it to `2,000` drops the ahoge. Tune per source rather than globally.

**Gate met:** tests over programmatically built fixtures, plus the real-sheet
measurement above. No provider involved.

### V5-3 — One group, end to end

- [x] Prepare deterministic 1024x1024 reference sheets for the legs, arms,
      and torso groups. Each locked `humanoid_v1` source part remains at its
      native size; the sheets are green-screen guides only, not garments.
- [x] Build a local legs clothing fixture with navy leggings and brown shoes,
      clipped strictly to each locked leg alpha mask. It is review-only and
      uses no provider request.
- [x] Build a second flat-color Gacha-style legs fixture with purple leggings
      and pink shoes, with no shadows, highlights, gradients, or added
      outlines. The first fixture remains preserved for comparison.
- [x] Build a quality Gacha-style shoe revision with a dark shoe body, flat
      straps, toe panel, sole, and the original outer outline reapplied. It
      remains clipped to the locked masks and uses no provider request.
- [x] Build a filled-shoe revision where the dark shoe body dominates and the
      lace/strap accents stay small, matching the supplied shoe reference.
      Preserve the original outline and keep the first three versions.
- [x] Preserve the owner-authored filled-shoe sheet and create a line-only
      polish that keeps its canvas, fills, positions, shoes, and internal
      details unchanged.
- [x] Preserve the three owner-supplied clothing sheets as 1K review assets
      under `garment_fixtures/v5/user_supplied_part_sheets_1k/`; normalize the
      1022x1022 torso with a one-pixel edge border and keep the arms/legs
      copies byte-exact.
- [ ] `PartGroupRequest` for `legs`, `arms`, `torso`, `hair`
- [ ] Use the Worker's existing per-part sprite mode; add a `part-group` mode
      only if none fits
- [ ] Reply → separator → garment layers → onto the character
- [ ] **Save every reply to `diagnostics/` before validating**, so a bad group is
      studied offline instead of re-bought
- [ ] Faked-Worker test drives the whole path with a fixture reply
- [ ] Switch `GEMINI_IMAGE_MODEL` to `gemini-3.1-flash-lite-image` and redeploy
- [ ] **One** owner-approved live request, legs group only

**Gate:** the offline test passes first. Only then does money get spent.

### V5-4 — The remaining clothing groups

- [ ] Arms group through the same path
- [ ] Torso group through the same path
- [ ] Re-requesting one group leaves the others untouched

### V5-5 — The hair catalog and one hair format

- [ ] Define the single hair format shared by Sprite Studio and generation,
      sized to the rig's hair parts (`front_hair 429x438`, `back_hair 429x800`)
- [ ] Anchor generated hair to the head exactly as current hair is anchored
- [ ] Generated hair goes through the separator, then `SpriteHairFit`
- [ ] Write it to a catalog **reused by every character**, not per character

**Gate:** a generated hair pair appears in Sprite Studio's "Fitted hair" list
beside the built-in styles and sits correctly on the head.

### V5-6 — Story analysis picks skin and outfit

- [ ] Analysis chooses the skin tone from the existing local palette
- [ ] Analysis writes the outfit brief per group
- [ ] Zero generation cost for skin

### V5-7 — Optional: cheaper provider

- [ ] Only if the owner chooses OpenAI: provider seam, key, per-mode model map

---

## 6. Delete and keep

Both lists are explicit on purpose.

### Delete — V4 and the one-sheet path

- [ ] `assets/images/characters/generation_templates/humanoid_v1/character_sheet_v4/`
- [ ] `data/character_sheet_contract.dart`
- [ ] `data/character_sheet_generation.dart`
- [ ] `data/character_sheet_processor.dart`
- [ ] `data/character_sheet_package.dart`
- [ ] `generateCharacterSheet` and its cache / in-flight state in
      `data/story_artwork_service.dart`
- [ ] `tool/generate_character_sheet_v2.dart`, `…v3.dart`, `…v4.dart`
- [ ] `test/character_sheet_*.dart` (contract, prompt, request, processor,
      end_to_end, live_sheet, fixtures)
- [ ] the `character-sheet` mode and its constants in
      `cloudflare/image-worker/src/index.ts`
- [ ] the `character_sheet_v4/` asset registration in `pubspec.yaml`
- [ ] the character-sheet mode selector and review UI in
      `presentation/story_pages.dart`

### Keep — deleting these would throw away work V5 needs

- [ ] `data/sprite_layer_processor.dart` — green removal and cropping **are**
      V5's separator
- [ ] `data/sprite_appearance.dart` — the garment model extends it
- [ ] `data/sprite_rig.dart`, `widgets/sprite_rig_view.dart`,
      `presentation/sprite_positioner_page.dart`
- [ ] the whole `humanoid_v1` rig: `rig.json`, base parts, poses, hair assets
- [ ] every `face_profiles/` profile and its `sets.json`
- [ ] the diagnostics save path and its admin endpoint
- [ ] `character_sheet_v1/` — **only until V5-3 passes**, as the documented
      rollback, then deleted in the commit that proves V5 works
- [ ] `docs/CHARACTER_SHEET_PLAN.md` — superseded, but it holds the measured
      evidence for why V5 exists

---

## 7. Rules that still apply

- No paid request without the owner's explicit approval for that exact request.
  One approval is one request. Nothing retries automatically.
- Provider success is never acceptance. The visible result in Sprite Studio is.
- The `humanoid_v1` head and nine body pieces stay immutable. V5 draws on top of
  them and never redraws them.
- No behaviour specific to any one book.
- Update this file, `ROADMAP.md`, and `PROJECT_HANDOFF.md` in the same work unit
  whenever phase status changes.
