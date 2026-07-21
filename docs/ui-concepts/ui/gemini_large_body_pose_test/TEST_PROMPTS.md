# Larger Body Pose Test

This is an isolated no-code test using the enlarged `../character_body.png` reference.

- Reference and final canvas: `419 x 481`.
- Gemini test aspect ratio: `4:5`, which gives the arms more horizontal room than the earlier `9:16` test.
- The generated background is pure green and is removed locally before each final transparent PNG is saved.

## Pose prompts

1. `body_talking_wide.png`: Edit only the pose of this exact headless body into a clear talking or presenting pose: extend the left arm farther away from the torso with the elbow bent and palm open upward, keep the right arm relaxed, keep both legs and closed rounded feet unchanged, preserve the narrow neck opening, body proportions, pale fill, shading, and black line art, keep the complete body centered inside the 419 x 481 canvas with no clipping, and use only a flat pure green background.
2. `body_action_wide.png`: Edit only the pose of this exact headless body into a strong action pose: fully extend the right arm sideways to point, bend the left arm slightly backward, place the legs in a small stable staggered stance, preserve the narrow neck opening, limb thickness, closed rounded feet with no toes, pale fill, shading, and black line art, keep the complete body centered inside the 419 x 481 canvas with no clipping, and use only a flat pure green background.
3. `body_reaction_wide.png`: Edit only the pose of this exact headless body into a clear surprised or defensive reaction: move both arms outward and upward with bent elbows and open palms facing forward, separate the feet slightly while keeping their closed rounded shape, preserve the narrow neck opening, torso size, limb thickness, pale fill, shading, and black line art, keep the complete body centered inside the 419 x 481 canvas with no clipping, and use only a flat pure green background.

## Locked face-expression rule

For every future face prompt, add this rule:

> Keep both eyes locked to their exact original coordinates, width, height, spacing, iris size, and art style; do not move, enlarge, shrink, rotate, or replace either eye, and change only the eyelids, eyebrows, and mouth necessary for the expression.

For anger specifically, use:

> Make the face look angry only by lowering the eyebrows toward the center, lowering the upper eyelids slightly without moving or resizing the eyes, and changing the mouth to a small clenched-teeth expression; keep both eyes, irises, nose mark, and every facial coordinate exactly unchanged.

## Test result

- All three final files are `419 x 481` transparent PNGs.
- Gemini generated a green background; StoryTale removed it locally. Gemini did not directly return the final transparency.
- The larger canvas gives the arms enough room for talking, pointing, and two-arm reaction poses without clipping.
- `body_talking_wide.png` preserves the original proportions best.
- `body_action_wide.png` creates the requested pointing pose, but Gemini still changes the neck into a raised collar and widens the stance.
- `body_reaction_wide.png` fits both raised arms, but the hands become larger than the reference.
- Use the larger body canvas for pose freedom, but keep the neutral reference as the approved geometry and reject generated poses when the neck, hands, or proportions drift.
