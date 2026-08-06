import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;

import 'character_sheet_contract.dart';
import 'character_sheet_generation.dart';
import 'character_sheet_package.dart';
import 'face_profile_catalog.dart';
import 'sprite_appearance.dart';
import 'sprite_layer_processor.dart';
import 'sprite_rig.dart';

class CharacterSheetProcessingException implements Exception {
  const CharacterSheetProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CharacterSheetProcessor {
  CharacterSheetProcessor({
    AssetBundle? bundle,
    CharacterSheetContractRepository? contracts,
  }) : _bundle = bundle ?? rootBundle,
       _contracts =
           contracts ??
           CharacterSheetContractRepository(bundle: bundle ?? rootBundle);

  static const _rigAsset = 'assets/images/characters/rigs/humanoid_v1/rig.json';
  static const _faceProfileCatalogAsset =
      'assets/images/characters/face_profiles/catalog.json';
  static const _requiredFaceExpressions = {
    'neutral': 'Neutral',
    'talking': 'Talking',
    'happy': 'Happy',
    'sad': 'Sad',
    'angry': 'Angry',
    'surprised': 'Surprised',
  };

  final AssetBundle _bundle;
  final CharacterSheetContractRepository _contracts;

  Future<CharacterSheetPackage> process({
    required CharacterSheetGenerationRequest request,
    required CharacterSheetGenerationResult generation,
  }) async {
    final contract = await _contracts.load();
    final expectedFingerprint = request.fingerprint(contract);
    if (generation.contractId != contract.contractId ||
        generation.contractVersion != contract.contractVersion) {
      throw const CharacterSheetProcessingException(
        'The generated sheet uses a different character-sheet contract.',
      );
    }
    if (generation.requestFingerprint != expectedFingerprint) {
      throw const CharacterSheetProcessingException(
        'The generated sheet does not belong to this character request.',
      );
    }

    final detectedMimeType = _detectMimeType(generation.bytes);
    final decoded = image.decodeImage(generation.bytes);
    if (decoded == null || detectedMimeType == null) {
      throw const CharacterSheetProcessingException(
        'The generated character sheet is not a readable image.',
      );
    }
    if (detectedMimeType != contract.canvas.mimeType ||
        generation.mimeType != contract.canvas.mimeType ||
        decoded.width != contract.canvas.width ||
        decoded.height != contract.canvas.height ||
        generation.width != contract.canvas.width ||
        generation.height != contract.canvas.height) {
      throw CharacterSheetProcessingException(
        'The generated sheet was ${decoded.width}x${decoded.height} '
        '$detectedMimeType; ${contract.canvas.width}x${contract.canvas.height} '
        '${contract.canvas.mimeType} is required.',
      );
    }

    final allowed = await _loadMask(
      contract.assets.allowedRegions,
      contract.assetSha256['allowedRegions']!,
      contract,
    );
    final protected = await _loadMask(
      contract.assets.protectedRegions,
      contract.assetSha256['protectedRegions']!,
      contract,
    );
    final seams = await _loadMask(
      contract.assets.seamAllowances,
      contract.assetSha256['seamAllowances']!,
      contract,
    );
    final rigData = await _loadRigData(contract);
    final placements = rigData.placements;

    final errors = <String>[];
    var geometryValid = true;
    var slotValid = true;
    var sideValid = true;
    var seamValid = true;

    for (final region in contract.regions) {
      if (!_sideMatches(region)) {
        sideValid = false;
        errors.add('${region.id} has inconsistent left/right ownership.');
      }
      if (!_geometryMatches(region, placements)) {
        geometryValid = false;
        errors.add('${region.id} no longer matches the locked rig geometry.');
      }
    }

    final unexpectedGapPixels = _unexpectedGapPixels(
      decoded,
      allowed,
      protected,
      seams,
    );
    if (unexpectedGapPixels > 0) {
      seamValid = false;
      errors.add(
        'The sheet contains $unexpectedGapPixels generated pixels outside '
        'the approved appearance and seam masks.',
      );
    }

    final selectedBackHair = request.selectedBackHairRegion(contract);
    final cleanSheet = image.Image(
      contract.canvas.width,
      contract.canvas.height,
    )..channels = image.Channels.rgba;
    final layerBytes = <String, Uint8List>{};
    final layerMetadata = <String, CharacterSheetLayerMetadata>{};
    final visiblePixels = <String, int>{};
    final rejectedPixels = <String, int>{};
    final greenPixelsRemoved = <String, int>{};
    final packageId = _packageId(request);
    final outfitId =
        'primary-${generation.requestFingerprint.substring(0, 12)}';

    for (final region in contract.regions) {
      final sourceCrop = image.copyCrop(
        decoded,
        region.crop.x,
        region.crop.y,
        region.crop.width,
        region.crop.height,
      );
      final allowedCrop = image.copyCrop(
        allowed,
        region.crop.x,
        region.crop.y,
        region.crop.width,
        region.crop.height,
      );
      final protectedCrop = image.copyCrop(
        protected,
        region.crop.x,
        region.crop.y,
        region.crop.width,
        region.crop.height,
      );
      final seamCrop = image.copyCrop(
        seams,
        region.crop.x,
        region.crop.y,
        region.crop.width,
        region.crop.height,
      );
      final cleaned = _cleanRegion(
        sourceCrop,
        allowedCrop,
        protectedCrop,
        seamCrop,
      );
      final isBackHair = region.kind == 'backHair';
      final shouldBeActive = !isBackHair || region.id == selectedBackHair;

      if (isBackHair && !shouldBeActive && cleaned.sourceArtworkPixels > 0) {
        slotValid = false;
        errors.add(
          '${region.id} must stay green because $selectedBackHair was selected.',
        );
      }
      if (isBackHair &&
          shouldBeActive &&
          selectedBackHair != 'none' &&
          cleaned.visiblePixels == 0) {
        slotValid = false;
        errors.add('The selected $selectedBackHair layer is empty.');
      }
      if (region.requirement == 'required' && cleaned.visiblePixels == 0) {
        slotValid = false;
        errors.add('The required ${region.id} appearance layer is empty.');
      }
      if (cleaned.rejectedPixels > 0) {
        seamValid = false;
      }

      visiblePixels[region.id] = cleaned.visiblePixels;
      rejectedPixels[region.id] = cleaned.rejectedPixels;
      greenPixelsRemoved[region.id] = cleaned.greenPixelsRemoved;
      final assetId = _layerAssetId(packageId, outfitId, region);
      Uint8List? bytes;
      if (cleaned.visiblePixels > 0 && shouldBeActive) {
        bytes = Uint8List.fromList(image.encodePng(cleaned.bitmap));
        layerBytes[region.id] = bytes;
        image.drawImage(
          cleanSheet,
          cleaned.bitmap,
          dstX: region.crop.x,
          dstY: region.crop.y,
        );
      }
      layerMetadata[region.id] = CharacterSheetLayerMetadata(
        regionId: region.id,
        kind: region.kind,
        parentPart: region.parentPart,
        side: region.side,
        width: region.outputCanvas.width,
        height: region.outputCanvas.height,
        anchorX: region.attachmentAnchor.x,
        anchorY: region.attachmentAnchor.y,
        layerOrder: region.defaultLayerOrder,
        requirement: region.requirement,
        assetId: assetId,
        visiblePixelCount: cleaned.visiblePixels,
        sha256: bytes == null ? null : sha256.convert(bytes).toString(),
        empty: bytes == null,
      );
    }

    var cutoutValid =
        errors.isEmpty && geometryValid && slotValid && sideValid && seamValid;
    var proofArtwork = await _buildProofArtwork(
      contract: contract,
      rig: rigData.rig,
      request: request,
      appearanceLayers: cutoutValid ? layerBytes : const {},
      selectedBackHair: selectedBackHair,
    );
    if (!proofArtwork.headGeometryValid) {
      geometryValid = false;
      errors.add(
        'Generated face details crossed the locked head alpha boundary.',
      );
      cutoutValid = false;
      proofArtwork = await _buildProofArtwork(
        contract: contract,
        rig: rigData.rig,
        request: request,
        appearanceLayers: const {},
        selectedBackHair: selectedBackHair,
      );
    }
    final artworkByPart = proofArtwork.artworkByPart;
    final faceArtwork = await _buildFaceArtwork(
      request: request,
      rig: rigData.rig,
      artworkByPart: artworkByPart,
    );
    var identityValid = cutoutValid && faceArtwork.valid;
    var faceProofValid = identityValid;
    if (!faceArtwork.valid) {
      errors.add(
        'The selected actor profile does not provide all six locked face sets.',
      );
    }

    final poses = SpriteLayerProcessor.canonicalPosesFor(contract.lockedRig.id);
    final neutralPose = poses['neutral']!;
    final facePreviewAssetIds = <String, String>{};
    final facePreviewBytesByExpression = <String, Uint8List>{};
    final faceProofMetadata = <String, CharacterSheetFaceProofMetadata>{};
    final faceProofHashes = <String>{};
    for (final entry in _requiredFaceExpressions.entries) {
      final expressionId = entry.key;
      final faceHead = faceArtwork.headsByExpression[expressionId];
      final expressionArtwork = Map<String, image.Image>.of(artworkByPart);
      if (faceHead != null) expressionArtwork['head'] = faceHead;
      final proof = _composePoseProof(
        rig: rigData.rig,
        pose: neutralPose,
        artworkByPart: expressionArtwork,
      );
      final bytes = Uint8List.fromList(image.encodePng(proof));
      final visible = _visiblePixelCount(proof);
      final proofHash = sha256.convert(bytes).toString();
      final assetId = '$packageId/previews/faces/$expressionId.png';
      final valid =
          faceHead != null &&
          proof.width == rigData.rig.canvasSize.width.round() &&
          proof.height == rigData.rig.canvasSize.height.round() &&
          visible > 0 &&
          !_containsGreenPixels(proof);
      if (!valid) {
        faceProofValid = false;
        errors.add('The ${entry.value} face proof failed local validation.');
      }
      facePreviewAssetIds[expressionId] = assetId;
      facePreviewBytesByExpression[expressionId] = bytes;
      faceProofHashes.add(proofHash);
      faceProofMetadata[expressionId] = CharacterSheetFaceProofMetadata(
        expressionId: expressionId,
        label: entry.value,
        assetId: assetId,
        width: proof.width,
        height: proof.height,
        visiblePixelCount: visible,
        sha256: proofHash,
        valid: valid,
      );
    }
    if (faceProofHashes.length != _requiredFaceExpressions.length) {
      identityValid = false;
      faceProofValid = false;
      errors.add('The six face proofs are not visually distinct.');
    }

    final previewAssetIds = <String, String>{};
    final previewBytesByPose = <String, Uint8List>{};
    final proofMetadata = <String, CharacterSheetPoseProofMetadata>{};
    final proofHashes = <String>{};
    var poseProofValid = cutoutValid;
    for (final poseId in const ['neutral', 'talking', 'pointing', 'walking']) {
      final pose = poses[poseId]!;
      final poseArtwork = Map<String, image.Image>.of(artworkByPart);
      poseArtwork['head'] =
          faceArtwork.headsByExpression[pose.faceExpressionId] ??
          faceArtwork.headsByExpression['neutral'] ??
          artworkByPart['head']!;
      final proof = _composePoseProof(
        rig: rigData.rig,
        pose: pose,
        artworkByPart: poseArtwork,
      );
      final bytes = Uint8List.fromList(image.encodePng(proof));
      final visible = _visiblePixelCount(proof);
      final proofHash = sha256.convert(bytes).toString();
      final assetId = '$packageId/previews/$poseId.png';
      final valid =
          proof.width == rigData.rig.canvasSize.width.round() &&
          proof.height == rigData.rig.canvasSize.height.round() &&
          visible > 0 &&
          !_containsGreenPixels(proof);
      if (!valid) {
        poseProofValid = false;
        errors.add('The ${pose.displayName} proof failed local validation.');
      }
      previewAssetIds[poseId] = assetId;
      previewBytesByPose[poseId] = bytes;
      proofHashes.add(proofHash);
      proofMetadata[poseId] = CharacterSheetPoseProofMetadata(
        poseId: poseId,
        label: pose.displayName,
        assetId: assetId,
        width: proof.width,
        height: proof.height,
        visiblePixelCount: visible,
        sha256: proofHash,
        valid: valid,
      );
    }
    if (cutoutValid && proofHashes.length != 4) {
      poseProofValid = false;
      errors.add('The four built-in pose proofs are not distinct.');
    }
    final validation = CharacterSheetPackageValidation(
      errors: List.unmodifiable(errors),
      visiblePixelsByRegion: Map.unmodifiable(visiblePixels),
      rejectedPixelsByRegion: Map.unmodifiable(rejectedPixels),
      greenPixelsRemovedByRegion: Map.unmodifiable(greenPixelsRemoved),
      canvasValid: true,
      fingerprintValid: true,
      geometryValid: geometryValid,
      slotValid: slotValid,
      sideValid: sideValid,
      seamValid: seamValid,
      lockedAssetsValid: true,
      identityValid: identityValid,
      faceProofValid: faceProofValid,
      poseProofValid: poseProofValid,
      proofsByFace: Map.unmodifiable(faceProofMetadata),
      proofsByPose: Map.unmodifiable(proofMetadata),
    );
    final cleanBytes = Uint8List.fromList(image.encodePng(cleanSheet));
    final package = CharacterSheetPackage(
      packageId: packageId,
      bookId: request.brief.bookId,
      characterId: request.brief.characterId,
      characterName: request.brief.canonicalName,
      outfitId: outfitId,
      skinTone: request.skinTone,
      frontHairId: request.frontHairId,
      backHairId: request.backHairId,
      selectedBackHairRegion: selectedBackHair,
      contract: contract,
      generation: generation,
      sourceAssetId: '$packageId/generation/character_sheet_source.png',
      cleanAssetId: '$packageId/generation/character_sheet_clean.png',
      facePreviewAssetIds: Map.unmodifiable(facePreviewAssetIds),
      previewAssetIds: Map.unmodifiable(previewAssetIds),
      layerMetadata: Map.unmodifiable(layerMetadata),
      layerBytes: Map.unmodifiable(layerBytes),
      sourceBytes: generation.bytes,
      cleanBytes: cleanBytes,
      facePreviewBytesByExpression: Map.unmodifiable(
        facePreviewBytesByExpression,
      ),
      previewBytesByPose: Map.unmodifiable(previewBytesByPose),
      validation: validation,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    CharacterSheetPackageStore.save(package);
    return package;
  }

  Future<image.Image> _loadMask(
    String path,
    String expectedHash,
    CharacterSheetContract contract,
  ) async {
    final bytes = await _loadVerified(path, expectedHash);
    final decoded = image.decodeImage(bytes);
    if (decoded == null ||
        decoded.width != contract.canvas.width ||
        decoded.height != contract.canvas.height) {
      throw CharacterSheetProcessingException(
        'The character-sheet mask is invalid: $path.',
      );
    }
    return decoded;
  }

  Future<Uint8List> _loadVerified(String path, String expectedHash) async {
    final data = await _bundle.load(path);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (sha256.convert(bytes).toString() != expectedHash) {
      throw CharacterSheetProcessingException(
        'The character-sheet contract asset changed: $path.',
      );
    }
    return bytes;
  }

  Future<_RigData> _loadRigData(CharacterSheetContract contract) async {
    final bytes = await _loadVerified(
      _rigAsset,
      contract.lockedRig.manifestSha256,
    );
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (json['id'] != contract.lockedRig.id) {
      throw const CharacterSheetProcessingException(
        'The character sheet does not match the active humanoid rig.',
      );
    }
    final rig = SpriteRigDefinition.fromJson(json);
    final placements = <String, _RigPlacement>{};
    for (final part in rig.parts) {
      placements[part.id] = _RigPlacement(
        x: part.position.dx,
        y: part.position.dy,
        width: part.size.width,
        height: part.size.height,
        z: part.z,
        canvasWidth: rig.canvasSize.width.round(),
        canvasHeight: rig.canvasSize.height.round(),
      );
    }
    return _RigData(rig: rig, placements: Map.unmodifiable(placements));
  }

  int _unexpectedGapPixels(
    image.Image source,
    image.Image allowed,
    image.Image protected,
    image.Image seams,
  ) {
    var count = 0;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        if (_isBackground(pixel)) continue;
        final allowedPixel = _isWhite(allowed.getPixel(x, y));
        final protectedPixel = _isWhite(protected.getPixel(x, y));
        final seamPixel = _isWhite(seams.getPixel(x, y));
        if (!((allowedPixel && !protectedPixel) || seamPixel)) count++;
      }
    }
    return count;
  }

  _CleanedRegion _cleanRegion(
    image.Image source,
    image.Image allowed,
    image.Image protected,
    image.Image seams,
  ) {
    final output = image.Image.from(source)..channels = image.Channels.rgba;
    final background = _connectedBackground(output);
    var sourceArtworkPixels = 0;
    var visiblePixels = 0;
    var rejectedPixels = 0;
    var greenPixelsRemoved = 0;
    for (var y = 0; y < output.height; y++) {
      for (var x = 0; x < output.width; x++) {
        final index = y * output.width + x;
        final pixel = output.getPixel(x, y);
        final exactGreen = _isExactGreen(pixel);
        if (!_isBackground(pixel)) sourceArtworkPixels++;
        if (background[index] != 0 || exactGreen) {
          output.setPixelRgba(x, y, 0, 0, 0, 0);
          greenPixelsRemoved++;
          continue;
        }
        final allowedPixel = _isWhite(allowed.getPixel(x, y));
        final protectedPixel = _isWhite(protected.getPixel(x, y));
        final seamPixel = _isWhite(seams.getPixel(x, y));
        if (!((allowedPixel && !protectedPixel) || seamPixel)) {
          if (image.getAlpha(pixel) > 0 && !_isBackground(pixel)) {
            rejectedPixels++;
          }
          output.setPixelRgba(x, y, 0, 0, 0, 0);
          continue;
        }
        if (image.getAlpha(pixel) == 0) continue;
        final red = image.getRed(pixel);
        final green = image.getGreen(pixel);
        final blue = image.getBlue(pixel);
        final despilledGreen = math.min(green, math.max(red, blue));
        output.setPixelRgba(
          x,
          y,
          red,
          despilledGreen,
          blue,
          image.getAlpha(pixel),
        );
        visiblePixels++;
      }
    }
    return _CleanedRegion(
      bitmap: output,
      sourceArtworkPixels: sourceArtworkPixels,
      visiblePixels: visiblePixels,
      rejectedPixels: rejectedPixels,
      greenPixelsRemoved: greenPixelsRemoved,
    );
  }

  Uint8List _connectedBackground(image.Image source) {
    final visited = Uint8List(source.width * source.height);
    final queue = Uint32List(source.width * source.height);
    var head = 0;
    var tail = 0;

    void add(int x, int y) {
      if (x < 0 || y < 0 || x >= source.width || y >= source.height) return;
      final index = y * source.width + x;
      if (visited[index] != 0) return;
      visited[index] = 1;
      if (_isBackground(source.getPixel(x, y))) queue[tail++] = index;
    }

    for (var x = 0; x < source.width; x++) {
      add(x, 0);
      add(x, source.height - 1);
    }
    for (var y = 0; y < source.height; y++) {
      add(0, y);
      add(source.width - 1, y);
    }
    while (head < tail) {
      final index = queue[head++];
      final x = index % source.width;
      final y = index ~/ source.width;
      add(x - 1, y);
      add(x + 1, y);
      add(x, y - 1);
      add(x, y + 1);
    }
    final connected = Uint8List(source.width * source.height);
    for (var index = 0; index < tail; index++) {
      connected[queue[index]] = 1;
    }
    return connected;
  }

  Future<_ProofArtwork> _buildProofArtwork({
    required CharacterSheetContract contract,
    required SpriteRigDefinition rig,
    required CharacterSheetGenerationRequest request,
    required Map<String, Uint8List> appearanceLayers,
    required String selectedBackHair,
  }) async {
    final artwork = <String, image.Image>{};
    var headGeometryValid = true;

    for (final region in contract.regions) {
      if (region.kind == 'backHair') {
        if (region.id != selectedBackHair ||
            !appearanceLayers.containsKey(region.id)) {
          continue;
        }
        artwork['back_hair'] = _scaledHairArtwork(
          region,
          rig.partsById['back_hair']!,
          appearanceLayers[region.id]!,
        );
        continue;
      }
      if (region.kind == 'frontHair') {
        final bytes = appearanceLayers[region.id];
        if (bytes == null) continue;
        artwork['front_hair'] = _scaledHairArtwork(
          region,
          rig.partsById['front_hair']!,
          bytes,
        );
        continue;
      }

      final rigPart = rig.partsById[region.parentPart];
      if (rigPart == null) continue;
      final expectedHash = contract.lockedRig.assetSha256[rigPart.asset];
      if (expectedHash == null) {
        throw CharacterSheetProcessingException(
          'The locked ${rigPart.id} runtime asset has no approved hash.',
        );
      }
      final decoded = image.decodeImage(
        await _loadVerified(rigPart.asset, expectedHash),
      );
      if (decoded == null) {
        throw CharacterSheetProcessingException(
          'The locked ${region.id} base asset has invalid geometry.',
        );
      }
      // A locked asset is not required to already be cell-sized. The nine body
      // parts are trimmed to their rig box, but the head is a large square
      // canvas the rig fits into its box, exactly as the two hair parts are; see
      // _scaledHairArtwork. Fitting it here reproduces what the runtime draws,
      // so the head this pipeline validates and tints is the head Story Mode
      // composes.
      final base = _fittedToCanvas(decoded, region.outputCanvas);
      final composed = _tintSkin(base, request.skinTone);
      final overlayBytes = appearanceLayers[region.id];
      if (overlayBytes != null) {
        final overlay = image.decodeImage(overlayBytes);
        if (overlay == null ||
            overlay.width != composed.width ||
            overlay.height != composed.height) {
          throw CharacterSheetProcessingException(
            'The extracted ${region.id} layer changed its native size.',
          );
        }
        if (region.id == 'head' && !_overlayFitsOpaqueBase(base, overlay)) {
          headGeometryValid = false;
        } else {
          image.drawImage(composed, overlay);
        }
      }
      artwork[rigPart.id] = composed;
    }
    return _ProofArtwork(
      artworkByPart: Map.unmodifiable(artwork),
      headGeometryValid: headGeometryValid,
    );
  }

  Future<_FaceArtwork> _buildFaceArtwork({
    required CharacterSheetGenerationRequest request,
    required SpriteRigDefinition rig,
    required Map<String, image.Image> artworkByPart,
  }) async {
    final actor = SpriteAppearanceCatalog.actor(request.brief.actorProfileId);
    final catalog = await SpriteFaceProfileCatalog.load(
      _faceProfileCatalogAsset,
      bundle: _bundle,
    );
    final bundle = await catalog.loadProfile(
      actor.faceProfileId,
      bundle: _bundle,
    );
    final baseHead = artworkByPart['head'];
    final rigHead = rig.partsById['head'];
    var valid =
        baseHead != null &&
        rigHead != null &&
        bundle.profile.rigId == rig.id &&
        bundle.profile.headPartId == 'head' &&
        bundle.profile.isReady &&
        bundle.sets.setsById.keys.toSet().containsAll(
          _requiredFaceExpressions.keys,
        );
    if (baseHead == null || rigHead == null) {
      return const _FaceArtwork(headsByExpression: {}, valid: false);
    }

    final heads = <String, image.Image>{};
    for (final expressionId in _requiredFaceExpressions.keys) {
      final set = bundle.sets.setsById[expressionId];
      if (set == null) {
        valid = false;
        continue;
      }
      final composition = bundle.compositionFromSet(set);
      final head = image.Image.from(baseHead)..channels = image.Channels.rgba;
      for (final asset in composition.layerAssets) {
        final data = await _bundle.load(asset);
        final layer = image.decodeImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        if (layer == null ||
            layer.width != bundle.profile.canvasWidth ||
            layer.height != bundle.profile.canvasHeight) {
          valid = false;
          continue;
        }
        final fitted = layer.width == head.width && layer.height == head.height
            ? layer
            : image.copyResize(
                layer,
                width: head.width,
                height: head.height,
                interpolation: image.Interpolation.linear,
              );
        image.drawImage(head, fitted);
      }
      _clipToBaseAlpha(head, baseHead);
      heads[expressionId] = head;
    }
    return _FaceArtwork(
      headsByExpression: Map.unmodifiable(heads),
      valid: valid && heads.length == _requiredFaceExpressions.length,
    );
  }

  image.Image _composePoseProof({
    required SpriteRigDefinition rig,
    required SpriteRigPose pose,
    required Map<String, image.Image> artworkByPart,
  }) {
    final proof = image.Image(
      rig.canvasSize.width.round(),
      rig.canvasSize.height.round(),
    )..channels = image.Channels.rgba;
    final transforms = SpriteRigCalculator.calculate(rig, pose);
    final parts = [...rig.parts]
      ..sort((left, right) {
        final leftLayer = SpriteLayerPolicy.effectiveLayer(
          left,
          pose.transformFor(left.id),
        );
        final rightLayer = SpriteLayerPolicy.effectiveLayer(
          right,
          pose.transformFor(right.id),
        );
        final order = leftLayer.compareTo(rightLayer);
        return order != 0 ? order : left.z.compareTo(right.z);
      });
    for (final part in parts) {
      final artwork = artworkByPart[part.id];
      if (artwork == null) continue;
      _drawTransformedPart(
        proof,
        artwork,
        part,
        transforms[part.id]!,
        pose.transformFor(part.id).scale,
      );
    }
    return proof;
  }

  image.Image _fittedToCanvas(
    image.Image source,
    CharacterSheetDimensions canvas,
  ) {
    if (source.width == canvas.width && source.height == canvas.height) {
      return source;
    }
    return image.copyResize(
      source,
      width: canvas.width,
      height: canvas.height,
      interpolation: image.Interpolation.linear,
    );
  }

  image.Image _scaledHairArtwork(
    CharacterSheetRegion region,
    SpriteRigPart rigPart,
    Uint8List bytes,
  ) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null ||
        decoded.width != region.outputCanvas.width ||
        decoded.height != region.outputCanvas.height) {
      throw CharacterSheetProcessingException(
        'The extracted ${region.id} hair layer changed its native size.',
      );
    }
    final scaled = image.copyResize(
      decoded,
      width: rigPart.size.width.round(),
      height: rigPart.size.height.round(),
      interpolation: image.Interpolation.linear,
    );
    return scaled;
  }

  void _drawTransformedPart(
    image.Image proof,
    image.Image source,
    SpriteRigPart part,
    SpritePartWorldTransform transform,
    double scale,
  ) {
    var artwork = source;
    var pivotX = part.imagePivot.dx * (source.width / part.size.width);
    var pivotY = part.imagePivot.dy * (source.height / part.size.height);
    if ((scale - 1).abs() > 0.0001) {
      artwork = image.copyResize(
        source,
        width: math.max(1, (source.width * scale).round()),
        height: math.max(1, (source.height * scale).round()),
        interpolation: image.Interpolation.linear,
      );
      pivotX *= scale;
      pivotY *= scale;
    }

    final radius = math
        .max(
          math.max(
            math.sqrt(pivotX * pivotX + pivotY * pivotY),
            math.sqrt(
              (artwork.width - pivotX) * (artwork.width - pivotX) +
                  pivotY * pivotY,
            ),
          ),
          math.max(
            math.sqrt(
              pivotX * pivotX +
                  (artwork.height - pivotY) * (artwork.height - pivotY),
            ),
            math.sqrt(
              (artwork.width - pivotX) * (artwork.width - pivotX) +
                  (artwork.height - pivotY) * (artwork.height - pivotY),
            ),
          ),
        )
        .ceil();
    final side = math.max(2, radius * 2 + 4);
    final centered = image.Image(side, side)..channels = image.Channels.rgba;
    final center = side / 2;
    image.drawImage(
      centered,
      artwork,
      dstX: (center - pivotX).round(),
      dstY: (center - pivotY).round(),
    );
    final angle = transform.rotation * 180 / math.pi;
    final rotated = angle.abs() < 0.0001
        ? centered
        : image.copyRotate(
            centered,
            angle,
            interpolation: image.Interpolation.linear,
          );
    image.drawImage(
      proof,
      rotated,
      dstX: (transform.pivot.dx - rotated.width / 2).round(),
      dstY: (transform.pivot.dy - rotated.height / 2).round(),
    );
  }

  image.Image _tintSkin(image.Image source, String skinTone) {
    final value = int.parse(skinTone.replaceFirst('#', ''), radix: 16);
    final targetRed = (value >> 16) & 0xff;
    final targetGreen = (value >> 8) & 0xff;
    final targetBlue = value & 0xff;
    final outlineRed = (targetRed * 0.38).round().clamp(36, 112);
    final outlineGreen = (targetGreen * 0.38).round().clamp(30, 104);
    final outlineBlue = (targetBlue * 0.38).round().clamp(30, 104);
    final result = image.Image.from(source)..channels = image.Channels.rgba;
    for (var y = 0; y < result.height; y++) {
      for (var x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final alpha = image.getAlpha(pixel);
        if (alpha == 0) continue;
        final luminance =
            (image.getRed(pixel) * 0.299 +
                image.getGreen(pixel) * 0.587 +
                image.getBlue(pixel) * 0.114) /
            255;
        int channel(int edge, int target) =>
            (edge + (target - edge) * luminance).round().clamp(0, 255);
        result.setPixelRgba(
          x,
          y,
          channel(outlineRed, targetRed),
          channel(outlineGreen, targetGreen),
          channel(outlineBlue, targetBlue),
          alpha,
        );
      }
    }
    return result;
  }

  bool _overlayFitsOpaqueBase(image.Image base, image.Image overlay) {
    if (base.width != overlay.width || base.height != overlay.height) {
      return false;
    }
    for (var y = 0; y < overlay.height; y++) {
      for (var x = 0; x < overlay.width; x++) {
        if (image.getAlpha(overlay.getPixel(x, y)) > 0 &&
            image.getAlpha(base.getPixel(x, y)) == 0) {
          return false;
        }
      }
    }
    return true;
  }

  void _clipToBaseAlpha(image.Image target, image.Image base) {
    for (var y = 0; y < target.height; y++) {
      for (var x = 0; x < target.width; x++) {
        if (image.getAlpha(base.getPixel(x, y)) == 0) {
          target.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
  }

  bool _geometryMatches(
    CharacterSheetRegion region,
    Map<String, _RigPlacement> placements,
  ) {
    if (region.kind == 'frontHair') return placements.containsKey('front_hair');
    if (region.kind == 'backHair') return placements.containsKey('back_hair');
    final placement = placements[region.parentPart];
    return placement != null &&
        placement.width.round() == region.outputCanvas.width &&
        placement.height.round() == region.outputCanvas.height;
  }

  bool _sideMatches(CharacterSheetRegion region) {
    if (region.id.endsWith('_left')) return region.side == 'left';
    if (region.id.endsWith('_right')) return region.side == 'right';
    return region.side == 'center';
  }

  bool _isWhite(int pixel) =>
      image.getAlpha(pixel) > 0 &&
      image.getRed(pixel) >= 250 &&
      image.getGreen(pixel) >= 250 &&
      image.getBlue(pixel) >= 250;

  bool _isBackground(int pixel) {
    if (image.getAlpha(pixel) == 0) return true;
    final red = image.getRed(pixel);
    final green = image.getGreen(pixel);
    final blue = image.getBlue(pixel);
    return green >= 160 && green >= red + 40 && green >= blue + 40;
  }

  bool _isExactGreen(int pixel) =>
      image.getAlpha(pixel) > 0 &&
      image.getRed(pixel) <= 12 &&
      image.getGreen(pixel) >= 243 &&
      image.getBlue(pixel) <= 12;

  int _visiblePixelCount(image.Image source) {
    var count = 0;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (image.getAlpha(source.getPixel(x, y)) > 0) count++;
      }
    }
    return count;
  }

  bool _containsGreenPixels(image.Image source) {
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        if (image.getAlpha(pixel) > 0 && _isExactGreen(pixel)) return true;
      }
    }
    return false;
  }

  String? _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    return null;
  }

  String _packageId(CharacterSheetGenerationRequest request) =>
      'books/${_segment(request.brief.bookId)}/story-bible/characters/'
      '${_segment(request.brief.characterId)}/appearance';

  String _layerAssetId(
    String packageId,
    String outfitId,
    CharacterSheetRegion region,
  ) {
    return switch (region.kind) {
      'faceDetails' => '$packageId/face/${region.id}.png',
      'frontHair' => '$packageId/hair/front/${region.id}.png',
      'backHair' => '$packageId/hair/back/${region.id}.png',
      _ => '$packageId/outfits/$outfitId/fitted/${region.id}.png',
    };
  }

  String _segment(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

class _RigPlacement {
  const _RigPlacement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.z,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final int z;
  final int canvasWidth;
  final int canvasHeight;
}

class _RigData {
  const _RigData({required this.rig, required this.placements});

  final SpriteRigDefinition rig;
  final Map<String, _RigPlacement> placements;
}

class _ProofArtwork {
  const _ProofArtwork({
    required this.artworkByPart,
    required this.headGeometryValid,
  });

  final Map<String, image.Image> artworkByPart;
  final bool headGeometryValid;
}

class _FaceArtwork {
  const _FaceArtwork({required this.headsByExpression, required this.valid});

  final Map<String, image.Image> headsByExpression;
  final bool valid;
}

class _CleanedRegion {
  const _CleanedRegion({
    required this.bitmap,
    required this.sourceArtworkPixels,
    required this.visiblePixels,
    required this.rejectedPixels,
    required this.greenPixelsRemoved,
  });

  final image.Image bitmap;
  final int sourceArtworkPixels;
  final int visiblePixels;
  final int rejectedPixels;
  final int greenPixelsRemoved;
}
