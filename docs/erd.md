### Plataforma Principal
```mermaid
erDiagram---
title: Plataforma Principal Zeepubs
---
erDiagram
    %% ======== RELACIONES PRINCIPALES ========

    %% Autenticación y Perfiles
    AUTH_USER ||..o| PUBLIC_PROFILE : "representado por"
    AUTH_USER ||--|{ USER_IDENTITY : "se autentica vía"
    AUTH_USER ||--o{ OIDC_ACCOUNT : "se federa con"
    AUTH_USER ||--o{ PASSKEY_ACCOUNT : "usa passkey"
    PUBLIC_PROFILE ||--o{ PROFILE_CONTACT_LINK : "posee"

    %% Grupos y Membresía
    PUBLIC_PROFILE }o--|| WORKGROUP : "funda"
    PUBLIC_PROFILE }o--|| WORKGROUP : "lidera"
    WORKGROUP ||--|{ GROUP_MEMBERSHIP : "contiene"
    PUBLIC_PROFILE ||--o{ GROUP_MEMBERSHIP : "es miembro vía"
    WORKGROUP ||--o{ GROUP_CONTACT_LINK : "tiene"

    %% Flujo de Trabajo
    EXTERNAL_SERIES }o--|| WORK_PROJECT : "es la base de"
    WORKGROUP ||--|{ WORK_PROJECT : "gestiona"
    WORK_PROJECT ||--|{ PROJECT_MILESTONE : "se divide en"
    PROJECT_MILESTONE ||--|{ MILESTONE_TASK : "se desglosa en"

    %% Contribuciones y Asignaciones
    PUBLIC_PROFILE }o..o| MILESTONE_TASK : "es asignado a"
    MILESTONE_TASK ||--|{ TASK_CONTRIBUTION : "acredita a"
    PUBLIC_PROFILE ||--o{ TASK_CONTRIBUTION : "contribuye en"
    CONTRIBUTION_ROLE ||--|{ TASK_CONTRIBUTION : "con el rol de"

    %% Revisiones, Lanzamientos e Interacción
    PROJECT_MILESTONE ||--o{ MILESTONE_REVIEW : "recibe"
    PUBLIC_PROFILE }o..|| MILESTONE_REVIEW : "escribe"
    PROJECT_MILESTONE ||--o{ MILESTONE_RELEASE : "genera"
    MILESTONE_RELEASE ||--|{ RELEASE_LINK : "es accesible vía"
    MILESTONE_RELEASE ||--o{ COMMENT : "recibe"
    AUTH_USER }o--|| COMMENT : "publica"
    COMMENT }o..o| COMMENT : "responde a"

    %% Notificaciones
    AUTH_USER ||..o{ NOTIFICATION : "recibe"


    %% ======== DEFINICIÓN DE ENTIDADES ========

    AUTH_USER {
        uuid id PK "ID universal del usuario"
        string username UK "NOT NULL, Inmutable, Requerido para login"
        string email UK "NULLABLE, Requerido si no hay contraseña"
        string password_hash "NULLABLE, Requerido si no hay email"
        string password_salt "NULLABLE, Requerido si no hay email"
        json scope_names "Scopes/Permisos"
        bool blocked "Si el usuario está bloqueado"
        bool is_active "NOT NULL, DEFAULT true"
        datetime email_verified_at "NULLABLE, Fecha de verificación de email"
        datetime created_at "NOT NULL"
        string _ "CONSTRAINT chk_email_or_password CHECK (email IS NOT NULL OR password_hash IS NOT NULL)"
    }

    USER_IDENTITY {
        int id PK
        uuid user_id FK "NOT NULL, Ref. a AUTH_USER"
        string provider UK "NOT NULL, Ej: 'google', 'microsoft_oidc', 'email_pass'"
        string provider_user_id "NOT NULL, ID único del usuario en el proveedor externo"
    }

    OIDC_ACCOUNT {
        int id PK
        uuid user_id FK "NOT NULL, Ref. a AUTH_USER"
        string issuer "NOT NULL, Emisor del token (ej. https://accounts.google.com)"
        string subject "NOT NULL, El 'subject' o ID de usuario único que provee el IdP"
    }

    PASSKEY_ACCOUNT {
        int id PK
        uuid user_id FK "NOT NULL, Ref. a AUTH_USER"
        bytea credential_id "ID de la credencial binario"
        string credential_id_base64 UK "ID de la credencial en base64url"
        string public_key "Clave pública en formato CborMap (JSON)"
        int sign_count "Último contador de firma verificado"
        json transports "NULLABLE, Métodos de transporte de la passkey"
        datetime created_at "NOT NULL"
    }

    PUBLIC_PROFILE {
        int id PK
        uuid user_id FK "UK, NULLABLE, Ref. a AUTH_USER 1-a-0..1"
        string nickname "NOT NULL, Mutable, no único"
        string avatar_url "NULLABLE, URL de la imagen de perfil"
        text bio "NULLABLE, Descripción corta del usuario"
    }

    PROFILE_CONTACT_LINK {
        int id PK
        int profile_id FK "NOT NULL, Ref. a PUBLIC_PROFILE"
        int next_contact_link_id FK "NULLABLE, Ref. a sí mismo para orden"
        string platform "NOT NULL, Ej: 'Discord', 'Twitter', 'Website'"
        string url "NOT NULL, Enlace al perfil de contacto"
    }

    WORKGROUP {
        int id PK
        string name UK "NOT NULL, Nombre del grupo"
        text description "NULLABLE, Descripción del grupo"
        int founder_profile_id FK "NOT NULL, Ref. a PUBLIC_PROFILE (Fundador, inmutable)"
        int leader_profile_id FK "NOT NULL, Ref. a PUBLIC_PROFILE (Líder actual, mutable)"
        datetime created_at "NOT NULL"
    }

    GROUP_CONTACT_LINK {
        int id PK
        int group_id FK "NOT NULL, Ref. a WORKGROUP"
        string platform "NOT NULL, Ej: 'Discord', 'Patreon', 'Website'"
        string url "NOT NULL, Enlace de contacto del grupo"
    }

    GROUP_MEMBERSHIP {
        int group_id PK, FK "Ref. a WORKGROUP"
        int profile_id PK, FK "Ref. a PUBLIC_PROFILE"
        datetime joined_at "NOT NULL"
        json scope_names "Permisos específicos del miembro en el grupo"
    }

    EXTERNAL_SERIES {
        int id PK "ID interno de la plataforma"
        int mangabaka_id UK "NOT NULL, ID de la API MangaBaka"
        string canonical_title "NOT NULL, Caché del título principal"
        string cover_url "NULLABLE, Caché de la URL de la portada"
        string series_type "NOT NULL, Caché del tipo (manga, novel, etc.)"
        datetime last_synced_at "NOT NULL, Para invalidación de caché"
    }

    WORK_PROJECT {
        int id PK
        int group_id FK "NOT NULL, Ref. a WORKGROUP"
        int external_series_id FK "NOT NULL, Ref. a EXTERNAL_SERIES"
        string project_type "NOT NULL, Enum: 'translation', 'scanlation', 'formatting', 'original_work'"
        string status "NOT NULL, Enum: 'planned', 'active', 'paused', 'completed', 'abandoned'"
        datetime created_at "NOT NULL"
    }

    PROJECT_MILESTONE {
        int id PK
        int project_id FK "NOT NULL, Ref. a WORK_PROJECT"
        string title "NOT NULL, Título definido por el grupo. Ej: 'Volumen 5'"
        float order_index "NOT NULL, Para ordenar hitos (1.0, 1.5, 2.0)"
        string status "NOT NULL, Enum: 'planned', 'in_progress', 'in_review', 'ready'"
        datetime deadline "NULLABLE, Fecha límite opcional"
    }

    MILESTONE_TASK {
        int id PK
        int milestone_id FK "NOT NULL, Ref. a PROJECT_MILESTONE"
        int assigned_profile_id FK "NULLABLE, Ref. a PUBLIC_PROFILE (Responsable)"
        string title "NOT NULL, Título de la tarea. Ej: 'Capítulo 32'"
        float order_index "NOT NULL, Para ordenar tareas dentro del hito"
        string status "NOT NULL, Enum: 'pending', 'in_progress', 'completed'"
        datetime claimed_at "NOT NULL, Fecha en que se asignó"
    }

    TASK_CONTRIBUTION {
        int task_id PK, FK "Ref. a MILESTONE_TASK"
        int profile_id PK, FK "Ref. a PUBLIC_PROFILE"
        int contribution_role_id PK, FK "Ref. a CONTRIBUTION_ROLE"
    }

    CONTRIBUTION_ROLE {
        int id PK
        string name UK "NOT NULL, Ej: 'Traductor', 'Editor', 'Maquetador'"
    }

    MILESTONE_REVIEW {
        int id PK
        int milestone_id FK "NOT NULL, Ref. a PROJECT_MILESTONE"
        int author_profile_id FK "NOT NULL, Ref. a PUBLIC_PROFILE (Revisor)"
        text content "NULLABLE, Notas de la revisión"
        string decision "NOT NULL, Enum: 'approved', 'corrections_needed', 'comment'"
        datetime created_at "NOT NULL"
    }

    MILESTONE_RELEASE {
        int id PK
        int milestone_id FK "NOT NULL, Ref. a PROJECT_MILESTONE"
        string version "NOT NULL, Ej: 'v1.0', 'v1.1 (Corregido)'"
        string visibility "NOT NULL, Enum: 'public', 'private', 'restricted'"
        string release_notes "NULLABLE, Notas sobre el lanzamiento (changelog)"
        datetime published_at "NOT NULL"
    }

    RELEASE_LINK {
        int id PK
        int release_id FK "NOT NULL, Ref. a MILESTONE_RELEASE"
        string platform "NOT NULL, Ej: 'LectorTMO', 'Google Drive', 'Web'"
        string url "NOT NULL, URL del lanzamiento"
        %% string type "NOT NULL, Enum: 'reader', 'download', 'info'"
    }

    COMMENT {
        int id PK
        uuid user_id FK "NOT NULL, Ref. a AUTH_USER (Autor)"
        int release_id FK "NOT NULL, Ref. a MILESTONE_RELEASE"
        int parent_comment_id FK "NULLABLE, Ref. a COMMENT (para respuestas)"
        text content "NOT NULL, Contenido del comentario"
        bool is_spoiler "NOT NULL"
        datetime created_at "NOT NULL"
        datetime updated_at "NULLABLE"
    }

    NOTIFICATION {
        int id PK
        uuid user_id FK "NOT NULL, Ref. a AUTH_USER (Receptor)"
        string type "NOT NULL, Enum: 'review_approved', 'new_comment', 'release_expired', 'release_ready'"
        text message "NOT NULL, Mensaje de la notificación"
        string target_url "NULLABLE, Enlace a la acción"
        bool is_read "NOT NULL, DEFAULT false"
        datetime created_at "NOT NULL"
    }

    EMAIL_OTP_REQUEST {
        int id PK
        string email "NOT NULL"
        string otpHash "NOT NULL"
        string otpSalt "NOT NULL"
        datetime expiresAt "NOT NULL"
    }

    PASSWORD_RESET_REQUEST {
        int id PK
        uuid userId FK "NOT NULL, Ref. a auth_user"
        string verificationCodeHash "NOT NULL"
        string verificationCodeSalt "NOT NULL"
        datetime expiresAt "NOT NULL"
    }

    EMAIL_VERIFICATION_REQUEST {
        int id PK
        uuid userId FK "NOT NULL, Ref. a auth_user"
        string verificationCodeHash "NOT NULL"
        string verificationCodeSalt "NOT NULL"
        datetime expiresAt "NOT NULL"
    }

    EMAIL_VERIFICATION_ATTEMPT {
        int id PK
        int requestId FK "NOT NULL, Ref. a email_verification_request"
        string ipAddress "NOT NULL"
        datetime attemptedAt "NOT NULL, DEFAULT CURRENT_TIMESTAMP"
    }

    PROFILE_MERGE_REQUEST {
        int id PK
        int targetProfileId FK "NOT NULL, Ref. a public_profile"
        int sourceProfileId FK "NOT NULL, Ref. a public_profile"
        uuid requesterId FK "NOT NULL, Ref. a auth_user"
        uuid resolvedById FK "NULLABLE, Ref. a auth_user"
        int status "NOT NULL, DEFAULT 0 (pending)"
        datetime createdAt "NOT NULL, DEFAULT CURRENT_TIMESTAMP"
        datetime resolvedAt "NULLABLE"
    }

    JWT_REFRESH_TOKEN {
      uuid id PK
      uuid userId FK
      json scopeNames
      text extraClaims
      text method
      bytea fixedSecret
      bytea rotatingSecretHash
      bytea rotatingSecretSalt
      datetime lastUpdatedAt
      datetime createdAt
    }

    AUTH_SESSION {
      uuid id PK
      uuid userId FK
      json scopeNames
      datetime createdAt
      datetime lastUsedAt
      datetime expiresAt
      bigint expireAfterUnusedFor
      bytea sessionKeyHash
      bytea sessionKeySalt
      text method
    }
```

### Lista de Permisos del Sistema

Aquí tienes una lista exhaustiva y categorizada de los permisos que se pueden derivar de la lógica de negocio descrita. La columna `category` en la tabla `PERMISSION` contendría estos agrupadores.

#### Categoría: `system` (Permisos Globales de Administración)
*   **`system.manage_users`**: Permite suspender, reactivar y editar las cuentas de `USER`.
*   **`system.manage_profiles`**: Permite editar cualquier `PUBLIC_PROFILE` y fusionar perfiles con identidades.
*   **`system.assign_permissions`**: Permite asignar cualquier permiso (incluidos los de `system`) a otros usuarios.
*   **`system.manage_workgroups`**: Permite editar, eliminar y gestionar cualquier `WORKGROUP` en la plataforma, incluyendo la reasignación del fundador y del líder.

#### Categoría: `workgroup` (Gestión de Grupos de Trabajo)
Permisos que se asignan a miembros dentro de un grupo específico para gestionarlo.

*   **`workgroup.create`**: Permite a un usuario crear un nuevo `WORKGROUP`, convirtiéndose en su fundador y líder inicial.
*   **`workgroup.edit_details`**: Permite editar el nombre, la descripción y los enlaces de contacto del grupo.
*   **`workgroup.assign_permissions`**: Permite asignar y revocar permisos de categorías como project, milestone, task, etc., a los miembros del grupo.
*   **`workgroup.invite_members`**: Permite invitar nuevos perfiles a unirse al grupo.
*   **`workgroup.remove_members`**: Permite expulsar a miembros del grupo.
*   **`workgroup.delete`**: Permite eliminar el grupo de trabajo de forma permanente.

#### Categoría: `project` (Gestión de Proyectos)
Permisos para la gestión de los proyectos de un grupo.

*   **`project.create`**: Crear un nuevo `WORK_PROJECT` dentro del grupo.
*   **`project.edit`**: Editar los detalles (tipo, estado) de un proyecto del grupo.
*   **`project.delete`**: Eliminar un proyecto del grupo.

#### Categoría: `milestone` (Gestión de Hitos / Entregables)
Permisos para planificar y gestionar las unidades de trabajo del grupo.

*   **`milestone.create`**: Permite definir un nuevo hito (ej. "Volumen 2") dentro de un proyecto.
*   **`milestone.edit`**: Permite editar el título o los capítulos que componen un hito planificado.
*   **`milestone.delete`**: Permite eliminar un hito planificado.
*   **`milestone.submit_for_review`**: Permite enviar un hito completado al proceso de revisión.

#### Categoría: `task` (Gestión de Tareas Individuales)
Permisos granulares sobre los `MILESTONE_TASK`, el checklist interno.

*   **`task.claim`**: Permite a un miembro auto-asignarse una tarea (capítulo) de un hito.
*   **`task.assign`**: Permite asignar una tarea a otro miembro del grupo.
*   **`task.update_status`**: Permite marcar una tarea como 'Completada'.
*   **`task.manage_contributions`**: Permite añadir o quitar créditos de colaboradores a una tarea específica.

#### Categoría: `review` (Revisión y Aprobación de Hitos)
Permisos para el control de calidad sobre los hitos.

*   **`review.milestone_approve`**: Permite aprobar un hito que está "En Revisión", dejándolo listo para su publicación.
*   **`review.milestone_reject`**: Permite devolver un hito a "En Progreso", adjuntando notas de corrección.

#### Categoría: `release` (Publicación de Hitos)
Permisos para gestionar la visibilidad de los hitos finalizados.

*   **`release.milestone_public`**: Permite crear un `MILESTONE_RELEASE` de tipo "Público".
*   **`release.milestone_private`**: Permite crear un `MILESTONE_RELEASE` de tipo "Privado" (ej. Patreon).
*   **`release.milestone_manage`**: Permite editar o eliminar lanzamientos existentes de un hito.

#### Categoría: `notification` (Suscripciones a Notificaciones)
Permisos que determinan qué tipo de notificaciones automáticas recibe un usuario.

*   **`notification.review_pending`**: Recibe notificaciones cuando un hito es enviado a revisión en sus grupos.
*   **`notification.release_expired`**: Recibe notificaciones cuando un lanzamiento privado de su grupo ha alcanzado su fecha de publicación.
*   **`notification.release_ready`**: Recibe notificaciones cuando un hito en su grupo es aprobado y está listo para publicarse.

#### Categoría: `comment` (Interacción Pública)
Permisos relacionados con los comentarios en las páginas de los hitos publicados.

*   **`comment.create`**: Permite escribir comentarios públicos en cualquier hito publicado.
*   **`comment.edit_own`**: Permite editar los propios comentarios.
*   **`comment.delete_own`**: Permite eliminar los propios comentarios.
*   **`comment.delete_any`**: Permite moderar y eliminar comentarios de cualquier usuario en los proyectos del grupo.
