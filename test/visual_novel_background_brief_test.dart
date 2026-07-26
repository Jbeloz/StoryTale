import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/visual_novel_background_brief.dart';
import 'package:storytale/src/shared/models/storytale_models.dart';

void main() {
  test('builds one grounded visual novel background prompt', () {
    final brief = VisualNovelBackgroundBrief.fromApprovedLocation(
      locationId: 'school_courtyard',
      stateId: 'sunset',
      place: 'School courtyard',
      parentSetting: 'A modern city school',
      sourceBrief: 'A cherry tree, benches, and a school building.',
    );

    final prompt = const VisualNovelBackgroundPromptBuilder().build(brief);

    expect(prompt, contains('1024x576 landscape 16:9'));
    expect(prompt, contains('School courtyard'));
    expect(prompt, contains('left, center, and right'));
    expect(prompt, contains('continuous physical environment'));
    expect(prompt, contains('floating islands'));
    expect(prompt, contains('warm sunset light'));
  });

  test('matches every shot to its cutscene location and state', () {
    final story = ChapterStoryData(
      chapterId: 'chapter-1',
      moral: '',
      cutscenes: [
        StoryCutsceneData(
          id: 'scene-1',
          locationId: 'garden',
          backgroundStateId: 'night',
          shots: [_shot('shot-1'), _shot('shot-2')],
        ),
        StoryCutsceneData(
          id: 'scene-2',
          locationId: 'garden',
          backgroundStateId: 'dawn',
          shots: [_shot('shot-3')],
        ),
        StoryCutsceneData(
          id: 'scene-3',
          locationId: 'courtyard',
          backgroundStateId: 'day',
          shots: [_shot('shot-4')],
        ),
      ],
    );

    expect(story.backgroundRequirementForShot(1)?.key, 'garden::night');
    expect(story.backgroundRequirementForShot(2)?.key, 'garden::dawn');
    expect(story.backgroundRequirementForShot(3)?.key, 'courtyard::day');
    expect(story.backgroundRequirementForShot(4), isNull);
  });
}

StoryShotPlanData _shot(String id) {
  return StoryShotPlanData(
    id: id,
    layoutId: 'background_establishing',
    backgroundId: 'background',
    beats: [
      StoryBeatData(id: '$id-beat', speakerId: 'narrator', originalText: 'Text'),
    ],
  );
}
