/// Contrato para ejecutar operaciones dentro de una transacción.
abstract class Transactional {
  Future<T> call<T>(Future<T> Function() action);
}
