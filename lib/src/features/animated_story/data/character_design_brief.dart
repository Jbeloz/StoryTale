class CharacterDesignBrief {
  const CharacterDesignBrief({
    required this.bookId,
    required this.characterId,
    required this.canonicalName,
    required this.actorProfileId,
    required this.sourceDescription,
    this.lockedAt,
  });

  final String bookId;
  final String characterId;
  final String canonicalName;
  final String actorProfileId;
  final String sourceDescription;
  final String? lockedAt;

  bool get isLocked => lockedAt != null;

  CharacterDesignBrief lock(String timestamp) {
    return CharacterDesignBrief(
      bookId: bookId,
      characterId: characterId,
      canonicalName: canonicalName,
      actorProfileId: actorProfileId,
      sourceDescription: sourceDescription,
      lockedAt: timestamp,
    );
  }

  String get generationPrompt {
    final description = sourceDescription.trim().isEmpty
        ? 'No extra appearance details were stated in the source.'
        : sourceDescription.trim();
    return 'Design ${canonicalName.trim()} as one reusable StoryTale '
        'character. Source-backed identity and appearance: $description '
        'Use the $actorProfileId modular face family only as an expression '
        'style guide. Preserve this hair, skin, fitted outfit, palette, and '
        'accessories for every chapter and volume. Do not invent weapons, '
        'logos, extra limbs, wings, facial features, scenery, or details not '
        'supported by the source.';
  }

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'characterId': characterId,
    'canonicalName': canonicalName,
    'actorProfileId': actorProfileId,
    'sourceDescription': sourceDescription,
    if (lockedAt != null) 'lockedAt': lockedAt,
  };

  factory CharacterDesignBrief.fromJson(Map<String, dynamic> json) {
    return CharacterDesignBrief(
      bookId: json['bookId'] as String? ?? '',
      characterId: json['characterId'] as String? ?? '',
      canonicalName: json['canonicalName'] as String? ?? '',
      actorProfileId: json['actorProfileId'] as String? ?? 'default',
      sourceDescription: json['sourceDescription'] as String? ?? '',
      lockedAt: json['lockedAt'] as String?,
    );
  }
}
