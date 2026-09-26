import '../../core/storage/catalog_storage.dart';
import '../models/class_model.dart';
import '../models/session_model.dart';

/// Read-through cache for catalog data only; never caches attendance writes.
class CatalogRepository {
  CatalogRepository({
    required this._loadClasses,
    required this._loadSlots,
    CatalogStorage? storage,
    DateTime Function()? clock,
  }) : _classes = _CatalogCache<ClassModel>(
         storage: storage,
         clock: clock ?? DateTime.now,
         decode: ClassModel.fromJson,
         encode: (item) => item.toJson(),
       ),
       _slots = _CatalogCache<SessionSlot>(
         storage: storage,
         clock: clock ?? DateTime.now,
         decode: SessionSlot.fromJson,
         encode: (item) => item.toJson(),
       );
  final Future<List<ClassModel>> Function() _loadClasses;
  final Future<List<SessionSlot>> Function(String) _loadSlots;
  final _CatalogCache<ClassModel> _classes;
  final _CatalogCache<SessionSlot> _slots;
  Future<List<ClassModel>> refreshClasses() =>
      _classes.refresh('classes', _loadClasses);
  Future<List<ClassModel>> getClasses() =>
      _classes.read('classes', _loadClasses);
  Future<List<SessionSlot>> getSlots(String classId) =>
      _slots.read('slots:$classId', () => _loadSlots(classId));
}

class _CatalogCache<T> {
  _CatalogCache({
    required this.storage,
    required this.clock,
    required this.decode,
    required this.encode,
  });
  final CatalogStorage? storage;
  final DateTime Function() clock;
  final T Function(Map<String, dynamic>) decode;
  final Map<String, dynamic> Function(T) encode;
  final _cache = <String, ({DateTime saved, List<T> items})>{};
  final _pending = <String, Future<List<T>>>{};

  Future<List<T>> refresh(String key, Future<List<T>> Function() load) async {
    final pending = _pending[key];
    if (pending != null) await pending;
    final items = List<T>.unmodifiable(await load());
    final saved = clock();
    _cache[key] = (saved: saved, items: items);
    await storage?.write(key, items.map(encode).toList(), saved);
    return items;
  }

  Future<List<T>> read(String key, Future<List<T>> Function() load) {
    final cached = _cache[key];
    if (cached != null &&
        !clock().difference(cached.saved).isNegative &&
        clock().difference(cached.saved) < const Duration(minutes: 5)) {
      return Future.value(cached.items);
    }
    return _pending[key] ??= _load(key, load).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<List<T>> _load(String key, Future<List<T>> Function() load) async {
    final stored = await storage?.read(key, clock());
    if (stored != null) {
      try {
        final items = List<T>.unmodifiable(
          stored.items.map(
            (item) => decode(
              Map<String, dynamic>.from(item as Map<Object?, Object?>),
            ),
          ),
        );
        _cache[key] = (saved: stored.saved, items: items);
        return items;
      } on Object {
        // A damaged local snapshot must not prevent a fresh network read.
      }
    }
    final items = List<T>.unmodifiable(await load());
    final saved = clock();
    _cache[key] = (saved: saved, items: items);
    await storage?.write(key, items.map(encode).toList(), saved);
    return items;
  }
}
