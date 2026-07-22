import 'package:flutter/material.dart';

import '../../../../shared/models/storytale_models.dart';
import '../../../../shared/widgets/storytale_image_placeholder.dart';
import 'story_character_view.dart';
import 'visual_novel_layouts.dart';

class VisualNovelStage extends StatelessWidget {
  const VisualNovelStage({
    required this.shot,
    required this.speaker,
    required this.subtitle,
    super.key,
  });

  static const fallbackBackground =
      'assets/images/backgrounds/cloudflare_examples/moonlit-rose-garden.jpg';

  final StoryShotPlanData shot;
  final String speaker;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final characters = shot.characterLayers.take(3).toList();
        final layout = VisualNovelLayoutPreset.resolve(
          shot.layoutId,
          characters.length,
        );
        return ClipRRect(
          key: const Key('visual-novel-stage'),
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            key: ValueKey('story-layout-${shot.layoutId}'),
            fit: StackFit.expand,
            children: [
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
              for (var index = 0; index < characters.length; index++)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  alignment: layout.slots[index].alignment,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: StoryCharacterView(
                      key: ValueKey('${characters[index].characterId}-$index'),
                      layer: characters[index],
                      width:
                          constraints.maxHeight *
                          layout.slots[index].heightFactor *
                          0.94,
                      height:
                          constraints.maxHeight *
                          layout.slots[index].heightFactor,
                      scale: 1.48,
                    ),
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
