import 'package:uuid/uuid.dart';

import '/common/mediator/interfaces.dart';
import '/src/generated/auth.pb.dart';

import '../../repositories/auth_repo.dart';

class GetActiveSessionsQuery implements IRequest<ActiveSessionsResponse> {
  final UuidValue userId;
  final UuidValue currentTokenId;

  GetActiveSessionsQuery({required this.userId, required this.currentTokenId});
}

class GetActiveSessionsHandler implements IRequestHandler<GetActiveSessionsQuery, ActiveSessionsResponse> {
  final IAuthRepository _authRepository;

  GetActiveSessionsHandler(this._authRepository);

  @override
  Future<ActiveSessionsResponse> handle(GetActiveSessionsQuery request) {
    return _authRepository.getActiveSessions(userId: request.userId, currentTokenId: request.currentTokenId);
  }
}
