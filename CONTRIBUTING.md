# Contribuir a ZeePubs Server

Agradecemos tu interés en colaborar con el desarrollo de **ZeePubs Server**. Para mantener la base de código limpia, mantenible y consistente, te pedimos que sigas las siguientes directrices antes de enviar tus aportaciones.

---

## 🛠️ Estructura y Reglas Arquitectónicas

Este proyecto está diseñado para ser altamente modular. Cada funcionalidad debe encapsularse en su respectiva característica (*feature*) dentro del directorio `lib/features/`.

Al agregar código, asegúrate de colocarlo en la capa adecuada:

### 1. Capa Core (Dominio)
*   **Qué contiene:** Casos de uso (*Commands*, *Queries*, *Handlers*), entidades del dominio, excepciones y contratos abstractos de los repositorios.
*   **Restricción:** No debe importar bibliotecas externas de persistencia, servidores web, gRPC ni utilidades de bajo nivel. Es la capa más interna y protegida.

### 2. Capa Data (Infraestructura de Datos)
*   **Qué contiene:** Definición de tablas de Drift, implementaciones concretas de las interfaces de los repositorios de `core`, llamadas directas a base de datos y envoltorios de utilidades externas que sean de uso exclusivo para esta característica.
*   **Restricción:** Debe implementar los contratos de `core` y depender solo de ellos y de los sistemas de almacenamiento del servidor.

### 3. Capa Presentation (Presentación)
*   **Qué contiene:** Clases autogeneradas de gRPC, implementaciones de `ServiceBase` de gRPC o controladores REST para Shelf.
*   **Restricción:** Traduce las solicitudes externas hacia comandos y queries del mediador para interactuar con la capa `core`.

### 4. Capa Common (Transversal)
*   **Qué contiene:** Mecanismos del sistema como inyección de dependencias (`service_locator.dart`), configuraciones de red, utilidades comunes de encriptación general o internacionalización global.
*   **Restricción:** Solo debe contener infraestructura que deba ser compartida estrictamente por dos o más módulos y que no pertenezca lógicamente a ninguno en particular.

---

## 📈 Flujo de Trabajo para Pull Requests

Para facilitar la revisión y mantener un historial de control de versiones legible, sigue este flujo de trabajo:

1.  **Notifica tus planes:** Si vas a trabajar en una característica nueva o corrección importante, abre un *Issue* o avisa al equipo de desarrollo para evitar duplicar esfuerzos en paralelo.
2.  **Ramas pequeñas y específicas:** Evita enviar Pull Requests gigantescos que abarquen múltiples cambios de comportamiento. Es preferible enviar varios Pull Requests enfocados en resolver una sola tarea a la vez.
3.  **Historial limpio (Squash):** Tus aportes serán consolidados (*squashed*) en un solo commit antes de ser mezclados a la rama principal. Escribe descripciones de commit claras y concisas en tus solicitudes de integración.

---

## 🧪 Pruebas Unitarias

Si agregas nuevos casos de uso o lógica dentro de la capa `core`, se requiere la inclusión de pruebas que validen su comportamiento antes de proceder al despliegue.

Para ejecutar las pruebas locales del servidor, utiliza la herramienta de testeo de Dart:

```bash
dart test
```
