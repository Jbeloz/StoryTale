import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/state/storytale_scope.dart';
import '../../../shared/widgets/storytale_components.dart';
import '../data/face_profile_catalog.dart';
import '../data/sprite_face_catalog.dart';
import '../data/sprite_layer_processor.dart';
import '../data/sprite_rig.dart';
import '../data/story_bible_repository.dart';
import '../data/story_human_repository.dart';
import 'sprite_positioner_page.dart';
import 'widgets/sprite_face_view.dart';
import 'widgets/sprite_rig_view.dart';

class StoryHumanCatalogPage extends StatefulWidget {
  const StoryHumanCatalogPage({
    super.key,
    this.humanRepository,
    this.storyBibleRepository,
  });

  final StoryHumanRepository? humanRepository;
  final StoryBibleRepository? storyBibleRepository;

  @override
  State<StoryHumanCatalogPage> createState() => _StoryHumanCatalogPageState();
}

class _StoryHumanCatalogPageState extends State<StoryHumanCatalogPage> {
  static const _faceProfileCatalogAsset =
      'assets/images/characters/face_profiles/catalog.json';

  late final StoryHumanRepository _humanRepository;
  late final StoryBibleRepository _storyBibleRepository;
  late final Future<SpriteFaceProfileCatalog> _faceProfileCatalog;
  final _generatedFaceCatalog = SpriteFaceCatalog(
    id: 'generated_character_faces',
    headPartId: 'head',
    defaultExpressionId: 'neutral',
    expressions: const [],
  );
  final _faceProfiles = <String, Future<SpriteFaceProfileBundle>>{};
  List<StoryHumanAssetData> _assets = const [];
  String? _bookId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _humanRepository = widget.humanRepository ?? StoryHumanRepository();
    _storyBibleRepository =
        widget.storyBibleRepository ?? StoryBibleRepository();
    _faceProfileCatalog = SpriteFaceProfileCatalog.load(
      _faceProfileCatalogAsset,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bookId = StoryTaleScope.of(context).currentBook?.id;
    if (bookId == null || bookId == _bookId) return;
    _bookId = bookId;
    _load(bookId);
  }

  Future<void> _load(String bookId) async {
    setState(() => _loading = true);
    final bible = await _storyBibleRepository.load(bookId);
    final assets = await _humanRepository.sync(bible);
    if (!mounted || _bookId != bookId) return;
    setState(() {
      _assets = assets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = StoryTaleScope.of(context).currentBook;
    if (book == null) {
      return const StoryTaleInfoPage(
        title: 'Book Characters',
        description: 'Choose a book before viewing its reusable characters.',
      );
    }
    return StoryTaleAppShell(
      title: 'Book Characters',
      actions: [
        IconButton(
          tooltip: 'Reload',
          onPressed: _loading || _bookId == null ? null : () => _load(_bookId!),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _content(book.title),
    );
  }

  Widget _content(String bookTitle) {
    if (_assets.isEmpty) {
      return StoryTaleEmptyState(
        title: 'No approved human characters',
        message:
            'Approved people found during volume analysis will appear here.',
        actionLabel: 'Go back',
        onAction: () => Navigator.of(context).pop(),
        icon: Icons.people_outline,
      );
    }
    final ready = _assets.where((asset) => asset.hasReadyBytes).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Each approved person has one locked reusable identity for every '
          'chapter. This catalog is read-only.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('${_assets.length} characters')),
            Chip(label: Text('$ready ready')),
          ],
        ),
        const SizedBox(height: 8),
        for (final asset in _assets) _characterCard(asset),
      ],
    );
  }

  Widget _characterCard(StoryHumanAssetData asset) {
    final validation = asset.packageValidation;
    final ready =
        asset.status == StoryHumanAssetStatus.approved && validation.isValid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(ready ? Icons.check : Icons.person_outline),
              ),
              title: Text(asset.name),
              subtitle: Text(
                '${asset.actorProfileId} actor • ${asset.faceProfileId} face • '
                '${asset.chapterIds.length} chapter'
                '${asset.chapterIds.length == 1 ? '' : 's'}',
              ),
              trailing: Text(ready ? 'Ready' : 'Needs review'),
            ),
            Text(asset.description),
            const SizedBox(height: 10),
            _packageDetails(asset, validation),
            const SizedBox(height: 12),
            if (ready) _proof(asset),
            if (asset.validationError != null) ...[
              const SizedBox(height: 6),
              Text(
                asset.validationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _packageDetails(
    StoryHumanAssetData asset,
    SpriteRigValidation validation,
  ) {
    final source = [
      asset.generationProvider,
      asset.generationModel,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: Icon(
            validation.isValid ? Icons.verified_outlined : Icons.error_outline,
            size: 18,
          ),
          label: Text(
            validation.isValid ? 'Rig package valid' : 'Rig package invalid',
          ),
        ),
        Chip(label: Text('Rig ${asset.rigId}')),
        Chip(label: Text('Entity ${asset.entityId}')),
        if (source.isNotEmpty) Chip(label: Text(source)),
      ],
    );
  }

  Widget _proof(StoryHumanAssetData asset) {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Character'),
              Tab(text: 'Parts'),
              Tab(text: 'Faces'),
              Tab(text: 'Poses'),
            ],
          ),
          SizedBox(
            height: 410,
            child: TabBarView(
              children: [
                _characterProof(asset),
                _partsProof(asset),
                _facesProof(asset),
                _posesProof(asset),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => _openInSpriteStudio(asset),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in Sprite Studio'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _characterProof(StoryHumanAssetData asset) {
    final neutral = _pose(asset, 'neutral');
    return _faceAware(
      asset,
      builder: (overlayFor) => Padding(
        padding: const EdgeInsets.all(12),
        child: _rigPreview(asset, neutral, faceOverlay: overlayFor('neutral')),
      ),
    );
  }

  Widget _partsProof(StoryHumanAssetData asset) {
    final bytes = asset.partBytesById;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisExtent: 150,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: asset.rigDefinition.parts.length,
      itemBuilder: (context, index) {
        final part = asset.rigDefinition.parts[index];
        return _proofTile(
          label: part.label,
          child: _memoryArtwork(bytes[part.id]),
        );
      },
    );
  }

  Widget _facesProof(StoryHumanAssetData asset) {
    const expressions = {
      'neutral': 'Neutral',
      'talking': 'Talking',
      'happy': 'Happy',
      'sad': 'Sad',
      'angry': 'Angry',
      'surprised': 'Surprised',
    };
    return _faceAware(
      asset,
      builder: (overlayFor) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 185,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: expressions.length,
        itemBuilder: (context, index) {
          final expression = expressions.entries.elementAt(index);
          return _proofTile(
            label: expression.value,
            child: _rigPreview(
              asset,
              _pose(asset, 'neutral'),
              faceOverlay: overlayFor(expression.key),
            ),
          );
        },
      ),
    );
  }

  Widget _posesProof(StoryHumanAssetData asset) {
    const poseIds = ['neutral', 'talking', 'pointing', 'walking'];
    return _faceAware(
      asset,
      builder: (overlayFor) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisExtent: 185,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: poseIds.length,
        itemBuilder: (context, index) {
          final pose = _pose(asset, poseIds[index]);
          return _proofTile(
            label: pose.displayName,
            child: _rigPreview(
              asset,
              pose,
              faceOverlay: overlayFor(pose.faceExpressionId),
            ),
          );
        },
      ),
    );
  }

  Widget _faceAware(
    StoryHumanAssetData asset, {
    required Widget Function(
      SpriteFaceOverlayData Function(String expressionId) overlayFor,
    )
    builder,
  }) {
    return FutureBuilder<SpriteFaceProfileBundle>(
      future: _faceProfile(asset.faceProfileId),
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        if (bundle == null) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('The selected face profile could not load.'),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        return builder((expressionId) => _faceOverlay(bundle, expressionId));
      },
    );
  }

  Widget _proofTile({required String label, required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(child: child),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rigPreview(
    StoryHumanAssetData asset,
    SpriteRigPose pose, {
    SpriteFaceOverlayData? faceOverlay,
  }) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SpriteRigView(
        rig: asset.rigDefinition,
        pose: pose,
        partBytes: asset.partBytesById,
        faceCatalog: _generatedFaceCatalog,
        faceOverlay: faceOverlay,
      ),
    );
  }

  Widget _memoryArtwork(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

  SpriteRigPose _pose(StoryHumanAssetData asset, String id) {
    return asset.canonicalPoses[id] ?? asset.canonicalPoses.values.first;
  }

  Future<SpriteFaceProfileBundle> _faceProfile(String profileId) {
    return _faceProfiles.putIfAbsent(
      profileId,
      () async => (await _faceProfileCatalog).loadProfile(profileId),
    );
  }

  SpriteFaceOverlayData _faceOverlay(
    SpriteFaceProfileBundle bundle,
    String expressionId,
  ) {
    final composition = bundle.compositionFor(expressionId);
    return SpriteFaceOverlayData(
      profileId: composition.profileId,
      setId: composition.setId,
      layers: [
        for (final asset in composition.layerAssets)
          SpriteFaceLayer.asset(asset),
      ],
    );
  }

  void _openInSpriteStudio(StoryHumanAssetData asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SpritePositionerPage(
          initialRig: asset.rigDefinition,
          initialPoses: asset.canonicalPoses,
          initialPartBytes: asset.partBytesById,
          initialTitle: '${asset.name} Sprite',
        ),
      ),
    );
  }
}
