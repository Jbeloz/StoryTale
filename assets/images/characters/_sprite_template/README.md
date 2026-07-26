# Character Sprite Template

This folder is a legacy visual reference. New StoryTale humanoids use one
approved transparent master, reusable rig parts, modular face parts, and JSON
poses:

```text
<character-id>/
|-- profile.json
`-- sprites/
    |-- master-transparent.png
    |-- rig.json
    |-- base-parts/
    |   |-- torso.png
    |   |-- upper_arm_left.png
    |   |-- upper_arm_right.png
    |   |-- forearm_hand_left.png
    |   |-- forearm_hand_right.png
    |   |-- thigh_left.png
    |   |-- thigh_right.png
    |   |-- lower_leg_foot_left.png
    |   `-- lower_leg_foot_right.png
    |-- faces/
    |   |-- eyes/
    |   |-- noses/
    |   |-- mouths/
    |   `-- details/
    |-- outfits/<outfit-id>/parts/
    |-- poses/<pose-id>.json
    `-- composites/full-neutral.png
```

- Generate and approve one complete master before splitting it.
- Keep every reusable face layer aligned to the same transparent head canvas.
- `rig.json` stores parent, pivot, original placement, size, and layer order.
- A pose stores transforms in JSON; do not generate a separate body PNG for
  Idle, Talking, Pointing, or Walking.
- `full-neutral.png` is the reviewed rejoined preview and fallback.
- Keep the approved large-head, short-body chibi proportion and one consistent
  outline/color style.
- Clothing follows the matching rig parts and pivots. Loose coats, skirts, and
  capes may use separate approved overlay layers.

See `docs/SPRITE_STUDIO_PLAN.md`, `docs/MODULAR_FACE_SYSTEM_PLAN.md`, and
`docs/ROADMAP.md`.
