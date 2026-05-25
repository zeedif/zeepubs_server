import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/common/session/permission_validator.dart';
import '/src/generated/auth.pb.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Query
class GetProfileMergeRequestsQuery implements IRequest<List<ProfileMergeRequest>> {
  final ProfileMergeRequestStatus? status;
  GetProfileMergeRequestsQuery({this.status});
}

// Handler
class GetProfileMergeRequestsHandler
    implements IRequestHandler<GetProfileMergeRequestsQuery, List<ProfileMergeRequest>> {
  final IProfileRepository _profileRepository;
  GetProfileMergeRequestsHandler(this._profileRepository);

  @override
  Future<List<ProfileMergeRequest>> handle(GetProfileMergeRequestsQuery request) async {
    final session = locator<AppSession>();
    session.requireScope(Scope.SYSTEM_MANAGE_PROFILES);

    return await _profileRepository.getMergeRequestsByStatus(status: request.status);
  }
}
