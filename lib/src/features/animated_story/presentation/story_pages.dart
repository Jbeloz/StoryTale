import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';

class StoryPreparationPage extends StatefulWidget {
  const StoryPreparationPage({super.key});

  @override
  State<StoryPreparationPage> createState() => _StoryPreparationPageState();
}

class _StoryPreparationPageState extends State<StoryPreparationPage> {
  double _progress = 0;
  bool _working = false;

  Future<void> _prepare() async {
    final controller = StoryTaleScope.of(context);
    final chapter = controller.currentChapter;
    if (chapter == null) return;
    controller.storyFor(chapter).status = PreparationStatus.preparing;
    setState(() => _working = true);
    for (final value in [0.2, 0.4, 0.65, 0.85, 1.0]) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _progress = value);
    }
    controller.markStoryPrepared(chapter);
    setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final chapter = controller.currentChapter;
    final story = chapter == null ? null : controller.storyFor(chapter);
    final ready = story?.status == PreparationStatus.ready;
    return StoryTaleAppShell(
      title: 'Prepare Story Mode',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const StoryTaleImagePlaceholder(
            path: 'assets/images/ui/story_preparing.png',
            label: 'Story preparation artwork placeholder',
            icon: Icons.auto_awesome_motion,
            height: 180,
          ),
          const SizedBox(height: 20),
          Text(
            chapter?.title ?? 'No chapter selected',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'This chapter package combines scene text, a moral, placeholder '
            'sprites and backgrounds, movements, subtitles, and cached voices.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(value: ready ? 1 : _progress),
          const SizedBox(height: 12),
          ...[
            'Analyze chapter and dialogue',
            'Create scene and moral data',
            'Prepare sprite/background placeholders',
            'Connect narration and subtitles',
          ].map(
            (task) => ListTile(
              dense: true,
              leading: Icon(
                ready ? Icons.check_circle_outline : Icons.circle_outlined,
              ),
              title: Text(task),
            ),
          ),
          FilledButton(
            onPressed: chapter == null || _working || ready ? null : _prepare,
            child: Text(
              ready
                  ? 'Story Ready'
                  : _working
                  ? 'Preparing…'
                  : 'Prepare Chapter Story',
            ),
          ),
          const SizedBox(height: 8),
          if (ready) ...[
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SpriteReviewPage()),
              ),
              child: const Text('Review Sprites & Backgrounds'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AnimatedStoryPage()),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Open Story Mode'),
            ),
          ],
        ],
      ),
    );
  }
}

class AnimatedStoryPage extends StatefulWidget {
  const AnimatedStoryPage({super.key});

  @override
  State<AnimatedStoryPage> createState() => _AnimatedStoryPageState();
}

class _AnimatedStoryPageState extends State<AnimatedStoryPage> {
  int _sceneIndex = 0;
  bool _playing = false;
  bool _filipinoSubtitles = false;
  bool _music = true;

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    final chapter = controller.currentChapter;
    if (book == null || chapter == null) {
      return const StoryTaleInfoPage(
        title: 'Story Mode',
        description: 'Choose a book chapter before opening Story Mode.',
      );
    }
    final story = controller.storyFor(chapter);
    if (story.status != PreparationStatus.ready) {
      return StoryTaleInfoPage(
        title: 'Story Mode',
        description: '${chapter.title} has not been prepared yet.',
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const StoryPreparationPage()),
            ),
            child: const Text('Prepare Chapter'),
          ),
        ],
      );
    }
    final scene = story.scenes[_sceneIndex];
    final subtitle = _filipinoSubtitles
        ? 'Filipino subtitle placeholder: ${scene.subtitle}'
        : scene.subtitle;

    return StoryTaleAppShell(
      title: '${book.title} • ${chapter.title}',
      actions: [
        IconButton(
          tooltip: 'Table of contents',
          onPressed: () => _showContents(context),
          icon: const Icon(Icons.toc),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryTaleImagePlaceholder(
                      path: scene.backgroundPath,
                      label: 'Chapter background placeholder',
                      icon: Icons.landscape_outlined,
                      height: double.infinity,
                      borderRadius: 0,
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 450),
                      alignment: _sceneIndex.isEven
                          ? Alignment.bottomLeft
                          : Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: StoryTaleImagePlaceholder(
                          path: scene.characterPath,
                          label: '${scene.speaker} sprite',
                          icon: Icons.accessibility_new,
                          width: 130,
                          height: 190,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black87,
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${scene.speaker}: $subtitle',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_sceneIndex + 1) / story.scenes.length,
                ),
                Text(
                  'Scene ${_sceneIndex + 1} of ${story.scenes.length} • '
                  '${scene.movement}',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _sceneIndex == 0 ? null : _previous,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filled(
                      onPressed: () => setState(() => _playing = !_playing),
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton(
                      onPressed: () => _next(story),
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Filipino subtitles'),
                      selected: _filipinoSubtitles,
                      onSelected: (value) {
                        setState(() => _filipinoSubtitles = value);
                      },
                    ),
                    FilterChip(
                      label: const Text('Music'),
                      selected: _music,
                      onSelected: (value) => setState(() => _music = value),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.record_voice_over_outlined),
                      label: const Text('Voice'),
                      onPressed: () => _showVoiceSheet(context),
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

  void _previous() => setState(() {
    _sceneIndex--;
    _playing = false;
  });

  void _next(ChapterStoryData story) {
    if (_sceneIndex < story.scenes.length - 1) {
      setState(() {
        _sceneIndex++;
        _playing = false;
      });
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChapterMoralPage()));
    }
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
            const ListTile(title: Text('Chapter Story Modes')),
            ...book.chapters.map((chapter) {
              final story = controller.storyFor(chapter);
              return ChapterListTile(
                chapter: chapter,
                trailing: Chip(
                  label: Text(
                    story.status == PreparationStatus.ready
                        ? 'Ready'
                        : 'Prepare',
                  ),
                ),
                onTap: () {
                  controller.openBook(book, chapter: chapter);
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => story.status == PreparationStatus.ready
                          ? const AnimatedStoryPage()
                          : const StoryPreparationPage(),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _showVoiceSheet(BuildContext context) {
    final voices = StoryTaleScope.of(context).voices;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: voices
              .map(
                (voice) => ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: Text(voice.name),
                  subtitle: Text(voice.role),
                  enabled: voice.status == PreparationStatus.ready,
                  onTap: () => Navigator.pop(context),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class ChapterMoralPage extends StatelessWidget {
  const ChapterMoralPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final chapter = controller.currentChapter;
    final moral = chapter == null
        ? 'Every story gives us something to remember.'
        : controller.storyFor(chapter).moral;
    return StoryTaleInfoPage(
      title: 'Chapter Moral',
      description: moral,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.replay),
          label: const Text('Return to Story'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Back to Library'),
        ),
      ],
    );
  }
}

class SpriteReviewPage extends StatelessWidget {
  const SpriteReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoryTaleAppShell(
      title: 'Review Story Artwork',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StoryTaleImagePlaceholder(
            label: 'Generated chapter background placeholder',
            icon: Icons.landscape_outlined,
            height: 180,
          ),
          const SizedBox(height: 12),
          const StoryTaleImagePlaceholder(
            label: 'Generated character sprite placeholder',
            icon: Icons.accessibility_new,
            height: 180,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
              ),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Cloudflare image regeneration will connect here.',
                    ),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate'),
              ),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Local image replacement will connect here.'),
                  ),
                ),
                icon: const Icon(Icons.image_search),
                label: const Text('Replace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
