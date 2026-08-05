import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storytale/src/features/animated_story/data/character_sheet_contract.dart';

/// Offline regression guard for the versioned character-sheet contracts.
///
/// These tests read the checked-in manifests, guides, and masks directly from
/// disk instead of the asset bundle, so V2 and V3 stay verifiable while they
/// remain unregistered review candidates. Nothing here loads a Flutter asset,
/// touches the runtime pipeline, or contacts a provider.
void main() {
  group('character sheet contract assets', () {
    for (final sheet in _sheets) {
      group(sheet.id, () {
        final manifest = _readManifest(sheet);

        test('declares its own contract ID and version', () {
          expect(manifest['contractId'], sheet.id);
          expect(manifest['contractVersion'], sheet.version);
        });

        test('canvas matches the guide and every mask on disk', () {
          final canvas = manifest['canvas'] as Map<String, dynamic>;
          final width = canvas['width'] as int;
          final height = canvas['height'] as int;
          expect(width, sheet.width);
          expect(height, sheet.height);
          expect(canvas['mimeType'], 'image/png');
          expect(
            (canvas['backgroundColor'] as String).toUpperCase(),
            '#00FF00',
          );

          final assets = manifest['assets'] as Map<String, dynamic>;
          for (final key in const [
            'guide',
            'allowedRegions',
            'protectedRegions',
            'seamAllowances',
          ]) {
            final size = _readPngSize(_repoFile(assets[key] as String));
            expect(size, (
              width: width,
              height: height,
            ), reason: '$key must use the declared sheet canvas');
          }
        });

        test('records a matching SHA-256 for every contract asset', () {
          final assets = manifest['assets'] as Map<String, dynamic>;
          final hashes = manifest['assetSha256'] as Map<String, dynamic>;
          expect(
            hashes.keys.toSet(),
            CharacterSheetContract.requiredHashIds,
            reason: 'the six contract assets must each carry one hash',
          );
          for (final entry in hashes.entries) {
            final file = _repoFile(assets[entry.key] as String);
            expect(file.existsSync(), isTrue, reason: '${file.path} missing');
            expect(
              _sha256(file),
              entry.value,
              reason: '${entry.key} no longer matches its approved hash',
            );
          }
        });

        test('locks the humanoid_v1 rig manifest and ten runtime parts', () {
          final lockedRig = manifest['lockedRig'] as Map<String, dynamic>;
          expect(lockedRig['id'], 'humanoid_v1');

          final rigManifest = _repoFile(
            'assets/images/characters/rigs/humanoid_v1/rig.json',
          );
          expect(_sha256(rigManifest), lockedRig['manifestSha256']);

          final lockedAssets =
              (lockedRig['assetSha256'] as Map<String, dynamic>)
                  .cast<String, String>();
          expect(
            lockedAssets.keys.toSet(),
            CharacterSheetContract.requiredLockedAssetPaths,
            reason: 'the locked head plus nine body parts must all be hashed',
          );
          for (final entry in lockedAssets.entries) {
            expect(
              _sha256(_repoFile(entry.key)),
              entry.value,
              reason: '${entry.key} changed; the locked geometry is immutable',
            );
          }
        });

        test('keeps the fixed-crop and no-resize rules', () {
          final rules = manifest['rules'] as Map<String, dynamic>;
          expect(rules['cropCoordinatesAreInclusiveExclusive'], isTrue);
          expect(rules['resizeRegions'], isFalse);
          expect(rules['cropToVisiblePixels'], isFalse);
          expect(rules['inactiveOptionalRegionsRemainGreen'], isTrue);
          expect(rules['visibleCellBorders'], isFalse);
        });

        test('contains its fixed regions exactly once', () {
          final regions = _regions(manifest);
          expect(regions.length, sheet.regionIds.length);
          expect(
            regions.map((region) => region['id']).toSet(),
            sheet.regionIds,
          );
        });

        test('cuts every region at its exact native output canvas', () {
          for (final region in _regions(manifest)) {
            final crop = region['crop'] as Map<String, dynamic>;
            final output = region['outputCanvas'] as Map<String, dynamic>;
            expect(
              (crop['width'], crop['height']),
              (output['width'], output['height']),
              reason: '${region['id']} would need a post-crop resize',
            );
          }
        });

        test('keeps every region inside the canvas and free of overlap', () {
          final canvas = manifest['canvas'] as Map<String, dynamic>;
          final rects = <String, _Rect>{
            for (final region in _regions(manifest))
              region['id'] as String: _Rect.fromJson(
                region['crop'] as Map<String, dynamic>,
              ),
          };

          for (final entry in rects.entries) {
            expect(
              entry.value.isInside(
                canvas['width'] as int,
                canvas['height'] as int,
              ),
              isTrue,
              reason: '${entry.key} falls outside the sheet canvas',
            );
          }

          final ids = rects.keys.toList(growable: false);
          for (var i = 0; i < ids.length; i++) {
            for (var j = i + 1; j < ids.length; j++) {
              expect(
                rects[ids[i]]!.overlaps(rects[ids[j]]!),
                isFalse,
                reason: '${ids[i]} and ${ids[j]} share sheet pixels',
              );
            }
          }
        });

        test('points every region at an existing rig source asset', () {
          for (final region in _regions(manifest)) {
            final source = _repoFile(region['sourceAsset'] as String);
            expect(
              source.existsSync(),
              isTrue,
              reason: '${region['id']} references ${source.path}',
            );
            expect(region['maskRegionId'], region['id']);
            expect(
              const {'left', 'right', 'center'}.contains(region['side']),
              isTrue,
            );
          }
        });
      });
    }
  });

  group('character_sheet_v3 landscape layout', () {
    final manifest = _readManifest(_v3);

    test('declares a 4:1 2K shape that the provider does not list', () {
      // Recorded as-is, not endorsed. Checked on 5 August 2026: the documented
      // aspect ratios are 1:1, 3:2, 2:3, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9 and
      // 21:9. 4:1 is absent, so V3 may not be requestable. V4 is the 1:1
      // replacement; confirm the provider before spending on V3.
      final canvas = manifest['canvas'] as Map<String, dynamic>;
      expect(canvas['width'], 4096);
      expect(canvas['height'], 1024);
      expect(canvas['providerAspectRatio'], '4:1');
      expect(canvas['providerImageSize'], '2K');
      expect(
        const [
          '1:1',
          '3:2',
          '2:3',
          '3:4',
          '4:3',
          '4:5',
          '5:4',
          '9:16',
          '16:9',
          '21:9',
        ],
        isNot(contains(canvas['providerAspectRatio'])),
        reason: 'if this ever passes, 4:1 became supported and V3 is viable',
      );
    });

    test('keeps three native-size back-hair cells plus one front cell', () {
      final byId = {
        for (final region in _regions(manifest)) region['id'] as String: region,
      };
      for (final id in const [
        'back_hair_short',
        'back_hair_medium',
        'back_hair_long',
      ]) {
        final output = byId[id]!['outputCanvas'] as Map<String, dynamic>;
        expect((output['width'], output['height']), (429, 800), reason: id);
      }
      final front = byId['front_hair']!['outputCanvas'] as Map<String, dynamic>;
      expect((front['width'], front['height']), (429, 438));
    });

    test('offers every rear-hair option and a valid default selection', () {
      final selection = manifest['selectionContract'] as Map<String, dynamic>;
      final byOption = (selection['backHairRegionById'] as Map<String, dynamic>)
          .cast<String, dynamic>();
      expect(byOption.keys.toSet(), {'short', 'medium', 'long', 'none'});
      expect(byOption['none'], isNull);

      final regionIds = _regions(
        manifest,
      ).map((region) => region['id'] as String).toSet();
      final generated = (selection['generatedBackHairOptions'] as List<dynamic>)
          .cast<String>();
      for (final option in generated) {
        expect(regionIds, contains(byOption[option]));
      }
      expect(generated, contains(selection['defaultBackHairId']));
      expect(selection['noneMeansHideBackHairAtRuntime'], isTrue);
    });

    test('records heroine-compatible sources without changing geometry', () {
      final actor = manifest['actorContract'] as Map<String, dynamic>;
      expect(actor['currentGuideActorId'], 'default');
      expect(actor['sharedRigGeometry'], isTrue);
      expect(
        (actor['compatibleActorIds'] as List<dynamic>).cast<String>(),
        containsAll(const ['default', 'heroine']),
      );
      for (final map in const [
        'frontHairSourceByActor',
        'longBackHairSourceByActor',
      ]) {
        final sources = (actor[map] as Map<String, dynamic>)
            .cast<String, String>();
        expect(sources.keys, containsAll(const ['default', 'heroine']));
        for (final source in sources.values) {
          expect(
            _repoFile(source).existsSync(),
            isTrue,
            reason: '$map references a missing $source',
          );
        }
      }
    });

    test('reuses the V1 region identifiers so migration cannot renumber', () {
      expect(
        _regions(_readManifest(_v3)).map((region) => region['id']).toSet(),
        _regions(_readManifest(_v1)).map((region) => region['id']).toSet(),
      );
    });
  });

  group('character_sheet_v4 square 1K layout', () {
    final manifest = _readManifest(_v4);

    test('uses a 1:1 1K provider shape, which V3\'s 4:1 is not', () {
      // 1:1 is documented for every image model; 4:1 is not a listed aspect
      // ratio at all. V4 exists so the sheet shape cannot be the reason a paid
      // request fails.
      final canvas = manifest['canvas'] as Map<String, dynamic>;
      expect(canvas['width'], 1024);
      expect(canvas['height'], 1024);
      expect(canvas['providerAspectRatio'], '1:1');
      expect(canvas['providerImageSize'], '1K');
    });

    test('keeps one selected back-hair cell at native size', () {
      final regions = _regions(manifest);
      final backHair = regions
          .where((region) => region['kind'] == 'backHair')
          .toList();
      expect(backHair, hasLength(1));
      expect(backHair.single['id'], 'back_hair_selected');
      expect(backHair.single['rigPartId'], 'back_hair');

      final output = backHair.single['outputCanvas'] as Map<String, dynamic>;
      expect((output['width'], output['height']), (429, 800));
      final front =
          regions.firstWhere(
                (region) => region['id'] == 'front_hair',
              )['outputCanvas']
              as Map<String, dynamic>;
      expect((front['width'], front['height']), (429, 438));
    });

    test('accepts every rear-hair option through the one cell', () {
      final selection = manifest['selectionContract'] as Map<String, dynamic>;
      expect(selection['backHairRegionId'], 'back_hair_selected');
      expect(
        (selection['acceptedValues'] as List<dynamic>).cast<String>().toSet(),
        {'short', 'medium', 'long', 'none'},
      );
      expect(selection['noneMeansEmptyRegion'], isTrue);
    });

    test('publishes one guide per rear-hair length', () {
      final selection = manifest['selectionContract'] as Map<String, dynamic>;
      final guides = (selection['guideByBackHairId'] as Map<String, dynamic>)
          .cast<String, String>();
      expect(guides.keys.toSet(), {'short', 'medium', 'long'});

      final hashes = (manifest['guideVariantSha256'] as Map<String, dynamic>)
          .cast<String, String>();
      expect(hashes.keys.toSet(), guides.keys.toSet());

      final seenHashes = <String>{};
      for (final entry in guides.entries) {
        final file = _repoFile(entry.value);
        expect(file.existsSync(), isTrue, reason: '${entry.key} guide missing');
        expect(_readPngSize(file), (width: 1024, height: 1024));
        expect(
          _sha256(file),
          hashes[entry.key],
          reason: '${entry.key} guide no longer matches its approved hash',
        );
        // Three lengths must be three genuinely different pictures.
        expect(
          seenHashes.add(hashes[entry.key]!),
          isTrue,
          reason: '${entry.key} guide is a duplicate of another length',
        );
      }

      // The six required contract hashes must keep their exact shape, so the
      // variant hashes live in their own map.
      expect(
        (manifest['assetSha256'] as Map<String, dynamic>).keys.toSet(),
        CharacterSheetContract.requiredHashIds,
      );
      expect(
        manifest['assets']!['guide'],
        guides[selection['canonicalBackHairId']],
        reason: 'assets.guide must point at the canonical variant',
      );
    });

    test('publishes how much of each cell the template actually fills', () {
      // A cell is a container, not a target. Body cells are nearly cell sized,
      // but the rear-hair cell is sized for the longest style, so telling a
      // provider to fill it would return oversized hair.
      for (final region in _regions(manifest)) {
        final crop = _Rect.fromJson(region['crop'] as Map<String, dynamic>);
        final content = region['referenceContent'] as Map<String, dynamic>;
        final bounds = _Rect.fromJson(content);
        expect(
          bounds.x >= 0 &&
              bounds.y >= 0 &&
              bounds.x + bounds.width <= crop.width &&
              bounds.y + bounds.height <= crop.height,
          isTrue,
          reason: '${region['id']} content escapes its own cell',
        );
        expect(
          (content['coverage'] as num).toDouble(),
          closeTo(
            bounds.width * bounds.height / (crop.width * crop.height),
            0.001,
          ),
          reason: '${region['id']} coverage does not match its bounds',
        );
      }
    });

    test('records the rear-hair cell as deliberately oversized', () {
      final byId = {
        for (final region in _regions(manifest)) region['id'] as String: region,
      };
      double coverage(String id) =>
          ((byId[id]!['referenceContent'] as Map<String, dynamic>)['coverage']
                  as num)
              .toDouble();

      // If this ever approaches 1.0 the cell stopped being oversized and the
      // "do not fill the cell" rule in the prompt contract needs revisiting.
      expect(coverage('back_hair_selected'), lessThan(0.7));
      expect(coverage('torso'), greaterThan(0.9));

      final extents =
          (manifest['selectionContract']!['referenceContentByBackHairId']
                  as Map<String, dynamic>)
              .cast<String, dynamic>();
      expect(extents.keys.toSet(), {'short', 'medium', 'long'});
      final heights = {
        for (final entry in extents.entries)
          entry.key: (entry.value as Map<String, dynamic>)['height'] as int,
      };
      expect(
        heights['short']!,
        lessThan(heights['medium']!),
        reason: 'short rear hair must be shorter than medium',
      );
      expect(
        heights['medium']!,
        lessThan(heights['long']!),
        reason: 'medium rear hair must be shorter than long',
      );
      // The tallest style still has to fit the cell it was sized for.
      expect(heights['long']!, lessThanOrEqualTo(800));
    });

    test('keeps rear hair no wider than front hair, as the template does', () {
      final byId = {
        for (final region in _regions(manifest)) region['id'] as String: region,
      };
      int contentWidth(String id) =>
          (byId[id]!['referenceContent'] as Map<String, dynamic>)['width']
              as int;
      // Rear hair sits behind the head instead of wrapping the face, so it is
      // narrower in the template. Generated hair must not invert that.
      expect(
        contentWidth('back_hair_selected'),
        lessThan(contentWidth('front_hair')),
      );
    });

    test('maps every rear-hair length to a real source asset', () {
      final byActor =
          (manifest['backHairSourceByIdForActor'] as Map<String, dynamic>)
              .cast<String, dynamic>();
      expect(byActor.keys, contains('default'));
      final sources = (byActor['default'] as Map<String, dynamic>)
          .cast<String, String>();
      expect(sources.keys.toSet(), {'short', 'medium', 'long'});
      final seen = <String>{};
      for (final entry in sources.entries) {
        expect(
          _repoFile(entry.value).existsSync(),
          isTrue,
          reason: '${entry.key} points at a missing ${entry.value}',
        );
        expect(
          seen.add(entry.value),
          isTrue,
          reason: '${entry.key} reuses another length\'s artwork',
        );
      }
    });

    test('dresses all nine body parts and keeps the head for face details', () {
      final regions = _regions(manifest);
      expect(
        regions.where((region) => region['kind'] == 'fittedClothing'),
        hasLength(9),
      );
      expect(
        regions.where((region) => region['kind'] == 'faceDetails'),
        hasLength(1),
      );
    });

    test('keeps a real green gap around every cell and the canvas edge', () {
      // The whole point of the tighter canvas is that cells still cannot touch;
      // touching cells would let generated content bleed between parts.
      final canvas = manifest['canvas'] as Map<String, dynamic>;
      final width = canvas['width'] as int;
      final height = canvas['height'] as int;
      expect(manifest['layout']!['cellPadding'], _v4CellPadding);

      final rects = {
        for (final region in _regions(manifest))
          region['id'] as String: _Rect.fromJson(
            region['crop'] as Map<String, dynamic>,
          ),
      };
      for (final entry in rects.entries) {
        final rect = entry.value;
        expect(
          rect.x >= _v4CellPadding &&
              rect.y >= _v4CellPadding &&
              rect.x + rect.width <= width - _v4CellPadding &&
              rect.y + rect.height <= height - _v4CellPadding,
          isTrue,
          reason: '${entry.key} breaks the $_v4CellPadding px canvas margin',
        );
      }
      final ids = rects.keys.toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          expect(
            rects[ids[i]]!.gapTo(rects[ids[j]]!),
            greaterThanOrEqualTo(_v4CellPadding),
            reason: '${ids[i]} and ${ids[j]} are too close',
          );
        }
      }
    });

    test('records a cell area that matches the real crops', () {
      final layout = manifest['layout'] as Map<String, dynamic>;
      final area = _regions(manifest).fold<int>(0, (sum, region) {
        final crop = _Rect.fromJson(region['crop'] as Map<String, dynamic>);
        return sum + crop.width * crop.height;
      });
      expect(layout['cellArea'], area);
      expect(layout['canvasArea'], 1024 * 1024);
      // The cells only fit because two spare back-hair cells were dropped.
      expect(area, lessThan(1024 * 1024));
    });

    test('cannot drop to the 0.5K tier because one cell is 800 px tall', () {
      // Documents why 1K is the floor, so nobody retries a cheaper tier and
      // silently downscales a locked part.
      final tallest = _regions(manifest)
          .map((region) => region['outputCanvas'] as Map<String, dynamic>)
          .map((output) => output['height'] as int)
          .reduce((a, b) => a > b ? a : b);
      expect(tallest, 800);
      expect(tallest, greaterThan(512));
    });

    test('carries the same cell set as the V2 checkpoint', () {
      expect(
        _regions(_readManifest(_v4)).map((region) => region['id']).toSet(),
        _regions(_readManifest(_v2)).map((region) => region['id']).toSet(),
      );
    });

    test('keeps every seam anchor needed for clothing continuity', () {
      // Clothing is drawn per cell but must line up across joints, so each
      // limb and the torso must still publish its seam markers.
      final byId = {
        for (final region in _regions(manifest)) region['id'] as String: region,
      };
      final anchorCounts = {
        for (final entry in byId.entries)
          entry.key: (entry.value['seamAnchors'] as List<dynamic>).length,
      };
      expect(anchorCounts['torso'], 5, reason: 'neck, shoulders, hips');
      for (final id in const ['upper_arm_right', 'upper_arm_left']) {
        expect(anchorCounts[id], 2, reason: '$id: shoulder and elbow');
      }
      for (final id in const ['upper_leg_right', 'upper_leg_left']) {
        expect(anchorCounts[id], 2, reason: '$id: hip and knee');
      }
      for (final id in const [
        'lower_arm_right',
        'lower_arm_left',
        'lower_leg_right',
        'lower_leg_left',
      ]) {
        expect(anchorCounts[id], 1, reason: '$id: one joint');
      }
    });
  });

  group('runtime contract support', () {
    test('accepts the active V1 manifest without a validation error', () {
      final contract = CharacterSheetContract.fromJson(_readManifest(_v1));
      expect(contract.validationErrors(), isEmpty);
      expect(
        CharacterSheetContractRepository.assetPath,
        _v1.manifestPath,
        reason: 'V1 is still the registered runtime contract',
      );
    });

    test('parses V4 but rejects it until the migration lands', () {
      // Same migration surface as V3: the parser already understands the shape,
      // so only the supported ID, version, and canvas assertions stand between
      // this sheet and the runtime pipeline.
      final contract = CharacterSheetContract.fromJson(_readManifest(_v4));
      expect(contract.contractId, 'character_sheet_v4');
      expect(contract.regions, hasLength(12));

      final errors = contract.validationErrors();
      expect(errors, isNotEmpty);
      expect(errors.join(' '), contains('character_sheet_v4'));
    });

    test('parses V3 but rejects it until the migration lands', () {
      // Documents the exact migration surface: the parser already understands
      // the V3 shape, so only the supported ID, version, and canvas assertions
      // stand between the approved sheet and the runtime pipeline.
      final contract = CharacterSheetContract.fromJson(_readManifest(_v3));
      expect(contract.contractId, 'character_sheet_v3');
      expect(contract.regions, hasLength(14));

      final errors = contract.validationErrors();
      expect(errors, isNotEmpty);
      expect(errors.join(' '), contains('character_sheet_v3'));
      expect(errors.join(' '), contains('4096 x 4096'));
    });
  });
}

class _Sheet {
  const _Sheet({
    required this.id,
    required this.version,
    required this.width,
    required this.height,
    required this.regionIds,
  });

  final String id;
  final int version;
  final int width;
  final int height;

  /// V1 and V3 publish the full three-cell back-hair catalog; the V2
  /// checkpoint deliberately packs one selected back-hair slot instead.
  final Set<String> regionIds;

  String get manifestPath =>
      'assets/images/characters/generation_templates/humanoid_v1/'
      '$id/crop_manifest.json';
}

const _sharedRegionIds = {
  'front_hair',
  'head',
  'torso',
  'upper_arm_right',
  'upper_arm_left',
  'lower_arm_right',
  'lower_arm_left',
  'upper_leg_right',
  'upper_leg_left',
  'lower_leg_right',
  'lower_leg_left',
};

const _v1 = _Sheet(
  id: 'character_sheet_v1',
  version: 1,
  width: 4096,
  height: 4096,
  regionIds: CharacterSheetContract.expectedRegionIds,
);
const _v2 = _Sheet(
  id: 'character_sheet_v2',
  version: 2,
  width: 2048,
  height: 2048,
  regionIds: {'back_hair_selected', ..._sharedRegionIds},
);
const _v3 = _Sheet(
  id: 'character_sheet_v3',
  version: 3,
  width: 4096,
  height: 1024,
  regionIds: CharacterSheetContract.expectedRegionIds,
);
const _v4 = _Sheet(
  id: 'character_sheet_v4',
  version: 4,
  width: 1024,
  height: 1024,
  regionIds: {'back_hair_selected', ..._sharedRegionIds},
);

const _sheets = [_v1, _v2, _v3, _v4];

/// Green gap V4 keeps around every cell and against the canvas edge.
const _v4CellPadding = 18;

File _repoFile(String relativePath) =>
    File('${Directory.current.path}/$relativePath');

Map<String, dynamic> _readManifest(_Sheet sheet) =>
    jsonDecode(_repoFile(sheet.manifestPath).readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _regions(Map<String, dynamic> manifest) =>
    (manifest['regions'] as List<dynamic>).cast<Map<String, dynamic>>();

String _sha256(File file) => sha256.convert(file.readAsBytesSync()).toString();

({int width, int height}) _readPngSize(File file) {
  final handle = file.openSync();
  final header = handle.readSync(24);
  handle.closeSync();
  int wordAt(int offset) =>
      (header[offset] << 24) |
      (header[offset + 1] << 16) |
      (header[offset + 2] << 8) |
      header[offset + 3];
  return (width: wordAt(16), height: wordAt(20));
}

class _Rect {
  const _Rect(this.x, this.y, this.width, this.height);

  factory _Rect.fromJson(Map<String, dynamic> json) => _Rect(
    json['x'] as int,
    json['y'] as int,
    json['width'] as int,
    json['height'] as int,
  );

  final int x;
  final int y;
  final int width;
  final int height;

  bool isInside(int canvasWidth, int canvasHeight) =>
      x >= 0 &&
      y >= 0 &&
      width > 0 &&
      height > 0 &&
      x + width <= canvasWidth &&
      y + height <= canvasHeight;

  bool overlaps(_Rect other) =>
      x < other.x + other.width &&
      other.x < x + width &&
      y < other.y + other.height &&
      other.y < y + height;

  /// Widest clear separation between two cells on either axis, or `-1` when they
  /// overlap. Two cells are safely apart when this is at least the padding.
  int gapTo(_Rect other) {
    final horizontal = x >= other.x + other.width
        ? x - (other.x + other.width)
        : other.x >= x + width
        ? other.x - (x + width)
        : -1;
    final vertical = y >= other.y + other.height
        ? y - (other.y + other.height)
        : other.y >= y + height
        ? other.y - (y + height)
        : -1;
    if (horizontal < 0 && vertical < 0) return -1;
    return horizontal > vertical ? horizontal : vertical;
  }
}
