import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/core/state/storytale_scope.dart';
import 'package:storytale/src/features/animated_story/data/story_background_repository.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_repository.dart';
import 'package:storytale/src/features/animated_story/presentation/story_background_catalog_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('allows the built-in preview location to generate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = StoryTaleController();

    await tester.pumpWidget(
      MaterialApp(
        home: StoryTaleScope(
          controller: controller,
          child: StoryBackgroundCatalogPage(
            backgroundRepository: StoryBackgroundRepository(),
            storyBibleRepository: StoryBibleRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moonlit rose garden'), findsOneWidget);
    expect(find.text('Built-in preview location'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(
        const Key('generate-background-moonlit_rose_garden::unspecified'),
      ),
    );
    expect(button.onPressed, isNotNull);
  });
}
