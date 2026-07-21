# StoryTale App Flow

```mermaid
flowchart TD
    A["Open Local Library"] --> B["Upload or choose EPUB"]
    B --> P["Confirm volume and chapter boundaries"]
    P --> R["Clean one chapter into source blocks"]
    R --> S["Gemini returns structured story analysis"]
    S --> Q["Review and update locked book story bible"]
    Q --> T["Choose approved rig and Sprite Studio pose IDs"]
    T --> C["Choose chapter"]
    C --> D["Read original text"]
    D --> E["Translate with DeepL"]
    D --> G["Open chapter Story Mode"]
    G --> H["Load local ChapterStory data"]
    H --> F["Prepare offline chapter voices"]
    F --> K["Cache generated audio"]
    K --> I["Move sprites with voices, subtitles, and sound"]
    I --> J["Show chapter moral"]
    E --> D
    J --> C
```

## Fallbacks

- No internet: saved books, progress, installed voice models, and cached translations still work.
- DeepL fails: keep the original chapter and allow retry.
- Voice model is missing or fails: keep reading and subtitles available; do not block the chapter.
- Story data is missing: keep normal reading available.
- Volume boundary or dialogue speaker is uncertain: request review before
  preparing Story Mode; do not block normal reading.
- Sprite is missing: show a simple placeholder image.

See [Animated Story Mode plan](ANIMATED_STORY_MODE_PLAN.md) for the full preparation pipeline.
