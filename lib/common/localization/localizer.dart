part 'localizer.g.dart';

class AppLocalizer {
  /// Recupera la traducción correspondiente a la clave y locale indicados.
  static String getString(String key, String locale, [List<Object>? args]) {
    final normalizedLocale = locale.toLowerCase();
    final langMap = _staticTranslations[normalizedLocale] ?? _staticTranslations['en']!;
    final template = langMap[key] ?? _staticTranslations['en']![key] ?? key;

    if (args == null || args.isEmpty) {
      return template;
    }

    return _format(template, args);
  }

  /// Procesa la plantilla de texto aplicando las reglas de sustitución y validación.
  static String _format(String template, List<Object> args) {
    final regExp = RegExp(r'%(\d+\$)?([sSdf%])');
    var sequentialIndex = 0;

    return template.replaceAllMapped(regExp, (match) {
      final specifier = match.group(2);

      if (specifier == '%') return '%';

      int index;
      final positionalGroup = match.group(1);
      if (positionalGroup != null) {
        final indexStr = positionalGroup.substring(0, positionalGroup.length - 1);
        index = int.parse(indexStr) - 1;
      } else {
        index = sequentialIndex++;
      }

      if (index < 0 || index >= args.length) return match.group(0) ?? '';

      final arg = args[index];

      // Validación estricta de tipos
      switch (specifier?.toLowerCase()) {
        case 'd':
          if (arg is int) return arg.toString();
          final parsed = int.tryParse(arg.toString());
          if (parsed != null) return parsed.toString();
          throw ArgumentError('L10N Format Error: %d esperaba int, recibió "$arg" (${arg.runtimeType}).');
        case 'f':
          if (arg is double) return arg.toString();
          final parsed = double.tryParse(arg.toString());
          if (parsed != null) return parsed.toString();
          throw ArgumentError('L10N Format Error: %f esperaba double, recibió "$arg" (${arg.runtimeType}).');
        case 's':
        default:
          return arg.toString();
      }
    });
  }
}
