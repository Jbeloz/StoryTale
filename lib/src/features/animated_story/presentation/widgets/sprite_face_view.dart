import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../data/face_profile_catalog.dart';

class SpriteFaceView extends StatelessWidget {
  const SpriteFaceView({
    required this.headAsset,
    required this.composition,
    this.fit = BoxFit.fill,
    super.key,
  });

  final String headAsset;
  final SpriteFaceComposition composition;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _image(headAsset),
        for (final asset in composition.layerAssets) _image(asset),
      ],
    );
  }

  Widget _image(String asset) {
    return Image.asset(asset, fit: fit, filterQuality: FilterQuality.high);
  }
}

class SpriteFaceLayer {
  const SpriteFaceLayer.asset(this.asset) : bytes = null;

  const SpriteFaceLayer.memory(this.bytes) : asset = null;

  final String? asset;
  final Uint8List? bytes;
}

class SpriteFaceOverlayData {
  const SpriteFaceOverlayData({
    required this.profileId,
    required this.setId,
    required this.layers,
  });

  final String profileId;
  final String setId;
  final List<SpriteFaceLayer> layers;
}

class SpriteFaceOverlayView extends StatelessWidget {
  const SpriteFaceOverlayView({required this.data, super.key});

  final SpriteFaceOverlayData data;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in data.layers)
          if (layer.bytes != null)
            Image.memory(
              layer.bytes!,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            )
          else
            Image.asset(
              layer.asset!,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
      ],
    );
  }
}
