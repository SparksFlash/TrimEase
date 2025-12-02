import 'dart:collection';

class PricingCacheEntry {
  final double demandScore;
  final DateTime computedAt;
  PricingCacheEntry({required this.demandScore, required this.computedAt});
  bool get isExpired =>
      DateTime.now().difference(computedAt) > const Duration(minutes: 30);
}

class PricingCache {
  static final Map<String, PricingCacheEntry> _map = HashMap();

  static PricingCacheEntry? get(String key) {
    final e = _map[key];
    if (e == null) return null;
    if (e.isExpired) {
      _map.remove(key);
      return null;
    }
    return e;
  }

  static void put(String key, double demandScore) {
    _map[key] = PricingCacheEntry(
      demandScore: demandScore,
      computedAt: DateTime.now(),
    );
  }
}
