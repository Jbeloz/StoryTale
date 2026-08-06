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
wider than the normal gap. Match each shape to its cell by these coordinates, not
by what the shape looks like.

## A limb shape is one segment, not a whole limb

Reading left to right, the four leg shapes are **right thigh, right shin, left
thigh, left shin**, and the four arm shapes are **right upper arm, right forearm,
left upper arm, left forearm**.

Each is **one segment of a limb**. A thigh fills its own shape. A shin fills its
own shape. They are drawn apart because the character is assembled from separate
pieces afterwards.

**Nothing you paint may be larger than the shape you paint it on.** These shapes
are only `118` to `156` pixels tall. A complete leg does not fit in one, so a
complete leg must never be drawn in one, at any size.

The failure this prevents, stated so it can be checked: **a trouser and a boot in
the same shape means a whole leg was drawn where one segment belongs.** A thigh
shape shows trouser only. A shin shape shows whatever covers the shin — the lower
trouser, the boot, or both, because that is what a shin wears.

Nothing may extend above, below, or beside its shape to make a limb look
complete. The space around these shapes is background, not room to finish a leg.

## The green gap is untouchable

Every pixel outside the twelve rectangles is background: an `18` pixel gap around
every cell and around the canvas edge, **256,187 pixels**, a quarter of the
canvas. It must come back exactly flat `#00FF00`. **Any mark there voids the
result** - a stray line, a shadow, an overhanging sleeve, a garment placed between
cells, or artwork nudged a few pixels outside its rectangle.

## Clothing is paint on a body part, never a separate object

Each cell holds one body part, and the clothing worn on it is painted onto that
part, inside its outline and stopping where the outline stops. A boot is not a
boot-shaped object placed near a leg; it is paint on a shin shape. The same goes
for sleeves, gloves, a coat, trousers, and a collar. No garment is drawn floating
free of a body part, and none spans two cells or bridges the gap between them.

## Green inside a cell stays green

A cell is a container, not a target. Every cell is bigger than the shape it
holds, and the leftover green inside it is **not free canvas**. It is not space
to fill, balance, decorate, or add anything to.

Paint only the one shape already drawn in the cell. Green inside a cell that the
shape does not cover must come back green.

- `back_hair_selected` is `429 x 800`, but the hair fills only the top of it:
  `412 x 404` for short, `425 x 546` for medium, `390 x 784` for long. **The
  empty lower part of that cell stays green.** Do not put an arm, a hand, a
  garment, or anything else in it.
- `front_hair` is `429 x 438` and the hair fills `424 x 389`. The green around
  the locks, and between them, stays green.

**Front and rear hair are deliberately the same width** so the two layers sit
together on the head: rear hair is `425` wide against front hair's `424`. Keep
that match. Rear hair must be neither narrower, which lets the front hair
overhang it, nor much wider.

## One shape per cell

Each cell contains exactly one shape and comes back with exactly one shape.

- Never add a second object to a cell. No extra arm, hand, leg, foot, or
  duplicate of any part, anywhere on the sheet.
- The two hair cells take **hair only**. No hood, cowl, hat, cap, headband,
  bandana, helmet, collar, or scarf. A hood is not hair; if the character wears
  one, it is not drawn on this sheet.
- Body cells take the body part and the clothing worn on it, nothing else.

## The outline is locked; paint inside it

Every body part is a dark outline around a pale interior. **That outline, and the
pixels immediately inside it, are locked geometry.**

- Paint the clothing into the interior, up to the outline and never over it.
- Do not re-ink, thicken, thin, soften, recolour, or redraw any outline.
- Do not let colour spill across an outline.
- Do not reshape a part to suit a garment. The silhouette is fixed.

The hair shapes work the same way: recolour and shade the shape that is there.
Do not add spikes, strands, wisps, or tips beyond its outline, and do not restyle
it. Keep shading simple - the base colour, one shadow, and one highlight - rather
than many dark streaks.

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
only an ear outline. **That is not a placeholder to complete.** Eyes, eyebrows,
nose, and mouth are **not generated** - StoryTale draws them locally from its own
modular parts, once per expression, over whatever this cell returns, so anything
drawn where a face belongs is overwritten or rejected.

The allowed window is for character-specific *detail* on the skin - freckles, a
birthmark, a scar, blush, a marking - that belongs to this character and stays
valid across every expression. The head content occupies `325 x 343` of the
`357 x 367` rectangle.

## Hair and character rules

- Both hair layers belong to the same character: identical colour, line style,
  texture, highlights, and crown/hairline logic, and the rear layer must sit
  correctly behind that same front layer and head.
- Hair stays independent of the head and body pixels.
- `none` means leave `back_hair_selected` flat green; it needs no artwork.
- Keep one identity across the face details, hair, palette, and outfit.
- In `head`, paint only inside the allowed facial-detail area. Do not redraw the
  locked head silhouette, ears, or neck edge.
- Right-side artwork stays in right-side cells and left-side artwork stays in
  left-side cells.
- Do not add scenery, shadows, text, labels, borders, props, extra characters, or
  unrelated objects.

## Clothing continuity across joints

Garments are painted in separate cells but must read as one outfit once the parts
are assembled. `torso` meets `head` at the neck, both upper arms at the
shoulders, and both upper legs at the hips; each upper arm meets its forearm at
the elbow, and each thigh meets its shin at the knee.

Where a garment crosses one of those joints its edge colour, thickness, trim,
fold direction, and shading must match on both sides. A sleeve ending at the
elbow in `upper_arm_right` must continue at the same width and colour where
`lower_arm_right` begins. Matching across a seam never means drawing across the
gap between the two cells.

## Check before returning

1. Exactly `1024 x 1024`.
2. Twelve shapes, each still at its listed rectangle and its original size.
3. Every pixel outside those rectangles flat `#00FF00`.
4. Green left over inside a cell still green; nothing added to empty space.
5. Exactly one shape per cell. No extra limbs, and nothing but hair in the two
   hair cells.
6. No whole limb in a single shape; no trouser and boot sharing one shape.
7. Every outline unchanged in shape, thickness, and colour.
8. No free-standing garment anywhere.
9. The head still bald and faceless.
10. Front and rear hair the same character.

Reject the result if any of those fails, if the format or dimensions differ, if
locked geometry changed, if clothing fails to match across a seam, or if the
separated parts cannot reproduce the supplied assembled character.
