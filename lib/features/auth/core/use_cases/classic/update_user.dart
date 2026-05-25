import 'package:uuid/uuid.dart';

import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class UpdateUserCommand implements IRequest<void> {
  final UuidValue targetUserId;
  final String username;
  final String? email;
  final Set<Scope> scopes;
  final bool blocked;
  final bool isActive;

  UpdateUserCommand({
    required this.targetUserId,
    required this.username,
    this.email,
    required this.scopes,
    required this.blocked,
    required this.isActive,
  });
}

// Handler
class UpdateUserHandler implements IRequestHandler<UpdateUserCommand, void> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  UpdateUserHandler(this._tx, this._authRepository);

  @override
  Future<void> handle(UpdateUserCommand request) {
    final session = locator<AppSession>();
    session.requireScope(Scope.SYSTEM_MANAGE_USERS);

    return _tx(() async {
      await _authRepository.updateUser(request: request);
    });
  }
}
