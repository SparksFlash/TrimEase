import 'package:hive_flutter/hive_flutter.dart';

class LocalStore {
  static const _ownerBox = 'owner_box';
  static const _kLastSyncMillis = 'last_sync_millis';
  static const _kOwnerShopName = 'owner_shop_name';

  static final LocalStore instance = LocalStore._();
  LocalStore._();

  Box? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_ownerBox)) {
      _box ??= await Hive.openBox(_ownerBox);
    } else {
      _box = Hive.box(_ownerBox);
    }
  }

  Future<void> setLastSyncNow() async {
    await init();
    await _box?.put(_kLastSyncMillis, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> setOwnerShopName(String name) async {
    await init();
    await _box?.put(_kOwnerShopName, name);
  }

  int? get lastSyncMillis {
    final v = _box?.get(_kLastSyncMillis);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  String get lastSyncString {
    final ms = lastSyncMillis;
    if (ms == null) return 'never';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get ownerShopName => (_box?.get(_kOwnerShopName) ?? '').toString();
}
