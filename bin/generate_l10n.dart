import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  generateL10n();
}

/// Genera los recursos de localización antes del arranque del servidor.
/// Lee los JSON de traducciones, valida la coherencia y genera el código Dart tipado.
void generateL10n() {
  const baseLang = 'en';
  final l10nDir = Directory('l10n');
  final outputFile = File('lib/common/localization/localizer.g.dart');

  if (!l10nDir.existsSync()) {
    print('❌ Carpeta l10n/ no encontrada. Crea l10n/$baseLang.jsonc');
    exit(1);
  }

  // Mapa para almacenar el archivo a usar por cada idioma (priorizando .jsonc)
  final filesByLang = <String, File>{};

  // Deconstrucción de objetos
  for (final entity in l10nDir.listSync()) {
    if (entity case File(path: final path) when path.endsWith('.json') || path.endsWith('.jsonc')) {
      final lang = p.basenameWithoutExtension(path);
      final ext = p.extension(path);

      // Prioridad: Si ya existe jsonc para este idioma y el actual es json, lo ignoramos.
      // Si el actual es jsonc, sobrescribe cualquier json previo.
      if (!filesByLang.containsKey(lang) || ext == '.jsonc') {
        filesByLang[lang] = entity;
      }
    }
  }

  if (filesByLang[baseLang] case final baseFile?) {
    // 1. Leer y limpiar el idioma base
    final baseJson = _parseTranslationFile(baseFile);

    // Mapa global para traducciones estáticas
    final allTranslations = <String, Map<String, String>>{
      baseLang: baseJson.cast<String, String>(),
    };

    // 2. Validar los demás idiomas contra el base
    for (final MapEntry(key: lang, value: langFile) in filesByLang.entries) {
      if (lang == baseLang) continue;

      final langJson = _parseTranslationFile(langFile);
      final fileName = p.basename(langFile.path);

      for (final MapEntry(:key, value: baseValue) in baseJson.entries) {
        if (!langJson.containsKey(key)) {
          throw Exception('❌ Error: Falta la clave "$key" en $fileName');
        }

        final baseParams = _extractParams(baseValue.toString());
        final langParams = _extractParams(langJson[key].toString());

        if (baseParams.length != langParams.length) {
          throw Exception('❌ Error: Disparidad de parámetros en "$key" para $fileName. '
              'Esperado: ${baseParams.length}, Encontrado: ${langParams.length}');
        }
      }

      allTranslations[lang] = langJson.cast<String, String>();
    }

    // 4. Generar localizer.g.dart
    final buffer = StringBuffer()
      ..writeln('// AUTO-GENERATED FILE. DO NOT MODIFY.')
      ..writeln('part of \'localizer.dart\';\n');

    _appendTranslationsMap(buffer, allTranslations);
    final langs = filesByLang.keys.toList()..sort();
    _appendTypedStrings(buffer..writeln(), baseJson, langs);

    outputFile.writeAsStringSync(buffer.toString());
    print('✅ Recursos L10n generados exitosamente en ${outputFile.path}');
  } else {
    print('❌ Idioma base "$baseLang" no encontrado en l10n/.');
    exit(1);
  }
}

/// Parsea el archivo dependiendo de su extensión.
/// Permite comentarios " // " de línea completa SÓLO en archivos .jsonc.
Map<String, dynamic> _parseTranslationFile(File file) {
  final content = file.readAsStringSync();

  // Dart 3: Pattern matching con switch expression para el flujo de retorno
  return switch (p.extension(file.path)) {
    '.jsonc' => jsonDecode(content.split('\n').where((line) => !line.trimLeft().startsWith('//')).join('\n')),
    // Si es .json, se pasa directo. Si tiene comentarios invalidos,
    // jsonDecode lanzará un FormatException indicando el error nativamente.
    _ => jsonDecode(content),
  };
}

void _appendTranslationsMap(StringBuffer buffer, Map<String, Map<String, String>> translations) {
  buffer.writeln('const Map<String, Map<String, String>> _staticTranslations = {');

  for (final MapEntry(key: lang, value: map) in translations.entries) {
    buffer.writeln("  '$lang': {");
    for (final MapEntry(:key, :value) in map.entries) {
      final escapedValue = value
          .replaceAll(r'\', r'\\')   // Escapa barras invertidas primero
          .replaceAll('\n', r'\n')   // Escapa saltos de línea reales
          .replaceAll("'", r"\'")    // Escapa comillas simples
          .replaceAll(r'$', r'\$');  // Escapa el signo de interpolación de Dart

      buffer.writeln("    '$key': '$escapedValue',");
    }
    buffer.writeln("  },");
  }
  buffer.writeln('};');
}

void _appendTypedStrings(StringBuffer buffer, Map<String, dynamic> baseJson, List<String> langs) {
  buffer..writeln('class L10n {')
  ..writeln('  static const strings = _Strings();')
  ..writeln('  static const supportedLocales = ${langs.map((l) => "'$l'").toList()};')
  ..writeln('}\n')
  ..writeln('class _Strings {')
  ..writeln('  const _Strings();');

  for (final MapEntry(:key, :value) in baseJson.entries) {
    final params = _extractParams(value.toString());
    final methodName = _toLowerCamelCase(key); // auth.login_failed -> authLoginFailed

    if (params.isEmpty) {
      buffer.writeln('  String $methodName(String locale) => AppLocalizer.getString(\'$key\', locale);');
    } else {
      final paramSignatures = params.asMap().entries.map((e) => '${e.value} arg${e.key}').join(', ');
      final paramNames = params.asMap().entries.map((e) => 'arg${e.key}').join(', ');
      buffer.writeln('  String $methodName(String locale, $paramSignatures) => AppLocalizer.getString(\'$key\', locale, [$paramNames]);');
    }
  }

  buffer.writeln('}');
}

/// Convierte strings como "auth.account_locked" o "user-profile" a "authAccountLocked"
String _toLowerCamelCase(String key) {
  // Dividimos la clave por puntos, guiones bajos o medios
  final parts = key.split(RegExp(r'[._-]')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';

  final buffer = StringBuffer(parts.first.toLowerCase());
  for (var i = 1; i < parts.length; i++) {
    buffer.write(parts[i][0].toUpperCase());
    buffer.write(parts[i].substring(1).toLowerCase());
  }
  return buffer.toString();
}

List<String> _extractParams(String template) {
  final regExp = RegExp(r'%(\d+\$)?([sSdf])');
  final matches = regExp.allMatches(template).toList();
  if (matches.isEmpty) return [];

  // Mapeamos los tipos
  String mapType(String specifier) => switch (specifier.toLowerCase()) {
        'd' => 'int',
        'f' => 'double',
        _ => 'String',
      };

  // Si hay indices posicionales, ordenamos el arreglo según el índice
  if (matches.any((m) => m.group(1) != null)) {
    final orderedParams = List<String?>.filled(matches.length, null);
    for (final match in matches) {
      final (posStr, specifier) = (match.group(1), match.group(2)!);

      if (posStr != null) {
        final index = int.parse(posStr.replaceAll(r'$', '')) - 1;
        orderedParams[index] = mapType(specifier);
      }
    }
    return orderedParams.map((e) => e ?? 'String').toList();
  }

  // Si son secuenciales, los retornamos en orden
  return matches.map((m) => mapType(m.group(2)!)).toList();
}
