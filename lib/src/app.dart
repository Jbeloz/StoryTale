import 'package:flutter/material.dart';

import 'core/state/storytale_controller.dart';
import 'core/state/storytale_scope.dart';
import 'core/theme/app_theme.dart';
import 'features/animated_story/presentation/story_pages.dart';
import 'features/home/presentation/storytale_home_page.dart';
import 'features/onboarding/presentation/startup_page.dart';

class StoryTaleApp extends StatefulWidget {
  const StoryTaleApp({this.controller, this.showStartup = true, super.key});

  final StoryTaleController? controller;
  final bool showStartup;

  @override
  State<StoryTaleApp> createState() => _StoryTaleAppState();
}

class _StoryTaleAppState extends State<StoryTaleApp> {
  late final StoryTaleController _controller;
  late final bool _ownsController;
  late bool _showStartup;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? StoryTaleController();
    _showStartup = widget.showStartup && !_controller.onboardingCompleted;
    // Load the locally stored library. This does not block the first frame;
    // the controller notifies its listeners once the books are back.
    _controller.restore();
  }

  @override
  void dispose() {
    // Save reading progress that is still waiting behind the debounce, even
    // when another owner keeps the controller alive.
    _controller.flushPendingSaves();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoryTaleScope(
      controller: _controller,
      child: MaterialApp(
        title: 'StoryTale',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routes: {'/review-story-artwork': (_) => const SpriteReviewPage()},
        home: _showStartup
            ? StartupPage(
                onFinished: () {
                  _controller.completeOnboarding();
                  setState(() => _showStartup = false);
                },
              )
            : const StoryTaleHomePage(),
      ),
    );
  }
}
