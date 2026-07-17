import 'package:flutter/material.dart';

import '../../library/presentation/library_page.dart';
import '../../narration/presentation/audio_pages.dart';
import '../../profile/presentation/profile_pages.dart';
import '../../search/presentation/search_page.dart';
import '../../../shared/widgets/storytale_components.dart';
import 'now_reading_page.dart';

class StoryTaleHomePage extends StatefulWidget {
  const StoryTaleHomePage({super.key});

  @override
  State<StoryTaleHomePage> createState() => _StoryTaleHomePageState();
}

class _StoryTaleHomePageState extends State<StoryTaleHomePage> {
  static const _pages = <Widget>[
    LibraryPage(),
    NowReadingPage(),
    AudioHubPage(),
    ProfilePage(),
  ];
  static const _titles = [
    'My Library',
    'Now Reading',
    'Audio Book',
    'My Profile',
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StoryTaleAppShell(
      title: _titles[_selectedIndex],
      selectedIndex: _selectedIndex,
      onTabSelected: (index) => setState(() => _selectedIndex = index),
      actions: _selectedIndex == 0
          ? [
              IconButton(
                tooltip: 'Search library',
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
                icon: const Icon(Icons.search),
              ),
            ]
          : null,
      body: IndexedStack(index: _selectedIndex, children: _pages),
    );
  }
}
