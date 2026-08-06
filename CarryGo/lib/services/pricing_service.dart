import 'dart:math';

class PricingResult {
  final double baseFare;
  final double distanceKm;
  final double distanceFee;
  final double sizeFee;
  final double weightFee;
  final double urgencyMultiplier;
  final double conditionMultiplier;
  final double subtotal;
  final double total;
  final double platformCommission;
  final double riderPayout;

  const PricingResult({
    required this.baseFare,
    required this.distanceKm,
    required this.distanceFee,
    required this.sizeFee,
    required this.weightFee,
    required this.urgencyMultiplier,
    required this.conditionMultiplier,
    required this.subtotal,
    required this.total,
    required this.platformCommission,
    required this.riderPayout,
  });
}

class PricingRule {
  final String city;
  final double baseFare;
  final double perKmRate;
  final double minimumBillableDistanceKm;
  final double commissionRate;
  final double roundingStep;
  final Map<String, double> sizeFees;
  final Map<String, double> weightFees;
  final Map<String, double> urgencyMultipliers;

  const PricingRule({
    required this.city,
    required this.baseFare,
    required this.perKmRate,
    required this.minimumBillableDistanceKm,
    required this.commissionRate,
    required this.roundingStep,
    required this.sizeFees,
    required this.weightFees,
    required this.urgencyMultipliers,
  });

  bool get isConfigured => baseFare > 0 && perKmRate > 0;

  factory PricingRule.fromMap(String city, Map<String, dynamic> data) {
    Map<String, double> numberMap(String key) {
      final value = data[key];
      if (value is! Map) return const {};
      return value.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as num?)?.toDouble() ?? 0,
        ),
      );
    }

    return PricingRule(
      city: data['city'] as String? ?? city,
      baseFare: (data['baseFare'] as num?)?.toDouble() ?? 0,
      perKmRate: ((data['perKmRate'] ?? data['distanceRatePerKm']) as num?)
              ?.toDouble() ??
          0,
      minimumBillableDistanceKm:
          (data['minimumBillableDistanceKm'] as num?)?.toDouble() ?? 1,
      commissionRate:
          ((data['commissionRate'] ?? data['platformCommissionRate']) as num?)
                  ?.toDouble() ??
              0,
      roundingStep: (data['roundingStep'] as num?)?.toDouble() ?? 50,
      sizeFees: numberMap('sizeFees'),
      weightFees: numberMap('weightFees'),
      urgencyMultipliers: numberMap('urgencyMultipliers'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'city': city,
      'baseFare': baseFare,
      'perKmRate': perKmRate,
      'minimumBillableDistanceKm': minimumBillableDistanceKm,
      'commissionRate': commissionRate,
      'roundingStep': roundingStep,
      'sizeFees': sizeFees,
      'weightFees': weightFees,
      'urgencyMultipliers': urgencyMultipliers,
    };
  }
}

class PricingService {
  static const parcelSizeExamples = <String, String>{
    'Small': 'Envelope, documents, medicine',
    'Medium': 'Food pack, small bag, shoes',
    'Large': 'Grocery bag, small carton',
    'Extra Large': 'Big carton or bulky item',
  };

  static const weightFeelExamples = <String, String>{
    'Light': 'Can be carried with one hand',
    'Medium': 'Needs two hands but easy to carry',
    'Heavy': 'Difficult to carry or needs extra care',
  };

  static const conditionMultipliers = <String, double>{
    'Clear': 1,
    'Rain': 1.15,
    'Heavy traffic': 1.2,
    'Rain + heavy traffic': 1.35,
  };

  static PricingRule fallbackRule(String city) {
    return PricingRule(
      city: city,
      baseFare: 900,
      perKmRate: 180,
      minimumBillableDistanceKm: 1,
      commissionRate: 0.15,
      roundingStep: 50,
      sizeFees: const {
        'Small': 0,
        'Medium': 250,
        'Large': 500,
        'Extra Large': 900,
      },
      weightFees: const {
        'Light': 0,
        'Medium': 250,
        'Heavy': 650,
      },
      urgencyMultipliers: const {
        'Normal': 1,
        'Express': 1.35,
      },
    );
  }

  static PricingResult estimate({
    required PricingRule rule,
    required double distanceKm,
    required String parcelSize,
    required String parcelWeight,
    required String urgency,
    required String condition,
  }) {
    final billableDistance =
        max(distanceKm, rule.minimumBillableDistanceKm).toDouble();
    final distanceFee = billableDistance * rule.perKmRate;
    final sizeFee = rule.sizeFees[parcelSize] ?? 0;
    final weightFee = rule.weightFees[parcelWeight] ?? 0;
    final urgencyMultiplier = rule.urgencyMultipliers[urgency] ?? 1;
    final conditionMultiplier = conditionMultipliers[condition] ?? 1;
    final subtotal = rule.baseFare + distanceFee + sizeFee + weightFee;
    final total = _roundUp(
        subtotal * urgencyMultiplier * conditionMultiplier, rule.roundingStep);
    final platformCommission =
        _roundUp(total * rule.commissionRate, rule.roundingStep);
    final riderPayout = max<double>(0, total - platformCommission);

    return PricingResult(
      baseFare: rule.baseFare,
      distanceKm: distanceKm,
      distanceFee: distanceFee,
      sizeFee: sizeFee,
      weightFee: weightFee,
      urgencyMultiplier: urgencyMultiplier,
      conditionMultiplier: conditionMultiplier,
      subtotal: subtotal,
      total: total,
      platformCommission: platformCommission,
      riderPayout: riderPayout,
    );
  }

  static double _roundUp(double value, [double step = 50]) {
    return (value / step).ceil() * step;
  }
}
