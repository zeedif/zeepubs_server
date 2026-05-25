enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal;

  static final Map<String, LogLevel> _nameMap = LogLevel.values.asNameMap();

  static LogLevel fromString(String name) {
    return _nameMap[name.toLowerCase()] ?? LogLevel.info;
  }
}
