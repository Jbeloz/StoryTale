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

Set each RVC conversion pitch in `models/voices/voice_settings.json`. Heroine
and Hero default to `+16`; valid values are `-24` through `+24`.

Use `./tool/run_storytale.ps1` to sync changed models and pitches before the
web app starts. `flutter run` alone does not run the voice converter, so it can
keep the previously generated voice files.
