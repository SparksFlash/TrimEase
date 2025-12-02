class SlotContext {
  final String shopId;
  final String serviceId; // fallback to serviceTitle
  final DateTime scheduledAt;
  final double basePrice;
  final int activeBarberCount;
  final int
  nominalSlotCapacity; // per hour capacity (barberCount * slotsPerHour)

  SlotContext({
    required this.shopId,
    required this.serviceId,
    required this.scheduledAt,
    required this.basePrice,
    required this.activeBarberCount,
    required this.nominalSlotCapacity,
  });

  int get hour => scheduledAt.hour;
  int get weekday => scheduledAt.weekday; // 1=Mon

  String get cacheKey =>
      '$serviceId|$weekday|$hour|$activeBarberCount|$nominalSlotCapacity';
}
