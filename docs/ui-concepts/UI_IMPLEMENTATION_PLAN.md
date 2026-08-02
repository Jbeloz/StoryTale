# StoryTale UI Implementation Plan

This guide maps the current UI concept images to Flutter screens, reusable widgets, dynamic data, navigation, and required app artwork.

This is a UI design reference, not the project progress tracker. Some screens
listed as missing during the original mockup phase now have functional
prototype routes. Use the [Master Roadmap](../ROADMAP.md) for current status and
implementation order.

## Design rules

- Use the purple StoryTale design from the mockups.
- Use responsive Flutter layouts; do not copy fixed screenshot coordinates.
- Do not recreate the phone frame or fake status bar shown around the mockups.
- Keep content dynamic. Books, chapters, characters, voices, progress, and scenes must come from data models.
- Use `StoryTale` everywhere. Replace the remaining `StoryWorld` text in mockups 6 and 16.
- Keep book upload EPUB-only. Mockup 7 incorrectly mentions PDF.
- Use page 13's new Story Mode player as the preferred design. Page 12 remains a useful control reference.

## Visual system

| Element | Direction |
| --- | --- |
| Primary color | Deep StoryTale purple |
| Secondary color | Light lavender |
| Background | White or very light lavender |
| Text | Dark navy for body text; purple for actions and headings |
| Corners | Rounded cards, buttons, sheets, and fields |
| Shadows | Soft and low contrast |
| Spacing | Consistent 8, 12, 16, 24, and 32 pixel steps |
| Navigation | Four tabs: Library, Now Reading, Audio, Profile |

Final color values should live in `AppTheme`; pages should not define their own purple values.

## Screen map

### 1. Splash

Source: `ui/1 revamped.png`

- Full-screen lavender background.
- Storybook illustration, StoryTale logo, tagline, and loading indicator.
- Checks whether onboarding has already been completed.
- Goes to onboarding for first-time users or Library for returning users.
- Asset needs: `splash_storybook.png` and `brand_logo.png`.

### 2. Onboarding - Welcome

Source: `ui/2 revamped.png`

- Introduces the local e-book library.
- Illustration, title, description, four progress dots, and Next button.
- Uses the shared onboarding layout instead of a separate hardcoded design.
- Asset need: `onboarding_library.png`.

### 3. Onboarding - Translation

Source: `ui/3.png`

- Introduces English-to-Filipino translation.
- Shows English and Filipino speech bubbles.
- The page is informational; actual translation happens through DeepL later.
- Asset need: `onboarding_translation.png`.

### 4. Onboarding - Voices

Source: `ui/4.jpg`

- Introduces narrator and character voices.
- Text must describe the planned five on-device voice profiles, not Android device voices.
- Asset need: `onboarding_voices.png`.

### 5. Onboarding - Story Mode

Source: `ui/5.png`

- Introduces sprites, backgrounds, subtitles, movements, sounds, and chapter Story Mode.
- Get Started saves `onboardingCompleted = true` locally and opens Library.
- Asset need: `onboarding_story_mode.png`.

### 6. Library

Source: `ui/6.png`

- Top bar with menu, My Library title, and Search action.
- Welcome banner must say `StoryTale`.
- Dynamic My Books section with reusable book cards.
- Add Book card opens EPUB import.
- Bottom navigation uses the shared app shell.
- Empty libraries replace the carousel with a clear Add EPUB state.
- Asset needs: `library_banner.png` and `empty_library.png`.

### 7. Add Book

Source: `ui/7.png`

- Back button, title, file picker area, metadata form, cover selector, and Save Book button.
- Accept `.epub` only; remove PDF from the design.
- EPUB metadata should automatically fill title, author, language, and cover when available.
- Manual fields are fallback edits, not required duplicate entry.
- Required states: selecting, parsing, success, unsupported file, protected EPUB, and invalid EPUB.
- Asset need: `epub_upload.png`.

### 8. Book Details

Source: `ui/8.png`

- Cover, title, author, language, progress, and chapter count.
- Main actions: Read Now, Listen, and Animated Story.
- About section, genres/tags, and dynamic chapter list.
- Ratings should be removed unless StoryTale later has a real rating source.
- Page count may be replaced with chapter count because EPUB pages change with text size.
- Book cover normally comes from the imported EPUB.

### 9. Reader - Read Mode

Source: `ui/9.png`

- Book title, chapter title, bookmark action, and overflow menu.
- Read/Translate segmented control.
- Scrollable chapter content.
- Reading progress and quick controls for text size, theme, and audio.
- Save chapter position locally while reading.
- Bottom navigation comes from the shared app shell.

### 10. Reader - Translate Mode

Source: `ui/10.png`

- Shares the same reader page as screen 9.
- Adds English Only, Filipino Only, and Dual View display choices.
- Translation is requested from DeepL using target code `TL` and cached locally.
- Audio action narrates the currently visible language.
- Loading, retry, and cached/offline states are required.

### 11. Reader Settings

Source: `ui/11 reader settings.png`

- Live text preview.
- Text size, font, theme, line spacing, and translation display settings.
- Reset and Apply actions.
- Store settings locally and reuse them for every book.
- Show this as a route or full-height sheet using shared setting controls.

### 12. Story Mode - Control Reference

Source: `ui/12 animated story mode.png`

- Useful reference for scene status, current voice, subtitle overlay, scene progress, playback, voice, subtitle, and contents controls.
- Do not implement as a separate player from page 13.
- Reuse its clearer control labels in the preferred page 13 design.

### 13A. Story Mode - Preferred Player

Source: `ui/13 animated story mode new design.png`

- Preferred full Story Mode layout.
- Header shows current book and chapter plus Table of Contents.
- Scene stage layers one background and character sprites.
- Dialogue bubble and bottom subtitle follow the active line.
- Scene progress, audio timeline, previous/play/next controls, voice selection, subtitle language, and music toggle.
- Characters move using simple transforms such as enter, exit, slide, bounce, face, and fade.
- Story Mode reads one dynamic `ChapterStory` object.

### 13B. Story Mode - Table of Contents

Source: `ui/13 animated story mode table contents.png`

- Bottom sheet over the player.
- Displays all available chapter Story Modes and their preparation state.
- Selecting a prepared chapter loads it.
- Selecting an unprepared chapter opens the chapter preparation flow.
- Reuse the shared chapter list tile and bottom sheet components.

### 14. Search

Source: `ui/14 search.png`

- Search field, recent searches, clear actions, and category chips.
- Results should search imported local books by title, author, tag, and chapter.
- Required states: recent searches, active results, no results, and empty library.
- Popular searches should become local category filters because there is no online marketplace.

### 15. Now Reading

Source: `ui/15 now reading.png`

- Current book card with cover, chapter, progress, and Continue Reading.
- Recently Opened uses dynamic local history.
- Recommended for You should initially be renamed Suggested From Your Library and use local genres/tags.
- No external recommendations are required for the local-first version.

### 16. Profile

Source: `ui/16 my profile.png`

- Rename My Account to My Profile because version one has no cloud account or authentication.
- Use a local name and optional avatar; email is not required.
- Menu: My Bookshelf, Reading History, Downloads, Settings, Help, and About StoryTale.
- Downloads manages stored EPUBs, generated images, prepared voices, and cached audio.
- Asset need: `default_profile_avatar.png`.

## Production screen and state reference

These screens and states are required for the finished product. Their presence
in this table does not mean they are unimplemented; provider, persistence,
loading, error, and polish work follows the owning roadmap phase.

| Priority | Screen | Purpose |
| --- | --- | --- |
| High | EPUB import progress/result | Shows parsing, errors, and successful import |
| High | Empty Library | First-use Add EPUB state |
| High | Audio hub | Required by the bottom navigation; lists prepared narration and voice settings |
| High | Voice manager | Shows the five installed ONNX voice packs and their test controls |
| High | Chapter audio preparation | Shows background TTS/RVC generation progress and errors |
| High | Reader chapter contents | Navigates between chapters without returning to Book Details |
| High | Story Mode preparation | Runs one minimal volume job for shared entities/assets and chapter analysis, then opens ready chapters or repairs one missing chapter on demand |
| High | Chapter moral | Displays the moral after Story Mode completes |
| Medium | Search results/empty | Results list and no-result state |
| Medium | Full bookshelf | See All books, sorting, filters, favorites, and delete/edit actions |
| Medium | Reading history | Books and chapters ordered by last opened time |
| Medium | Book options sheet | Rename metadata, replace cover, remove book, and clear progress |
| Medium | Generated asset catalog | Read-only previews and readiness/error details; normal users cannot regenerate, replace, or remove paid generated artwork |
| Medium | Settings | Theme, language, storage, translation, audio, and accessibility |
| Low | Help and About | Local documentation, API notices, and app information |

## Reusable Flutter component plan

Shared components belong in `lib/src/shared/widgets/`. Feature-only widgets stay inside their feature.

| Component | Responsibility |
| --- | --- |
| `StoryTaleAppShell` | Shared Scaffold, safe area, body, and optional bottom navigation |
| `StoryTaleBottomNav` | Four dynamic tabs with selected state and callback |
| `StoryTaleTopBar` | Shared back/menu/title/action header |
| `StoryTaleButton` | Primary, secondary, outline, loading, and disabled buttons |
| `StoryTaleSegmentedControl<T>` | Read/Translate and language mode selectors |
| `StoryTaleSectionHeader` | Section title with optional See All action |
| `BookCoverCard` | Cover, title, author/chapter, progress, and tap/menu callbacks |
| `BookSummaryCard` | Current book and Continue Reading block |
| `ChapterListTile` | Chapter name, status, progress, and action |
| `StoryTaleSearchField` | Search input with clear and submit actions |
| `ReaderQuickToolbar` | Text, theme/language, and audio actions |
| `StoryTaleProgressBar` | Reading, audio generation, and playback progress |
| `StorySceneStage` | Background, sprite layers, dialogue, and subtitles |
| `StoryPlayerControls` | Timeline and previous/play/next actions |
| `VoiceProfileChip` | Voice name, role, installed/preparing/error state |
| `StoryTaleBottomSheet` | Contents, options, voice selection, and confirmations |
| `StoryTaleEmptyState` | Empty library, search, audio, and history states |
| `StoryTaleAsyncState` | Loading, progress, error, retry, and success presentation |

`StoryTaleBottomNav` must be written once and called by `StoryTaleAppShell`. Pages must not copy its layout.

## Suggested shared folder organization

```text
lib/src/
├── core/
│   ├── navigation/
│   ├── storage/
│   └── theme/
├── features/
│   ├── onboarding/
│   ├── library/
│   ├── reader/
│   ├── translation/
│   ├── narration/
│   ├── animated_story/
│   ├── search/
│   └── profile/
└── shared/
    ├── models/
    └── widgets/
        ├── navigation/
        ├── buttons/
        ├── books/
        ├── reader/
        ├── story/
        └── states/
```

## Dynamic data needed

```text
Book
- id, epubPath, title, author, language, coverPath
- description, tags, volumes, progress, lastOpenedAt

Volume
- id, bookId, title, sortOrder, epubPath, chapters

Chapter
- id, bookId, volumeId, title, sortOrder, chapterType
- originalText, translatedText, sourceStart, sourceEnd
- translationStatus, readingPosition, bookmarked

BookStoryBible
- bookId, characters, aliases, lockedDesigns, locations, style, timeline
- Gemini analysis version and unresolvedItems

VoiceProfile
- id, name, role, modelPath, status

ChapterStory
- chapterId, sourceTextHash, moral, characters, scenes, preparationStatus

StoryScene
- backgroundPath, bodyAssetId, headAssetId, speakerId, subtitle
- audioPath, movement, soundEffectPath, duration

ReaderSettings
- textSize, fontFamily, theme, lineSpacing, languageMode
```

The current prototype keeps chapters directly under `BookData`. The planned
volume migration and complete Story Mode preparation schema are documented in
[Animated Story Mode plan](../ANIMATED_STORY_MODE_PLAN.md).

## UI image asset plan

Clean app artwork belongs in one folder:

```text
assets/images/ui/
```

The complete UI screenshots stay under `docs/ui-concepts/ui/`. Do not bundle those screenshots into Flutter.

Planned clean files:

```text
brand_logo.png
splash_storybook.png
onboarding_library.png
onboarding_translation.png
onboarding_voices.png
onboarding_story_mode.png
library_banner.png
empty_library.png
epub_upload.png
default_book_cover.png
default_profile_avatar.png
story_preparing.png
search_empty.png
audio_empty.png
error_epub.png
```

Book covers extracted from EPUBs are stored dynamically. Generated Story Mode backgrounds and sprites continue using `assets/images/backgrounds/`, `assets/images/characters/`, and local app storage.

## Historical UI build order

This was the initial screen-construction order and is retained only as a design
history reference:

1. Finalize theme tokens and create `StoryTaleAppShell`.
2. Extract shared navigation, top bars, buttons, headers, cards, and states.
3. Build onboarding.
4. Build EPUB import, Library, Search, Book Details, and Now Reading.
5. Build Reader and settings.
6. Build Audio and chapter preparation screens.
7. Build the preferred Story Mode player, contents, and moral screens.
8. Add profile, storage, help, and remaining empty/error states.

Do not use this list to choose the next implementation. Follow the
[Master Roadmap](../ROADMAP.md).
