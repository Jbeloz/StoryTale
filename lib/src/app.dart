import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/storytale_home_page.dart';

class StoryTaleApp extends StatelessWidget {
  const StoryTaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StoryTale',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const StoryTaleHomePage(),
    );
  }
}
