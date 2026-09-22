/// Exception métier générique, affichée directement à l'utilisateur
/// via ToastService — le message doit donc toujours être en français
/// et compréhensible sans jargon technique.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class AuthException extends AppException {
  const AuthException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

class PrinterException extends AppException {
  const PrinterException(super.message);
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}
