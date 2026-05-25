# ZeePubs Server

ZeePubs Server es un backend modular de alto rendimiento desarrollado en Dart. Utiliza gRPC como protocolo de comunicación principal y Drift con PostgreSQL para la persistencia de datos. El sistema implementa una arquitectura desacoplada basada en el patrón Mediator e inyección de dependencias.

## Arquitectura del Proyecto

El servidor sigue un diseño orientado a características (*features*), donde cada módulo encapsula su propia lógica para garantizar la mantenibilidad y escalabilidad:

```text
lib/
├── common/              # Infraestructura transversal (DI, DB, utilidades globales)
└── features/            # Módulos funcionales del sistema
    └── [feature_name]/
        ├── core/        # Reglas de negocio: Casos de uso, excepciones e interfaces
        ├── data/        # Implementación de datos: Repositorios, tablas y adaptadores
        └── presentation/# Capa de transporte: Servicios gRPC y controladores REST
```

### Capas de Dominio
*   **Core:** Contiene la lógica pura de negocio. Es independiente de frameworks y bases de datos. Define los contratos de los repositorios y los casos de uso (*Commands/Queries*).
*   **Data:** Implementa las interfaces definidas en la capa Core. Gestiona el acceso a la base de datos PostgreSQL y adaptadores de librerías externas.
*   **Presentation:** Expone los servicios mediante contratos gRPC y puntos de enlace HTTP/REST para callbacks de autenticación externa.

---

## Requisitos Previos

Para ejecutar y desarrollar en este proyecto, se requiere:

1.  **Dart SDK:** Versión `^3.8.0` o superior. [Instrucciones de instalación](https://dart.dev/get-dart).
2.  **Protocol Buffers (protoc):** Compilador oficial para procesar archivos `.proto`. [Descargas de Protobuf](https://github.com/protocolbuffers/protobuf/releases).
3.  **Plugin de Dart para protoc:** Requerido para generar el código gRPC. Instálelo ejecutando:
    ```bash
    dart pub global activate protoc_plugin
    ```
    *Asegúrese de incluir el directorio de binarios de pub en su variable de entorno PATH.*

---

## Instalación y Configuración

### 1. Clonar el repositorio y obtener dependencias
```bash
git clone https://github.com/tu-usuario/zeepubs_server.git
cd zeepubs_server
dart pub get
```

### 2. Generación de Código
El proyecto depende de la generación automática de código para gRPC, la base de datos y la localización.

**A. Contratos gRPC:**
```bash
protoc --dart_out=grpc:lib/src/generated -Iprotos protos/auth.proto protos/profile.proto
```

**B. Persistencia (Drift):**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**C. Localización (L10n):**
```bash
dart run bin/generate_l10n.dart
```

### 3. Configuración del Entorno
Cree un archivo `app_config.yaml` en la raíz del proyecto basado en el siguiente esquema:

```yaml
jwt:
  issuer: 'zeepubs.com'
  algorithm: 'HS512'
  secretKey: 'su_clave_secreta_aqui'
  accessTokenMinutes: 15

session:
  secretLength: 32
  hashPepper: 'pepper_de_sesion'
  lifetimeDays: 30
  inactivityDays: 7

refreshToken:
  fixedSecretLength: 16
  rotatingSecretLength: 64
  hashPepper: 'pepper_de_refresh_token'
  lifetimeDays: 14

security:
  passwordHashPepper: 'pepper_de_contraseña'
  emailOtpHashPepper: 'pepper_de_otp'
  passwordResetHashPepper: 'pepper_de_reseteo'
  emailVerificationHashPepper: 'PEPPER_PARA_VERIFICAR_CORREOS'
```

---

## Ejecución

Para iniciar el servidor, ejecute el siguiente comando:

```bash
dart run bin/server.dart
```

*   **Puerto gRPC:** `8080` (Comunicación principal)
*   **Puerto HTTP:** `8081` (OIDC y Webhooks)

---

## Pruebas

Para ejecutar el conjunto de pruebas unitarias y de integración:

```bash
dart test
```

## Licencia

Este proyecto está bajo la licencia **GNU General Public License v3.0**. Consulte el archivo `LICENSE` para más detalles.
