class DemandCalculatorResult {
  final double demandScore; // 0..1
  final int confirmedCount;
  final int cancelledCount;
  final int capacity;
  const DemandCalculatorResult({
    required this.demandScore,
    required this.confirmedCount,
    required this.cancelledCount,
    required this.capacity,
  });
}

class DemandCalculator {
  static DemandCalculatorResult compute({
    required int confirmedCount,
    required int cancelledCount,
    required int capacity,
  }) {
    if (capacity <= 0) capacity = 1;
    // weight cancellations lightly to avoid inflation
    final adjusted = confirmedCount - 0.3 * cancelledCount;
    double score = adjusted / capacity;
    if (score.isNaN || score.isInfinite) score = 0.0;
    score = score.clamp(0.0, 1.0);
    return DemandCalculatorResult(
      demandScore: score,
      confirmedCount: confirmedCount,
      cancelledCount: cancelledCount,
      capacity: capacity,
    );
  }
}
