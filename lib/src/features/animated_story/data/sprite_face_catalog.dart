import 'dart:convert';

import 'package:flutter/services.dart';

class SpriteFaceCatalog {
  SpriteFaceCatalog({
    required this.id,
    required this.headPartId,
    required this.defaultExpressionId,
    required this.expressions,
  }) : expressionsById = {
         for (final expression in expressions) expression.id: expression,
       };

  final String id;
  final String headPartId;
  final String defaultExpressionId;
  final List<SpriteFaceExpression> expressions;
  final Map<String, SpriteFaceExpression> expressionsById;

  static Future<SpriteFaceCatalog> load(String assetPath) async {
    final source = await rootBundle.loadString(assetPath);
    return SpriteFaceCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  factory SpriteFaceCatalog.fromJson(Map<String, dynamic> json) {
    return SpriteFaceCatalog(
      id: json['id'] as String,
      headPartId: json['headPartId'] as String,
      defaultExpressionId: json['defaultExpressionId'] as String,
      expressions: (json['expressions'] as List<dynamic>)
          .map(
            (value) =>
                SpriteFaceExpression.fromJson(value as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  String resolveId(String requestedId, {bool isSpeaking = false}) {
    final safeId = expressionsById.containsKey(requestedId)
        ? requestedId
        : defaultExpressionId;
    if (isSpeaking &&
        safeId == defaultExpressionId &&
        expressionsById.containsKey('talking')) {
      return 'talking';
    }
    return safeId;
  }

  SpriteFaceExpression expressionFor(String requestedId) {
    return expressionsById[resolveId(requestedId)]!;
  }
}

class SpriteFaceExpression {
  const SpriteFaceExpression({
    required this.id,
    required this.label,
    required this.asset,
  });

  final String id;
  final String label;
  final String asset;

  factory SpriteFaceExpression.fromJson(Map<String, dynamic> json) {
    return SpriteFaceExpression(
      id: json['id'] as String,
      label: json['label'] as String,
      asset: json['asset'] as String,
    );
  }
}
