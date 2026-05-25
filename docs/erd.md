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

---

### Descripción y Flujos de Trabajo de la Plataforma

**ZeePubs** está diseñado como un ecosistema colaborativo centrado en la creación, gestión y publicación de trabajos derivados (traducciones, limpiezas, colorizaciones, maquetaciones a formato EPUB, etc.) basados en obras o series ya existentes.

**1. Usuarios, Perfiles y Grupos**
Todo usuario en la plataforma posee un perfil público personalizable, al cual puede asociar enlaces de contacto o redes sociales. Los usuarios pueden agruparse creando o uniéndose a **Grupos de Trabajo**. En lugar de utilizar un sistema rígido de "Roles" predefinidos en la base de datos, la plataforma confía en la asignación directa de permisos (*Scopes*) a los miembros del grupo. Esto permite a cada equipo organizar su jerarquía de forma orgánica y flexible, evitando la complejidad de mantener entidades de roles separadas.

**2. Proyectos y Trabajos Derivados**
Los grupos no reclaman la autoría de una obra original completa, sino que registran "Proyectos" basados en ellas. Por ejemplo, un grupo puede crear un proyecto para la "Traducción del Volumen 5 de una novela serializada". El enfoque recae enteramente en lo que el grupo ha producido. De esta manera, el catálogo global permite a cualquier visitante consultar una serie externa y descubrir todos los trabajos derivados que distintos grupos han aportado a esa misma obra.

**3. Tareas y Créditos**
Cada hito o entregable (*Milestone*) se divide en tareas internas (ej. traducir el capítulo 1, limpiar imágenes, corregir estilo). El sistema permite asignar estas tareas a los miembros y, lo que es más importante, otorgar **créditos detallados** (*Contributions*) a cada persona involucrada según el rol que desempeñó (Traductor, Editor, Maquetador), asegurando el reconocimiento adecuado del esfuerzo colectivo.

**4. Ciclo de Vida y Revisiones Internas**
El trabajo interno de un grupo pasa por un flujo de estados claramente definido:
*   **Planificado / Sin empezar:** El hito existe pero no se ha trabajado.
*   **En Progreso:** Las tareas internas se están completando.
*   **En Revisión:** El trabajo está terminado y se somete al control de calidad del grupo.
*   **Aprobado / Listo:** El trabajo ha superado la revisión.
*   **Requiere Correcciones:** Se detectaron errores durante la revisión que deben subsanarse.

**5. Visibilidad, Lanzamientos y Enlaces**
Una vez que un hito es aprobado, se genera un Lanzamiento (*Release*). La visibilidad de un lanzamiento es de estado único y excluyente (ej. *Público*, *Privado*, *Restringido a Patreon*); si es público, no puede ser privado simultáneamente. De forma independiente a su estado de visibilidad, un lanzamiento puede tener múltiples enlaces asociados (*Release Links*) que indican dónde se aloja o consume el recurso final (un enlace a Google Drive, a un lector online, etc.).

**6. Interacción Pública y Bucle de Retroalimentación**
Cuando un lanzamiento adquiere estado Público, aparece en el catálogo global de ZeePubs. A partir de este momento, usuarios ajenos al grupo pueden interactuar mediante un sistema de **Comentarios**. 
Si los lectores encuentran errores (ej. *typos*, páginas faltantes), lo reportan a través de estos comentarios. Para mantener la simplicidad de la máquina de estados, un reporte público *no cambia* el estado del lanzamiento automáticamente. En su lugar, un miembro del grupo con los permisos adecuados lee los comentarios y, si lo considera válido, abre una **Revisión Interna** para notificar al equipo exactamente qué debe corregirse. El lanzamiento pasa a un estado de "Publicado pero requiere correcciones", cerrando el bucle de retroalimentación de forma ordenada.

**7. Sistema de Notificaciones**
La plataforma cuenta con un motor de eventos que notifica a los usuarios en momentos clave: cuando se les asigna una tarea, cuando un hito en el que participaron es enviado a revisión, cuando se aprueba, cuando recibe comentarios públicos, o cuando un lanzamiento programado (ej. acceso anticipado en Patreon) cambia su estado o alcanza su fecha de expiración.

---

### Lista de Permisos del Sistema (Scopes)

#### Categoría: Permisos Globales de Administración (`system`)
Estos permisos se otorgan a nivel de cuenta (`AUTH_USER`) e impactan en toda la plataforma.

*   **`SYSTEM_ADMIN`**: Acceso total e irrestricto a la plataforma.
    *   `bypass_all_checks`: Omitir cualquier validación de permisos en toda la plataforma.
    *   `prevent_self_lockout`: Evitar la remoción de este propio permiso si el usuario es el último administrador activo en la base de datos.

*   **`SYSTEM_MANAGE_USERS`**: Gestión de cuentas y seguridad.
    *   `block_user`: Bloquear permanentemente el acceso a una cuenta de usuario.
    *   `unblock_user`: Restaurar el acceso a una cuenta de usuario previamente bloqueada.
    *   `suspend_user`: Aplicar un bloqueo temporal a una cuenta de usuario.
    *   `force_password_change`: Cambiar la contraseña de un usuario de manera forzada.
    *   `update_user_email`: Modificar el correo electrónico asociado a la cuenta de otro usuario.
    *   `view_user_details`: Consultar información interna de la cuenta, como estado de verificación o intentos fallidos de inicio de sesión.

*   **`SYSTEM_MANAGE_PROFILES`**: Moderación de identidades públicas.
    *   `edit_profile_nickname`: Modificar el apodo (nickname) de cualquier perfil público.
    *   `edit_profile_bio`: Alterar o censurar la biografía de cualquier perfil.
    *   `remove_profile_avatar`: Eliminar la imagen de avatar actual de cualquier perfil.
    *   `manage_ghost_profiles`: Administrar perfiles "fantasma" que aún no tienen una cuenta de usuario vinculada.
    *   `approve_merge_request`: Aprobar una solicitud para fusionar la historia de dos perfiles distintos.
    *   `reject_merge_request`: Denegar una solicitud de fusión de perfiles.

*   **`SYSTEM_MANAGE_WORKGROUPS`**: Intervención global en grupos.
    *   `edit_group_name`: Modificar el nombre de cualquier grupo en la plataforma.
    *   `edit_group_description`: Modificar la descripción de cualquier grupo.
    *   `transfer_founder`: Reasignar forzosamente quién es el miembro fundador de un grupo.
    *   `transfer_leader`: Reasignar forzosamente quién es el líder actual de un grupo.
    *   `delete_group`: Eliminar por completo un grupo de trabajo y todos sus datos asociados de la plataforma.

#### Categoría: Permisos de Grupo de Trabajo (`group`)
Estos permisos se otorgan a nivel de la tabla `GROUP_MEMBERSHIP` (el contexto interno de un grupo). Un usuario asume estos poderes *solo* dentro de los proyectos y miembros de ese grupo específico.

*   **`GROUP_MANAGE_MEMBERS`**: Administración del personal del grupo.
    *   `edit_details`: Cambiar el nombre y la descripción del grupo de trabajo.
    *   `add_contact_link`: Agregar nuevos enlaces sociales o de contacto al perfil del grupo.
    *   `edit_contact_link`: Modificar los enlaces de contacto existentes del grupo.
    *   `remove_contact_link`: Eliminar enlaces de contacto del grupo.
    *   `invite_member`: Enviar invitaciones a nuevos usuarios para que se unan al grupo.
    *   `remove_member`: Expulsar a un miembro actual del grupo.
    *   `assign_permission`: Otorgar permisos locales (cualquier `GROUP_*`) a otros miembros del equipo.
    *   `revoke_permission`: Quitar permisos locales a otros miembros del equipo.

*   **`GROUP_MANAGE_PROJECTS`**: Gestión estructural del flujo de trabajo y publicaciones.
    *   `create_project`: Iniciar un nuevo proyecto derivado (ej. comenzar a traducir una nueva novela).
    *   `edit_project`: Modificar el tipo o el estado general de un proyecto existente.
    *   `delete_project`: Eliminar un proyecto completo del grupo.
    *   `create_milestone`: Planificar un nuevo hito o entregable (ej. "Volumen 1", "Capítulo 20") dentro del proyecto.
    *   `edit_milestone`: Cambiar el título, el orden lógico o la fecha límite de un hito.
    *   `delete_milestone`: Eliminar un hito planificado.
    *   `publish_public_release`: Generar un lanzamiento cambiando la visibilidad de un hito a público en el catálogo.
    *   `publish_private_release`: Generar un lanzamiento con visibilidad restringida (ej. acceso anticipado para Patreon).
    *   `edit_release_notes`: Modificar las notas de publicación (changelog) de un lanzamiento existente.
    *   `add_release_link`: Agregar enlaces donde los lectores pueden consumir o descargar el lanzamiento.
    *   `edit_release_link`: Modificar una URL de un enlace de lanzamiento existente.
    *   `remove_release_link`: Eliminar un enlace de lectura o descarga de un lanzamiento.

*   **`GROUP_MANAGE_TASKS`**: Organización del esfuerzo diario.
    *   `create_task`: Añadir nuevas tareas al checklist interno de un hito.
    *   `edit_task`: Cambiar el nombre o el orden de una tarea en el checklist.
    *   `delete_task`: Eliminar una tarea del checklist.
    *   `claim_task`: Auto-asignarse una tarea que se encuentre disponible.
    *   `assign_task`: Asignar una tarea específica a otro miembro del grupo.
    *   `unassign_task`: Retirar a un miembro de una tarea que tenía asignada.
    *   `update_task_progress`: Cambiar el estado de una tarea a "En progreso".
    *   `complete_task`: Cambiar el estado de una tarea a "Completada".
    *   `add_contribution`: Registrar el crédito de un miembro especificando el rol que cumplió en una tarea (ej. Traductor, Limpiador).
    *   `remove_contribution`: Retirar un crédito de contribución otorgado en una tarea.

*   **`GROUP_MANAGE_REVIEWS`**: Control de calidad (QC) interno.
    *   `submit_for_review`: Tomar un hito con tareas completadas y pasarlo a la fase de control de calidad.
    *   `approve_milestone`: Aprobar un hito que estaba en revisión, marcándolo oficialmente como listo para ser publicado.
    *   `reject_milestone`: Rechazar un hito en revisión, devolviendo su estado a "En progreso".
    *   `add_review_notes`: Escribir y adjuntar las notas detallando qué correcciones son necesarias en un hito rechazado.

*   **`GROUP_MANAGE_COMMENTS`**: Moderación comunitaria.
    *   `delete_external_comment`: Eliminar comentarios o reportes dejados por usuarios externos en las páginas públicas de los lanzamientos del grupo.
    *   `hide_spoiler_comment`: Forzar a que un comentario externo quede oculto bajo una advertencia de spoiler.
    *   *(Nota general: Las acciones `create_own_comment`, `edit_own_comment` y `delete_own_comment` son implícitas y están disponibles para cualquier usuario autenticado en el sistema).*