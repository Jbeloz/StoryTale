import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
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
          // The provider's output format. V1-V3 were authored expecting PNG;
          // V4 records image/jpeg because the Interactions API rejects
          // image/png for response_format.mime_type.
          expect(canvas['mimeType'], sheet.outputMimeType);
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

        test('draws each cell from the asset the rig actually composes', () {
          // A cell that shows anything other than its rig part shows the
          // provider a character the runtime cannot reproduce. Rear-hair cells
          // are the one legitimate exception: the request picks a length, so
          // sheets that publish all three cannot match the single asset the rig
          // carries. V4's single rear-hair cell is checked in its own group.
          final rigAssets = _rigAssetsByPartId();
          for (final region in _regions(manifest)) {
            if (region['kind'] == 'backHair') continue;
            final rigPartId = _rigPartIdOf(region);
            final rigAsset = rigAssets[rigPartId];
            expect(
              rigAsset,
              isNotNull,
              reason: '${region['id']} claims missing rig part $rigPartId',
            );
            if (region['id'] == 'head' && !sheet.headDrawsRigAsset) {
              // Recorded, not endorsed. V1 drew its head cell from
              // base/head.png, which carries a drawn face and is not the asset
              // the rig composes, and V2 and V3 inherited that. They stay
              // untouched behind their approved hashes; V4 corrects it.
              expect(
                region['sourceAsset'],
                isNot(rigAsset),
                reason:
                    '${sheet.id} head no longer carries its known V1 defect; '
                    'flip headDrawsRigAsset instead of loosening this check',
              );
              continue;
            }
            expect(
              region['sourceAsset'],
              rigAsset,
              reason: '${region['id']} does not draw its rig part',
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

    test('matches rear-hair width to front-hair width', () {
      final byId = {
        for (final region in _regions(manifest)) region['id'] as String: region,
      };
      int contentWidth(String id) =>
          (byId[id]!['referenceContent'] as Map<String, dynamic>)['width']
              as int;

      // The rear-hair source carries more transparent padding than the front,
      // so at equal cell width its art came out narrower and the front hair
      // overhung it. The builder enlarges the rear artwork inside its unchanged
      // cell until the two widths match.
      final front = contentWidth('front_hair');
      final rear = contentWidth('back_hair_selected');
      expect(
        rear,
        closeTo(front, front * 0.02),
        reason: 'rear hair should be the same width as front hair',
      );

      final scale =
          (manifest['selectionContract']!['rearHairReferenceScale'] as num)
              .toDouble();
      expect(scale, greaterThan(1.0));
      // Only the artwork grows. The cell is a rig box and must not change.
      final crop = byId['back_hair_selected']!['crop'] as Map<String, dynamic>;
      expect((crop['width'], crop['height']), (429, 800));
    });

    test('separates the limb cells into a leg block and an arm block', () {
      // Eight similar pale shapes in one row invite the provider to mix up which
      // cell is which, so legs and arms sit in two blocks with a wide channel.
      final rects = {
        for (final region in _regions(manifest))
          region['id'] as String: _Rect.fromJson(
            region['crop'] as Map<String, dynamic>,
          ),
      };
      const legs = [
        'upper_leg_right',
        'lower_leg_right',
        'upper_leg_left',
        'lower_leg_left',
      ];
      const arms = [
        'upper_arm_right',
        'lower_arm_right',
        'upper_arm_left',
        'lower_arm_left',
      ];

      final legRight = legs
          .map((id) => rects[id]!.x + rects[id]!.width)
          .reduce((a, b) => a > b ? a : b);
      final armLeft = arms
          .map((id) => rects[id]!.x)
          .reduce((a, b) => a < b ? a : b);
      expect(
        armLeft - legRight,
        greaterThan(_v4CellPadding * 2),
        reason: 'the two limb blocks must read as separate groups',
      );

      // Each block keeps its own cells adjacent rather than interleaved.
      for (final block in [legs, arms]) {
        final xs = block.map((id) => rects[id]!.x).toList()..sort();
        final other = block == legs ? arms : legs;
        for (final id in other) {
          final x = rects[id]!.x;
          expect(
            x > xs.last || x < xs.first,
            isTrue,
            reason: '$id sits inside the other limb block',
          );
        }
      }
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

    test('keeps its one rear-hair cell on the length the rig carries', () {
      final region = _regions(
        manifest,
      ).firstWhere((region) => region['kind'] == 'backHair');
      final rigAsset = _rigAssetsByPartId()['back_hair'];
      expect(region['sourceAsset'], rigAsset);
      final byId =
          (manifest['backHairSourceByIdForActor']
                  as Map<String, dynamic>)['default']
              as Map<String, dynamic>;
      final canonical = manifest['selectionContract']['canonicalBackHairId'];
      expect(
        byId[canonical],
        rigAsset,
        reason: 'the canonical guide must show the rig rear-hair length',
      );
    });

    group('head cell after the V1 source correction', () {
      // The head is the one cell whose artwork changed size inside an unchanged
      // cell, so its masks and anchors had to move with it. These assertions
      // check the result against the runtime asset rather than against the
      // guide, which ties the sheet to what Story Mode composes.
      final region = _regions(
        manifest,
      ).firstWhere((region) => region['id'] == 'head');
      final cell = _Rect.fromJson(region['crop'] as Map<String, dynamic>);
      final head = _fittedRigArtwork(region['sourceAsset'] as String, cell);
      final content = _opaqueBounds(head);

      test('records the real content bounds of the fitted rig head', () {
        final reference =
            region['referenceContent'] as Map<String, dynamic>;
        expect(reference['x'], content.x);
        expect(reference['y'], content.y);
        expect(reference['width'], content.width);
        expect(reference['height'], content.height);
        expect(
          content.width < cell.width && content.height < cell.height,
          isTrue,
          reason: 'the runtime head sits inside its cell, it does not fill it',
        );
      });

      test('keeps the writable window on the head and nowhere else', () {
        final allowed = _cellMask(manifest, 'allowedRegions', cell);
        final protected = _cellMask(manifest, 'protectedRegions', cell);
        var writable = 0;
        var writableOffHead = 0;
        var both = 0;
        var neither = 0;
        for (var y = 0; y < cell.height; y++) {
          for (var x = 0; x < cell.width; x++) {
            final index = y * cell.width + x;
            if (allowed[index] && protected[index]) both++;
            if (!allowed[index] && !protected[index]) neither++;
            if (!allowed[index] || protected[index]) continue;
            writable++;
            if (image.getAlpha(head.getPixel(x, y)) == 0) writableOffHead++;
          }
        }
        expect(writable, greaterThan(0));
        expect(
          writableOffHead,
          0,
          reason: 'generated face detail must land on the locked head',
        );
        expect(both, 0, reason: 'allowed and protected must stay disjoint');
        expect(neither, 0, reason: 'protected must cover the rest of the cell');
      });

      test('marks its neck seam where its own anchor says the neck is', () {
        // Measured in V1: none of the head cell's 181 seam pixels fell within
        // its recorded anchor, while all nine other body cells matched theirs
        // exactly. V4 paints the head marker from the anchor.
        final anchors = (region['seamAnchors'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(anchors, hasLength(1));
        final seam = _cellMask(manifest, 'seamAllowances', cell);
        var marked = 0;
        var offAnchor = 0;
        for (var y = 0; y < cell.height; y++) {
          for (var x = 0; x < cell.width; x++) {
            if (!seam[y * cell.width + x]) continue;
            marked++;
            final inside = anchors.any((anchor) {
              final dx = x + 0.5 - (anchor['x'] as num);
              final dy = y + 0.5 - (anchor['y'] as num);
              final radius = (anchor['radius'] as num) + 1;
              return dx * dx + dy * dy <= radius * radius;
            });
            if (!inside) offAnchor++;
          }
        }
        expect(marked, greaterThan(0));
        expect(offAnchor, 0);
      });
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
    test('accepts the active V4 manifest without a validation error', () {
      final contract = CharacterSheetContract.fromJson(_readManifest(_v4));
      expect(contract.validationErrors(), isEmpty);
      expect(contract.regions, hasLength(12));
      expect(
        CharacterSheetContractRepository.assetPath,
        _v4.manifestPath,
        reason: 'V4 is the registered runtime contract',
      );
    });

    test('resolves one rear-hair region and one guide per length', () {
      final contract = CharacterSheetContract.fromJson(_readManifest(_v4));
      final selection = contract.selection;
      final manifest = _readManifest(_v4);
      final variants =
          (manifest['guideVariantSha256'] as Map<String, dynamic>)
              .cast<String, String>();

      for (final length in const ['short', 'medium', 'long']) {
        expect(
          selection.regionFor(length),
          'back_hair_selected',
          reason: 'V4 activates one cell whatever the length',
        );
        final guide = selection.guideFor(length);
        expect(guide.sha256, variants[length]);
        expect(
          _sha256(_repoFile(guide.path)),
          guide.sha256,
          reason: '$length must send the guide its hash names',
        );
        expect(guide.path, contains(length));
      }

      expect(selection.regionFor('none'), 'none');
      expect(
        selection.guideFor('none').sha256,
        variants[selection.canonicalBackHairId],
        reason: 'none still needs a guide; it just leaves the cell green',
      );
      expect(() => selection.regionFor('beehive'), throwsFormatException);
      expect(selection.acceptedGuideSha256, containsAll(variants.values));
    });

    test('still parses V1 so the rollback target stays loadable', () {
      // V1 remains registered in pubspec.yaml. It no longer validates, because
      // validation now describes V4: 14 regions instead of 12, and a 4096
      // canvas. Parsing is what a rollback would need first.
      final contract = CharacterSheetContract.fromJson(_readManifest(_v1));
      expect(contract.contractId, 'character_sheet_v1');
      expect(contract.regions, hasLength(14));
      expect(
        contract.selection.backHairRegionId,
        isNull,
        reason: 'V1 names one region per length rather than a shared cell',
      );
      expect(contract.selection.regionFor('medium'), 'back_hair_medium');
      expect(contract.validationErrors(), isNotEmpty);
    });

    test('the Worker source agrees with the active manifest', () {
      // The Worker cannot import Dart, so its contract constants are copied by
      // hand and only take effect on deploy. A stale copy fails a paid request
      // with a 409 after the money is committed, so compare the two here
      // instead of trusting a manual diff.
      final contract = CharacterSheetContract.fromJson(_readManifest(_v4));
      final worker = _repoFile(
        'cloudflare/image-worker/src/index.ts',
      ).readAsStringSync();

      String constant(String name) {
        final match = RegExp(
          '$name\\s*=\\s*\\n?\\s*"([^"]+)"',
        ).firstMatch(worker);
        expect(match, isNotNull, reason: '$name is missing from the Worker');
        return match!.group(1)!;
      }

      expect(constant('CHARACTER_SHEET_CONTRACT_ID'), contract.contractId);
      expect(
        constant('CHARACTER_SHEET_CONTRACT_VERSION'),
        '${contract.contractVersion}',
      );
      expect(
        constant('CHARACTER_SHEET_GEOMETRY_HASH'),
        contract.lockedRig.geometryHash,
      );
      expect(
        RegExp(r'CHARACTER_SHEET_CANVAS\s*=\s*(\d+)').firstMatch(worker)?.
            group(1),
        '${contract.canvas.width}',
        reason: 'the Worker must validate the canvas the contract declares',
      );
      expect(
        RegExp(r'image_size:\s*mode === "character-sheet"\s*\n?\s*\?\s*"(\w+)"')
            .firstMatch(worker)
            ?.group(1),
        '1K',
        reason: 'the requested tier is what StoryTale is billed for',
      );

      // Scoped to generateSprite: other Gemini paths declare their own
      // response_format, and the analysis one asks for application/json.
      final spriteSource = worker.substring(
        worker.indexOf('async function generateSprite('),
      );
      expect(
        RegExp(r'mime_type:\s*"([\w/]+)"').firstMatch(spriteSource)?.group(1),
        contract.canvas.mimeType,
        reason:
            'the format asked for and the format accepted must be the same. '
            'Measured on 2026-08-06: this endpoint rejects image/png with '
            'HTTP 400 and supports only image/jpeg',
      );
      expect(
        RegExp(
          r'CHARACTER_SHEET_MIME\s*=\s*"([\w/]+)"',
        ).firstMatch(worker)?.group(1),
        contract.canvas.mimeType,
        reason: 'the Worker must accept the format the contract declares',
      );

      expect(
        worker,
        contains('"${contract.selection.backHairRegionId}"'),
        reason: 'the Worker must accept the rear-hair region V4 actually sends',
      );

      final workerGuides = RegExp(r'^\s+(short|medium|long): "([a-f0-9]{64})"',
        multiLine: true,
      ).allMatches(worker);
      expect(
        {for (final match in workerGuides) match.group(1)!: match.group(2)!},
        contract.selection.guideSha256ByBackHairId,
        reason: 'every published guide variant must be accepted on deploy',
      );
    });

    test('rejects V3, whose 4:1 canvas the provider does not document', () {
      final contract = CharacterSheetContract.fromJson(_readManifest(_v3));
      expect(contract.contractId, 'character_sheet_v3');
      final errors = contract.validationErrors();
      expect(errors.join(' '), contains('character_sheet_v3'));
      expect(errors.join(' '), contains('4096 x 1024'));
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
    this.headDrawsRigAsset = false,
    this.outputMimeType = 'image/png',
  });

  final String id;
  final int version;
  final int width;
  final int height;

  /// Whether the `head` cell shows the asset the rig composes. V1 drew it from
  /// the faced `base/head.png` instead, and V2 and V3 inherited that; only V4
  /// was corrected, because the earlier three are locked behind approved
  /// hashes.
  final bool headDrawsRigAsset;

  /// What a returned sheet must be, not what the guide on disk is.
  final String outputMimeType;

  /// V1 and V3 publish the full three-cell back-hair catalog; the V2
  /// checkpoint deliberately packs one selected back-hair slot instead.
  final Set<String> regionIds;

  String get manifestPath =>
      'assets/images/characters/generation_templates/humanoid_v1/'
      '$id/crop_manifest.json';
}

/// V1 and V3 publish one cell per rear-hair length. This used to borrow
/// `CharacterSheetContract.expectedRegionIds`, which now describes V4's twelve,
/// so the older shape is spelled out here instead of tracking the active one.
const _perLengthRegionIds = {
  'back_hair_short',
  'back_hair_medium',
  'back_hair_long',
  ..._sharedRegionIds,
};

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
  regionIds: _perLengthRegionIds,
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
  regionIds: _perLengthRegionIds,
);
const _v4 = _Sheet(
  id: 'character_sheet_v4',
  version: 4,
  width: 1024,
  height: 1024,
  regionIds: {'back_hair_selected', ..._sharedRegionIds},
  headDrawsRigAsset: true,
  outputMimeType: 'image/jpeg',
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

Map<String, String> _rigAssetsByPartId() {
  final rig =
      jsonDecode(
            _repoFile(
              'assets/images/characters/rigs/humanoid_v1/rig.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return <String, String>{
    for (final raw in rig['parts'] as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw['asset'] as String,
  };
}

/// V1 predates the `rigPartId` field, so fall back to the region's own naming.
/// Every body region is named after its rig part; only the two hair kinds are
/// named after the slot they fill.
String _rigPartIdOf(Map<String, dynamic> region) =>
    region['rigPartId'] as String? ??
    switch (region['kind']) {
      'frontHair' => 'front_hair',
      'backHair' => 'back_hair',
      _ => region['id'] as String,
    };

/// A rig source drawn the way both the sheet builder and the rig renderer draw
/// it: resized to the cell, without preserving the source aspect ratio.
image.Image _fittedRigArtwork(String sourceAsset, _Rect cell) {
  final decoded = image.decodeImage(_repoFile(sourceAsset).readAsBytesSync())!;
  return image.copyResize(
    decoded..channels = image.Channels.rgba,
    width: cell.width,
    height: cell.height,
    interpolation: image.Interpolation.linear,
  );
}

_Rect _opaqueBounds(image.Image value) {
  var minX = value.width;
  var minY = value.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < value.height; y++) {
    for (var x = 0; x < value.width; x++) {
      if (image.getAlpha(value.getPixel(x, y)) == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  return _Rect(minX, minY, maxX - minX + 1, maxY - minY + 1);
}

/// One row-major white/not-white flag per pixel of [cell] in the named mask.
List<bool> _cellMask(
  Map<String, dynamic> manifest,
  String assetKey,
  _Rect cell,
) {
  final assets = manifest['assets'] as Map<String, dynamic>;
  final mask = image.decodeImage(
    _repoFile(assets[assetKey] as String).readAsBytesSync(),
  )!;
  return <bool>[
    for (var y = 0; y < cell.height; y++)
      for (var x = 0; x < cell.width; x++)
        image.getRed(mask.getPixel(cell.x + x, cell.y + y)) >= 250,
  ];
}

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
