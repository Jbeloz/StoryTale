import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_models.dart';
import 'package:storytale/src/features/animated_story/data/story_bible_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores one story bible per book', () async {
    final repository = StoryBibleRepository();
    final bible = BookStoryBibleData(bookId: 'book-1', entities: [_fox()]);

    await repository.save(bible);
    final loaded = await repository.load('book-1');

    expect(loaded.entities.single.canonicalName, 'Fox');
    expect(loaded.entities.single.assetIds, ['fox-neutral']);
    expect((await repository.load('book-2')).entities, isEmpty);
  });

  test('merges aliases but preserves approved appearance and assets', () {
    final existing = _fox();
    final candidate = StoryEntityData(
      entityId: 'fox',
      kind: StoryEntityKind.animal,
      canonicalName: 'The fox',
      aliases: const ['Red fox'],
      description: 'A speaking fox in the field.',
      firstSeenChapterId: 'chapter-2',
      sourceBlockIds: const ['block-4'],
      recurring: true,
      importance: StoryEntityImportance.focus,
      speaker: true,
      confidence: 0.94,
    );

    final merged = BookStoryBibleData(
      bookId: 'book-1',
      entities: [existing],
    ).mergeCandidates([candidate]).entities.single;

    expect(merged.entityId, 'fox');
    expect(merged.aliases, containsAll(['The fox', 'Red fox']));
    expect(merged.approved, isTrue);
    expect(merged.lockedAppearance, isTrue);
    expect(merged.assetIds, ['fox-neutral']);
    expect(merged.sourceBlockIds, containsAll(['block-1', 'block-4']));
  });

  test('refreshes an unlocked broad location with a specific scene place', () {
    const broad = StoryEntityData(
      entityId: 'chapter_place',
      kind: StoryEntityKind.location,
      canonicalName: 'Small Planet',
      description: 'A small planet.',
      firstSeenChapterId: 'chapter-1',
      approved: true,
    );
    const specific = StoryEntityData(
      entityId: 'chapter_place',
      kind: StoryEntityKind.location,
      canonicalName: 'Rose Garden Path',
      description: 'A path beside the prince’s rose garden.',
      firstSeenChapterId: 'chapter-1',
      sourceBlockIds: ['block-1'],
      approved: true,
      automaticallyApproved: true,
      sceneLocation: true,
      parentSetting: 'Small Planet',
      backgroundBrief: 'A narrow path bordered by roses.',
      confidence: 0.96,
    );

    final merged = BookStoryBibleData(
      bookId: 'book-1',
      entities: [broad],
    ).mergeCandidates([specific]).entities.single;

    expect(merged.canonicalName, 'Rose Garden Path');
    expect(merged.aliases, contains('Small Planet'));
    expect(merged.parentSetting, 'Small Planet');
    expect(merged.backgroundBrief, isNotEmpty);
  });
}

StoryEntityData _fox() {
  return const StoryEntityData(
    entityId: 'fox',
    kind: StoryEntityKind.animal,
    canonicalName: 'Fox',
    aliases: ['the animal'],
    description: 'A small fox.',
    firstSeenChapterId: 'chapter-1',
    sourceBlockIds: ['block-1'],
    recurring: true,
    importance: StoryEntityImportance.focus,
    speaker: true,
    voiceId: 'hero',
    approved: true,
    lockedAppearance: true,
    assetIds: ['fox-neutral'],
    confidence: 1,
  );
}
