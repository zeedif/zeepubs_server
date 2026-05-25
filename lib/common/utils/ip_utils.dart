import 'dart:io';

class IpUtils {
  /// Limpia y normaliza una dirección IP cruda obtenida de las cabeceras HTTP o gRPC.
  ///
  /// Procesa tanto direcciones IPv4 como IPv6, eliminando puertos adicionales,
  /// corchetes de formato de puerto IPv6, o listas de proxies.
  static String? normalizeIp(String? rawIp) {
    if (rawIp == null || rawIp.trim().isEmpty) return null;

    // 1. Extraer la IP del cliente original si viene en una cadena de proxies (X-Forwarded-For)
    var ip = rawIp.split(',').first.trim();

    // 2. Remover corchetes de formato de puerto IPv6 (ej. [2001:db8::1]:8080 -> 2001:db8::1)
    if (ip.startsWith('[') && ip.contains(']')) {
      final closeBracketIndex = ip.indexOf(']');
      ip = ip.substring(1, closeBracketIndex);
    } else {
      // 3. Remover el puerto para IPv4 u otras variantes si no se utilizaron corchetes
      final colonCount = ':'.allMatches(ip).length;
      if (colonCount == 1) {
        // Estructura clásica IPv4 con puerto (ej. 192.168.1.1:8080)
        ip = ip.split(':').first;
      } else if (colonCount > 1 && ip.contains('.')) {
        // Posible IPv6 que mapea IPv4 con puerto final (ej. ::ffff:192.0.2.128:8080)
        final lastColon = ip.lastIndexOf(':');
        final portCandidate = ip.substring(lastColon + 1);
        if (int.tryParse(portCandidate) != null) {
          ip = ip.substring(0, lastColon);
        }
      }
    }

    // 4. Validar la dirección resultante con el parser de la plataforma
    final parsed = InternetAddress.tryParse(ip);
    if (parsed != null) {
      return parsed.address; // Retorna la IP normalizada (comprimida para IPv6)
    }

    return null;
  }
}
