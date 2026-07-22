import 'package:flutter/material.dart';

import '../../../../shared/models/storytale_models.dart';
import '../../data/story_pose_resolver.dart';
import 'sprite_face_view.dart';
import 'sprite_rig_view.dart';

class StoryCharacterView extends StatefulWidget {
  const StoryCharacterView({required this.layer, this.resolver, super.key});

  final StoryCharacterLayerData layer;
  final StoryPoseResolver? resolver;

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
    return FutureBuilder<ResolvedStoryCharacter?>(
      future: _character,
      builder: (context, snapshot) {
        final character = snapshot.data;
        if (character == null) return const SizedBox.shrink();
        return SizedBox(
          key: ValueKey('story-character-${character.pose.id}'),
          width: 180,
          height: 260,
          child: ClipRect(
            child: Transform.scale(
              scale: 1.55,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SpriteRigView(
                  rig: character.rig,
                  pose: character.pose,
                  faceCatalog: character.faceCatalog,
                  faceOverlay: _faceOverlay(character),
                ),
              ),
            ),
          ),
        );
      },
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
