# StoryTale Character Sheet V4 Provider Contract

## What this request is

This is an **edit of image 1**, not a new illustration. Image 1 already contains
twelve separate shapes on a flat green background. Return that same image at
exactly `1024 x 1024`, `1:1` aspect ratio, `1K` size, with paint added to those
shapes and nothing else changed.

- Twelve shapes go in and twelve shapes come out.
- Every shape keeps its exact position, size, and outline. Nothing moves,
  rotates, scales, or is recentered.
- Do not add a thirteenth shape. Do not merge, split, or reorder shapes.
- Do not re-lay-out, rearrange, or tidy the sheet. The layout is fixed.
- Do not draw the assembled character anywhere on this canvas.

If you would change where something sits in order to compose a better picture,
that is the failure this contract exists to prevent.

## The five supplied images, in order

1. **The sheet to edit and return.** The only image whose pixels you output.
2. **The assembled reference** - how the separated parts connect on a finished
   character. Context for style and continuity only; never copy it into image 1.
3. **Allowed mask** - white pixels may receive new paint.
4. **Protected mask** - white pixels must keep the pixels already in image 1.
5. **Seam mask** - white markers show where neighbouring parts join.

Images 3 to 5 share image 1's `1024 x 1024` canvas, pixel for pixel.

## The twelve cells, in canvas coordinates

Each line is `cell_id  left,top  width x height`. These rectangles are fixed and
are the only places paint may appear.

```
back_hair_selected   18,18     429x800
front_hair          465,18     429x438
head                465,474    357x367
torso               840,474    165x234
upper_leg_right      18,836     94x150
lower_leg_right     130,836     84x156
upper_leg_left      232,836     85x141
lower_leg_left      335,836     88x140
upper_arm_right     465,859     67x118
lower_arm_right     550,859     77x145
upper_arm_left      645,859     78x128
lower_arm_left      741,859     86x129
```

The eight limb cells form two blocks: **legs on the left**, spanning `x` 18 to
423, and **arms on the right**, spanning `x` 465 to 827, separated by a channel
wider than the normal gap. Within each block the order is right limb first, then
left, and hip or shoulder before knee or elbow. Match each shape to its cell by
these coordinates, not by what the shape looks like.

## The green gap is untouchable

Every pixel outside the twelve rectangles above is background: an `18` pixel gap
around every cell and around the canvas edge. That is **256,187 pixels**, a
quarter of the canvas.

It must come back exactly flat `#00FF00`. **Any mark in the gap voids the
result** - a stray line, a shadow, an overhanging sleeve, a garment placed
between cells, or artwork nudged a few pixels outside its rectangle. Nothing
legitimate is ever drawn there.

## Clothing is paint on a body part, never a separate object

Each cell holds exactly one body part, and the clothing worn on that part is
painted onto it, inside its silhouette.

- A boot is **not** a boot-shaped object placed near a leg. It is paint on the
  lower end of `lower_leg_right` and `lower_leg_left`, following the leg outline
  already in that cell and stopping where that outline stops.
- The same is true of sleeves, gloves, a coat, trousers, and a collar.
- No garment is drawn on its own, floating free of a body part.
- No garment spans two cells or bridges the gap between them.

## Cell size is not target size

A cell is a container, not a target. Several cells are larger than the artwork
they hold, so **do not fill a cell to its edges.** Match the extent of the shape
already drawn in that cell.

The rear-hair cell is the clearest case. It is `429 x 800` because it must be
able to hold the longest style, so shorter styles leave much of it green: short
occupies `412 x 404`, medium `425 x 546`, and long `390 x 784`.

Front hair fills `424 x 389` of its `429 x 438` cell. **Front and rear hair are
deliberately the same width** so the two layers sit together on the head: rear
hair is `425` wide against front hair's `424`. Keep that match. Rear hair must be
neither narrower, which lets the front hair overhang it, nor much wider.

## This request

Values written in double braces are replaced by StoryTale before the request is
sent. They are data fields, not permission to change the geometry contract. If
any of them still reads as a brace placeholder when you receive this, reject the
request rather than inventing a character.

First reason about the character as one complete front-facing person, then paint
only that character's appearance into the cells listed above.

Character identity: `{{character_name}}`  
Source-backed design brief: `{{character_design_brief}}`  
Age and role: `{{age_and_role}}`  
Skin tone: `{{skin_tone}}`  
Hair requirements: `{{hair_requirements}}`  
Selected rear-hair cell: `{{selected_back_hair_region}}`  
Outfit requirements: `{{outfit_requirements}}`  
Approved accessories for this request: `{{approved_accessories_or_none}}`

The rear-hair value is either `back_hair_selected`, meaning paint the one rear
length described in the hair requirements onto the shape already in that cell, or
`none`, meaning leave that cell flat green. There is no other valid value.

## The head cell

`head` shows the exact head StoryTale composes at runtime: bald, faceless, with
only an ear outline. **That is not a placeholder to complete.**

Eyes, eyebrows, nose, and mouth are **not generated**. StoryTale draws them
locally from its own modular face parts, once per expression, over whatever this
cell returns. Anything drawn where a face belongs is either overwritten or
rejected, and a face drawn outside the allowed window fails the request.

What the allowed window is for is character-specific *detail* on the skin -
freckles, a birthmark, a scar, blush, a face marking - that belongs to this
character and stays valid across every expression. The head content sits slightly
inside its cell, occupying `325 x 343` of the `357 x 367` rectangle.

## Hair rules

- Paint one front-hair layer onto the shape in `front_hair`.
- Paint one rear-hair layer onto the shape in `back_hair_selected`, at the length
  named above, keeping that shape's existing silhouette.
- Both hair layers belong to the same character: identical color, line style,
  texture, highlights, and crown/hairline logic.
- The rear layer must attach correctly to the same front-hair layer and head.
- Hair stays independent from the head and body pixels.
- `none` means leave `back_hair_selected` flat green; it is a runtime visibility
  choice and needs no artwork.

## Character and clothing rules

- Keep one identity across the face details, hair, palette, and outfit.
- In `head`, modify only the allowed facial-detail area. Do not redraw the locked
  head silhouette, ears, neck edge, or protected pixels.
- **The head is bald and faceless on purpose, and must stay that way.** Do not
  draw eyes, eyebrows, a nose, or a mouth.
- Right-side artwork stays in right-side cells and left-side artwork stays in
  left-side cells.
- The separated head, torso, arms, legs, and hair must assemble into the supplied
  assembled reference without changing pivots or seams.
- Do not add scenery, shadows, text, labels, borders, props, extra characters, or
  unrelated objects.

## Clothing continuity across joints

This is the part most likely to fail, so it is stated explicitly.

Garments are painted in separate cells but must read as one outfit on the
assembled character. Seam markers sit at the joints each cell shares with its
neighbour:

- `torso` meets `head` at the neck, both upper arms at the shoulders, and both
  upper legs at the hips.
- each `upper_arm_*` meets `torso` at the shoulder and its `lower_arm_*` at the
  elbow.
- each `upper_leg_*` meets `torso` at the hip and its `lower_leg_*` at the knee.

Where a garment crosses one of those joints, its edge colour, thickness, trim,
fold direction, and shading must match on both sides of the seam, so the two
cells line up when the rig is posed. A sleeve that ends at the elbow in
`upper_arm_right` must continue at the same width and colour where
`lower_arm_right` begins. Matching across a seam never means drawing across the
gap between the two cells.

## Check before returning

1. Exactly `1024 x 1024`.
2. Twelve shapes, each still at its listed rectangle and its original size.
3. Every pixel outside those rectangles flat `#00FF00`.
4. No free-standing garment anywhere.
5. The head still bald and faceless.
6. Front and rear hair the same character.

Reject the result if any of those fails, if the format or dimensions differ, if
locked geometry changed, if clothing fails to match across a seam, or if the
separated parts cannot reproduce the supplied assembled character.
