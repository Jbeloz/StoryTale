# StoryTale Sprite Studio Plan

Sprite Studio is the final name of the rig editor previously called Sprite
Positioner. It is a
small editor for selecting rig parts, adjusting joints, fixing layer order,
and creating reusable named poses for Animated Story Mode.

This is a subsystem plan. The authoritative global next phase is maintained in
the [Master Roadmap](ROADMAP.md).

## Implementation status

Parts 1-6 are complete. Sprite Studio now has one canvas-level alpha
resolver, locked base-body layers, a responsive two-pane desktop layout, a
pinned mobile canvas with a draggable inspector, zoom controls, numeric
Rotation/X/Y inputs, fixed save actions, Undo/Redo, and direct bone posing with
optional joint limits. It also has the five-expression default face catalog
with pose saving, fallback behavior, and the neutral-to-talking speech rule.
Named custom poses now start from Idle, use safe stable IDs, support rename,
duplicate, delete, session drafts, app-local saves, project-default saves, and
an unsaved-change guard. Story Mode now resolves scene rig and pose IDs with
safe fallbacks.
The full Story Mode review chapter now preserves every source block while
testing all five starter face profiles and all four approved poses.

## Current prototype gap

- Generated book characters are not yet real Sprite Studio rigs. The current
  prototype uses different part IDs, broad rectangular image regions,
  provisional metadata, baked faces, and a separate renderer.
- Phase 7G must export canonical part assets plus a real `rig.json`, modular
  face catalog, and compatible pose files. Book Characters must then open that
  exact generated package in Sprite Studio.

See the
[Generated Character Pipeline Plan](GENERATED_CHARACTER_PIPELINE_PLAN.md).

## 1. Final scope

Sprite Studio will support:

- selecting a transparent body part directly or from a dropdown;
- consistent mouse, touchpad, touch, and stylus selection;
- optional hitbox and joint-anchor overlays;
- an optional bone overlay for direct joint posing;
- drag mode, rotation, X/Y position, Undo, and Redo;
- safe front/back layer adjustments;
- a reusable five-expression default face catalog;
- creating, naming, saving, renaming, and deleting custom poses;
- built-in neutral, talking, pointing, and walking poses;
- session drafts and permanent local pose files; and
- pose IDs that Animated Story Mode can reference dynamically.

Outfits, hair, animals, and full character creation remain separate work.
Sprite Studio edits an already prepared compatible rig and can swap approved
face-expression layers without redesigning the character.

## 2. Required fixed layer rules

The editor must preserve these rules for the humanoid rig:

1. Right arm parts render in front of matching left arm parts.
2. Right leg parts render in front of matching left leg parts.
3. Upper arms render in front of lower legs.
4. The head remains above the body unless a future accessory explicitly uses
   a higher approved layer.

The canonical base order is:

```text
back
left lower leg
left upper leg
right lower leg
right upper leg
left lower arm
left upper arm
torso
right lower arm
right upper arm
head
front
```

The base humanoid body parts use locked layers, so their `Bring to front` and
`Send to back` controls are disabled. Future accessories may still use those
controls without changing the permanent anatomical order. The inspector shows
the selected part's effective layer and explains the lock.

Walking now uses the same fixed policy as every other pose; its temporary
layer `41` override has been removed.

## 3. Mouse, touchpad, and touch selection fix

The existing implementation gives every image its own alpha-aware render-box
hit test. There is no intentional mouse-only branch, so the reported external
mouse difference is most likely caused by tight transparent edges combined
with canvas scaling and rotated child coordinates.

Replace the separate hit targets with one canvas-level hit resolver:

1. Convert the pointer position into the rig's unscaled canvas coordinates.
2. Convert that point into each rotated part's local image coordinates.
3. Check parts from front to back using their effective layer order.
4. Use the PNG alpha mask for the exact first pass.
5. If no exact pixel is found, allow a small 6-8 logical-pixel opaque-edge
   tolerance so mouse clicks near thin limbs still work.
6. Use this same resolver for mouse, touchpad, touch, and stylus events.

The tolerance must not be a large rectangle. It expands only around opaque
pixels. Hovering with a mouse highlights the part that would be selected, and
the optional hitbox overlay displays the same calculated target.

Drag mode stays explicit:

- Off: click/tap selects, but pointer movement cannot change the pose.
- On: pointer-down selects, then dragging moves only that selected joint.

Acceptance checks include Windows display scaling at 100%, 125%, and 150%,
browser zoom at 100%, mouse and touchpad clicks on every limb, rotated limbs,
transparent gaps, and overlapping torso/leg areas.

## 4. Editor UI and UX

**Status: complete.** Desktop uses the fixed two-pane layout and mobile uses
the pinned canvas plus draggable inspector described below.

The sprite and transform controls must remain visible together.

### Desktop and tablet landscape

```text
+---------------------------------------------------------------+
| Sprite Studio | pose selector | New Pose | Undo | Redo | Save |
+--------------------------------+------------------------------+
|                                | Selected Part                |
|      fixed sprite canvas       | Transform / Layers / Pose    |
|      zoom and fit controls     | Rotation slider + number     |
|                                | X and Y slider + number      |
|                                | layer and display toggles    |
+--------------------------------+------------------------------+
```

- Use a two-pane layout instead of one long `ListView`.
- The left canvas stays fixed while the right inspector scrolls independently.
- The canvas gets Fit, Zoom In, Zoom Out, and Reset View controls.
- The right inspector uses three compact sections: Transform, Layers, and
  Pose.
- Rotation, X, and Y each have both a slider and a numeric field for precise
  input.
- Undo, Redo, and Save stay in a fixed header or footer.

### Mobile portrait

- Keep the sprite canvas pinned in the upper 42-48% of the screen.
- Put the inspector in a draggable lower sheet.
- Scrolling affects only the inspector, never the canvas.
- Collapsed inspector state still shows selected part, rotation, and X/Y.

The canvas always shows the selected alpha outline. Hitboxes and anchors are
optional because they are debugging aids, not part of the final sprite.

## 5. Bone posing controls

**Status: complete.** The editor derives ten controls from the existing rig,
shows an optional bone overlay, rotates limbs by dragging their handles, moves
the connected rig from its root, respects joint limits, and records each drag
as one Undo step.

Bones are editor controls built from the hierarchy and pivots already stored in
`rig.json`. They are not extra sprite images and they are never visible in
Animated Story Mode. This keeps the implementation small and preserves the
current pose format.

### Minimum humanoid controls

- one root handle on the torso for moving the whole connected rig;
- one neck/head joint;
- left and right shoulder joints;
- left and right elbow joints;
- left and right hip joints; and
- left and right knee joints.

This gives ten useful controls. The connecting bone lines are derived from each
part's `parent` and `pivot`, so a separate `bones.json` file is not needed.

### Bone mode interaction

- `Show bones` displays thin bone lines and large joint handles.
- `Bone mode` enables bone dragging; when it is off, the existing part
  selection and drag behavior remains unchanged.
- Clicking a joint or bone selects its matching sprite part and keeps the
  dropdown synchronized.
- Dragging a limb handle around its parent pivot changes that part's rotation.
- Dragging the root handle changes the torso X/Y and moves all descendants.
- One continuous drag creates one Undo entry, not an entry for every pointer
  update.
- Numeric Rotation/X/Y inputs remain available for final precise corrections.

The selected bone uses the primary color, unselected bones stay muted, and a
joint at its configured limit uses a warning color. Handles must be large
enough for mouse and touch, but the visible lines and handles must not affect
alpha hit testing or saved output.

### Bone limits and simple first version

Each rotatable part may add an optional range to `rig.json`:

```json
{
  "id": "lower_arm_right",
  "parent": "upper_arm_right",
  "pivot": {"x": 473.71, "y": 659},
  "rotationRange": {"min": -10, "max": 145}
}
```

The first version uses direct bone rotation only. It does not need inverse
kinematics: dragging a shoulder rotates the upper arm and the existing parent
chain carries the lower arm with it. A later version may add optional two-bone
IK for hands and feet only if direct posing is still too slow.

Bone edits continue to save as the existing `rotation`, `x`, and `y` part
transforms. Loading an old pose therefore still works.

## 6. Default face catalog

**Status: complete.** The face-free head base and five aligned expression
layers live in `assets/images/characters/rigs/humanoid_v1/faces/`. Sprite Studio
loads them from `catalog.json`, saves `faceExpressionId` in pose JSON, and
includes face changes in Undo/Redo.

Use five approved transparent expressions for the first catalog:

1. Neutral
2. Talking
3. Happy
4. Sad
5. Angry

`Surprised` is not required for the first version. It can be added later only
if chapter testing shows that it is used often enough.

Every expression PNG must use the exact same canvas size and face alignment as
the compatible head base. Only the eyes, eyebrows, nose when needed, and mouth
change. The head shape, position, scale, skin, and identity stay fixed. White
eye areas and pupil highlights must remain opaque instead of being removed by
the transparency cleanup.

Runtime starter files belong here:

```text
assets/images/characters/face_catalog/default_humanoid/
|-- catalog.json
|-- neutral.png
|-- talking.png
|-- happy.png
|-- sad.png
`-- angry.png
```

`catalog.json` stores a stable face ID, label, asset path, compatible rig/head
ID, canvas size, and optional alignment offset. Sprite Studio shows these five
faces in a compact thumbnail grid and overlays the selected face above the head
base and below future front hair or accessories.

The selected `faceExpressionId` participates in Undo/Redo and is saved with a
pose. Talking follows the deliberately small expression rule:

- neutral dialogue uses `talking` while that line plays;
- happy, sad, or angry dialogue keeps its stronger expression; and
- no separate `angry_talking`, `sad_talking`, or other combinations are
  required.

The default catalog is the fallback and testing pack. A finished story
character may later have its own folder with the same five IDs so appearance
stays consistent across every chapter and volume:

```text
books/<book-id>/story-bible/characters/<character-id>/sprites/faces/
```

Unknown or missing expressions always fall back to `neutral`.

## 7. Named custom poses

Add a `+ New Pose` action:

1. Ask for a unique display name.
2. Create a safe stable ID from the name.
3. Start from the untouched neutral pose.
4. Open it immediately in Sprite Studio.
5. Mark it as unsaved after the first edit.

Name rules:

- 2-40 visible characters;
- no blank-only or duplicate names;
- stable lowercase ID with letters, numbers, and underscores; and
- changing the display name does not change an existing pose ID.

Built-in poses are Neutral, Talking, Pointing, and Walking. They may be
edited by the local development admin, but normal users cannot delete them.
Custom poses can be renamed, duplicated, or deleted after confirmation.

Switching poses with unsaved changes asks the user to Save, Discard, or Cancel.

## 8. Pose data and folders

Each pose stores transforms and optional layer values, not rendered images:

```json
{
  "id": "thinking",
  "name": "Thinking",
  "rigId": "humanoid_v1",
  "faceExpressionId": "neutral",
  "layerPolicyVersion": 1,
  "parts": {
    "upper_arm_right": {
      "rotation": 25,
      "x": 0,
      "y": 0,
      "layer": 32
    }
  }
}
```

Bundled demo files:

```text
assets/images/characters/rigs/humanoid_v1/
|-- rig.json
|-- pose_manifest.json
|-- base/*.png
`-- poses/
    |-- neutral.json
    |-- talking.json
    |-- pointing.json
    `-- walking.json
```

Runtime custom poses belong in app-local storage, not Flutter assets:

```text
sprite-studio/rigs/<rig-id>/poses/<pose-id>.json
```

Book-specific character poses remain in the shared story bible:

```text
books/<book-id>/story-bible/characters/<character-id>/sprites/poses/
```

Use a small `PoseRepository` so the UI does not care whether a pose comes from
bundled assets, mobile app storage, or browser local storage.

## 9. Save behavior

- `Save in session`: temporary draft used for quick comparison and Undo/Load.
- `Save Pose`: persists a custom pose in app-local storage across restarts.
- `Save as project default`: development-only action that writes an approved
  built-in or custom JSON file through the local admin server.
- `Copy JSON`: exports the same validated data without changing storage.

Every save includes rotation, X/Y, effective layers, pose name, rig ID,
`faceExpressionId`, and layer-policy version. Loading runs rig, face-catalog,
and layer validation before the pose is displayed.

The development admin replaces its four-name whitelist with safe pose-ID
validation and updates `pose_manifest.json` when a new project pose is added.
It must reject path separators, unknown body-part IDs, invalid numbers, and an
incompatible rig ID.

## 10. Animated Story Mode integration

Story scenes reference a pose instead of storing another body image:

```text
CharacterLayer
- characterId
- rigId
- poseId
- faceProfileId
- faceSetId
- faceExpressionId (legacy fallback)
- outfitId
- stagePosition
- movement
```

Gemini analysis may request semantic tags such as `neutral`, `talking`,
`pointing`, or `walking`. A local pose mapper chooses a compatible approved
pose ID. Gemini does not create joint values directly.

Fallbacks:

- missing requested pose -> Neutral;
- incompatible rig -> hide the character and show subtitles;
- missing expression -> neutral face;
- missing profile or set -> Default profile and Neutral set;
- invalid layer data -> normalize using the rig's fixed layer policy.

The player loads the pose once and applies simple stage movement separately.
Walking across the screen moves the whole character while the Walking pose
controls its joints.

## 11. Implementation order

### Part 1 - Stability

- Rename the page and navigation label to Sprite Studio.
- Remove the temporary Walking layer `41` override and normalize every built-in
  pose against the canonical layer policy.
- Add the central pointer hit resolver and opaque-edge tolerance.
- Test mouse, touchpad, touch, scale, rotation, and overlapping parts.
- Add the fixed layer-policy validator and migrate the four built-in poses.

### Part 2 - Editor layout

- Replace the single scrolling page with responsive canvas and inspector panes.
- Add numeric Rotation/X/Y input, zoom controls, Undo, and Redo.
- Keep the canvas visible while the inspector scrolls.

### Part 3 - Bone posing - complete

- Derive the ten humanoid controls from the existing parent and pivot data.
- Add Show bones and Bone mode toggles.
- Rotate a selected part by dragging its bone around the parent joint.
- Move the complete rig by dragging the torso root.
- Add optional per-joint rotation limits in `rig.json`.
- Keep bone drags connected to the existing Undo/Redo and numeric inputs.

### Part 4 - Default face catalog - complete

- Prepare the five aligned transparent face layers.
- Add `catalog.json` and a small catalog loader.
- Add the five-thumbnail Face section in Sprite Studio.
- Save and restore `faceExpressionId` with Undo/Redo and pose data.
- Validate the neutral fallback and talking-priority rule.

### Part 5 - Pose creation and storage - complete

- Add pose metadata and `pose_manifest.json`.
- Add `PoseRepository` and app-local storage.
- Implement New Pose, Rename, Duplicate, Delete, Save, and unsaved-change guard.
- Extend the local project admin to accept safe custom pose IDs.

### Part 6 - Story Mode connection - complete

- Add `poseId` and `rigId` to character scene layers.
- Map analyzer pose tags to approved local poses.
- Add Neutral fallback and compatibility validation.
- Play one test chapter using at least Neutral, Talking, Pointing, and Walking.

### Part 7E - Modular face connection - complete

- Save `faceProfileId` and `faceSetId` with poses and scene character layers.
- Let a scene override the pose face selection when required.
- Render the selected modular actor face in Story Mode.
- Keep legacy `faceExpressionId` scenes working through safe fallback mapping.

### Part 7F - Full actor and chapter review - complete

- Group all cleaned source blocks into 4-10 ordered scenes without dropping
  chapter text.
- Resolve Default, Hero, Heroine, Elder, and Adult through the real player.
- Exercise Neutral, Talking, Pointing, and Walking in one review chapter.
- Validate speaking and strong-emotion fallbacks with project assets.

The default `humanoid_v1` rig is only the test character. A generated book
character gets its own stable `rigId`, body-part assets, `rig.json`, face
catalog, outfit layers, and compatible pose files. Story scenes use the
`characterId + rigId + poseId + faceProfileId + faceSetId` contract while still
reading legacy `faceExpressionId`, so adding new faces or a fully designed body
does not require changing the player.

## 12. Final acceptance checklist

Sprite Studio is complete when:

- every body part selects correctly with mouse, touchpad, and touch;
- the canvas never disappears while adjusting Rotation or X/Y;
- drag-off prevents movement but still allows selection;
- Undo and Redo cover transforms and layers;
- fixed right/left and arm/leg layer rules hold in every pose;
- bone handles rotate the correct connected chain without changing layer order;
- turning off Bone mode prevents joint movement but still permits selection;
- every default face aligns with the same head and preserves eye whites and
  highlights;
- neutral speech changes to Talking while stronger emotions remain unchanged;
- a named pose starts from Neutral and survives an app restart;
- session and project-default saves preserve layer order;
- invalid names and incompatible pose files are rejected safely; and
- Animated Story Mode can load a saved `poseId`, `faceProfileId`, and
  `faceSetId` with Default/Neutral fallbacks.
- one complete review chapter preserves all source blocks and resolves every
  starter actor.
