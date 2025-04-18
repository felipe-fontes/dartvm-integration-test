import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:fake_http_client/fake_http_client.dart';

dynamic deepMerge(dynamic original, dynamic overrides) {
  if (original is Map && overrides is Map) {
    final result = Map.from(original);
    overrides.forEach((key, value) {
      if (result.containsKey(key)) {
        result[key] = deepMerge(result[key], value);
      } else {
        result[key] = value;
      }
    });
    return result;
  } else if (original is List && overrides is List) {
    return deepMergeLists(original, overrides);
  } else {
    return overrides;
  }
}

List<dynamic> deepMergeLists(List<dynamic> original, List<dynamic> overrides) {
  List<dynamic> merged = [];
  for (int i = 0; i < original.length; i++) {
    if (i < overrides.length) {
      merged.add(deepMerge(original[i], overrides[i]));
    } else {
      merged.add(original[i]);
    }
  }
  for (int i = original.length; i < overrides.length; i++) {
    merged.add(overrides[i]);
  }
  return merged;
}

enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete;

  factory HttpMethod.fromString(String method) {
    return HttpMethod.values.firstWhere(
      (e) => e.name.toUpperCase() == method.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid HTTP method: $method'),
    );
  }

  @override
  String toString() => name.toUpperCase();
}

class IntegrationTestHttpResponse {
  final String path;
  final dynamic body;
  final Map<String, dynamic>? headers;
  final int statusCode;
  final bool ignoreQuery;
  final Duration? delay;
  final HttpMethod? method;

  const IntegrationTestHttpResponse({
    required this.path,
    this.statusCode = 200,
    this.headers,
    this.body,
    this.ignoreQuery = false,
    this.delay,
    this.method,
  });

  /// Creates a new response by overriding specific fields of an existing response.
  IntegrationTestHttpResponse withOverrides({
    String? pathOverride,
    dynamic bodyMerge,
    dynamic bodyOverrides,
    int? statusCodeOverride,
    bool ignoreQuery = false,
    Duration? delayOverride,
    HttpMethod? methodOverride,
  }) {
    // Return same instance if no overrides are needed
    if (pathOverride == null &&
        bodyMerge == null &&
        bodyOverrides == null &&
        statusCodeOverride == null &&
        ignoreQuery == false &&
        delayOverride == null &&
        methodOverride == null) {
      return this;
    }

    // Check if the overrides would result in the same values
    if (pathOverride == path &&
        bodyOverrides == null &&
        bodyMerge == null &&
        statusCodeOverride == statusCode &&
        ignoreQuery == this.ignoreQuery &&
        delayOverride == delay &&
        methodOverride == method) {
      return this;
    }

    // Calculate new body only if needed
    dynamic newBody = body;
    if (bodyMerge != null || bodyOverrides != null) {
      if (bodyMerge != null) {
        newBody = deepMerge(newBody, bodyMerge);
      }
      if (bodyOverrides != null) {
        newBody = bodyOverrides;
      }
      // If after merging/overriding the body is identical, and no other changes
      if (identical(newBody, body) &&
          pathOverride == null &&
          statusCodeOverride == null &&
          ignoreQuery == this.ignoreQuery &&
          delayOverride == null &&
          methodOverride == null) {
        return this;
      }
    }

    return IntegrationTestHttpResponse(
      path: pathOverride ?? path,
      statusCode: statusCodeOverride ?? statusCode,
      headers: headers,
      body: newBody,
      ignoreQuery: ignoreQuery,
      delay: delayOverride ?? delay,
      method: methodOverride ?? method,
    );
  }
}

class RequestVerification {
  final HttpMethod method;
  final String path;
  final Map<String, dynamic>? body;
  final Map<String, String>? headers;

  RequestVerification({
    required this.method,
    required this.path,
    this.body,
    this.headers,
  });

  @override
  String toString() {
    return 'RequestVerification(method: $method, path: $path, body: $body, headers: $headers)';
  }
}

class IntegrationTestHttpOverrides extends HttpOverrides {
  final Map<String, IntegrationTestHttpResponse> _permanentResponses = {};
  final Map<String, List<IntegrationTestHttpResponse>> _queuedResponses = {};
  final List<RequestVerification> _requests = [];

  List<RequestVerification> get requests => List.unmodifiable(_requests);
  Map<String, IntegrationTestHttpResponse> get permanentResponses => _permanentResponses;

  void clearRequests() {
    _requests.clear();
  }

  void clearQueuedResponses() {
    _queuedResponses.clear();
  }

  void clearPermanentResponses() {
    _permanentResponses.clear();
  }

  void clearAll() {
    clearRequests();
    clearQueuedResponses();
    clearPermanentResponses();
  }

  RequestVerification? findRequest(String path, {HttpMethod? method}) {
    return _requests.cast<RequestVerification?>().firstWhere(
          (req) => req!.path.contains(path) && (method == null || req.method == method),
          orElse: () => null,
        );
  }

  List<RequestVerification> findAllRequests(String path, {HttpMethod? method}) {
    return _requests
        .where((req) => req.path.contains(path) && (method == null || req.method == method))
        .toList();
  }

  String getMapKey(String path, bool ignoreQuery, HttpMethod? method) {
    final uri = Uri.parse(path);
    final pathKey = ignoreQuery ? uri.path : '${uri.path}?${uri.query}';
    return method != null ? '${method.name.toUpperCase()}:$pathKey' : pathKey;
  }

  IntegrationTestHttpOverrides() {
    HttpOverrides.global = this;
  }

  void addResponse(IntegrationTestHttpResponse response) {
    final key = getMapKey(response.path, response.ignoreQuery, response.method);
    _permanentResponses[key] = response;
  }

  void addResponses(List<IntegrationTestHttpResponse> responses) {
    for (final response in responses) {
      addResponse(response);
    }
  }

  void queueResponse(IntegrationTestHttpResponse response) {
    final key = getMapKey(response.path, response.ignoreQuery, response.method);
    _queuedResponses.putIfAbsent(key, () => []).add(response);
  }

  void replaceResponse(IntegrationTestHttpResponse response) {
    final key = getMapKey(response.path, response.ignoreQuery, response.method);
    _queuedResponses[key] = [response];
  }

  String _findMatchingKey(String requestPath, Map<String, dynamic> map, HttpMethod requestMethod) {
    final requestUri = Uri.parse(requestPath);
    final fullPath = '${requestUri.path}?${requestUri.query}';

    // First try exact match with method
    final methodKey = '${requestMethod.name.toUpperCase()}:$fullPath';
    if (map.containsKey(methodKey)) {
      return methodKey;
    }

    // Then try to find a matching ignoreQuery response with method
    final methodPathKey = '${requestMethod.name.toUpperCase()}:${requestUri.path}';
    if (map.containsKey(methodPathKey)) {
      return methodPathKey;
    }

    // If no method-specific match found, try without method (for responses that match any method)
    if (map.containsKey(fullPath)) {
      return fullPath;
    }

    if (map.containsKey(requestUri.path)) {
      return requestUri.path;
    }

    return '';
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return FakeHttpClient(onFakeRequest);
  }

  Future<Map<String, dynamic>?> _parseRequestBody(dynamic request) async {
    try {
      if (request.contentLength == 0) {
        return null;
      }

      final contentType = request.headers['content-type']?.first.toLowerCase() ?? '';

      String body;
      if (request is FakeHttpClientRequest) {
        body = request.bodyText;
        if (body.isEmpty || body == '{}') {
          return null;
        }
      } else {
        final content = await request.fold<List<int>>(
          <int>[],
          (previous, element) => [...previous, ...element],
        );

        if (content.isEmpty) {
          return null;
        }

        body = utf8.decode(content);
      }

      try {
        if (contentType.contains('application/json')) {
          return jsonDecode(body) as Map<String, dynamic>;
        }

        if (contentType.contains('application/x-www-form-urlencoded')) {
          return Map<String, dynamic>.from(Uri.splitQueryString(body));
        }

        return null;
      } catch (e) {
        debugPrint('Failed to parse request body: $e');
        return null;
      }
    } catch (e, stack) {
      debugPrint('Failed to parse request body: $e\n$stack');
      return null;
    }
  }

  Map<String, String> _extractHeaders(dynamic request) {
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headers[name.toLowerCase()] = values.first;
      }
    });
    return headers;
  }

  FutureOr<FakeHttpResponse> onFakeRequest(request, client) async {
    final requestPath = request.uri.toString();
    final requestHeaders = _extractHeaders(request);
    final requestBody = await _parseRequestBody(request);
    final requestMethod = HttpMethod.fromString(request.method);

    debugPrint('📤 Request: ${request.method} $requestPath');

    // Store request for verification
    _requests.add(RequestVerification(
      method: requestMethod,
      path: requestPath,
      body: requestBody,
      headers: requestHeaders,
    ));

    try {
      // Check queued responses first (priority)
      final queuedKey = _findMatchingKey(requestPath, _queuedResponses, requestMethod);
      if (queuedKey.isNotEmpty && _queuedResponses[queuedKey]!.isNotEmpty) {
        final queuedResponse = _queuedResponses[queuedKey]!.removeAt(0);
        if (_queuedResponses[queuedKey]!.isEmpty) {
          _queuedResponses.remove(queuedKey);
        }

        debugPrint('📥 Response found (queued): ${queuedResponse.statusCode}');

        // Apply delay if specified
        if (queuedResponse.delay != null) {
          debugPrint('⏳ Delaying response by ${queuedResponse.delay}');
          await Future.delayed(queuedResponse.delay!);
        }

        return FakeHttpResponse(
          statusCode: queuedResponse.statusCode,
          body: jsonEncode(queuedResponse.body),
          headers: {
            'Content-Type': 'application/json',
            if (queuedResponse.headers != null)
              ...Map<String, String>.from(queuedResponse.headers!),
          },
        );
      }

      // Check permanent responses
      final permanentKey = _findMatchingKey(requestPath, _permanentResponses, requestMethod);
      if (permanentKey.isNotEmpty) {
        final permanentResponse = _permanentResponses[permanentKey]!;

        debugPrint('📥 Response found (permanent): ${permanentResponse.statusCode}');

        // Apply delay if specified
        if (permanentResponse.delay != null) {
          debugPrint('⏳ Delaying response by ${permanentResponse.delay}');
          await Future.delayed(permanentResponse.delay!);
        }

        return FakeHttpResponse(
          statusCode: permanentResponse.statusCode,
          body: jsonEncode(permanentResponse.body),
          headers: {
            'Content-Type': 'application/json',
            if (permanentResponse.headers != null)
              ...Map<String, String>.from(permanentResponse.headers!),
          },
        );
      }

      // No mock found
      debugPrint('❌ Mock not found: ${request.method} $requestPath');

      return FakeHttpResponse(
        statusCode: HttpStatus.notFound,
        body: jsonEncode({
          'message': 'Mock response not found for $requestPath',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      debugPrint('🔴 Error processing request: $e');
      rethrow;
    }
  }
}
