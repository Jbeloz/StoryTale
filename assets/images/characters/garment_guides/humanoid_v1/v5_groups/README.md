# V5 part-group 1K reference sheets

These three PNGs are deterministic geometry references for the V5 clothing
groups. They are not generated garments and are not runtime replacements for
the immutable `humanoid_v1` parts.

## Files

- `legs_1k_reference.png` — left column: left upper/lower leg; right column: right upper/lower leg.
- `arms_1k_reference.png` — left column: left upper/lower arm; right column: right upper/lower arm.
- `torso_1k_reference.png` — one centered torso reference.

Each canvas is exactly 1024x1024. Every source part is copied at its exact
native runtime size. The flat `#00FF00` background is intentionally removable
by `SpriteGarmentSeparator`; it is not part of the clothing output.

The later provider prompt must request clothing overlays only, with no skin,
no replacement body geometry, and no text or labels. The `manifest.json` file
records the exact source hash, native size, and canvas placement for every part.
