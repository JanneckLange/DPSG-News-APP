class RemoteEventSourceException implements Exception {
  RemoteEventSourceException(
    this.message, {
    this.exception,
    this.stackTrace,
    this.statusCode,
    this.serverMessage,
  });

  final String message;
  final Object? exception;
  final StackTrace? stackTrace;
  final int? statusCode;

  /// Die vom Server im JSON-Body ({"error": "..."}) gelieferte Klartext-Meldung,
  /// sofern vorhanden. Nutzerfreundlicher als [message], das den rohen
  /// Response-Text enthaelt.
  final String? serverMessage;

  @override
  String toString() => 'RemoteEventSourceException: $message';
}
