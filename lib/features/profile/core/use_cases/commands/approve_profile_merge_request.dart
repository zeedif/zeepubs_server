import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class ApproveProfileMergeRequestCommand implements IRequest<ProfileMergeRequest> {
  final int requestId;
  ApproveProfileMergeRequestCommand({required this.requestId});
}

// Handler
class ApproveProfileMergeRequestHandler implements IRequestHandler<ApproveProfileMergeRequestCommand, ProfileMergeRequest> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  ApproveProfileMergeRequestHandler(this._tx, this._profileRepository);

  @override
  Future<ProfileMergeRequest> handle(ApproveProfileMergeRequestCommand request) async {
    final session = locator<AppSession>();
    session.requireScope(Scope.SYSTEM_MANAGE_PROFILES);

    return _tx(() async {
      return await _profileRepository.approveMergeRequest(
        requestId: request.requestId,
        resolverAuthUserId: session.authenticated!.userId,
      );
    });
  }
}
