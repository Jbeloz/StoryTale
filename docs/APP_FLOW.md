# StoryTale App Flow

```mermaid
flowchart TD
    A["Open Local Library"] --> B["Upload or choose EPUB"]
    B --> P["Confirm volume and chapter boundaries"]
    P --> R["Clean one chapter into source blocks"]
    R --> S["Gemini returns structured story analysis"]
    S --> Q["Review and update locked book story bible"]
    Q --> T["Generate or reuse required approved assets"]
    T --> U["Gemini plans scenes using approved IDs only"]
    U --> V["Validate and save ChapterStory package"]
    V --> C["Choose prepared chapter"]
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
- Matching sprite or focus asset is missing: hide that layer and use an approved
  location/detail shot with subtitles or narration. Never substitute an
  unrelated prototype human.

See [Animated Story Mode plan](ANIMATED_STORY_MODE_PLAN.md) for the full preparation pipeline.
See the [Master Roadmap](ROADMAP.md) for current implementation status.
