# StoryTale UI Concepts

The current custom app flow is stored in `ui/` and contains pages 1-17,
including two states for page 13 and the audiobook screen.

- [UI implementation plan](UI_IMPLEMENTATION_PLAN.md)
- [Prompts used](PROMPTS.md)

The implementation plan is the source of truth for recreating these images as
responsive, reusable Flutter screens. The
[Master Roadmap](../ROADMAP.md) owns project status and development order.

This folder contains three complete visual directions for the same StoryTale app. Every direction has the same seven pages and the same features, so the comparison is based on visual design instead of missing content.

## Shared page list

1. `01-library.png` - local EPUB library
2. `02-import-epub.png` - EPUB upload and validation
3. `03-book-details.png` - book details and chapter list
4. `04-reader-translation.png` - chapter reader with DeepL translation
5. `05-narration.png` - offline voice model controls and five voice profiles
6. `06-story-mode.png` - sprites, backgrounds, subtitles, and movement
7. `07-chapter-moral.png` - chapter completion and moral

## Three directions

| Folder | Direction | Best quality |
| --- | --- | --- |
| `type-1-cozy-storybook/` | Cozy Storybook | Friendly, warm, and suitable for younger readers |
| `type-2-clean-academic/` | Clean Academic | Clear, accessible, and easy to build |
| `type-3-immersive-adventure/` | Immersive Adventure | Atmospheric and strongest for Story Mode |

## Comparison rule

Compare the same filename across all three folders. Check readability, navigation clarity, age suitability, implementation difficulty, and how well normal reading connects to Story Mode.

These files are visual references only. They do not change the Flutter implementation.
