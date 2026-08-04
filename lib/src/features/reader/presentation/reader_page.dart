import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';
import '../../narration/presentation/audio_pages.dart';
import '../data/chapter_paginator.dart';

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
    final textStyle = TextStyle(
      fontSize: settings.textSize,
      height: settings.lineSpacing,
      fontFamily: settings.fontFamily == 'Serif' ? 'serif' : null,
    );
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
            child: settings.readingMode == ReaderReadingMode.page
                ? _PagedChapterView(
                    chapter: chapter,
                    style: textStyle,
                    // Translated text is one block, so interleaving art into
                    // it is not meaningful.
                    overrideText: _translateMode ? content : null,
                    progress: _progress,
                    onProgressChanged: _setProgress,
                  )
                // A lazy ListView would give an unstable maxScrollExtent and
                // break the progress save/restore below, so the scrolling
                // chapter stays in one scroll view.
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    child: _ChapterBody(
                      chapter: chapter,
                      text: content,
                      style: textStyle,
                      showImages: !_translateMode,
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

  /// Records a position reported by the paged view.
  void _setProgress(double progress) {
    if ((progress - _progress).abs() < 0.0001) return;
    setState(() => _progress = progress);
    StoryTaleScope.of(context).updateReadingProgress(progress);
  }

  void _seekToProgress(double progress) {
    final controller = StoryTaleScope.of(context);
    // Page mode has no scroll extent; the paged view follows this value.
    if (controller.readerSettings.readingMode == ReaderReadingMode.page) {
      setState(() => _progress = progress);
      controller.updateReadingProgress(progress);
      return;
    }
    if (!_scrollController.hasClients) return;
    _progress = progress;
    _scrollController.jumpTo(
      _scrollController.position.maxScrollExtent * progress,
    );
    controller.updateReadingProgress(progress);
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

/// The chapter laid out as fixed pages, turned sideways like a printed book.
class _PagedChapterView extends StatefulWidget {
  const _PagedChapterView({
    required this.chapter,
    required this.style,
    required this.overrideText,
    required this.progress,
    required this.onProgressChanged,
  });

  final ChapterData chapter;
  final TextStyle style;
  final String? overrideText;
  final double progress;
  final ValueChanged<double> onProgressChanged;

  @override
  State<_PagedChapterView> createState() => _PagedChapterViewState();
}

class _PagedChapterViewState extends State<_PagedChapterView> {
  static const _padding = EdgeInsets.all(20);

  PageController? _pageController;
  List<ChapterPage> _pages = const [];
  String? _layoutKey;
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PagedChapterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The progress slider moves this view from outside.
    if (widget.progress != oldWidget.progress) {
      final target = _indexForProgress(widget.progress);
      if (target != _pageIndex) _jumpTo(target);
    }
  }

  double get _progressForIndex =>
      _pages.length < 2 ? 1.0 : _pageIndex / (_pages.length - 1);

  int _indexForProgress(double progress) {
    if (_pages.length < 2) return 0;
    return (progress * (_pages.length - 1)).round().clamp(0, _pages.length - 1);
  }

  void _jumpTo(int index) {
    _pageIndex = index;
    final controller = _pageController;
    if (controller != null && controller.hasClients) {
      controller.jumpToPage(index);
    }
  }

  /// Re-paginates only when the chapter, the viewport, or the style changes.
  void _layout(Size size) {
    final key = [
      widget.chapter.id,
      widget.overrideText?.length ?? -1,
      size.width.round(),
      size.height.round(),
      widget.style.fontSize,
      widget.style.height,
      widget.style.fontFamily,
    ].join('|');
    if (key == _layoutKey) return;

    final pages = const ChapterPaginator().paginate(
      items: ChapterPaginator.itemsFor(
        widget.chapter,
        includeImages: widget.overrideText == null,
        overrideText: widget.overrideText,
      ),
      pageSize: size,
      style: widget.style,
    );

    _layoutKey = key;
    _pages = pages;
    // Keep the reader near the same place after a re-flow.
    _pageIndex = _indexForProgress(widget.progress);
    final controller = _pageController;
    if (controller == null) {
      _pageController = PageController(initialPage: _pageIndex);
    } else if (controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(_pageIndex);
      });
    }
  }

  void _turn(int delta) {
    final target = (_pageIndex + delta).clamp(0, _pages.length - 1);
    if (target == _pageIndex) return;
    _pageController?.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(
          constraints.maxWidth - _padding.horizontal,
          constraints.maxHeight - _padding.vertical,
        );
        if (available.width <= 0 || available.height <= 0) {
          return const SizedBox.shrink();
        }
        _layout(available);

        if (_pages.isEmpty) {
          return const Center(
            child: Text('This chapter has no readable text.'),
          );
        }

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _pageIndex = index);
                      widget.onProgressChanged(_progressForIndex);
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: _padding,
                        child: page.isImage
                            ? _ChapterIllustration(
                                image: page.image!,
                                fullPage: true,
                              )
                            : Text(page.text, style: widget.style),
                      );
                    },
                  ),
                  // Tapping the edges turns pages, as in a normal reader.
                  Positioned.fill(
                    child: Row(
                      children: [
                        _PageTapTarget(onTap: () => _turn(-1)),
                        const Spacer(flex: 3),
                        _PageTapTarget(onTap: () => _turn(1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_pageIndex + 1} / ${_pages.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        );
      },
    );
  }
}

class _PageTapTarget extends StatelessWidget {
  const _PageTapTarget({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Chapter text with its illustrations kept in their original places.
class _ChapterBody extends StatelessWidget {
  const _ChapterBody({
    required this.chapter,
    required this.text,
    required this.style,
    required this.showImages,
  });

  final ChapterData chapter;
  final String text;
  final TextStyle style;
  final bool showImages;

  @override
  Widget build(BuildContext context) {
    final blocks = chapter.sourceBlocks;
    if (!showImages || chapter.images.isEmpty || blocks.isEmpty) {
      return Text(text, style: style);
    }

    final children = <Widget>[];
    final pending = <String>[];

    void flushText() {
      if (pending.isEmpty) return;
      children.add(Text(pending.join('\n\n'), style: style));
      pending.clear();
    }

    for (var index = 0; index <= blocks.length; index++) {
      for (final image in chapter.images) {
        if (image.afterBlockIndex != index) continue;
        flushText();
        children.add(_ChapterIllustration(image: image));
      }
      if (index < blocks.length) pending.add(blocks[index].text);
    }
    flushText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _ChapterIllustration extends StatelessWidget {
  const _ChapterIllustration({required this.image, this.fullPage = false});

  final ChapterImageData image;

  /// In page mode an illustration owns the whole page, so it fills it instead
  /// of being capped against the screen.
  final bool fullPage;

  /// Illustrations are print sized, so they are capped against the screen
  /// instead of overflowing the scroll view.
  static const _viewportFraction = 0.7;

  @override
  Widget build(BuildContext context) {
    final label = image.alt.isEmpty ? 'Chapter illustration' : image.alt;
    final maxHeight = MediaQuery.sizeOf(context).height * _viewportFraction;

    if (!image.isStored) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: StoryTaleImagePlaceholder(
          label: '$label\n(not stored on this device)',
          height: fullPage ? double.infinity : 160,
        ),
      );
    }

    final artwork = Semantics(
      label: label,
      image: true,
      child: GestureDetector(
        onTap: () => _openFullScreen(context, label),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            image.bytes!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                StoryTaleImagePlaceholder(label: label, height: 160),
          ),
        ),
      ),
    );

    if (fullPage) return Center(child: artwork);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: artwork,
      ),
    );
  }

  void _openFullScreen(BuildContext context, String label) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _IllustrationViewerPage(image: image, label: label),
      ),
    );
  }
}

class _IllustrationViewerPage extends StatelessWidget {
  const _IllustrationViewerPage({required this.image, required this.label});

  final ChapterImageData image;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.memory(image.bytes!, fit: BoxFit.contain),
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
          const Text('Reading mode'),
          const SizedBox(height: 8),
          SegmentedButton<ReaderReadingMode>(
            segments: const [
              ButtonSegment(
                value: ReaderReadingMode.scroll,
                icon: Icon(Icons.swap_vert),
                label: Text('Scroll'),
              ),
              ButtonSegment(
                value: ReaderReadingMode.page,
                icon: Icon(Icons.menu_book_outlined),
                label: Text('Page'),
              ),
            ],
            selected: {settings.readingMode},
            onSelectionChanged: (values) {
              setState(() => settings.readingMode = values.first);
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
