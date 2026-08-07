# V5 legs clothing fixture — flat Gacha-style v2

This is a second local review design. It uses exactly two flat colors: purple
leggings and pink shoes. There are no shadows, highlights, gradients, added
outlines, or details. Every nontransparent pixel is clipped to the matching
immutable `humanoid_v1` leg alpha mask, so the silhouette cannot change.

Files:

- `legs_clothing_fixture_1k.png` — 1024x1024 green-screen review sheet.
- Four transparent per-leg overlays with native runtime dimensions.
- `manifest.json` — source hashes, colors, placements, and mask guarantees.

This is a review fixture only. It is not a provider response and is not
registered in Flutter.
