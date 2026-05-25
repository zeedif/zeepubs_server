import 'database.dart';
import 'transactional.dart';

class DriftTx implements Transactional {
  final AppDatabase _db;

  DriftTx(this._db);

  @override
  Future<T> call<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }
}
