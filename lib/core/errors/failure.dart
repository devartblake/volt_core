// A simple error abstraction for usecases/repositories.
// Feature modules can extend this or define their own subtypes.

class Failure {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  final String? code; // e.g. 'network', 'validation', 'auth'

  const Failure(
      this.message, {
        this.cause,
        this.stackTrace,
        this.code,
      });

  @override
  String toString() {
    final buffer = StringBuffer('Failure(')
      ..write('message: $message');
    if (code != null) buffer.write(', code: $code');
    if (cause != null) buffer.write(', cause: $cause');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Some common, convenient subtypes you can use from modules.
class NetworkFailure extends Failure {
  const NetworkFailure(
      super.message, {
        super.cause,
        super.stackTrace,
      }) : super(
    code: 'network',
  );
}

class AuthFailure extends Failure {
  const AuthFailure(
      super.message, {
        super.cause,
        super.stackTrace,
      }) : super(
    code: 'auth',
  );
}

class ValidationFailure extends Failure {
  const ValidationFailure(
      super.message, {
        super.cause,
        super.stackTrace,
      }) : super(
    code: 'validation',
  );
}
