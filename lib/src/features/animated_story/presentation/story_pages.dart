import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';
import '../data/sprite_layer_processor.dart';
import '../data/story_artwork_service.dart';
import '../data/subtitle_beat_splitter.dart';
import 'sprite_positioner_page.dart';
import 'widgets/visual_novel_stage.dart';

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
  int _beatIndex = 0;
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
    final beats = splitSubtitleBeats(scene.subtitle);
    final beat = beats[_beatIndex];
    final subtitle = _filipinoSubtitles ? 'Filipino: $beat' : beat;

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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: VisualNovelStage(scene: scene, subtitle: subtitle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                LinearProgressIndicator(value: _storyProgress(story)),
                Text(
                  'Scene ${_sceneIndex + 1} of ${story.scenes.length} • '
                  'Line ${_beatIndex + 1} of ${beats.length}',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('story-previous'),
                      tooltip: 'Previous line',
                      onPressed: _sceneIndex == 0 && _beatIndex == 0
                          ? null
                          : () => _previous(story),
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filled(
                      onPressed: () => setState(() => _playing = !_playing),
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton(
                      key: const Key('story-next'),
                      tooltip: 'Next line',
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

  void _previous(ChapterStoryData story) => setState(() {
    if (_beatIndex > 0) {
      _beatIndex--;
    } else {
      _sceneIndex--;
      _beatIndex =
          splitSubtitleBeats(story.scenes[_sceneIndex].subtitle).length - 1;
    }
    _playing = false;
  });

  void _next(ChapterStoryData story) {
    final beats = splitSubtitleBeats(story.scenes[_sceneIndex].subtitle);
    if (_beatIndex < beats.length - 1) {
      setState(() {
        _beatIndex++;
        _playing = false;
      });
    } else if (_sceneIndex < story.scenes.length - 1) {
      setState(() {
        _sceneIndex++;
        _beatIndex = 0;
        _playing = false;
      });
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChapterMoralPage()));
    }
  }

  double _storyProgress(ChapterStoryData story) {
    final completed = story.scenes.take(_sceneIndex).fold<int>(0, (
      total,
      scene,
    ) {
      return total + splitSubtitleBeats(scene.subtitle).length;
    });
    final total = story.scenes.fold<int>(0, (sum, scene) {
      return sum + splitSubtitleBeats(scene.subtitle).length;
    });
    if (total == 0) return 0;
    return (completed + _beatIndex + 1) / total;
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

class SpriteReviewPage extends StatefulWidget {
  const SpriteReviewPage({super.key});

  @override
  State<SpriteReviewPage> createState() => _SpriteReviewPageState();
}

class _SpriteReviewPageState extends State<SpriteReviewPage> {
  final _service = StoryArtworkService();
  final _processor = const SpriteLayerProcessor();
  final _spriteDetails = TextEditingController(
    text:
        'a kind young prince with short golden hair, a long blue coat, '
        'cream trousers, and brown boots',
  );
  final _backgroundDetails = TextEditingController(
    text:
        'a moonlit rose garden on a tiny asteroid with a gentle purple-blue '
        'sky and room for two character sprites',
  );
  _ArtworkMode _mode = _ArtworkMode.sprite;
  Uint8List? _generatedImage;
  SpriteLayers? _spriteLayers;
  _SpritePreview _spritePreview = _SpritePreview.rejoined;
  String? _error;
  bool _generating = false;

  @override
  void dispose() {
    _spriteDetails.dispose();
    _backgroundDetails.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _generatedImage = null;
      _spriteLayers = null;
      _error = null;
    });
    try {
      if (_mode == _ArtworkMode.sprite) {
        final master = await _service.generateSpriteMaster(_spriteDetails.text);
        final layers = _processor.process(master);
        if (mounted) {
          setState(() {
            _spriteLayers = layers;
            _spritePreview = _SpritePreview.rejoined;
          });
        }
      } else {
        final background = await _service.generateBackground(
          _backgroundDetails.text,
        );
        if (mounted) setState(() => _generatedImage = background);
      }
    } on ArtworkGenerationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The story artwork could not be generated.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoryTaleAppShell(
      title: 'Review Story Artwork',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_ArtworkMode>(
            segments: const [
              ButtonSegment(
                value: _ArtworkMode.sprite,
                icon: Icon(Icons.face_retouching_natural_outlined),
                label: Text('Sprite'),
              ),
              ButtonSegment(
                value: _ArtworkMode.background,
                icon: Icon(Icons.landscape_outlined),
                label: Text('Background'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() {
              _mode = selection.first;
              _generatedImage = null;
              _spriteLayers = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          Text(
            _mode == _ArtworkMode.sprite
                ? 'Gemini Sprite Test'
                : 'Cloudflare Background Test',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _service.isConfigured
                ? _mode == _ArtworkMode.sprite
                      ? 'Ready. Gemini 3.1 Flash Image creates character sprites.'
                      : 'Ready. Cloudflare Workers AI creates chapter backgrounds.'
                : 'Token not loaded. Add it to .env and restart with the run script.',
          ),
          const SizedBox(height: 8),
          const Text(
            'The app calls the private Worker. Your Gemini API key stays on the '
            'server and is never added to Flutter.',
          ),
          if (_mode == _ArtworkMode.sprite) ...[
            const SizedBox(height: 8),
            const Text(
              'Gemini makes one master using all three references. StoryTale '
              'then removes the green background and splits that same image, '
              'so the head and body always fit when rejoined.',
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _mode == _ArtworkMode.sprite
                ? _spriteDetails
                : _backgroundDetails,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _mode == _ArtworkMode.sprite
                  ? 'Character appearance'
                  : 'Background scene description',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: _generating
                ? const Center(child: CircularProgressIndicator())
                : _previewImage != null
                ? Image.memory(_previewImage!, fit: BoxFit.contain)
                : Image.asset(_placeholderAsset, fit: BoxFit.contain),
          ),
          if (_mode == _ArtworkMode.sprite && _spriteLayers != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _SpritePreview.values
                  .map(
                    (preview) => ChoiceChip(
                      label: Text(preview.label),
                      selected: _spritePreview == preview,
                      onSelected: (_) {
                        setState(() => _spritePreview = preview);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  !_hasGeneratedArtwork
                      ? _mode == _ArtworkMode.sprite
                            ? 'Generate Master Sprite'
                            : 'Generate Background'
                      : 'Regenerate',
                ),
              ),
              OutlinedButton.icon(
                onPressed: !_hasGeneratedArtwork
                    ? null
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: Text(
                  _mode == _ArtworkMode.sprite
                      ? 'Accept Sprite'
                      : 'Accept Background',
                ),
              ),
              if (_mode == _ArtworkMode.sprite)
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SpritePositionerPage(),
                    ),
                  ),
                  icon: const Icon(Icons.accessibility_new),
                  label: const Text('Open Sprite Studio'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String get _placeholderAsset {
    if (_mode == _ArtworkMode.background) {
      return 'assets/images/backgrounds/cloudflare_examples/'
          'moonlit-rose-garden.jpg';
    }
    return 'assets/images/characters/references/full-proportion.png';
  }

  bool get _hasGeneratedArtwork => _mode == _ArtworkMode.sprite
      ? _spriteLayers != null
      : _generatedImage != null;

  Uint8List? get _previewImage {
    if (_mode == _ArtworkMode.background) return _generatedImage;
    final layers = _spriteLayers;
    if (layers == null) return null;
    return switch (_spritePreview) {
      _SpritePreview.source => layers.source,
      _SpritePreview.head => layers.head,
      _SpritePreview.body => layers.body,
      _SpritePreview.rejoined => layers.rejoined,
    };
  }
}

enum _ArtworkMode { sprite, background }

enum _SpritePreview {
  source('Gemini source'),
  head('Head'),
  body('Body'),
  rejoined('Rejoined');

  const _SpritePreview(this.label);

  final String label;
}
