import '/common/database/transactional.dart';
import '/common/di/service_locator.dart';
import '/common/mediator/interfaces.dart';
import '/common/session/app_session.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Command
class CreateProfileMergeRequestCommand implements IRequest<ProfileMergeRequest> {
  final int targetProfileId;

  CreateProfileMergeRequestCommand({
    required this.targetProfileId,
  });
}

// Handler
class CreateProfileMergeRequestHandler implements IRequestHandler<CreateProfileMergeRequestCommand, ProfileMergeRequest> {
  final IProfileRepository _profileRepository;
  final Transactional _tx;

  CreateProfileMergeRequestHandler(this._tx, this._profileRepository);

  @override
  Future<ProfileMergeRequest> handle(CreateProfileMergeRequestCommand request) async {
    final session = locator<AppSession>();

    return _tx(() async {
      return await _profileRepository.createMergeRequest(
        targetProfileId: request.targetProfileId,
        requesterAuthUserId: session.authenticated!.userId,
      );
    });
  }
}
