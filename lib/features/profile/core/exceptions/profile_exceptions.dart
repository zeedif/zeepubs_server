// --- Excepciones del Dominio de Perfil (Profiles) ---

class UserProfileNotFoundException implements Exception {
  const UserProfileNotFoundException();
}

class ContactLinkNotFoundException implements Exception {
  const ContactLinkNotFoundException();
}

class ProfileAccessDeniedException implements Exception {
  const ProfileAccessDeniedException();
}

class InvalidMergeRequestException implements Exception {
  const InvalidMergeRequestException();
}
