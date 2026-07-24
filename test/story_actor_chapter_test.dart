import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storytale/src/core/state/storytale_controller.dart';
import 'package:storytale/src/features/animated_story/data/story_pose_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('one review chapter covers its text and all starter actors', (
    tester,
  ) async {
    final controller = StoryTaleController();
    final chapter = controller.books.first.chapters.first;
    final story = controller.storyFor(chapter);
    final sourceText = chapter.originalText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final storyText = story.shots
        .expand((shot) => shot.beats)
        .map((beat) => beat.originalText)
        .join(' ');

    expect(storyText, sourceText);
    expect(story.shots.length, inInclusiveRange(4, 10));

    final profiles = story.shots
        .expand((shot) => shot.characterLayers)
        .map((layer) => layer.faceProfileId)
        .toSet();
    expect(profiles, {'default', 'hero', 'heroine', 'elder', 'adult_deep'});

    final resolvedSets = <String, String>{};
    final resolver = StoryPoseResolver();
    for (final layer in story.shots.expand((shot) => shot.characterLayers)) {
      final resolved = await tester.runAsync(() => resolver.resolve(layer));
      expect(
        resolved,
        isNotNull,
        reason: 'Character ${layer.characterId} did not resolve.',
      );
      expect(resolved!.faceComposition?.profileId, layer.faceProfileId);
      resolvedSets[layer.characterId] = resolved.faceComposition!.setId;
    }

    expect(resolvedSets['hero_actor'], 'neutral');
    expect(resolvedSets['hero_walking_actor'], 'talking');
    expect(resolvedSets['heroine_actor'], 'happy');
    expect(resolvedSets['elder_actor'], 'sad');
    expect(resolvedSets['adult_actor'], 'angry');
  });
}
