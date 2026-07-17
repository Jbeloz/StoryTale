import 'package:flutter/material.dart';

import '../models/storytale_models.dart';
import 'storytale_image_placeholder.dart';

class StoryTaleBottomNav extends StatelessWidget {
  const StoryTaleBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.local_library_outlined),
          selectedIcon: Icon(Icons.local_library),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Now Reading',
        ),
        NavigationDestination(
          icon: Icon(Icons.headphones_outlined),
          selectedIcon: Icon(Icons.headphones),
          label: 'Audio',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class StoryTaleAppShell extends StatelessWidget {
  const StoryTaleAppShell({
    required this.title,
    required this.body,
    this.selectedIndex,
    this.onTabSelected,
    this.actions,
    this.drawer,
    super.key,
  });

  final String title;
  final Widget body;
  final int? selectedIndex;
  final ValueChanged<int>? onTabSelected;
  final List<Widget>? actions;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(child: body),
      bottomNavigationBar: selectedIndex == null || onTabSelected == null
          ? null
          : StoryTaleBottomNav(
              selectedIndex: selectedIndex!,
              onSelected: onTabSelected!,
            ),
    );
  }
}

class StoryTaleSectionHeader extends StatelessWidget {
  const StoryTaleSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class StoryTaleEmptyState extends StatelessWidget {
  const StoryTaleEmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    required this.book,
    required this.onTap,
    this.onMenu,
    super.key,
  });

  final BookData book;
  final VoidCallback onTap;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: StoryTaleImagePlaceholder(
          path: book.coverPath,
          label: book.title,
          icon: Icons.menu_book,
          width: 56,
          height: 72,
          borderRadius: 8,
        ),
        title: Text(book.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.author),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: book.progress),
          ],
        ),
        trailing: onMenu == null
            ? const Icon(Icons.chevron_right)
            : IconButton(onPressed: onMenu, icon: const Icon(Icons.more_vert)),
      ),
    );
  }
}

class ChapterListTile extends StatelessWidget {
  const ChapterListTile({
    required this.chapter,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final ChapterData chapter;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        chapter.bookmarked ? Icons.bookmark : Icons.description_outlined,
      ),
      title: Text(chapter.title),
      subtitle: chapter.progress > 0
          ? LinearProgressIndicator(value: chapter.progress)
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class StoryTaleInfoPage extends StatelessWidget {
  const StoryTaleInfoPage({
    required this.title,
    required this.description,
    this.children = const [],
    super.key,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return StoryTaleAppShell(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StoryTaleImagePlaceholder(
            label: '$title image placeholder',
            icon: Icons.auto_awesome_outlined,
            height: 140,
          ),
          const SizedBox(height: 16),
          Text(description),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
