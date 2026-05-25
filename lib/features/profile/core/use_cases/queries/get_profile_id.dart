import '/common/mediator/interfaces.dart';
import '/src/generated/profile.pb.dart';

import '../../exceptions/profile_exceptions.dart';
import '../../repositories/profile_repo.dart';

// Query
class GetProfileByIdQuery implements IRequest<PublicProfile> {
  final int profileId;
  GetProfileByIdQuery({required this.profileId});
}

// Handler
class GetProfileByIdHandler implements IRequestHandler<GetProfileByIdQuery, PublicProfile> {
  final IProfileRepository _profileRepository;
  GetProfileByIdHandler(this._profileRepository);

  @override
  Future<PublicProfile> handle(GetProfileByIdQuery request) async {
    final profile = await _profileRepository.getProfileById(profileId: request.profileId);
    if (profile == null) throw const UserProfileNotFoundException();
    return profile;
  }
}
