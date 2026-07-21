import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../../../shared/widgets/storytale_image_placeholder.dart';
import '../../animated_story/presentation/sprite_positioner_page.dart';
import '../../library/presentation/library_page.dart';
import '../../narration/presentation/audio_pages.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const StoryTaleImagePlaceholder(
                  path: 'assets/images/ui/default_profile_avatar.png',
                  label: 'Local profile',
                  icon: Icons.person,
                  width: 84,
                  height: 84,
                  borderRadius: 42,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.localProfileName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text('Local profile • no account required'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit local name',
                  onPressed: () => _editName(context),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ProfileLink(
          icon: Icons.library_books_outlined,
          title: 'My Bookshelf',
          onTap: () => _open(context, const BookshelfPage()),
        ),
        _ProfileLink(
          icon: Icons.history,
          title: 'Reading History',
          onTap: () => _open(context, const ReadingHistoryPage()),
        ),
        _ProfileLink(
          icon: Icons.download_outlined,
          title: 'Downloads',
          onTap: () => _open(context, const DownloadsPage()),
        ),
        _ProfileLink(
          icon: Icons.accessibility_new,
          title: 'Sprite Studio',
          onTap: () => _open(context, const SpritePositionerPage()),
        ),
        _ProfileLink(
          icon: Icons.settings_outlined,
          title: 'Settings',
          onTap: () => _open(context, const SettingsPage()),
        ),
        _ProfileLink(
          icon: Icons.help_outline,
          title: 'Help',
          onTap: () => _open(context, const HelpPage()),
        ),
        _ProfileLink(
          icon: Icons.info_outline,
          title: 'About StoryTale',
          onTap: () => _open(context, const AboutPage()),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = StoryTaleScope.of(context);
    final input = TextEditingController(text: controller.localProfileName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit local profile'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              controller.updateProfileName(input.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    input.dispose();
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class ReadingHistoryPage extends StatelessWidget {
  const ReadingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = StoryTaleScope.of(context);
    final books = [...controller.books]
      ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return StoryTaleAppShell(
      title: 'Reading History',
      body: books.isEmpty
          ? StoryTaleEmptyState(
              title: 'No history yet',
              message: 'Books you open will be listed here.',
              actionLabel: 'Back',
              onAction: () => Navigator.pop(context),
              icon: Icons.history,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: books
                  .map(
                    (book) => BookCoverCard(
                      book: book,
                      onTap: () {
                        controller.openBook(book);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BookDetailsPage(),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _automaticTranslation = false;
  bool _wifiOnlyImages = true;
  bool _reduceMotion = false;
  bool _cacheAudio = true;

  @override
  Widget build(BuildContext context) {
    return StoryTaleAppShell(
      title: 'Settings',
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('App language'),
            subtitle: Text('English'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: const Text('Automatic chapter translation'),
            subtitle: const Text('DeepL calls remain off by default'),
            value: _automaticTranslation,
            onChanged: (value) {
              setState(() => _automaticTranslation = value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('Generate images on Wi-Fi only'),
            value: _wifiOnlyImages,
            onChanged: (value) => setState(() => _wifiOnlyImages = value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.animation),
            title: const Text('Reduce Story Mode movement'),
            value: _reduceMotion,
            onChanged: (value) => setState(() => _reduceMotion = value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save_alt),
            title: const Text('Cache prepared chapter audio'),
            value: _cacheAudio,
            onChanged: (value) => setState(() => _cacheAudio = value),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Storage location'),
            subtitle: Text('Local app storage (prototype)'),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'These controls are functional in this session. Persistent local '
              'settings will be connected with the storage service.',
            ),
          ),
        ],
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoryTaleInfoPage(
      title: 'Help',
      description:
          'Import an EPUB, choose a chapter, then read, translate, prepare '
          'audio, or prepare its Story Mode. Original reading always remains '
          'available if an optional service fails.',
      children: [
        ListTile(
          leading: Icon(Icons.face_retouching_natural_outlined),
          title: Text('Gemini 3.1 Flash Image'),
          subtitle: Text('Reviewed character sprite creation'),
        ),
        ListTile(
          leading: Icon(Icons.upload_file),
          title: Text('Books must use the .epub format'),
        ),
        ListTile(
          leading: Icon(Icons.translate),
          title: Text('Filipino translation uses DeepL target code TL'),
        ),
        ListTile(
          leading: Icon(Icons.offline_bolt_outlined),
          title: Text('Saved books and prepared content work locally'),
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoryTaleInfoPage(
      title: 'About StoryTale',
      description:
          'StoryTale is a local-first mobile EPUB library prototype with '
          'English–Filipino translation, on-device narration, and sprite-based '
          'chapter Story Mode. Version 0.1.0.',
      children: [
        ListTile(
          leading: Icon(Icons.cloud_outlined),
          title: Text('Cloudflare Workers AI'),
          subtitle: Text('Chapter background generation only'),
        ),
        ListTile(
          leading: Icon(Icons.record_voice_over_outlined),
          title: Text('Offline ONNX voices'),
          subtitle: Text('Planned narrator and character voice packs'),
        ),
      ],
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
