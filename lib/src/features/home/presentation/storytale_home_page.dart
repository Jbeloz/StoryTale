import 'package:flutter/material.dart';

import '../../animated_story/presentation/animated_story_page.dart';
import '../../library/presentation/library_page.dart';
import '../../reader/presentation/reader_page.dart';

class StoryTaleHomePage extends StatefulWidget {
  const StoryTaleHomePage({super.key});

  @override
  State<StoryTaleHomePage> createState() => _StoryTaleHomePageState();
}

class _StoryTaleHomePageState extends State<StoryTaleHomePage> {
  static const _pages = <Widget>[
    LibraryPage(),
    ReaderPage(),
    AnimatedStoryPage(),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('StoryTale'),
            Text(
              'Read. Understand. Imagine.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_library_outlined),
            selectedIcon: Icon(Icons.local_library),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Reader',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_motion_outlined),
            selectedIcon: Icon(Icons.auto_awesome_motion),
            label: 'Story Mode',
          ),
        ],
      ),
    );
  }
}
