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
    this.chapterAppearanceIds = const [],
    this.speakingChapterIds = const [],
    this.visualStates = const [],
    this.recurring = false,
    this.importance = StoryEntityImportance.background,
    this.speaker = false,
    this.voiceId,
    this.approved = false,
    this.automaticallyApproved = false,
    this.lockedAppearance = false,
    this.assetIds = const [],
    this.unresolvedNotes = const [],
    this.confidence = 0,
    this.sceneLocation = false,
    this.parentSetting,
    this.backgroundBrief,
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
  final List<String> chapterAppearanceIds;
  final List<String> speakingChapterIds;
  final List<String> visualStates;
  final bool recurring;
  final StoryEntityImportance importance;
  final bool speaker;
  final String? voiceId;
  final bool approved;
  final bool automaticallyApproved;
  final bool lockedAppearance;
  final List<String> assetIds;
  final List<String> unresolvedNotes;
  final double confidence;
  final bool sceneLocation;
  final String? parentSetting;
  final String? backgroundBrief;

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
    'chapterAppearanceIds': chapterAppearanceIds,
    'speakingChapterIds': speakingChapterIds,
    'visualStates': visualStates,
    'recurring': recurring,
    'importance': importance.name,
    'speaker': speaker,
    if (voiceId != null) 'voiceId': voiceId,
    'approved': approved,
    'automaticallyApproved': automaticallyApproved,
    'lockedAppearance': lockedAppearance,
    'assetIds': assetIds,
    'unresolvedNotes': unresolvedNotes,
    'confidence': confidence,
    'sceneLocation': sceneLocation,
    if (parentSetting != null) 'parentSetting': parentSetting,
    if (backgroundBrief != null) 'backgroundBrief': backgroundBrief,
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
      chapterAppearanceIds: _strings(json['chapterAppearanceIds']),
      speakingChapterIds: _strings(json['speakingChapterIds']),
      visualStates: _strings(json['visualStates']),
      recurring: json['recurring'] as bool? ?? false,
      importance: StoryEntityImportance.values.byName(
        json['importance'] as String? ?? 'background',
      ),
      speaker: json['speaker'] as bool? ?? false,
      voiceId: json['voiceId'] as String?,
      approved: json['approved'] as bool? ?? false,
      automaticallyApproved: json['automaticallyApproved'] as bool? ?? false,
      lockedAppearance: json['lockedAppearance'] as bool? ?? false,
      assetIds: _strings(json['assetIds']),
      unresolvedNotes: _strings(json['unresolvedNotes']),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      sceneLocation: json['sceneLocation'] as bool? ?? false,
      parentSetting: json['parentSetting'] as String?,
      backgroundBrief: json['backgroundBrief'] as String?,
    );
  }

  StoryEntityData copyWith({
    StoryEntityKind? kind,
    String? canonicalName,
    List<String>? aliases,
    String? description,
    List<String>? relationships,
    List<String>? chapterAppearanceIds,
    List<String>? speakingChapterIds,
    List<String>? visualStates,
    bool? recurring,
    StoryEntityImportance? importance,
    bool? speaker,
    String? voiceId,
    bool? approved,
    bool? automaticallyApproved,
    bool? lockedAppearance,
    List<String>? assetIds,
    List<String>? unresolvedNotes,
    bool? sceneLocation,
    String? parentSetting,
    String? backgroundBrief,
  }) {
    return StoryEntityData(
      entityId: entityId,
      kind: kind ?? this.kind,
      canonicalName: canonicalName ?? this.canonicalName,
      aliases: aliases ?? this.aliases,
      description: description ?? this.description,
      relationships: relationships ?? this.relationships,
      firstSeenVolumeId: firstSeenVolumeId,
      firstSeenChapterId: firstSeenChapterId,
      sourceBlockIds: sourceBlockIds,
      chapterAppearanceIds: chapterAppearanceIds ?? this.chapterAppearanceIds,
      speakingChapterIds: speakingChapterIds ?? this.speakingChapterIds,
      visualStates: visualStates ?? this.visualStates,
      recurring: recurring ?? this.recurring,
      importance: importance ?? this.importance,
      speaker: speaker ?? this.speaker,
      voiceId: voiceId ?? this.voiceId,
      approved: approved ?? this.approved,
      automaticallyApproved:
          automaticallyApproved ?? this.automaticallyApproved,
      lockedAppearance: lockedAppearance ?? this.lockedAppearance,
      assetIds: assetIds ?? this.assetIds,
      unresolvedNotes: unresolvedNotes ?? this.unresolvedNotes,
      confidence: confidence,
      sceneLocation: sceneLocation ?? this.sceneLocation,
      parentSetting: parentSetting ?? this.parentSetting,
      backgroundBrief: backgroundBrief ?? this.backgroundBrief,
    );
  }

  StoryEntityData mergeCandidate(StoryEntityData candidate) {
    final refreshLocation =
        kind == StoryEntityKind.location &&
        candidate.sceneLocation &&
        !lockedAppearance &&
        assetIds.isEmpty;
    final mergedName = refreshLocation
        ? candidate.canonicalName
        : canonicalName;
    return StoryEntityData(
      entityId: entityId,
      kind: kind,
      canonicalName: mergedName,
      aliases: _union([
        ...aliases,
        if (refreshLocation) canonicalName,
        candidate.canonicalName,
        ...candidate.aliases,
      ], excluding: mergedName),
      description: refreshLocation || description.isEmpty
          ? candidate.description
          : description,
      relationships: _union([...relationships, ...candidate.relationships]),
      firstSeenVolumeId: firstSeenVolumeId ?? candidate.firstSeenVolumeId,
      firstSeenChapterId: firstSeenChapterId,
      sourceBlockIds: _union([...sourceBlockIds, ...candidate.sourceBlockIds]),
      chapterAppearanceIds: _union([
        ...chapterAppearanceIds,
        ...candidate.chapterAppearanceIds,
      ]),
      speakingChapterIds: _union([
        ...speakingChapterIds,
        ...candidate.speakingChapterIds,
      ]),
      visualStates: _union([...visualStates, ...candidate.visualStates]),
      recurring: recurring || candidate.recurring,
      importance: importance.index >= candidate.importance.index
          ? importance
          : candidate.importance,
      speaker: speaker || candidate.speaker,
      voiceId: voiceId,
      approved: approved,
      automaticallyApproved: automaticallyApproved,
      lockedAppearance: lockedAppearance,
      assetIds: assetIds,
      unresolvedNotes: _union([
        ...unresolvedNotes,
        ...candidate.unresolvedNotes,
      ]),
      confidence: confidence >= candidate.confidence
          ? confidence
          : candidate.confidence,
      sceneLocation: sceneLocation || candidate.sceneLocation,
      parentSetting: candidate.parentSetting ?? parentSetting,
      backgroundBrief: candidate.backgroundBrief ?? backgroundBrief,
    );
  }

  StoryEntityData withChapterAppearance(String chapterId) {
    return copyWith(
      chapterAppearanceIds: _union([...chapterAppearanceIds, chapterId]),
      speakingChapterIds: speaker
          ? _union([...speakingChapterIds, chapterId])
          : speakingChapterIds,
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

class StoryEntityPolicy {
  const StoryEntityPolicy._();

  static const autoApprovalConfidence = 0.85;

  static StoryEntityData applyAutomaticApproval(StoryEntityData entity) {
    final specificLocation =
        entity.kind != StoryEntityKind.location ||
        (entity.sceneLocation &&
            (entity.backgroundBrief?.trim().isNotEmpty ?? false) &&
            (entity.parentSetting == null ||
                _normalize(entity.canonicalName) !=
                    _normalize(entity.parentSetting!)));
    final approve =
        entity.confidence >= autoApprovalConfidence &&
        entity.description.trim().isNotEmpty &&
        entity.sourceBlockIds.isNotEmpty &&
        entity.unresolvedNotes.isEmpty &&
        specificLocation;
    return entity.copyWith(approved: approve, automaticallyApproved: approve);
  }

  static String _normalize(String value) => value.trim().toLowerCase();
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
