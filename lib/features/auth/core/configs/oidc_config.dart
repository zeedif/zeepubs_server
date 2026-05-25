class OidcConfig {
  final String authority;
  final String clientId;
  final String clientSecret;
  final String redirectUri;

  OidcConfig({
    required this.authority,
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });
}
