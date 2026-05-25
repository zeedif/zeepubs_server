import 'package:uuid/uuid.dart';

import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class ForcePasswordChangeCommand implements IRequest<void> {
  final UuidValue authUserId;
  final String newPassword;

  ForcePasswordChangeCommand({
    required this.authUserId,
    required this.newPassword,
  });
}

// Handler
class ForcePasswordChangeHandler implements IRequestHandler<ForcePasswordChangeCommand, void> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  ForcePasswordChangeHandler(this._tx, this._authRepository);

  @override
  Future<void> handle(ForcePasswordChangeCommand request) async {
    final session = locator<AppSession>();
    session.requireScope(Scope.SYSTEM_MANAGE_USERS);

    return _tx(() async {
      await _authRepository.forcePasswordChange(
        authUserId: request.authUserId,
        newPassword: request.newPassword,
      );
    });
  }
}
