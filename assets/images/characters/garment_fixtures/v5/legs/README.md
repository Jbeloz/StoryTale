# V5 legs clothing fixture

This is a local, deterministic review fixture for the V5 legs group. It uses
the locked `humanoid_v1` leg alpha masks and paints a simple navy leggings /
brown shoes design **inside those masks only**. It is not a provider response,
does not replace any runtime body part, and costs no credits.

## Files

- `legs_clothing_fixture_1k.png` — 1024x1024 green-screen review sheet.
- `upper_leg_left_clothing.png` and `upper_leg_right_clothing.png` — pants overlays.
- `lower_leg_left_clothing.png` and `lower_leg_right_clothing.png` — pants plus shoes overlays.
- `manifest.json` — source hashes, native sizes, placements, and mask guarantees.

The transparent overlays are ready for the existing `SpriteGarmentLayer` shape,
but they are not registered in Flutter until the owner approves the design and
the offline V5-3 group path is complete.
