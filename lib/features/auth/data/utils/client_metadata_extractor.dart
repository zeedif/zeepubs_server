class ClientMetadataExtractor {
  static ({String clientNameKey, String clientTypeKey}) extract(String? userAgent) {
    switch (userAgent) {
      case null || '' || 'unknown':
        return (
          clientNameKey: 'client.name_unknown',
          clientTypeKey: 'client.type_unknown',
        );
    }

    final lower = userAgent.toLowerCase();
    final typeKey = switch (lower) {
      _ when lower.contains('mobile') || lower.contains('android') || lower.contains('iphone') => 'client.type_mobile',
      _ when lower.contains('tablet') || lower.contains('ipad') => 'client.type_tablet',
      _ => 'client.type_desktop',
    };

    // 3. Identificación del nombre del cliente
    final nameKey = switch (lower) {
      _ when lower.contains('chrome') => 'client.name_chrome',
      _ when lower.contains('firefox') => 'client.name_firefox',
      _ when lower.contains('safari') && !lower.contains('chrome') => 'client.name_safari',
      _ when lower.contains('edge') => 'client.name_edge',
      _ when lower.contains('postman') => 'client.name_postman',
      _ when lower.contains('grpc-dart') => 'client.name_mobile_app',
      _ => 'client.name_browser',
    };

    return (clientNameKey: nameKey, clientTypeKey: typeKey);
  }
}
