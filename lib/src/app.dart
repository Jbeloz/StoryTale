import 'package:flutter/material.dart';

import 'core/state/storytale_controller.dart';
import 'core/state/storytale_scope.dart';
import 'core/theme/app_theme.dart';
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
  }

  @override
  void dispose() {
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
