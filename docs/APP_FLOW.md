# StoryTale App Flow

```mermaid
flowchart TD
    A["Open Local Library"] --> B["Upload or choose EPUB"]
    B --> C["Choose chapter"]
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
- Sprite is missing: show a simple placeholder image.
