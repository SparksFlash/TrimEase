import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/slot_context.dart';
import 'pricing_cache.dart';
import 'pricing_rules.dart';
import 'demand_calculator.dart';
import '../../utils/firestore_pricing_queries.dart';

class DynamicPriceResult {
  final double basePrice;
  final double finalPrice;
  final double demandScore;
  final String adjustmentType;
  final double percentApplied;
  final bool fromCache;
  final bool fallback;
  const DynamicPriceResult({
    required this.basePrice,
    required this.finalPrice,
    required this.demandScore,
    required this.adjustmentType,
    required this.percentApplied,
    required this.fromCache,
    required this.fallback,
  });
}

class PricingService {
  static Future<DynamicPriceResult> getDynamicPrice({
    required String shopId,
    required String serviceTitle,
    required DateTime scheduledAt,
    required double basePrice,
  }) async {
    // Build slot context (capacity heuristic slotsPerHour=1)
    final slotCtx = SlotContext(
      shopId: shopId,
      serviceId: serviceTitle,
      scheduledAt: scheduledAt,
      basePrice: basePrice,
      activeBarberCount: 0, // will fill after query
      nominalSlotCapacity: 0,
    );

    final cacheKey = slotCtx.cacheKey;
    final cached = PricingCache.get(cacheKey);
    if (cached != null) {
      final rr = PricingRules.apply(basePrice, cached.demandScore);
      return DynamicPriceResult(
        basePrice: basePrice,
        finalPrice: rr.finalPrice,
        demandScore: cached.demandScore,
        adjustmentType: rr.adjustmentType,
        percentApplied: rr.percentApplied,
        fromCache: true,
        fallback: false,
      );
    }

    try {
      final (
        confirmed,
        cancelled,
        activeBarbers,
      ) = await FirestorePricingQueries.bookingStats(
        shopId: shopId,
        serviceTitle: serviceTitle,
        scheduledAt: scheduledAt,
      );
      final capacity = activeBarbers; // simple heuristic
      final calc = DemandCalculator.compute(
        confirmedCount: confirmed,
        cancelledCount: cancelled,
        capacity: capacity,
      );
      PricingCache.put(cacheKey, calc.demandScore);
      final rr = PricingRules.apply(basePrice, calc.demandScore);
      return DynamicPriceResult(
        basePrice: basePrice,
        finalPrice: rr.finalPrice,
        demandScore: calc.demandScore,
        adjustmentType: rr.adjustmentType,
        percentApplied: rr.percentApplied,
        fromCache: false,
        fallback: false,
      );
    } catch (e) {
      // fallback: base price unchanged
      return DynamicPriceResult(
        basePrice: basePrice,
        finalPrice: basePrice,
        demandScore: 0.0,
        adjustmentType: 'none',
        percentApplied: 0.0,
        fromCache: false,
        fallback: true,
      );
    }
  }

  // Persist pricing metadata to booking/doc
  static Map<String, dynamic> pricingMetadata(DynamicPriceResult r) => {
    'dynamicPrice': r.finalPrice,
    'basePrice': r.basePrice,
    'demandScore': r.demandScore,
    'pricingApplied': r.adjustmentType,
    'pricingPercent': r.percentApplied,
    'pricingFromCache': r.fromCache,
    'pricingFallback': r.fallback,
    'pricingComputedAt': FieldValue.serverTimestamp(),
  };
}
