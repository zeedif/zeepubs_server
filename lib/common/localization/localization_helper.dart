import 'package:grpc/grpc.dart' as grpc;
import 'package:shelf/shelf.dart' as shelf;

import 'localizer.dart';

class LocalizationHelper {
  static List<String> get supportedLocales => L10n.supportedLocales;

  /// Extrae el Locale de una petición HTTP (Shelf)
  static String ctxToLocale(shelf.Request request, [String? langParam]) {
    return _resolveLocale(langParam, request.headers['accept-language']);
  }

  /// Extrae el Locale de una petición gRPC
  static String grpcToLocale(grpc.ServiceCall call, [String? langParam]) {
    return _resolveLocale(langParam, call.clientMetadata?['accept-language']);
  }

  static String _resolveLocale(String? langParam, String? headerLang) {
    // 1. Query param manual (ej: ?lang=es)
    if (langParam != null && langParam.trim().isNotEmpty) {
      final loc = langParam.trim().toLowerCase();
      if (supportedLocales.contains(loc)) return loc;
    }

    // 2. Cabecera Accept-Language (ej: "es-AR,es;q=0.9,en;q=0.8")
    if (headerLang != null && headerLang.isNotEmpty) {
      final langs = headerLang.split(',').map((l) => l.split(';').first.trim().toLowerCase());
      for (final l in langs) {
        final match = supportedLocales.cast<String?>().firstWhere(
            (supported) => l == supported || l.startsWith('$supported-'), 
            orElse: () => null);
        if (match != null) return match;
      }
    }

    // 3. Fallback al idioma base
    return 'en';
  }
}
