import 'package:get_it/get_it.dart';
import 'interfaces.dart';

/// La clase Mediator actúa como el despachador central de solicitudes.
/// No contiene lógica de negocio, solo enruta una [IRequest] a su [IRequestHandler] correspondiente.
class Mediator {
  final GetIt _locator;

  // Mapa que asocia un tipo de Request con una función que crea su Handler.
  // Esto evita que el Mediator conozca directamente los Handlers concretos.
  final Map<Type, Function> _handlerFactories = {};

  Mediator(this._locator);

  /// Registra un manejador para un tipo de solicitud específico.
  /// Se usa en el `service_locator` para construir el mapa de enrutamiento.
  void registerHandler<
    TRequest extends IRequest<TResponse>,
    TResponse,
    THandler extends IRequestHandler<TRequest, TResponse>
  >() {
    _handlerFactories[TRequest] = () => _locator<THandler>();
  }

  /// Envía una solicitud para ser procesada por su manejador correspondiente.
  Future<TResponse> send<TResponse>(IRequest<TResponse> request) {
    final handlerFactory = _handlerFactories[request.runtimeType];

    if (handlerFactory == null) {
      throw Exception('No handler registered for ${request.runtimeType}');
    }

    // Usamos la factory para obtener una instancia fresca del handler desde get_it.
    final handler = handlerFactory();

    // Requerimos que el handler sea del tipo correcto para asegurar la integridad.
    if (handler is IRequestHandler<IRequest<TResponse>, TResponse>) {
      return handler.handle(request);
    }

    throw Exception('Handler for ${request.runtimeType} is of the wrong type.');
  }
}
