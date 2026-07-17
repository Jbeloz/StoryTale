import 'dart:typed_data';

import 'package:flutter/material.dart';

class StoryTaleImagePlaceholder extends StatelessWidget {
  const StoryTaleImagePlaceholder({
    required this.label,
    this.path,
    this.bytes,
    this.icon = Icons.image_outlined,
    this.height = 160,
    this.width,
    this.borderRadius = 16,
    super.key,
  });

  final String label;
  final String? path;
  final Uint8List? bytes;
  final IconData icon;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 96 || constraints.maxWidth < 96;
          if (compact) {
            return Tooltip(
              message: label,
              child: Icon(
                icon,
                size: constraints.biggest.shortestSide.clamp(24, 40),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(label, textAlign: TextAlign.center),
              ),
            ],
          );
        },
      ),
    );

    if (bytes != null && bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          bytes!,
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    if (path == null || path!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        path!,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
