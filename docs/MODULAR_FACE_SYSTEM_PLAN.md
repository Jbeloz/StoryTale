# StoryTale Modular Face System Plan

This plan replaces the current one-image-per-expression catalog with reusable
face parts. It is planning only; the existing Sprite Studio and Story Mode
behavior stay unchanged until implementation begins.

## 1. Goal

Each compatible character head will be assembled from:

```text
head base
+ eyes and eyebrows
+ nose
+ mouth
+ optional face details
```

The eyes remain one paired image instead of separate left and right images.
This preserves their spacing, direction, pupils, highlights, eyelids, and
expression. The same rule applies to paired eyebrows.

The five starter visual profiles are:

1. Default
2. Hero
3. Heroine
4. Elder
5. Deep Voice (stored internally as `adult_deep`)

There is no narrator face. These are visual profiles only; a character's face
and selected voice must remain separate settings.

## 2. Minimal image inventory

Every part uses a transparent 1254 x 1254 PNG. It must keep the exact position,
scale, and alignment of the approved head base. Empty canvas around the part is
intentional and must not be cropped.

### Eyes and eyebrows: five per profile

- `neutral`
- `happy`
- `sad`
- `angry`
- `surprised`

Talking uses neutral eyes. White eye areas and pupil highlights must stay
opaque. Angry eyes must not move away from the normal eye positions.

### Nose: one per profile

- `default`

The nose primarily establishes character identity and age. It does not need a
different image for every emotion.

### Mouth: five per profile

- `neutral`
- `talking`
- `smile`
- `sad`
- `angry_teeth`

The single `talking` mouth is reused for ordinary dialogue and surprised open
mouth scenes. Extra talking frames or emotion-plus-talking images are not
required for the first version.

### Optional details

- Elder: `wrinkles`
- Deep Voice: `adult_lines`

Details are separate overlays so wrinkles do not have to be regenerated for
every set. Blush, tears, facial hair, scars, and makeup can be added later only
when a story character needs them.

### Counts

| Item | Per profile | Five profiles |
| --- | ---: | ---: |
| Eye layers | 5 | 25 |
| Nose layers | 1 | 5 |
| Mouth layers | 5 | 25 |
| Core PNG total | 11 | 55 |
| Optional starter details | - | 2 |

The current Default expression images should be reused and separated where
possible. The 55 figure is the complete target catalog, not necessarily 55 new
generations.

## 3. Reusable face sets

A face set is JSON data that points to existing parts. It is not another
rendered face image.

Each profile starts with six sets:

| Set | Eyes | Nose | Mouth |
| --- | --- | --- | --- |
| Neutral | neutral | default | neutral |
| Talking | neutral | default | talking |
| Happy | happy | default | smile |
| Sad | sad | default | sad |
| Angry | angry | default | angry_teeth |
| Surprised | surprised | default | talking |

This creates 30 starter set definitions from 55 reusable core PNGs. Users can
later create sets such as `serious`, `nervous`, or `gentle_smile` without
generating another image when the required parts already exist.

## 4. Folder organization

Bundled starter profiles:

```text
assets/images/characters/face_profiles/
|-- catalog.json
|-- default/
|   |-- profile.json
|   |-- eyes/
|   |-- noses/
|   |-- mouths/
|   |-- details/
|   `-- sets.json
|-- hero/
|-- heroine/
|-- elder/
`-- adult_deep/
```

Every profile uses the same subfolders and filenames. `profile.json` records
the compatible rig and head template, 1254 x 1254 canvas, and alignment data.

Custom imported parts and sets belong in app-local storage:

```text
sprite-studio/face-profiles/<profile-id>/
|-- parts/<part-type>/<part-id>.png
`-- sets/<set-id>.json
```

Finished book-specific characters keep their approved face parts in the story
bible so their identity remains unchanged across chapters and volumes:

```text
books/<book-id>/story-bible/characters/<character-id>/sprites/faces/
```

## 5. Small data contract

The catalog needs only four main records:

- `FaceProfile`: profile ID, label, compatible rig/head, canvas size, and
  default set ID.
- `FacePart`: ID, label, type, asset path, profile ID, and compatibility data.
- `FaceSet`: ID, label, profile ID, eyes ID, nose ID, mouth ID, and optional
  detail IDs.
- `CharacterFaceSelection`: selected profile ID, selected set ID, and optional
  temporary part overrides while editing.

Story scenes should eventually store `faceSetId`, not three separate part IDs.
Sprite Studio may expose advanced per-part overrides, but saving a finished
face creates or updates a set first.

The current `faceExpressionId` remains readable during migration:

```text
neutral -> default/neutral
talking -> default/talking
happy   -> default/happy
sad     -> default/sad
angry   -> default/angry
```

Unknown profiles, parts, or sets fall back to `default/neutral`.

## 6. Sprite Studio face UI

The Face section becomes a compact editor with two tabs.

### Sets tab (default)

- Profile selector: Default, Hero, Heroine, Elder, or Deep Voice.
- Grid of composed set previews.
- Select a set with one click.
- Actions: New Set, Duplicate, Rename, and Delete.
- Built-in sets are locked; users duplicate them before editing.

### Parts tab (advanced)

- Three compact categories: Eyes, Nose, and Mouth.
- Details stays collapsed unless a profile has detail layers.
- Each category shows aligned thumbnails over the same head preview.
- Actions: Import PNG, Rename, and Delete.
- Selecting a part changes only that layer in the live preview.

### Set Maker

`New Set` opens one small panel containing:

1. Set name
2. Eyes picker
3. Nose picker
4. Mouth picker
5. Optional details picker
6. Live composed preview
7. Save Set button

The sprite canvas must remain visible while using the Face section, just like
it remains visible while adjusting a pose.

### Safe add and delete rules

- Imported PNGs must be transparent, 1254 x 1254, and compatible with the
  selected head template.
- Bundled parts and sets cannot be deleted.
- A custom part cannot be deleted while a set uses it. Sprite Studio shows the
  sets that use it and asks for a replacement first.
- Deleting a custom set that is used by a pose or scene replaces that reference
  with the profile's Neutral set.
- Face edits participate in the existing Undo and Redo history.

## 7. Generation workflow

Generate one approved neutral identity for a profile before generating its
parts. Every later prompt must edit that same approved reference rather than
inventing the character again.

Recommended order for each profile:

1. Approve one neutral full-face reference.
2. Extract or generate neutral eyes, default nose, and neutral mouth.
3. Generate four eye variations without changing position or identity.
4. Generate four mouth variations without changing position or identity.
5. Add the optional detail overlay only when needed.
6. Import the parts and inspect every set over the actual head base.

The selected Heroine reference
`heroine_neutral_r2_04_simple_cute.png` is the first approved identity to use
for this proof test.

## 8. Prompt pattern

Attach the approved neutral face reference and the empty compatible head base.
Use one sentence per requested part.

### Eyes prompt

> Keep this exact character identity, art style, canvas size, eye positions,
> spacing, proportions, and front-facing direction; output only both eyes,
> eyelids, eyelashes when present, pupils, opaque white eye areas, highlights,
> and eyebrows with a [neutral/happy/sad/angry/surprised] expression on a fully
> transparent 1254 x 1254 PNG, change no nose or mouth, do not crop or move the
> features, and keep every other pixel transparent.

### Nose prompt

> Keep this exact character identity, art style, canvas size, nose position,
> scale, and front-facing direction; output only the [profile description] nose
> marks and minimal nose shading on a fully transparent 1254 x 1254 PNG, add no
> eyes, eyebrows, mouth, head, skin area, or background, do not crop, and keep
> every other pixel transparent.

### Mouth prompt

> Keep this exact character identity, art style, canvas size, mouth position,
> scale, and front-facing direction; output only a
> [neutral/talking/smile/sad/angry showing teeth] mouth on a fully transparent
> 1254 x 1254 PNG, add no eyes, eyebrows, nose, head, skin area, or background,
> do not crop or move the mouth, and keep every other pixel transparent.

If the generator cannot preserve transparency, request a flat pure green
`#00FF00` background with no green on the face part, then use StoryTale's local
background-removal step before import.

Profile descriptions should change identity without changing alignment:

- Hero: determined but simple, slightly stronger eyebrows, clear focused eyes.
- Heroine: simple and cute, soft lashes and bright highlights, matching the
  approved Heroine reference.
- Elder: mature eyes, gentle age lines, small age-appropriate nose marks.
- Deep Voice: mature adult features, firm eyes, slightly stronger nose marks.
- Default: preserve the current neutral style exactly.

## 9. Implementation parts

### Part 7A - Asset contract and proof profile

- Add the folder and JSON schemas.
- Prepare the Heroine proof profile from the approved reference.
- Verify all layers at 1254 x 1254 with matching alpha alignment.
- Do not migrate Story Mode yet.

### Part 7B - Catalog and compatibility loader

- Load profiles, parts, and sets.
- Compose selected parts in the fixed order: head, eyes, nose, mouth, details.
- Add neutral fallbacks and legacy `faceExpressionId` mapping.

### Part 7C - Sets UI and Set Maker

- Replace the current five face chips with the Profile selector and Sets tab.
- Add New Set, Duplicate, Rename, Delete, and live preview.

### Part 7D - Parts UI and local import

- Add Eyes, Nose, Mouth, and optional Details categories.
- Add transparent PNG validation, import, rename, safe delete, and replacement.
- Keep external prompt generation for the first version; no generation API is
  required inside Sprite Studio yet.

### Part 7E - Story Mode migration

- Save `faceProfileId` and `faceSetId` in poses and character scene layers.
- Keep old files working through the legacy mapping.
- Preserve the rule that ordinary neutral dialogue temporarily uses Talking,
  while Happy, Sad, or Angry keeps its stronger set.

### Part 7F - Remaining profiles and chapter test

- Import Hero, Elder, and Deep Voice after Heroine passes alignment checks.
- Migrate the current Default catalog.
- Test every set in Sprite Studio and one full chapter in Story Mode.

## 10. Acceptance checklist

- All parts are transparent 1254 x 1254 PNGs and never shift when swapped.
- Eye whites and pupil highlights remain visible.
- Angry and surprised eyes stay in the approved eye positions.
- A set changes eyes, nose, and mouth together with one click.
- Parts can still be changed individually in the advanced tab.
- Built-in content cannot be accidentally deleted.
- Removing custom content never leaves a broken pose or story scene.
- Old `faceExpressionId` files still display the same Default faces.
- A generated book character can use its own profile and sets without changing
  the Story Mode player.

## 11. Recommended immediate next step

Build only one Heroine proof pack first: five eye layers, one nose layer, and
five mouth layers. Once those 11 parts align correctly and the six composed
sets look consistent, implement the catalog and Sprite Studio UI. This prevents
building the editor around generated assets that do not align reliably.
