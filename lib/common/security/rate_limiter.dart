import 'dart:math';

class _TokenBucket {
  int tokens;
  DateTime lastRefill;

  _TokenBucket(this.tokens, this.lastRefill);
}

/// Implementación de Rate Limiter basada en Token Bucket.
class RateLimiter {
  final int maxRequests;
  final Duration duration;
  final bool refillBetween;
  
  final Map<String, _TokenBucket> _buckets = {};

  RateLimiter({
    required this.maxRequests,
    required this.duration,
    required this.refillBetween,
  });

  /// Intenta consumir un token. Devuelve true si fue exitoso, false si fue limitado.
  bool tryAcquire(String key) {
    final now = DateTime.now().toUtc();
    
    // Si no existe, inicializa el bucket lleno
    _buckets.putIfAbsent(key, () => _TokenBucket(maxRequests, now));

    _refillTokens(key, now);

    final bucket = _buckets[key]!;
    if (bucket.tokens > 0) {
      bucket.tokens--;
      return true;
    }

    return false;
  }

  void _refillTokens(String key, DateTime now) {
    final bucket = _buckets[key]!;
    final timeSinceLastRefill = now.difference(bucket.lastRefill);

    // Cantidad de tokens a añadir basada en la proporción del tiempo transcurrido
    final tokensToAdd = (timeSinceLastRefill.inMilliseconds / duration.inMilliseconds).floor();

    if (timeSinceLastRefill >= duration) {
      // Si ha pasado el tiempo completo, llenamos el bucket
      bucket.tokens = maxRequests;
      bucket.lastRefill = now;
    } else if (tokensToAdd > 0 && refillBetween) {
      // Si permitimos recargas parciales y hay tokens para añadir
      bucket.tokens = min(maxRequests, bucket.tokens + tokensToAdd);
      bucket.lastRefill = now;
    }
  }

  /// Limpia buckets antiguos para evitar fugas de memoria (Memory Leaks).
  /// Útil si se llama en un Job en segundo plano.
  void cleanup(Duration inactivityThreshold) {
    final now = DateTime.now().toUtc();
    _buckets.removeWhere((key, bucket) => now.difference(bucket.lastRefill) > inactivityThreshold);
  }
}
