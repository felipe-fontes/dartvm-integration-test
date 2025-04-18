import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Base class for method channel mocks that provides common functionality
/// and standardizes the way we create method channel mocks.
abstract class BaseMethodChannelMock {
  /// The method channel instance
  final MethodChannel methodChannel;

  /// The binary messenger used for testing
  final TestDefaultBinaryMessenger binaryMessenger;

  /// Queue of responses for specific method calls
  final Map<String, List<dynamic>> _queuedResponses = {};

  /// Permanent responses for specific method calls
  final Map<String, dynamic> _permanentResponses = {};

  /// Constructor that sets up the mock handlers
  BaseMethodChannelMock({
    required this.methodChannel,
    TestDefaultBinaryMessenger? binaryMessenger,
  }) : binaryMessenger =
            binaryMessenger ?? TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger {
    this.binaryMessenger.setMockMethodCallHandler(methodChannel, _handleMethodCall);
  }

  /// Internal method to handle method calls and manage responses
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      // Check for queued responses first
      if (_queuedResponses.containsKey(call.method) && _queuedResponses[call.method]!.isNotEmpty) {
        final response = _queuedResponses[call.method]!.removeAt(0);
        return _processResponse(response, call);
      }

      // Check for permanent responses
      if (_permanentResponses.containsKey(call.method)) {
        return _processResponse(_permanentResponses[call.method], call);
      }

      // Fall back to the implementation's handler
      return handleMethodCall(call);
    } catch (e) {
      if (e is PlatformException) {
        rethrow;
      }
      throw PlatformException(
        code: 'ERROR',
        message: e.toString(),
      );
    }
  }

  /// Process a response, handling functions and exceptions
  dynamic _processResponse(dynamic response, MethodCall call) {
    if (response is Function) {
      try {
        return response(call);
      } catch (e) {
        if (e is PlatformException) {
          rethrow;
        }
        throw PlatformException(
          code: 'ERROR',
          message: e.toString(),
        );
      }
    } else if (response is Exception) {
      throw response;
    }
    return response;
  }

  /// Abstract method that subclasses must implement to handle method calls
  Future<dynamic> handleMethodCall(MethodCall call) {
    throw PlatformException(
      code: 'Unimplemented',
      message: 'The method ${call.method} is not implemented.',
      details: 'Method was called with arguments: ${call.arguments}',
    );
  }

  /// Queue a response for a specific method
  void queueResponse(String method, dynamic response) {
    _queuedResponses.putIfAbsent(method, () => []).add(response);
  }

  /// Set a permanent response for a specific method
  void setPermanentResponse(String method, dynamic response) {
    _permanentResponses[method] = response;
  }

  /// Clear queued responses for a specific method
  void clearQueuedResponses(String method) {
    _queuedResponses.remove(method);
  }

  /// Clear all queued responses
  void clearAllQueuedResponses() {
    _queuedResponses.clear();
  }

  /// Clear permanent response for a specific method
  void clearPermanentResponse(String method) {
    _permanentResponses.remove(method);
  }

  /// Clear all permanent responses
  void clearAllPermanentResponses() {
    _permanentResponses.clear();
  }

  /// Disposes of the mock channel handlers
  Future<void> dispose() async {
    binaryMessenger.setMockMethodCallHandler(methodChannel, null);
    clearAllQueuedResponses();
    clearAllPermanentResponses();
  }
}
