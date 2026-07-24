enum StoryEntityKind { human, animal, creature, plant, prop, location }

enum StoryEntityImportance { background, supporting, focus }

class StoryEntityData {
  const StoryEntityData({
    required this.entityId,
    required this.kind,
    required this.canonicalName,
    required this.description,
    required this.firstSeenChapterId,
    this.aliases = const [],
    this.relationships = const [],
    this.firstSeenVolumeId,
    this.sourceBlockIds = const [],
    this.recurring = false,
    this.importance = StoryEntityImportance.background,
    this.speaker = false,
    this.voiceId,
    this.approved = false,
    this.lockedAppearance = false,
    this.assetIds = const [],
    this.unresolvedNotes = const [],
    this.confidence = 0,
  });

  final String entityId;
  final StoryEntityKind kind;
  final String canonicalName;
  final List<String> aliases;
  final String description;
  final List<String> relationships;
  final String? firstSeenVolumeId;
  final String firstSeenChapterId;
  final List<String> sourceBlockIds;
  final bool recurring;
  final StoryEntityImportance importance;
  final bool speaker;
  final String? voiceId;
  final bool approved;
  final bool lockedAppearance;
  final List<String> assetIds;
  final List<String> unresolvedNotes;
  final double confidence;

  Map<String, dynamic> toJson() => {
    'entityId': entityId,
    'kind': kind.name,
    'canonicalName': canonicalName,
    'aliases': aliases,
    'description': description,
    'relationships': relationships,
    if (firstSeenVolumeId != null) 'firstSeenVolumeId': firstSeenVolumeId,
    'firstSeenChapterId': firstSeenChapterId,
    'sourceBlockIds': sourceBlockIds,
    'recurring': recurring,
    'importance': importance.name,
    'speaker': speaker,
    if (voiceId != null) 'voiceId': voiceId,
    'approved': approved,
    'lockedAppearance': lockedAppearance,
    'assetIds': assetIds,
    'unresolvedNotes': unresolvedNotes,
    'confidence': confidence,
  };

  factory StoryEntityData.fromJson(Map<String, dynamic> json) {
    return StoryEntityData(
      entityId: json['entityId'] as String,
      kind: StoryEntityKind.values.byName(json['kind'] as String),
      canonicalName: json['canonicalName'] as String,
      aliases: _strings(json['aliases']),
      description: json['description'] as String? ?? '',
      relationships: _strings(json['relationships']),
      firstSeenVolumeId: json['firstSeenVolumeId'] as String?,
      firstSeenChapterId: json['firstSeenChapterId'] as String,
      sourceBlockIds: _strings(json['sourceBlockIds']),
      recurring: json['recurring'] as bool? ?? false,
      importance: StoryEntityImportance.values.byName(
        json['importance'] as String? ?? 'background',
      ),
      speaker: json['speaker'] as bool? ?? false,
      voiceId: json['voiceId'] as String?,
      approved: json['approved'] as bool? ?? false,
      lockedAppearance: json['lockedAppearance'] as bool? ?? false,
      assetIds: _strings(json['assetIds']),
      unresolvedNotes: _strings(json['unresolvedNotes']),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  StoryEntityData mergeCandidate(StoryEntityData candidate) {
    return StoryEntityData(
      entityId: entityId,
      kind: kind,
      canonicalName: canonicalName,
      aliases: _union([
        ...aliases,
        candidate.canonicalName,
        ...candidate.aliases,
      ], excluding: canonicalName),
      description: description.isNotEmpty ? description : candidate.description,
      relationships: _union([...relationships, ...candidate.relationships]),
      firstSeenVolumeId: firstSeenVolumeId ?? candidate.firstSeenVolumeId,
      firstSeenChapterId: firstSeenChapterId,
      sourceBlockIds: _union([...sourceBlockIds, ...candidate.sourceBlockIds]),
      recurring: recurring || candidate.recurring,
      importance: importance.index >= candidate.importance.index
          ? importance
          : candidate.importance,
      speaker: speaker || candidate.speaker,
      voiceId: voiceId,
      approved: approved,
      lockedAppearance: lockedAppearance,
      assetIds: assetIds,
      unresolvedNotes: _union([
        ...unresolvedNotes,
        ...candidate.unresolvedNotes,
      ]),
      confidence: confidence >= candidate.confidence
          ? confidence
          : candidate.confidence,
    );
  }

  static List<String> _strings(dynamic value) {
    return (value as List<dynamic>? ?? const []).whereType<String>().toList(
      growable: false,
    );
  }

  static List<String> _union(List<String> values, {String? excluding}) {
    final excluded = excluding?.trim().toLowerCase();
    final seen = <String>{};
    return [
      for (final value in values)
        if (value.trim().isNotEmpty &&
            value.trim().toLowerCase() != excluded &&
            seen.add(value.trim().toLowerCase()))
          value.trim(),
    ];
  }
}

class BookStoryBibleData {
  const BookStoryBibleData({
    required this.bookId,
    this.version = 1,
    this.entities = const [],
  });

  final String bookId;
  final int version;
  final List<StoryEntityData> entities;

  factory BookStoryBibleData.empty(String bookId) {
    return BookStoryBibleData(bookId: bookId);
  }

  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'version': version,
    'entities': entities.map((entity) => entity.toJson()).toList(),
  };

  factory BookStoryBibleData.fromJson(Map<String, dynamic> json) {
    return BookStoryBibleData(
      bookId: json['bookId'] as String,
      version: json['version'] as int? ?? 1,
      entities: (json['entities'] as List<dynamic>? ?? const [])
          .map(
            (value) => StoryEntityData.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  BookStoryBibleData mergeCandidates(List<StoryEntityData> candidates) {
    final merged = [...entities];
    for (final candidate in candidates) {
      final index = merged.indexWhere(
        (entity) => _sameEntity(entity, candidate),
      );
      if (index < 0) {
        merged.add(candidate);
      } else {
        merged[index] = merged[index].mergeCandidate(candidate);
      }
    }
    return BookStoryBibleData(
      bookId: bookId,
      version: version,
      entities: merged,
    );
  }

  static bool _sameEntity(StoryEntityData left, StoryEntityData right) {
    if (left.entityId == right.entityId) return true;
    final leftNames = {
      left.canonicalName,
      ...left.aliases,
    }.map((value) => value.trim().toLowerCase()).toSet();
    final rightNames = {
      right.canonicalName,
      ...right.aliases,
    }.map((value) => value.trim().toLowerCase()).toSet();
    return left.kind == right.kind &&
        leftNames.intersection(rightNames).isNotEmpty;
  }
}
