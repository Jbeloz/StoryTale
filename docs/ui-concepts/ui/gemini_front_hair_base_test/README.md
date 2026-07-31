# Gemini front-hair base test

This test creates one reusable **front-hair-only** layer for the StoryTale
humanoid head. Back hair is intentionally excluded.

## References

1. `character_head_no_space.png` locks the head size, angle, and canvas.
2. `codex-clipboard-764f192a-f62d-4011-9bb4-a93fec341c85.png` provides the
   dark, spiky chibi hairstyle direction.

## Prompt

> Dark navy-blue chibi front hair with a softly rounded crown, several playful
> upward crown tufts, layered side spikes, and long tapered bangs that frame the
> forehead like the hairstyle inspiration. Keep the center bangs above or
> between the eyes so both eyes and the lower face remain clearly visible. This
> is the reusable neutral StoryTale front-hair base. Generate only the isolated
> front-hair layer; no back hair.

## Outputs

- `gemini_source.jpg` — original Gemini result.
- `front_hair_transparent.png` — cleaned transparent hair-only layer.
- `front_hair_on_head.png` — alignment preview on the locked StoryTale head.

The app asset is
`assets/images/characters/rigs/humanoid_v1/hair/front_default.png`.
