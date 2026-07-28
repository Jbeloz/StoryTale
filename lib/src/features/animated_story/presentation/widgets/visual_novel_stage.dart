import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/models/storytale_models.dart';
import '../../../../shared/widgets/storytale_image_placeholder.dart';
import 'story_camera_viewport.dart';
import 'story_character_motion.dart';
import 'story_character_view.dart';
import 'visual_novel_layouts.dart';

double storyScaleFactor(String scale) {
  return switch (scale) {
    'background' => 0.78,
    'medium' => 1.16,
    'close' => 1.32,
    _ => 1,
  };
}

int storyDepthOrder(String depth) {
  return switch (depth) {
    'back' => 0,
    'front' => 2,
    _ => 1,
  };
}

double storyCharacterOpacity({
  required bool isSpeaking,
  required bool hasSpeaker,
  required int characterCount,
  required String depth,
}) {
  if (characterCount > 1 && hasSpeaker) {
    return isSpeaking ? 1 : 0.68;
  }
  return depth == 'back' ? 0.84 : 1;
}

class VisualNovelStage extends StatelessWidget {
  const VisualNovelStage({
    required this.shot,
    required this.speaker,
    required this.subtitle,
    this.backgroundBytes,
    this.focusAssetBytes = const {},
    super.key,
  });

  static const fallbackBackground =
      'assets/images/backgrounds/cloudflare_examples/moonlit-rose-garden.jpg';

  final StoryShotPlanData shot;
  final String speaker;
  final String subtitle;
  final Uint8List? backgroundBytes;
  final Map<String, Uint8List> focusAssetBytes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final characters = shot.characterLayers.take(3).toList();
        final layout = VisualNovelLayoutPreset.resolve(
          shot.layoutId,
          characters.length,
        );
        final entries =
            List.generate(
              characters.length,
              (index) => _StageCharacter(
                characters[index],
                layout.slots[index],
                index,
              ),
            )..sort((a, b) {
              final depth = storyDepthOrder(
                a.layer.depth,
              ).compareTo(storyDepthOrder(b.layer.depth));
              return depth == 0
                  ? a.originalIndex.compareTo(b.originalIndex)
                  : depth;
            });
        final hasSpeaker = characters.any((layer) => layer.isSpeaking);
        final media = MediaQuery.maybeOf(context);
        final reducedMotion =
            media?.disableAnimations == true ||
            media?.accessibleNavigation == true;
        final stageLayers =
            <_StageLayerWidget>[
              for (final entry in entries)
                _StageLayerWidget(
                  depth: storyDepthOrder(entry.layer.depth),
                  originalIndex: entry.originalIndex * 2,
                  child: _character(
                    entry: entry,
                    shot: shot,
                    constraints: constraints,
                    hasSpeaker: hasSpeaker,
                    characterCount: characters.length,
                    reducedMotion: reducedMotion,
                  ),
                ),
              for (final entry
                  in shot.focusAssetLayers
                      .where(
                        (layer) => focusAssetBytes.containsKey(layer.assetId),
                      )
                      .take(2)
                      .indexed)
                _StageLayerWidget(
                  depth: storyDepthOrder(entry.$2.depth),
                  originalIndex: entry.$1 * 2 + 1,
                  child: _focusAsset(
                    layer: entry.$2,
                    bytes: focusAssetBytes[entry.$2.assetId]!,
                    constraints: constraints,
                    reducedMotion: reducedMotion,
                  ),
                ),
            ]..sort((a, b) {
              final depth = a.depth.compareTo(b.depth);
              return depth == 0
                  ? a.originalIndex.compareTo(b.originalIndex)
                  : depth;
            });
        return ClipRRect(
          key: const Key('visual-novel-stage'),
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            key: ValueKey('story-layout-${shot.layoutId}'),
            fit: StackFit.expand,
            children: [
              StoryCameraViewport(
                animationKey: shot.id,
                presetId: shot.camera.presetId,
                reducedMotion: reducedMotion,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (backgroundBytes != null)
                      Image.memory(
                        backgroundBytes!,
                        key: const Key('approved-visual-novel-background'),
                        fit: BoxFit.cover,
                      )
                    else
                      StoryTaleImagePlaceholder(
                        key: const Key('visual-novel-background'),
                        path: shot.backgroundPath ?? fallbackBackground,
                        label: 'Chapter background',
                        icon: Icons.landscape_outlined,
                        height: double.infinity,
                        borderRadius: 0,
                      ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x33000000)],
                          stops: [0.58, 1],
                        ),
                      ),
                    ),
                    for (final layer in stageLayers) layer.child,
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _SubtitleBar(speaker: speaker, subtitle: subtitle),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _character({
    required _StageCharacter entry,
    required StoryShotPlanData shot,
    required BoxConstraints constraints,
    required bool hasSpeaker,
    required int characterCount,
    required bool reducedMotion,
  }) {
    return AnimatedAlign(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: entry.slot.alignment,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: AnimatedOpacity(
          key: ValueKey(
            'story-focus-${entry.layer.characterId}-'
            '${entry.layer.isSpeaking}',
          ),
          duration: const Duration(milliseconds: 220),
          opacity: storyCharacterOpacity(
            isSpeaking: entry.layer.isSpeaking,
            hasSpeaker: hasSpeaker,
            characterCount: characterCount,
            depth: entry.layer.depth,
          ),
          child: StoryCharacterMotion(
            animationKey: '${shot.id}-${entry.layer.characterId}',
            movementId: entry.layer.movement,
            reducedMotion: reducedMotion,
            child: StoryCharacterView(
              key: ValueKey(
                '${entry.layer.characterId}-${entry.originalIndex}',
              ),
              layer: entry.layer,
              width:
                  constraints.maxHeight *
                  entry.slot.heightFactor *
                  storyScaleFactor(entry.layer.scale) *
                  0.94,
              height:
                  constraints.maxHeight *
                  entry.slot.heightFactor *
                  storyScaleFactor(entry.layer.scale),
              scale: 1.48,
            ),
          ),
        ),
      ),
    );
  }

  Widget _focusAsset({
    required StoryFocusAssetLayerData layer,
    required Uint8List bytes,
    required BoxConstraints constraints,
    required bool reducedMotion,
  }) {
    final alignment = switch (layer.stagePosition) {
      'left' => const Alignment(-0.68, 0.88),
      'right' => const Alignment(0.68, 0.88),
      _ => const Alignment(0, 0.88),
    };
    final heightFactor = switch (layer.scale) {
      'background' => 0.38,
      'full' => 0.62,
      'close' => 0.78,
      _ => 0.54,
    };
    return AnimatedAlign(
      key: ValueKey('story-focus-asset-${layer.assetId}'),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: StoryCharacterMotion(
          animationKey: '${shot.id}-${layer.assetId}',
          movementId: layer.movement,
          reducedMotion: reducedMotion,
          child: SizedBox(
            height: constraints.maxHeight * heightFactor,
            width: constraints.maxWidth * 0.46,
            child: Image.memory(
              bytes,
              key: ValueKey('prepared-foreground-${layer.assetId}'),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageCharacter {
  const _StageCharacter(this.layer, this.slot, this.originalIndex);

  final StoryCharacterLayerData layer;
  final VisualNovelSlot slot;
  final int originalIndex;
}

class _StageLayerWidget {
  const _StageLayerWidget({
    required this.depth,
    required this.originalIndex,
    required this.child,
  });

  final int depth;
  final int originalIndex;
  final Widget child;
}

class _SubtitleBar extends StatelessWidget {
  const _SubtitleBar({required this.speaker, required this.subtitle});

  final String speaker;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xD91B1720),
      child: Row(
        children: [
          Text(
            speaker,
            style: const TextStyle(
              color: Color(0xFFD8C8FF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                key: const Key('story-subtitle-line'),
                maxLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
