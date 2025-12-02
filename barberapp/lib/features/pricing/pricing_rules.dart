class PricingRuleResult {
  final double finalPrice;
  final String adjustmentType; // discount/premium/none
  final double percentApplied; // e.g. 0.15
  const PricingRuleResult({
    required this.finalPrice,
    required this.adjustmentType,
    required this.percentApplied,
  });
}

class PricingRules {
  // Configurable thresholds
  static double lowDemandThreshold = 0.30;
  static double highDemandThreshold = 0.80;
  static double lowDemandDiscountPct = 0.15; // 15% off
  static double highDemandPremiumPct = 0.10; // 10% add
  static double floorMultiplier = 0.70; // do not go below 70% base
  static double capMultiplier = 1.25; // do not go above 125% base

  static PricingRuleResult apply(double basePrice, double demandScore) {
    double finalPrice = basePrice;
    String type = 'none';
    double pct = 0.0;

    if (demandScore < lowDemandThreshold) {
      pct = lowDemandDiscountPct;
      finalPrice = basePrice * (1 - pct);
      type = 'discount';
    } else if (demandScore > highDemandThreshold) {
      pct = highDemandPremiumPct;
      finalPrice = basePrice * (1 + pct);
      type = 'premium';
    }

    // safety floor/cap
    finalPrice = finalPrice.clamp(
      basePrice * floorMultiplier,
      basePrice * capMultiplier,
    );

    return PricingRuleResult(
      finalPrice: double.parse(finalPrice.toStringAsFixed(2)),
      adjustmentType: type,
      percentApplied: pct,
    );
  }
}
