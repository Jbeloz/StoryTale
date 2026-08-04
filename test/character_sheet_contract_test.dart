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

    test('uses the supported 4:1 2K provider shape', () {
      final canvas = manifest['canvas'] as Map<String, dynamic>;
      expect(canvas['width'], 4096);
      expect(canvas['height'], 1024);
      expect(canvas['providerAspectRatio'], '4:1');
      expect(canvas['providerImageSize'], '2K');
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

const _sheets = [_v1, _v2, _v3];

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
}
