import '/common/mediator/interfaces.dart';
import '/src/generated/profile.pb.dart';

import '../../repositories/profile_repo.dart';

// Query
class GetProfilesQuery implements IRequest<PaginatedProfilesData> {
  final int pageSize;
  final String? cursor;
  final String? searchQuery;

  GetProfilesQuery({required this.pageSize, this.cursor, this.searchQuery});
}

// Handler
class GetProfilesHandler implements IRequestHandler<GetProfilesQuery, PaginatedProfilesData> {
  final IProfileRepository _profileRepository;
  GetProfilesHandler(this._profileRepository);

  @override
  Future<PaginatedProfilesData> handle(GetProfilesQuery request) async {
    return await _profileRepository.getProfiles(
      pageSize: request.pageSize,
      cursor: request.cursor,
      searchQuery: request.searchQuery,
    );
  }
}
