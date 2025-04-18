// ignore_for_file: avoid_setters_without_getters

import 'dart:developer' as dev;
import 'dart:io';

import 'integration_test_http_overrides.dart';

class TesterHttpClient implements HttpClient {
  final List<IntegrationTestHttpResponse> testerResponses;
  final HttpClient fakeHttpClient;
  final HttpClient realHttpClient;

  TesterHttpClient({
    required this.testerResponses,
    required this.fakeHttpClient,
    required this.realHttpClient,
  });

  bool shouldOverride = false;

  @override
  late bool autoUncompress = realHttpClient.autoUncompress;

  @override
  late Duration? connectionTimeout = realHttpClient.connectionTimeout;

  @override
  late Duration idleTimeout = realHttpClient.idleTimeout;

  @override
  late int? maxConnectionsPerHost = realHttpClient.maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {
    realHttpClient.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {
    realHttpClient.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) {
    realHttpClient.authenticate = f;
  }

  @override
  set authenticateProxy(
    Future<bool> Function(
      String host,
      int port,
      String scheme,
      String? realm,
    )? f,
  ) {
    realHttpClient.authenticateProxy = f;
  }

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {
    realHttpClient.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) {
    realHttpClient.close(force: force);
  }

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )? f,
  ) {
    realHttpClient.connectionFactory = f;
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    if (shouldOverride) {
      return fakeHttpClient.delete(host, port, path);
    }

    return realHttpClient.delete(host, port, path);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    checkOverride(url);

    if (shouldOverride) {
      return fakeHttpClient.deleteUrl(url);
    }

    return realHttpClient.deleteUrl(url);
  }

  @override
  set findProxy(String Function(Uri url)? f) {
    realHttpClient.findProxy = f;
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    if (shouldOverride) {
      return fakeHttpClient.get(host, port, path);
    }

    return realHttpClient.get(host, port, path);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (shouldOverride) {
      return fakeHttpClient.getUrl(url);
    }

    return realHttpClient.getUrl(url);
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    if (shouldOverride) {
      return fakeHttpClient.head(host, port, path);
    }

    return realHttpClient.head(host, port, path);
  }

  @override
  Future<HttpClientRequest> headUrl(Uri uri) {
    checkOverride(uri);

    if (shouldOverride) {
      return fakeHttpClient.headUrl(uri);
    }

    return realHttpClient.headUrl(uri);
  }

  @override
  set keyLog(Function(String line)? callback) {
    realHttpClient.keyLog = callback;
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) {
    if (shouldOverride) {
      return fakeHttpClient.open(method, host, port, path);
    }

    return realHttpClient.open(method, host, port, path);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    checkOverride(url);

    if (shouldOverride) {
      return fakeHttpClient.openUrl(method, url);
    }

    return realHttpClient.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    if (shouldOverride) {
      return fakeHttpClient.patch(host, port, path);
    }

    return realHttpClient.patch(host, port, path);
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri uri) {
    checkOverride(uri);
    if (shouldOverride) {
      return fakeHttpClient.patchUrl(uri);
    }

    return realHttpClient.patchUrl(uri);
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    if (shouldOverride) {
      return fakeHttpClient.post(host, port, path);
    }

    return realHttpClient.post(host, port, path);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri uri) {
    checkOverride(uri);
    if (shouldOverride) {
      return fakeHttpClient.postUrl(uri);
    }

    return realHttpClient.postUrl(uri);
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    if (shouldOverride) {
      return fakeHttpClient.put(host, port, path);
    }

    return realHttpClient.put(host, port, path);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    checkOverride(url);

    return fakeHttpClient.putUrl(url);
  }

  void checkOverride(Uri uri) {
    dev.log("Checking override for: ${uri.hasQuery}");
    dev.log("Checking override for: ${uri.hasQuery}");
    final isPathMatching = testerResponses.any((response) {
      final responseUri = Uri.parse(response.path);
      final isPathMatching = responseUri.path == uri.path;
      final isQueryMatching = responseUri.query.isEmpty || responseUri.query == uri.query;

      dev.log("isPathMatching: $isPathMatching");
      dev.log("isQueryMatching: $isQueryMatching");

      return isPathMatching && isQueryMatching;
    });

    shouldOverride = isPathMatching;

    if (!isPathMatching) {
      dev.log(
        "Unmocked Endpoint Detected!",
        error: uri.toString(),
        stackTrace: StackTrace.current,
        level: 1000,
      );
    }
  }
}
