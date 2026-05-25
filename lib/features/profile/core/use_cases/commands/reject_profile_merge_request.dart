import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class RejectProfileMergeRequestCommand implements IRequest<ProfileMergeRequest> {
  final int requestId;
  RejectProfileMergeRequestCommand({required this.requestId});
}

// Handler
class RejectProfileMergeRequestHandler implements IRequestHandler<RejectProfileMergeRequestCommand, ProfileMergeRequest> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  RejectProfileMergeRequestHandler(this._tx, this._profileRepository);

  @override
  Future<ProfileMergeRequest> handle(RejectProfileMergeRequestCommand request) async {
    final session = locator<AppSession>();
    session.requireScope(Scope.SYSTEM_MANAGE_PROFILES);

    return _tx(() async {
      return await _profileRepository.rejectMergeRequest(
        requestId: request.requestId,
        resolverAuthUserId: session.authenticated!.userId,
      );
    });
  }
}
