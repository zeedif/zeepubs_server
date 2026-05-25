import 'log_level.dart';

class SessionLogManager {
  final List<String> _logs = [];

  void log(String message, {LogLevel level = LogLevel.info}) {
    // Aquí puedes imprimir a consola, o guardar en memoria para
    // insertarlos en la base de datos al finalizar la sesión.
    final logEntry = '[${DateTime.now().toUtc().toIso8601String()}] [${level.name.toUpperCase()}] $message';
    _logs.add(logEntry);
    print(logEntry); // Opcional: imprimir en consola/terminal
  }

  Future<void> finalizeLogs({required Duration duration, dynamic error}) async {
    // Igual que Serverpod: Al cerrar la sesión, este método decide
    // si guarda los logs en la DB dependiendo del tiempo que tardó (slow session)
    // o si hubo errores.
    if (error != null) {
      log('Sesión finalizada con error: $error', level: LogLevel.error);
    }

    // Serverpod clasifica las sesiones lentas. Si tarda más de 1 segundo (1000ms), es "slow"
    final isSlow = duration.inMilliseconds > 1000;
    final level = isSlow ? LogLevel.warning : LogLevel.debug;

    log('Sesión finalizada en ${duration.inMilliseconds} ms', level: level);

    // TODO: Operaciones de escritura en DB o fichero de logs.
  }
}
