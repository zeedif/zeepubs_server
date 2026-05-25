import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

import '/common/di/service_locator.dart';
import '/common/localization/localizer.dart';
import '/common/mediator/mediator.dart';
import '/common/session/app_session.dart';
import '/common/utils/request_scope.dart';
import '/src/generated/profile.pbgrpc.dart';

import '../core/exceptions/profile_exceptions.dart';
import '../core/use_cases/commands/add_profile_contact_link.dart';
import '../core/use_cases/commands/approve_profile_merge_request.dart';
import '../core/use_cases/commands/create_profile_merge_request.dart';
import '../core/use_cases/commands/reject_profile_merge_request.dart';
import '../core/use_cases/commands/remove_profile_contact_link.dart';
import '../core/use_cases/commands/reorder_profile_contact_links.dart';
import '../core/use_cases/commands/update_profile.dart';
import '../core/use_cases/commands/update_profile_contact_link.dart';
import '../core/use_cases/queries/get_profile_id.dart';
import '../core/use_cases/queries/get_profile_merge_requests.dart';
import '../core/use_cases/queries/get_profile_uuid.dart';
import '../core/use_cases/queries/get_profiles.dart';

class ProfileServiceImpl extends ProfileServiceBase {
  /// Mapea excepciones de negocio a errores gRPC.
  GrpcError _mapExceptionToGrpcError(Object e, StackTrace? stack) {
    String locale = 'en';
    try {
      if (locator.isRegistered<AppSession>()) {
        locale = locator<AppSession>().locale;
      }
    } catch (_) {}

    switch (e) {
      case UserProfileNotFoundException():
        return GrpcError.notFound(L10n.strings.profileNotFound(locale));

      case ContactLinkNotFoundException():
        return GrpcError.notFound(L10n.strings.profileContactLinkNotFound(locale));

      case ProfileAccessDeniedException():
        return GrpcError.permissionDenied(L10n.strings.profileAccessDenied(locale));

      case InvalidMergeRequestException():
        return GrpcError.failedPrecondition(L10n.strings.profileInvalidMergeRequest(locale));
      case UnimplementedError(:final message):
        return GrpcError.unimplemented(message ?? 'Unimplemented operation.');
      case UnsupportedError(:final message):
        return GrpcError.unimplemented(message ?? 'Unsupported operation.');
      case ArgumentError(:final message):
        return GrpcError.invalidArgument(message?.toString() ?? 'Invalid argument.');
      case StateError(:final message):
        return GrpcError.failedPrecondition(message);
      default:
        print('🚨 [Unhandled Error in Profile gRPC]: $e\n$stack');
        return GrpcError.internal(L10n.strings.commonGenericInternalError(locale));
    }
  }

  // =========================================================================
  // --- GESTIÓN DE PERFILES PÚBLICOS ---
  // =========================================================================

  @override
  Future<PublicProfile> getProfile(ServiceCall call, GetProfileRequest request) async {
    return withRequestScope(call, () async {
      try {
        final profileId = request.hasProfileId() ? request.profileId : null;

        if (profileId == null) {
          // Si no se especifica ID, intentamos devolver el perfil del usuario autenticado
          final session = locator<AppSession>();
          if (!session.isAuthenticated) {
            throw GrpcError.unauthenticated('Sesión requerida para obtener el perfil propio.');
          }
          final query = GetProfileByUuidQuery(authUserId: session.authenticated!.userId);
          return await locator<Mediator>().send(query);
        } else {
          // Obtenemos un perfil específico por su ID numérico
          final query = GetProfileByIdQuery(profileId: profileId);
          return await locator<Mediator>().send(query);
        }
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<PublicProfile> getProfileByUuid(ServiceCall call, GetProfileByUuidRequest request) async {
    return withRequestScope(call, () async {
      try {
        final query = GetProfileByUuidQuery(authUserId: UuidValue.fromString(request.userId));
        return await locator<Mediator>().send(query);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<PublicProfile> updateProfile(ServiceCall call, UpdateProfileRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = UpdateProfileCommand(
          profileId: request.profileId,
          nickname: request.hasNickname() ? request.nickname : null,
          avatarUrl: request.hasAvatarUrl() ? request.avatarUrl : null,
          bio: request.hasBio() ? request.bio : null,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<PaginatedProfilesData> getProfiles(ServiceCall call, GetProfilesRequest request) async {
    return withRequestScope(call, () async {
      try {
        final query = GetProfilesQuery(
          pageSize: request.pageSize > 0 ? request.pageSize : 20, // Default pageSize
          cursor: request.hasCursor() ? request.cursor : null,
          searchQuery: request.hasSearchQuery() ? request.searchQuery : null,
        );
        return await locator<Mediator>().send(query);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  // =========================================================================
  // --- ENLACES DE CONTACTO ---
  // =========================================================================

  @override
  Future<ProfileContactLink> addContactLink(ServiceCall call, AddContactLinkRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = AddProfileContactLinkCommand(
          profileId: request.profileId,
          platform: request.platform,
          url: request.url,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> removeContactLink(ServiceCall call, RemoveContactLinkRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = RemoveProfileContactLinkCommand(contactLinkId: request.contactLinkId);
        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<ProfileContactLink> updateContactLink(ServiceCall call, UpdateContactLinkRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = UpdateProfileContactLinkCommand(
          contactLinkId: request.contactLinkId,
          platform: request.hasPlatform() ? request.platform : null,
          url: request.hasUrl() ? request.url : null,
        );
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<EmptyResponse> reorderContactLink(ServiceCall call, ReorderContactLinkRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = ReorderProfileContactLinksCommand(
          contactLinkId: request.contactLinkId,
          newIndex: request.newIndex,
        );
        await locator<Mediator>().send(command);
        return EmptyResponse();
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  // =========================================================================
  // --- FUSIÓN DE IDENTIDADES (MERGE REQUESTS) ---
  // =========================================================================

  @override
  Future<ProfileMergeRequest> createMergeRequest(ServiceCall call, CreateMergeRequestRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = CreateProfileMergeRequestCommand(targetProfileId: request.targetProfileId);
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<GetMergeRequestsResponse> getMergeRequests(ServiceCall call, GetMergeRequestsRequest request) async {
    return withRequestScope(call, () async {
      try {
        final query = GetProfileMergeRequestsQuery(
          status: request.hasStatus() ? request.status : null,
        );
        final list = await locator<Mediator>().send(query);
        return GetMergeRequestsResponse(requests: list);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<ProfileMergeRequest> approveMergeRequest(ServiceCall call, MergeDecisionRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = ApproveProfileMergeRequestCommand(requestId: request.requestId);
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }

  @override
  Future<ProfileMergeRequest> rejectMergeRequest(ServiceCall call, MergeDecisionRequest request) async {
    return withRequestScope(call, () async {
      try {
        final command = RejectProfileMergeRequestCommand(requestId: request.requestId);
        return await locator<Mediator>().send(command);
      } catch (e, stack) {
        throw _mapExceptionToGrpcError(e, stack);
      }
    });
  }
}
