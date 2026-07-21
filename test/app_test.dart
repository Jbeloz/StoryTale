import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/app.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';

void main() {
  testWidgets('StoryTale shell navigates between its main sections', (
    tester,
  ) async {
    await _usePhoneSize(tester);
    await _pumpStoryTale(tester);

    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('My Books'), findsOneWidget);
    expect(find.text('Add EPUB Book'), findsOneWidget);

    await tester.tap(find.text('Now Reading'));
    await tester.pumpAndSettle();
    expect(find.text('Continue Reading'), findsWidgets);

    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    expect(find.text('Audio Book'), findsOneWidget);
    expect(
      find.text(
        'Daily Dose Narrator - Pitch +0 - real generated chapter audio',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Voice'));
    await tester.pumpAndSettle();
    expect(find.text('Deep Character'), findsOneWidget);
    await tester.tap(find.text('Deep Character'));
    await tester.pumpAndSettle();
    expect(
      find.text('Deep Character - Pitch +0 - real generated chapter audio'),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Reading History'), findsOneWidget);
  });

  testWidgets('library opens the functional EPUB import page', (tester) async {
    await _usePhoneSize(tester);
    await _pumpStoryTale(tester);

    await tester.ensureVisible(find.text('Add EPUB Book'));
    await tester.tap(find.text('Add EPUB Book'));
    await tester.pumpAndSettle();

    expect(find.text('Add EPUB'), findsOneWidget);
    expect(find.text('Select EPUB File'), findsOneWidget);
    expect(find.text('Save Book'), findsOneWidget);
  });

  testWidgets('book details opens reader and Filipino translation mode', (
    tester,
  ) async {
    await _usePhoneSize(tester);
    await _pumpStoryTale(tester);

    await tester.tap(find.text('The Little Prince').first);
    await tester.pumpAndSettle();
    expect(find.text('Read Now'), findsOneWidget);

    await tester.tap(find.text('Read Now'));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1'), findsOneWidget);

    await tester.tap(find.text('Translate'));
    await tester.pumpAndSettle();
    expect(find.text('Filipino'), findsOneWidget);
    await tester.tap(find.text('Filipino'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noong unang panahon'), findsOneWidget);
  });

  testWidgets('chapter Story Mode preparation reaches the player', (
    tester,
  ) async {
    await _usePhoneSize(tester);
    await _pumpStoryTale(tester);

    await tester.tap(find.text('The Little Prince').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Story Mode'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare Story Mode'), findsOneWidget);

    await tester.ensureVisible(find.text('Prepare Chapter Story'));
    await tester.tap(find.text('Prepare Chapter Story'));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    expect(find.text('Story Ready'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Story Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Story Mode'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Scene 1 of 4'), findsOneWidget);
    expect(find.byKey(const Key('story-character-neutral')), findsOneWidget);

    for (final pose in ['talking', 'pointing', 'walking']) {
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('story-character-$pose')), findsOneWidget);
    }
  });

  testWidgets('startup can move from splash to onboarding and library', (
    tester,
  ) async {
    await _usePhoneSize(tester);
    await _pumpStoryTale(tester, showStartup: true);

    expect(find.text('StoryTale'), findsOneWidget);
    expect(find.text('Tap anywhere to continue'), findsOneWidget);
    await tester.tap(find.text('Tap anywhere to continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your stories, all in one place'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('My Library'), findsOneWidget);
  });

  testWidgets('reader scroll saves chapter and book progress', (tester) async {
    await _usePhoneSize(tester);
    final controller = StoryTaleController();
    await _pumpStoryTale(tester, controller: controller);

    await tester.tap(find.text('The Little Prince').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read Now'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -10000),
    );
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsOneWidget);
    expect(controller.currentChapter!.progress, 1);
    expect(controller.currentBook!.progress, closeTo(0.25, 0.001));
  });

  testWidgets('voice manifest loads current models and pitch defaults', (
    tester,
  ) async {
    await _usePhoneSize(tester);
    final controller = StoryTaleController();
    await _pumpStoryTale(tester, controller: controller);

    expect(
      controller.voiceModelFile('heroine'),
      'Suika Ibuki (The Memories of Phantasm).pth',
    );
    expect(controller.voiceModelFile('hero'), 'maki.pth');
    expect(controller.voicePitch('heroine'), 16);
    expect(controller.voicePitch('hero'), 16);
    expect(
      controller.audioPath('little-prince-chapter-1', 'heroine'),
      contains('chapter-1-heroine-'),
    );
  });
}

Future<StoryTaleController> _pumpStoryTale(
  WidgetTester tester, {
  StoryTaleController? controller,
  bool showStartup = false,
}) async {
  final appController = controller ?? StoryTaleController();
  await tester.pumpWidget(
    StoryTaleApp(controller: appController, showStartup: showStartup),
  );
  await tester.pump();
  return appController;
}

Future<void> _usePhoneSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
