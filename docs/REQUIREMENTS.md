# StoryTale Requirements

## Local E-Library

- Users can upload their own `.epub` books.
- Invalid or protected files show a clear error.
- Books, covers, chapters, favorites, and reading progress stay on the device.
- Supabase is not used in the first version.

## Reader and DeepL Translation

- Read original EPUB chapters with adjustable text.
- Translate English words or chapters into Filipino using DeepL only.
- Cache translations locally to reduce character usage.
- Reading still works when DeepL is unavailable.

## Text-to-Speech

- Play, pause, stop, and change speed.
- Run narration inside the app using offline ONNX models instead of installed Android voices.
- Install five selectable voice packs for the narrator and characters.
- Use an offline Tagalog base TTS model before applying a selected RVC voice.
- Prepare and cache chapter audio in the background before Story Mode playback.
- Highlight the text currently being spoken.

## Story Mode

- A book may contain one or more ordered volumes, and each volume contains
  ordered chapters.
- Every chapter may have its own Story Mode.
- Story preparation identifies recurring characters, aliases, dialogue
  speakers, locations, plot beats, and exact chapter boundaries.
- Gemini analyzes one cleaned chapter at a time and returns schema-validated
  structured story data.
- The prepared script keeps the complete normalized chapter text in order from
  its first content block to its last content block.
- A chapter includes sprites, backgrounds, subtitles, simple movement, voices, and sound effects.
- A short moral appears at the end of each chapter.
- Chapter content is saved and reused locally.
- Accepted characters, sprites, locations, and voices are reused across
  chapters and volumes through a shared story bible.
- Approved character appearance is locked. Sprites use transparent body layers,
  separate expression-head layers, and stored head anchors.
- Sprites and backgrounds may be generated through the private Cloudflare image Worker, reviewed, and then saved locally.
- Background music is not required for the first version; sound effects remain optional.

## Safety and Quality

- Do not commit the DeepL API key.
- Do not commit the Gemini API key or bundle it into Flutter.
- Do not commit the Cloudflare Worker token or Cloudflare account credentials.
- Tell users before chapter text is sent to DeepL.
- Rate-limit image generation and avoid logging story prompts.
- Use only original, public-domain, user-owned, or licensed content.
- Keep the UI mobile-first, readable, dynamic, and suitable for common Android devices.
- Load only one voice pack at a time and test performance on the target Android phone.

## Not included yet

- PDF or Word upload
- Public book marketplace
- Cloud database or account syncing
- DRM bypassing
