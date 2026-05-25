class AppCaches {
  final Map<String, dynamic> _localCache = {};

  Future<void> put(String key, dynamic value) async => _localCache[key] = value;
  Future<dynamic> get(String key) async => _localCache[key];
  Future<void> invalidate(String key) async => _localCache.remove(key);
}
