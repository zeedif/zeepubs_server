import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

// Command
class CreateUserCommand implements IRequest<CreateUserResponse> {
  final String username;
  final String? email;
  final String? password;

  CreateUserCommand({
    required this.username,
    this.email,
    this.password,
  });
}

// Handler
class CreateUserHandler implements IRequestHandler<CreateUserCommand, CreateUserResponse> {
  final IAuthRepository _authRepository;
  final Transactional _tx;

  CreateUserHandler(this._tx, this._authRepository);

  @override
  Future<CreateUserResponse> handle(CreateUserCommand request) {
    final session = locator<AppSession>();
    session.requireScope(Scope.SYSTEM_MANAGE_USERS); 

    return _tx(() async {
      return await _authRepository.createUser(request: request);
    });
  }
}
