class VisualNovelBackgroundBrief {
  const VisualNovelBackgroundBrief({
    required this.locationId,
    required this.stateId,
    required this.place,
    required this.parentSetting,
    required this.foreground,
    required this.middleGround,
    required this.distantBackground,
    required this.stageSurface,
    required this.landmarks,
    required this.safeZones,
    required this.lighting,
    required this.weather,
    required this.style,
    required this.exclusions,
  });

  factory VisualNovelBackgroundBrief.fromApprovedLocation({
    required String locationId,
    required String stateId,
    required String place,
    required String sourceBrief,
    String? parentSetting,
  }) {
    final state = _stateDetails(stateId);
    return VisualNovelBackgroundBrief(
      locationId: locationId,
      stateId: stateId,
      place: '$place. $sourceBrief',
      parentSetting: parentSetting?.trim().isNotEmpty == true
          ? parentSetting!.trim()
          : place,
      foreground:
          'An unobstructed, grounded foreground that belongs to this place.',
      middleGround:
          'The main walkable scene area with recognizable environmental details.',
      distantBackground:
          'A natural continuation of the same environment with atmospheric depth.',
      stageSurface:
          'One continuous floor or ground plane suitable for standing characters.',
      landmarks:
          'Preserve the important landmarks stated in the approved place description.',
      safeZones:
          'Keep open character lanes on the left, center, and right; do not block them with large objects.',
      lighting: state.$1,
      weather: state.$2,
      style:
          'Polished 2D storybook anime visual-novel background, cohesive perspective, clean shapes, gentle detail.',
      exclusions: const [
        'people',
        'characters',
        'animals',
        'text',
        'letters',
        'logos',
        'watermarks',
        'UI',
        'frames',
        'floating islands',
        'dioramas',
        'isolated objects',
        'portrait composition',
      ],
    );
  }

  final String locationId;
  final String stateId;
  final String place;
  final String parentSetting;
  final String foreground;
  final String middleGround;
  final String distantBackground;
  final String stageSurface;
  final String landmarks;
  final String safeZones;
  final String lighting;
  final String weather;
  final String style;
  final List<String> exclusions;

  Map<String, dynamic> toJson() => {
    'locationId': locationId,
    'stateId': stateId,
    'place': place,
    'parentSetting': parentSetting,
    'foreground': foreground,
    'middleGround': middleGround,
    'distantBackground': distantBackground,
    'stageSurface': stageSurface,
    'landmarks': landmarks,
    'safeZones': safeZones,
    'lighting': lighting,
    'weather': weather,
    'style': style,
    'exclusions': exclusions,
  };

  static (String, String) _stateDetails(String stateId) {
    return switch (stateId.trim().toLowerCase()) {
      'dawn' => ('soft dawn light with long gentle shadows', 'clear'),
      'sunset' => ('warm sunset light with a readable foreground', 'clear'),
      'night' => ('moonlit night with readable stage lighting', 'clear'),
      'rain' => ('soft overcast light with visible reflections', 'rain'),
      'storm' => ('dramatic storm light without hiding the stage', 'storm'),
      'snow' => ('soft cold daylight with readable contrast', 'snow'),
      'damaged' => ('neutral readable light', 'clear after damage'),
      _ => ('balanced storybook daylight', 'clear'),
    };
  }
}

class VisualNovelBackgroundPromptBuilder {
  const VisualNovelBackgroundPromptBuilder();

  String build(VisualNovelBackgroundBrief brief) {
    return [
      'Create exactly one 1024x576 landscape 16:9 visual-novel environment background.',
      'Place: ${brief.place}',
      'Wider setting: ${brief.parentSetting}.',
      'Required state: ${brief.stateId}.',
      'Foreground: ${brief.foreground}',
      'Middle ground: ${brief.middleGround}',
      'Distant background: ${brief.distantBackground}',
      'Stage surface: ${brief.stageSurface}',
      'Landmarks: ${brief.landmarks}',
      'Composition: ${brief.safeZones}',
      'Lighting: ${brief.lighting}. Weather: ${brief.weather}.',
      'Style: ${brief.style}',
      'Show a continuous physical environment at human eye level with a wide camera.',
      'Do not crop the environment and do not make a close-up.',
      'Exclude: ${brief.exclusions.join(', ')}.',
    ].join(' ');
  }
}
