import 'package:flutter/material.dart';

import '../../../../shared/models/storytale_models.dart';
import '../../../../shared/widgets/storytale_image_placeholder.dart';
import 'story_character_view.dart';

class VisualNovelStage extends StatelessWidget {
  const VisualNovelStage({
    required this.scene,
    required this.subtitle,
    super.key,
  });

  static const fallbackBackground =
      'assets/images/backgrounds/cloudflare_examples/moonlit-rose-garden.jpg';

  final StorySceneData scene;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final characterHeight = constraints.maxHeight * 0.76;
        return ClipRRect(
          key: const Key('visual-novel-stage'),
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              StoryTaleImagePlaceholder(
                key: const Key('visual-novel-background'),
                path: scene.backgroundPath ?? fallbackBackground,
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
              for (final layer in scene.characterLayers)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  alignment: _stageAlignment(layer.stagePosition),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: StoryCharacterView(
                      key: ValueKey(layer.characterId),
                      layer: layer,
                      width: characterHeight * 0.94,
                      height: characterHeight,
                      scale: 1.48,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _SubtitleBar(speaker: scene.speaker, subtitle: subtitle),
              ),
            ],
          ),
        );
      },
    );
  }

  Alignment _stageAlignment(String position) {
    return switch (position) {
      'left' => const Alignment(-0.72, 1),
      'right' => const Alignment(0.72, 1),
      _ => Alignment.bottomCenter,
    };
  }
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
