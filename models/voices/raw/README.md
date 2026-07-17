# Raw RVC Voice Downloads

Place one downloaded `.pth` and its matching `.index` or `.model` file in each
role folder:

```text
narrator/
heroine/
hero/
deep/
elder/
```

Keep the original filenames. These files are conversion inputs and are ignored
by Git. Do not move them into Flutter assets.

Run `./tool/sync_voices.ps1` after replacing a model. It validates each pair,
regenerates changed chapter audio, and updates the Flutter voice manifest.
