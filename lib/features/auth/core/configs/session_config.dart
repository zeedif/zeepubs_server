class SessionConfig {
  final int secretLength;
  final String hashPepper;
  final Duration lifetime;
  final Duration inactivityTimeout;

  SessionConfig({
    required this.secretLength,
    required this.hashPepper,
    required this.lifetime,
    required this.inactivityTimeout,
  });
}
