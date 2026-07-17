import 'package:flutter/material.dart';

import '../../../shared/widgets/storytale_image_placeholder.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  final _pageController = PageController();
  bool _showSplash = true;
  int _page = 0;

  static const _items = [
    (
      title: 'Your stories, all in one place',
      message:
          'Import EPUB books and keep your reading progress on this device.',
      asset: 'assets/images/ui/onboarding_library.png',
      icon: Icons.local_library_outlined,
    ),
    (
      title: 'English to Filipino',
      message:
          'Request Filipino translations and keep the original text nearby.',
      asset: 'assets/images/ui/onboarding_translation.png',
      icon: Icons.translate,
    ),
    (
      title: 'Five expressive voices',
      message:
          'Prepare narrator and character voices locally for each chapter.',
      asset: 'assets/images/ui/onboarding_voices.png',
      icon: Icons.record_voice_over_outlined,
    ),
    (
      title: 'Bring every chapter to life',
      message: 'Use sprites, simple movement, subtitles, sounds, and a moral.',
      asset: 'assets/images/ui/onboarding_story_mode.png',
      icon: Icons.auto_awesome_motion_outlined,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return Scaffold(
        body: InkWell(
          onTap: () => setState(() => _showSplash = false),
          child: SizedBox.expand(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const StoryTaleImagePlaceholder(
                      path: 'assets/images/ui/splash_storybook.png',
                      label: 'Storybook artwork placeholder',
                      icon: Icons.auto_stories,
                      height: 220,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'StoryTale',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const Text('Read. Understand. Imagine.'),
                    const SizedBox(height: 24),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined),
                        SizedBox(height: 6),
                        Text('Tap anywhere to continue'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onFinished,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StoryTaleImagePlaceholder(
                          path: item.asset,
                          label: '${item.title} illustration placeholder',
                          icon: item.icon,
                          height: 240,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(item.message, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _items.length,
                (index) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: index == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_page == _items.length - 1) {
                      widget.onFinished();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    _page == _items.length - 1 ? 'Get Started' : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
