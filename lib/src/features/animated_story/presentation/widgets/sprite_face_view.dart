import 'package:flutter/material.dart';

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
