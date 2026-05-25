/// Marcador para cualquier tipo de solicitud (Comando o Query)
abstract class IRequest<TResponse> {}

/// Interfaz para todos los manejadores de solicitudes
abstract class IRequestHandler<TRequest extends IRequest<TResponse>, TResponse> {
  Future<TResponse> handle(TRequest request);
}
