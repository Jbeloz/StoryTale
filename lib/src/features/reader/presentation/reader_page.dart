import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../narration/presentation/audio_pages.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final _scrollController = ScrollController();
  bool _translateMode = false;
  String? _chapterId;
  double _progress = 0;
  bool _restoringProgress = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_saveScrollProgress);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chapter = StoryTaleScope.of(context).currentChapter;
    if (chapter != null && chapter.id != _chapterId) {
      _chapterId = chapter.id;
      _progress = chapter.progress;
      _restoreScrollProgress();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_saveScrollProgress)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    final chapter = controller.currentChapter;
    if (book == null || chapter == null) {
      return const StoryTaleInfoPage(
        title: 'Reader',
        description: 'Select a book and chapter from your library first.',
      );
    }

    final settings = controller.readerSettings;
    final content = _visibleContent(chapter, settings.languageMode);
    return StoryTaleAppShell(
      title: book.title,
      actions: [
        IconButton(
          tooltip: 'Bookmark',
          onPressed: () => controller.toggleBookmark(chapter),
          icon: Icon(
            chapter.bookmarked ? Icons.bookmark : Icons.bookmark_border,
          ),
        ),
        IconButton(
          tooltip: 'Chapter contents',
          onPressed: () => _showContents(context),
          icon: const Icon(Icons.toc),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  chapter.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Read')),
                    ButtonSegment(value: true, label: Text('Translate')),
                  ],
                  selected: {_translateMode},
                  onSelectionChanged: (values) {
                    final translate = values.first;
                    setState(() => _translateMode = translate);
                    if (translate) controller.translateChapter(chapter);
                  },
                ),
                if (_translateMode) ...[
                  const SizedBox(height: 8),
                  SegmentedButton<ReaderLanguageMode>(
                    segments: const [
                      ButtonSegment(
                        value: ReaderLanguageMode.english,
                        label: Text('English'),
                      ),
                      ButtonSegment(
                        value: ReaderLanguageMode.filipino,
                        label: Text('Filipino'),
                      ),
                      ButtonSegment(
                        value: ReaderLanguageMode.dual,
                        label: Text('Dual'),
                      ),
                    ],
                    selected: {settings.languageMode},
                    onSelectionChanged: (values) {
                      final copy = settings.copy()..languageMode = values.first;
                      controller.saveReaderSettings(copy);
                    },
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: settings.textSize,
                  height: settings.lineSpacing,
                  fontFamily: settings.fontFamily == 'Serif' ? 'serif' : null,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Progress'),
                    Expanded(
                      child: Slider(
                        value: _progress,
                        onChanged: _seekToProgress,
                      ),
                    ),
                    Text('${(_progress * 100).round()}%'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Reader settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReaderSettingsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.text_fields),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Toggle translation',
                      onPressed: () {
                        setState(() => _translateMode = !_translateMode);
                        if (_translateMode) {
                          controller.translateChapter(chapter);
                        }
                      },
                      icon: const Icon(Icons.translate),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Prepare chapter audio',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChapterAudioPreparationPage(),
                        ),
                      ),
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _visibleContent(ChapterData chapter, ReaderLanguageMode mode) {
    if (!_translateMode || mode == ReaderLanguageMode.english) {
      return chapter.originalText;
    }
    final filipino =
        chapter.translatedText ?? 'Preparing the Filipino translation…';
    if (mode == ReaderLanguageMode.filipino) return filipino;
    return 'ENGLISH\n\n${chapter.originalText}\n\nFILIPINO\n\n$filipino';
  }

  void _saveScrollProgress() {
    if (_restoringProgress || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final progress = position.maxScrollExtent == 0
        ? 1.0
        : (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
    if ((progress - _progress).abs() < 0.005 && progress < 1) return;
    _progress = progress;
    StoryTaleScope.of(context).updateReadingProgress(progress);
  }

  void _restoreScrollProgress() {
    _restoringProgress = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _restoringProgress = false;
        return;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(maxScroll * _progress);
      _restoringProgress = false;
      if (maxScroll == 0 && _progress < 1) {
        _progress = 1;
        StoryTaleScope.of(context).updateReadingProgress(1);
      }
    });
  }

  void _seekToProgress(double progress) {
    if (!_scrollController.hasClients) return;
    _progress = progress;
    _scrollController.jumpTo(
      _scrollController.position.maxScrollExtent * progress,
    );
    StoryTaleScope.of(context).updateReadingProgress(progress);
  }

  Future<void> _showContents(BuildContext context) async {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    if (book == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Chapter Contents')),
            ...book.chapters.map(
              (chapter) => ChapterListTile(
                chapter: chapter,
                onTap: () {
                  controller.openBook(book, chapter: chapter);
                  Navigator.pop(sheetContext);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderSettingsPage extends StatefulWidget {
  const ReaderSettingsPage({super.key});

  @override
  State<ReaderSettingsPage> createState() => _ReaderSettingsPageState();
}

class _ReaderSettingsPageState extends State<ReaderSettingsPage> {
  ReaderSettingsData? _settings;

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final settings = _settings ??= controller.readerSettings.copy();
    return StoryTaleAppShell(
      title: 'Reader Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'This preview updates as you change the reading settings.',
                style: TextStyle(
                  fontSize: settings.textSize,
                  height: settings.lineSpacing,
                  fontFamily: settings.fontFamily == 'Serif' ? 'serif' : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Text size: ${settings.textSize.round()}'),
          Slider(
            min: 14,
            max: 30,
            value: settings.textSize,
            onChanged: (value) => setState(() => settings.textSize = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: settings.fontFamily,
            decoration: const InputDecoration(labelText: 'Font'),
            items: const [
              DropdownMenuItem(value: 'Sans Serif', child: Text('Sans Serif')),
              DropdownMenuItem(value: 'Serif', child: Text('Serif')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => settings.fontFamily = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: settings.theme,
            decoration: const InputDecoration(labelText: 'Reader theme'),
            items: const [
              DropdownMenuItem(value: 'Light', child: Text('Light')),
              DropdownMenuItem(value: 'Sepia', child: Text('Sepia')),
              DropdownMenuItem(value: 'Dark', child: Text('Dark')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => settings.theme = value);
            },
          ),
          const SizedBox(height: 16),
          Text('Line spacing: ${settings.lineSpacing.toStringAsFixed(1)}'),
          Slider(
            min: 1.0,
            max: 2.2,
            divisions: 6,
            value: settings.lineSpacing,
            onChanged: (value) => setState(() => settings.lineSpacing = value),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _settings = ReaderSettingsData());
                  },
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    controller.saveReaderSettings(settings);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
