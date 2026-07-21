# Character Sprite Template

Keep every layer on the same canvas size and use a transparent background.

```text
_sprite_template/
|-- bodies/
|   `-- default/
|       `-- poses/
|           |-- idle.png
|           |-- talking.png
|           |-- pointing.png
|           `-- walking.png
|-- heads/
|   `-- expressions/
|       |-- neutral.png
|       |-- happy.png
|       |-- sad.png
|       |-- angry.png
|       `-- surprised.png
`-- composites/
    `-- full-neutral.png
```

- A body pose stops at the neck and does not contain a head.
- A head file contains the complete head and expression only.
- `full-neutral.png` is the reviewed head-and-body preview.
- Keep the head about 45% and the body about 55% of the full character height.
- Keep the head wider than the shoulders, matching the proportion references in
  `docs/ui-concepts/ui/character_*.png`.
- Lock one outline color for every layer. The current approved example uses
  blue-black `#081440`; do not mix it with pure black body outlines.
- New clothing uses another folder beside `default`, with the same `poses`
  filenames.
