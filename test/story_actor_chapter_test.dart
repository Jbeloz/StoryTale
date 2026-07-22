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
    final sourceBlocks = chapter.originalText
        .split(RegExp(r'\n\s*\n'))
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final sceneBlocks = story.scenes
        .expand((scene) => scene.subtitle.split(RegExp(r'\n\s*\n')))
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    expect(sceneBlocks, sourceBlocks);
    expect(story.scenes.length, inInclusiveRange(4, 10));

    final profiles = story.scenes
        .expand((scene) => scene.characterLayers)
        .map((layer) => layer.faceProfileId)
        .toSet();
    expect(profiles, {'default', 'hero', 'heroine', 'elder', 'adult_deep'});

    final resolvedSets = <String, String>{};
    final resolver = StoryPoseResolver();
    for (final scene in story.scenes) {
      final layer = scene.characterLayers.single;
      final resolved = await tester.runAsync(() => resolver.resolve(layer));
      expect(resolved, isNotNull, reason: 'Scene ${scene.id} did not resolve.');
      expect(resolved!.faceComposition?.profileId, layer.faceProfileId);
      resolvedSets[layer.characterId] = resolved.faceComposition!.setId;
    }

    expect(resolvedSets['hero_actor'], 'talking');
    expect(resolvedSets['heroine_actor'], 'happy');
    expect(resolvedSets['elder_actor'], 'sad');
    expect(resolvedSets['adult_actor'], 'angry');
  });
}
