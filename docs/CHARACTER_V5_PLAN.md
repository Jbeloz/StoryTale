# Character V5 Plan — separate parts, local skin, reusable hair

Status: **Current. This file replaces `CHARACTER_SHEET_PLAN.md` as the active
plan.** Approved by the owner on 2026-08-07. Nothing in V5 has been built yet.

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

### V5-0 — Retire V4, keep what V5 needs

- [ ] Delete everything in the "Delete" list in section 6
- [ ] Confirm nothing in the "Keep" list was touched
- [ ] `flutter test` passes; record the new test count here: `___` (was 218)
- [ ] App still builds and Sprite Studio still opens on `52827`
- [ ] Commit as one phase-scoped commit

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

### V5-1 — The garment layer *(no provider, no cost)*

- [ ] `SpriteGarmentLayer`: part id, bytes, fit, source request id
- [ ] Per-actor garment map on `SpriteAppearanceSelection`, reusing the existing
      `hairFits` shape and repository
- [ ] Render the garment as an **overlay above the part** in `_partArtwork`
- [ ] **Do not** use `partBytes` replacement — it would lose the skin tint
      underneath and break "clothes on top, no skin"
- [ ] "Clothing" section in Sprite Studio beside "Fitted hair", with the same
      offset/scale controls and a per-part clear
- [ ] Tests over a fixture garment PNG

**Gate:** put a fixture garment on the torso in Sprite Studio, see it on the
character, move it, save the session, reload, find it still there.

### V5-2 — The separator *(no provider, no cost)*

The chopper: one generated image in, one PNG per piece out.

- [ ] Green → transparent using the existing `removeGreenBackground`
- [ ] Find connected components of visible pixels
- [ ] Drop specks below a size threshold
- [ ] Crop each component to its own bounds, one PNG each
- [ ] Map pieces to the slots of the group being processed
- [ ] Tests: a two-piece image splits into exactly two; a four-piece into four;
      a speckled image gives the right count with noise dropped

**Gate:** unit tests over hand-built fixtures. No provider involved.

### V5-3 — One group, end to end

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
