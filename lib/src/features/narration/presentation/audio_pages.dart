import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/state/storytale_controller.dart';
import '../../../core/state/storytale_scope.dart';
import '../../../shared/models/storytale_models.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';

class AudioHubPage extends StatefulWidget {
  const AudioHubPage({super.key});

  @override
  State<AudioHubPage> createState() => _AudioHubPageState();
}

class _AudioHubPageState extends State<AudioHubPage> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<void>? _completeSubscription;

  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 110);
  PlayerState _playerState = PlayerState.stopped;
  String? _loadedChapterId;
  double _speed = 1;
  int _sleepMinutes = 30;
  String _voiceId = 'narrator';

  bool get _playing => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _player.audioCache.prefix = '';
    }
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = _duration);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final book = controller.currentBook;
    final chapter = controller.currentChapter;
    if (book == null || chapter == null) {
      return StoryTaleEmptyState(
        title: 'No audiobook selected',
        message: 'Open a book from your library first.',
        actionLabel: 'View Downloads',
        onAction: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DownloadsPage())),
        icon: Icons.headphones_outlined,
      );
    }

    final chapterIndex = book.chapters.indexOf(chapter);
    final selectedVoice = controller.voices.firstWhere(
      (voice) => voice.id == _voiceId,
    );
    final hasAudio = controller.audioPath(chapter.id, _voiceId) != null;
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/ui/audio_background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoryTaleImagePlaceholder(
                    path: book.coverPath,
                    label: '${book.title} cover placeholder',
                    icon: Icons.auto_stories,
                    width: 92,
                    height: 132,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(chapter.title),
                        const SizedBox(height: 10),
                        Text('Author\n${book.author}'),
                        const SizedBox(height: 8),
                        Text('Language: ${book.language}'),
                        Text('Narrated by: ${selectedVoice.name}'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bookmark chapter',
                    onPressed: () => controller.toggleBookmark(chapter),
                    icon: Icon(
                      chapter.bookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    chapter.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    hasAudio
                        ? '${selectedVoice.name} - real generated chapter audio'
                        : 'Audio has not been generated for this chapter yet',
                  ),
                  Slider(
                    value: progress,
                    onChanged: hasAudio
                        ? (value) => _seekTo(
                            Duration(
                              milliseconds: (_duration.inMilliseconds * value)
                                  .round(),
                            ),
                          )
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(_time(_position)), Text(_time(_duration))],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Previous chapter',
                        onPressed: chapterIndex > 0
                            ? () => _openChapter(
                                controller,
                                book,
                                chapterIndex - 1,
                              )
                            : null,
                        icon: const Icon(Icons.skip_previous),
                      ),
                      IconButton(
                        tooltip: 'Back 15 seconds',
                        onPressed: hasAudio
                            ? () => _seekTo(
                                _position - const Duration(seconds: 15),
                              )
                            : null,
                        icon: const Icon(Icons.replay_10),
                      ),
                      IconButton.filled(
                        tooltip: _playing ? 'Pause' : 'Play',
                        onPressed: hasAudio
                            ? () => _togglePlayback(controller, chapter)
                            : null,
                        iconSize: 34,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      ),
                      IconButton(
                        tooltip: 'Forward 15 seconds',
                        onPressed: hasAudio
                            ? () => _seekTo(
                                _position + const Duration(seconds: 15),
                              )
                            : null,
                        icon: const Icon(Icons.forward_10),
                      ),
                      IconButton(
                        tooltip: 'Next chapter',
                        onPressed: chapterIndex < book.chapters.length - 1
                            ? () => _openChapter(
                                controller,
                                book,
                                chapterIndex + 1,
                              )
                            : null,
                        icon: const Icon(Icons.skip_next),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AudioOption(
                icon: Icons.list,
                value: 'Chapters',
                label: 'Contents',
                onTap: () => _showChapters(context, controller, book),
              ),
              _AudioOption(
                icon: Icons.speed,
                value: '${_speed}x',
                label: 'Speed',
                onTap: () async {
                  setState(() {
                    _speed = switch (_speed) {
                      1 => 1.25,
                      1.25 => 1.5,
                      _ => 1,
                    };
                  });
                  if (_playerState == PlayerState.playing) {
                    await _player.setPlaybackRate(_speed);
                  }
                },
              ),
              _AudioOption(
                icon: Icons.bedtime_outlined,
                value: '$_sleepMinutes min',
                label: 'Sleep',
                onTap: () => setState(() {
                  _sleepMinutes = switch (_sleepMinutes) {
                    15 => 30,
                    30 => 60,
                    _ => 15,
                  };
                }),
              ),
              _AudioOption(
                icon: Icons.record_voice_over_outlined,
                value: 'Voice',
                label: 'Change',
                onTap: () => _showVoices(context, controller, chapter),
              ),
            ],
          ),
          const SizedBox(height: 18),
          StoryTaleSectionHeader(
            title: 'Up Next',
            actionLabel: 'Voice Manager',
            onAction: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const VoiceManagerPage())),
          ),
          ...book.chapters
              .skip(chapterIndex + 1)
              .map(
                (nextChapter) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${book.chapters.indexOf(nextChapter) + 1}'),
                    ),
                    title: Text(nextChapter.title),
                    subtitle: const Text('10:00 placeholder'),
                    trailing: const Icon(Icons.more_vert),
                    onTap: () {
                      _openChapter(
                        controller,
                        book,
                        book.chapters.indexOf(nextChapter),
                      );
                    },
                  ),
                ),
              ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChapterAudioPreparationPage(),
              ),
            ),
            icon: const Icon(Icons.graphic_eq),
            label: Text(
              hasAudio ? 'Chapter Audio Ready' : 'Prepare Chapter Audio Later',
            ),
          ),
        ],
      ),
    );
  }

  String _time(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayback(
    StoryTaleController controller,
    ChapterData chapter,
  ) async {
    final audioPath = controller.audioPath(chapter.id, _voiceId);
    if (audioPath == null) return;

    try {
      if (_loadedChapterId != chapter.id ||
          _playerState == PlayerState.stopped ||
          _playerState == PlayerState.completed) {
        _loadedChapterId = chapter.id;
        await _player.play(AssetSource(audioPath));
        await _player.setPlaybackRate(_speed);
      } else if (_playing) {
        await _player.pause();
      } else {
        await _player.resume();
        await _player.setPlaybackRate(_speed);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The chapter audio could not be played.')),
      );
    }
  }

  Future<void> _seekTo(Duration position) async {
    final safePosition = position < Duration.zero
        ? Duration.zero
        : position > _duration
        ? _duration
        : position;
    await _player.seek(safePosition);
    if (mounted) setState(() => _position = safePosition);
  }

  Future<void> _resetPlayer() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _position = Duration.zero;
      _playerState = PlayerState.stopped;
      _loadedChapterId = null;
    });
  }

  void _openChapter(StoryTaleController controller, BookData book, int index) {
    controller.openBook(book, chapter: book.chapters[index]);
    _resetPlayer();
  }

  Future<void> _showChapters(
    BuildContext context,
    StoryTaleController controller,
    BookData book,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Audiobook Chapters')),
            ...book.chapters.map(
              (item) => ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(item.title),
                onTap: () {
                  controller.openBook(book, chapter: item);
                  Navigator.pop(sheetContext);
                  _resetPlayer();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVoices(
    BuildContext context,
    StoryTaleController controller,
    ChapterData chapter,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose Voice')),
            ...controller.voices.map((voice) {
              final ready = controller.audioPath(chapter.id, voice.id) != null;
              return ListTile(
                leading: Icon(
                  voice.id == _voiceId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(voice.name),
                subtitle: Text(
                  ready
                      ? '${voice.role} - chapter audio ready'
                      : '${voice.role} - chapter audio not generated',
                ),
                enabled: ready,
                onTap: ready
                    ? () {
                        Navigator.pop(sheetContext);
                        setState(() => _voiceId = voice.id);
                        _resetPlayer();
                      }
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AudioOption extends StatelessWidget {
  const _AudioOption({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Icon(icon),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceManagerPage extends StatelessWidget {
  const VoiceManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    return StoryTaleAppShell(
      title: 'Voice Manager',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Installed RVC voices are converted on the computer. Choose a '
            'generated voice from the Audio page to hear it.',
          ),
          const SizedBox(height: 16),
          ...controller.voices.map(
            (voice) => Card(
              child: ListTile(
                leading: Icon(_voiceIcon(voice.status)),
                title: Text(voice.name),
                subtitle: Text(
                  '${voice.role} - '
                  '${controller.voiceModelFile(voice.id) ?? _status(voice.status)}',
                ),
                trailing: Text(
                  voice.status == PreparationStatus.ready
                      ? 'Installed'
                      : 'Not installed',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _voiceIcon(PreparationStatus status) => switch (status) {
    PreparationStatus.ready => Icons.check_circle_outline,
    PreparationStatus.preparing => Icons.downloading,
    PreparationStatus.failed => Icons.error_outline,
    PreparationStatus.notStarted => Icons.record_voice_over_outlined,
  };

  static String _status(PreparationStatus status) => switch (status) {
    PreparationStatus.ready => 'Ready',
    PreparationStatus.preparing => 'Preparing',
    PreparationStatus.failed => 'Failed',
    PreparationStatus.notStarted => 'Not prepared',
  };
}

class ChapterAudioPreparationPage extends StatefulWidget {
  const ChapterAudioPreparationPage({super.key});

  @override
  State<ChapterAudioPreparationPage> createState() =>
      _ChapterAudioPreparationPageState();
}

class _ChapterAudioPreparationPageState
    extends State<ChapterAudioPreparationPage> {
  double _progress = 0;
  bool _working = false;

  Future<void> _prepare() async {
    final controller = StoryTaleScope.of(context);
    final chapter = controller.currentChapter;
    if (chapter == null) return;
    setState(() => _working = true);
    for (final value in [0.15, 0.35, 0.6, 0.85, 1.0]) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() => _progress = value);
    }
    controller.markAudioPrepared(chapter);
    setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final chapter = controller.currentChapter;
    final isReady =
        chapter != null &&
        controller.preparedAudioChapters.contains(chapter.id);
    return StoryTaleAppShell(
      title: 'Prepare Chapter Audio',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.graphic_eq, size: 72),
            const SizedBox(height: 16),
            Text(
              chapter?.title ?? 'No chapter selected',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Current test flow: generate the chapter narration, apply the '
              'downloaded RVC voice on the computer, then bundle the finished '
              'audio file with the app.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: isReady ? 1 : _progress),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: chapter == null || _working || isReady
                  ? null
                  : _prepare,
              icon: Icon(isReady ? Icons.check : Icons.play_arrow),
              label: Text(
                isReady
                    ? 'Audio Ready'
                    : _working
                    ? 'Preparing…'
                    : 'Prepare Audio',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    return StoryTaleAppShell(
      title: 'Downloads & Storage',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StorageTile(
            icon: Icons.menu_book_outlined,
            title: 'Imported EPUBs',
            value: '${controller.books.length} books',
          ),
          _StorageTile(
            icon: Icons.headphones_outlined,
            title: 'Cached narration',
            value: '${controller.preparedAudioChapters.length} chapters',
          ),
          _StorageTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Voice packs',
            value: '${controller.voices.length} planned slots',
          ),
          _StorageTile(
            icon: Icons.image_outlined,
            title: 'Story artwork',
            value: '${controller.stories.length} chapter packages',
          ),
          const SizedBox(height: 16),
          const Text(
            'Storage values are local prototype counts until filesystem '
            'persistence is connected.',
          ),
        ],
      ),
    );
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(value),
      ),
    );
  }
}
