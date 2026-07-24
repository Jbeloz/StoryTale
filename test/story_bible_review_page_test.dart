import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/core/state/storytale_scope.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_models.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_repository.dart';
import 'package:storytale/src/features/animated_story/presentation/story_bible_review_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reviews and approves a pending story subject', (tester) async {
    final controller = StoryTaleController();
    final bookId = controller.currentBook!.id;
    final repository = StoryBibleRepository();
    await repository.save(
      BookStoryBibleData(
        bookId: bookId,
        entities: const [
          StoryEntityData(
            entityId: 'rose',
            kind: StoryEntityKind.plant,
            canonicalName: 'Rose',
            aliases: ['flower'],
            description: 'A rose growing on the small planet.',
            firstSeenChapterId: 'chapter-1',
            sourceBlockIds: ['block-1'],
            recurring: true,
            importance: StoryEntityImportance.focus,
            confidence: 0.98,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StoryTaleScope(
          controller: controller,
          child: StoryBibleReviewPage(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rose'), findsOneWidget);
    expect(find.textContaining('Pending review'), findsOneWidget);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect((await repository.load(bookId)).entities.single.approved, isTrue);
    expect(find.textContaining('Approved'), findsWidgets);
  });
}
