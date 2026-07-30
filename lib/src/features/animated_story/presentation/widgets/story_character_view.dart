import 'package:flutter/material.dart';

import '../../../../shared/models/storytale_models.dart';
import '../../data/story_asset_binary_store.dart';
import '../../data/sprite_layer_processor.dart';
import '../../data/story_pose_resolver.dart';
import 'sprite_face_view.dart';
import 'sprite_rig_view.dart';
import 'story_generated_human_view.dart';

bool shouldFlipStoryCharacter(String facing) => facing == 'left';

class StoryCharacterView extends StatefulWidget {
  const StoryCharacterView({
    required this.layer,
    this.resolver,
    this.width = 180,
    this.height = 260,
    this.scale = 1.55,
    super.key,
  });

  final StoryCharacterLayerData layer;
  final StoryPoseResolver? resolver;
  final double width;
  final double height;
  final double scale;

  @override
  State<StoryCharacterView> createState() => _StoryCharacterViewState();
}

class _StoryCharacterViewState extends State<StoryCharacterView> {
  late Future<ResolvedStoryCharacter?> _character;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StoryCharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.rigId != widget.layer.rigId ||
        oldWidget.layer.poseId != widget.layer.poseId ||
        oldWidget.layer.faceExpressionId != widget.layer.faceExpressionId ||
        oldWidget.layer.faceProfileId != widget.layer.faceProfileId ||
        oldWidget.layer.faceSetId != widget.layer.faceSetId ||
        oldWidget.layer.isSpeaking != widget.layer.isSpeaking) {
      _load();
    }
  }

  void _load() {
    _character = (widget.resolver ?? StoryPoseResolver()).resolve(widget.layer);
  }

  @override
  Widget build(BuildContext context) {
    final generatedMaster = StoryAssetBinaryStore.read(
      '${widget.layer.rigId}.master',
    );
    if (generatedMaster != null) {
      final parts = {
        for (final partId in SpriteLayerProcessor.rigPartIds)
          if (StoryAssetBinaryStore.read('${widget.layer.rigId}.$partId')
              case final bytes?)
            partId: bytes,
      };
      return _frame(
        key: ValueKey('story-human-${widget.layer.characterId}'),
        child: parts.length == SpriteLayerProcessor.rigPartIds.length
            ? FittedBox(
                fit: BoxFit.contain,
                child: StoryGeneratedHumanView(
                  parts: parts,
                  poseId: widget.layer.poseId,
                ),
              )
            : Image.memory(
                generatedMaster,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
      );
    }
    return FutureBuilder<ResolvedStoryCharacter?>(
      future: _character,
      builder: (context, snapshot) {
        final character = snapshot.data;
        if (character == null) return const SizedBox.shrink();
        return _frame(
          key: ValueKey('story-character-${character.pose.id}'),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SpriteRigView(
              rig: character.rig,
              pose: character.pose,
              faceCatalog: character.faceCatalog,
              faceOverlay: _faceOverlay(character),
            ),
          ),
        );
      },
    );
  }

  Widget _frame({required Key key, required Widget child}) {
    return SizedBox(
      key: key,
      width: widget.width,
      height: widget.height,
      child: ClipRect(
        child: Transform.flip(
          key: ValueKey(
            'story-facing-${widget.layer.characterId}-'
            '${widget.layer.facing}',
          ),
          flipX: shouldFlipStoryCharacter(widget.layer.facing),
          child: Transform.scale(
            scale: widget.scale,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }

  SpriteFaceOverlayData? _faceOverlay(ResolvedStoryCharacter character) {
    final composition = character.faceComposition;
    if (composition == null) return null;
    return SpriteFaceOverlayData(
      profileId: composition.profileId,
      setId: composition.setId,
      layers: composition.layerAssets
          .map(SpriteFaceLayer.asset)
          .toList(growable: false),
    );
  }
}
