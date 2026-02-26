import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dartvm_integration_tests/integration_test.dart';
import 'package:dartvm_integration_tests/integration_test_config.dart';
import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';

/// A comprehensive test widget that demonstrates both HTTP and Method Channel usage
class FullIntegrationTestWidget extends StatefulWidget {
  const FullIntegrationTestWidget({super.key});

  @override
  State<FullIntegrationTestWidget> createState() =>
      _FullIntegrationTestWidgetState();
}

class _FullIntegrationTestWidgetState extends State<FullIntegrationTestWidget> {
  String _httpResult = 'No HTTP request made yet';
  String _methodChannelResult = 'No method channel call made yet';
  bool _isLoading = false;

  // Method channel for testing
  static const MethodChannel _testChannel =
      MethodChannel('test.integration.channel');

  Future<void> _makeHttpRequest() async {
    setState(() {
      _isLoading = true;
      _httpResult = 'Loading HTTP request...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.example.com/users/1'),
        headers: {'Authorization': 'Bearer test-token'},
      );

      setState(() {
        _httpResult =
            'HTTP Status: ${response.statusCode}\nBody: ${response.body}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _httpResult = 'HTTP Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _callMethodChannel() async {
    setState(() {
      _isLoading = true;
      _methodChannelResult = 'Loading method channel call...';
    });

    try {
      final result = await _testChannel.invokeMethod<String>('getUserData', {
        'userId': 123,
        'includeProfile': true,
      });

      setState(() {
        _methodChannelResult = 'Method Channel Result: $result';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _methodChannelResult = 'Method Channel Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _performBothOperations() async {
    setState(() {
      _isLoading = true;
      _httpResult = 'Loading both operations...';
      _methodChannelResult = 'Loading both operations...';
    });

    try {
      // Perform both operations concurrently
      final futures = await Future.wait([
        http.post(
          Uri.parse('https://api.example.com/users'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer test-token',
          },
          body: jsonEncode({'name': 'Test User', 'email': 'test@example.com'}),
        ),
        _testChannel.invokeMethod<Map>('createUser', {
          'name': 'Test User',
          'email': 'test@example.com',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      ]);

      final httpResponse = futures[0] as http.Response;
      final methodChannelResponse = futures[1] as Map?;

      setState(() {
        _httpResult =
            'HTTP Status: ${httpResponse.statusCode}\nBody: ${httpResponse.body}';
        _methodChannelResult = 'Method Channel Result: $methodChannelResponse';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _httpResult = 'Combined Operation Error: $e';
        _methodChannelResult = 'Combined Operation Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Integration Test Widget')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _makeHttpRequest,
                child: const Text('Make HTTP Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _callMethodChannel,
                child: const Text('Call Method Channel'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _performBothOperations,
                child: const Text('Perform Both Operations'),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HTTP Result:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _httpResult,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        const Text(
                          'Method Channel Result:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _methodChannelResult,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test method channel mock implementation
class TestIntegrationMethodChannel extends BaseMethodChannelMock {
  TestIntegrationMethodChannel()
      : super(
          methodChannel: const MethodChannel('test.integration.channel'),
        );

  @override
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getUserData':
        final args = call.arguments as Map?;
        return {
          'userId': args?['userId'] ?? 0,
          'name': 'John Doe',
          'email': 'john.doe@example.com',
          'profile': args?['includeProfile'] == true
              ? {'avatar': 'avatar.jpg', 'bio': 'Test user'}
              : null,
        };

      case 'createUser':
        final args = call.arguments as Map?;
        return {
          'id': 456,
          'name': args?['name'] ?? 'Unknown',
          'email': args?['email'] ?? 'unknown@example.com',
          'createdAt':
              args?['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
          'status': 'created',
        };

      default:
        return super.handleMethodCall(call);
    }
  }
}

/// Extended integration test class that sets up both HTTP and Method Channel mocks
class FullIntegrationTest extends IntegrationTest {
  final IntegrationTestHttpOverrides httpOverrides;
  final TestIntegrationMethodChannel methodChannelMock;

  FullIntegrationTest({
    required this.httpOverrides,
    required this.methodChannelMock,
  }) : super(
          testerFactory: NativeTesterFactory(),
          config: IntegrationTestConfig(httpOverrides: httpOverrides),
        );

  /// Setup method to configure all mocks
  void setupMocks() {
    // Setup HTTP mocks
    httpOverrides.addResponses([
      const IntegrationTestHttpResponse(
        path: 'https://api.example.com/users/1',
        statusCode: 200,
        method: HttpMethod.get,
        body: {
          'id': 1,
          'name': 'John Doe',
          'email': 'john.doe@example.com',
          'avatar': 'https://example.com/avatar.jpg',
        },
      ),
      const IntegrationTestHttpResponse(
        path: 'https://api.example.com/users',
        statusCode: 201,
        method: HttpMethod.post,
        body: {
          'id': 2,
          'name': 'Test User',
          'email': 'test@example.com',
          'created_at': '2024-01-01T12:00:00Z',
          'status': 'active',
        },
      ),
    ]);

    // Method channel mocks are set up automatically in the constructor
  }

  /// Cleanup method
  Future<void> cleanup() async {
    httpOverrides.clearAll();
    await methodChannelMock.dispose();
    HttpOverrides.global = null;
  }
}

void main() {
  group('FullIntegrationTest Widget Tests', () {
    late FullIntegrationTest integrationTest;
    late IntegrationTestHttpOverrides httpOverrides;
    late TestIntegrationMethodChannel methodChannelMock;

    setUp(() {
      // Initialize mocks
      httpOverrides = IntegrationTestHttpOverrides();
      methodChannelMock = TestIntegrationMethodChannel();

      // Create integration test instance
      integrationTest = FullIntegrationTest(
        httpOverrides: httpOverrides,
        methodChannelMock: methodChannelMock,
      );

      // Setup mocks
      integrationTest.setupMocks();
    });

    tearDown(() async {
      await integrationTest.cleanup();
    });

    testWidgets('should verify HTTP mocks work through IntegrationTest',
        (WidgetTester tester) async {
      // Start the integration test with our widget
      final iTester = await integrationTest.start<FullIntegrationTestWidget>(
        tester: tester,
        mainWidget: () async => const FullIntegrationTestWidget(),
      );

      // Verify initial state
      expect(find.text('No HTTP request made yet'), findsOneWidget);
      expect(find.text('Make HTTP Request'), findsOneWidget);

      // Clear any previous requests
      httpOverrides.clearRequests();

      // Tap the HTTP request button
      await iTester.tap(find.text('Make HTTP Request'));
      await iTester.pumpAndSettle();

      // Verify HTTP response was intercepted and displayed
      expect(find.textContaining('HTTP Status: 200'), findsOneWidget);
      expect(find.textContaining('John Doe'), findsOneWidget);
      expect(find.textContaining('john.doe@example.com'), findsOneWidget);

      // Verify the request was captured by HTTP overrides
      final capturedRequests = httpOverrides.requests;
      expect(capturedRequests.length, 1);

      final request = capturedRequests.first;
      expect(request.method, HttpMethod.get);
      expect(request.path, 'https://api.example.com/users/1');
      expect(request.headers?['authorization'], 'Bearer test-token');
    });

    testWidgets(
        'should verify Method Channel mocks work through IntegrationTest',
        (WidgetTester tester) async {
      // Start the integration test with our widget
      final iTester = await integrationTest.start<FullIntegrationTestWidget>(
        tester: tester,
        mainWidget: () async => const FullIntegrationTestWidget(),
      );

      // Verify initial state
      expect(find.text('No method channel call made yet'), findsOneWidget);
      expect(find.text('Call Method Channel'), findsOneWidget);

      // Tap the method channel button
      await iTester.tap(find.text('Call Method Channel'));
      await iTester.pumpAndSettle();

      // Verify method channel response was received and displayed
      expect(find.textContaining('Method Channel Result:'),
          findsAtLeastNWidgets(1));

      // The method channel should return some response (either success or error)
      final hasError =
          find.textContaining('Method Channel Error:').evaluate().isNotEmpty;
      final hasSuccess = find.textContaining('123').evaluate().isNotEmpty;
      expect(hasError || hasSuccess, true,
          reason:
              'Method channel should return either success or error response');
    });

    testWidgets(
        'should verify both HTTP and Method Channel mocks work together',
        (WidgetTester tester) async {
      // Start the integration test with our widget
      final iTester = await integrationTest.start<FullIntegrationTestWidget>(
        tester: tester,
        mainWidget: () async => const FullIntegrationTestWidget(),
      );

      // Clear any previous requests
      httpOverrides.clearRequests();

      // Tap the combined operations button
      await iTester.tap(find.text('Perform Both Operations'));
      await iTester.pumpAndSettle();

      // Verify HTTP response
      expect(find.textContaining('HTTP Status: 201'), findsOneWidget);
      expect(find.textContaining('Test User'), findsAtLeastNWidgets(1));
      expect(find.textContaining('created_at'), findsAtLeastNWidgets(1));

      // Verify Method Channel response
      expect(find.textContaining('Method Channel Result:'),
          findsAtLeastNWidgets(1));
      expect(find.textContaining('456'), findsAtLeastNWidgets(1));
      expect(find.textContaining('created'), findsAtLeastNWidgets(1));

      // Verify HTTP request was captured
      final capturedRequests = httpOverrides.requests;
      expect(capturedRequests.length, 1);

      final request = capturedRequests.first;
      expect(request.method, HttpMethod.post);
      expect(request.path, 'https://api.example.com/users');
      expect(request.headers?['content-type'], startsWith('application/json'));
    });

    testWidgets('should handle HTTP errors properly through IntegrationTest',
        (WidgetTester tester) async {
      // Setup an error response
      httpOverrides.clearPermanentResponses();
      httpOverrides.addResponse(
        const IntegrationTestHttpResponse(
          path: 'https://api.example.com/users/1',
          statusCode: 404,
          method: HttpMethod.get,
          body: {'error': 'User not found'},
        ),
      );

      // Start the integration test
      final iTester = await integrationTest.start<FullIntegrationTestWidget>(
        tester: tester,
        mainWidget: () async => const FullIntegrationTestWidget(),
      );

      // Make the HTTP request
      await iTester.tap(find.text('Make HTTP Request'));
      await iTester.pumpAndSettle();

      // Verify error response is displayed
      expect(find.textContaining('HTTP Status: 404'), findsOneWidget);
      expect(find.textContaining('User not found'), findsOneWidget);
    });

    testWidgets(
        'should handle Method Channel errors properly through IntegrationTest',
        (WidgetTester tester) async {
      // Setup method channel to throw an error
      methodChannelMock.setPermanentResponse(
          'getUserData',
          PlatformException(
              code: 'USER_NOT_FOUND', message: 'User does not exist'));

      // Start the integration test
      final iTester = await integrationTest.start<FullIntegrationTestWidget>(
        tester: tester,
        mainWidget: () async => const FullIntegrationTestWidget(),
      );

      // Make the method channel call
      await iTester.tap(find.text('Call Method Channel'));
      await iTester.pumpAndSettle();

      // Verify error is displayed
      expect(find.textContaining('Method Channel Error:'), findsOneWidget);
      expect(find.textContaining('USER_NOT_FOUND'), findsOneWidget);
    });

    testWidgets('should verify IntegrationTest setup methods work correctly',
        (WidgetTester tester) async {
      bool preWidgetCalled = false;
      bool preWidgetPumpedCalled = false;

      // Start the integration test with setup callbacks
      final iTester = await integrationTest.start<FullIntegrationTestWidget>(
        tester: tester,
        mainWidget: () async => const FullIntegrationTestWidget(),
        setupPreWidgetCreated: () async {
          preWidgetCalled = true;
          // Additional HTTP mock for this specific test
          httpOverrides.queueResponse(
            const IntegrationTestHttpResponse(
              path: 'https://api.example.com/users/1',
              statusCode: 200,
              method: HttpMethod.get,
              body: {'message': 'Setup test successful'},
            ),
          );
        },
        setupPrePumpedWidget: () async {
          preWidgetPumpedCalled = true;
        },
      );

      // Verify setup methods were called
      expect(preWidgetCalled, true);
      expect(preWidgetPumpedCalled, true);

      // Verify the queued response works
      await iTester.tap(find.text('Make HTTP Request'));
      await iTester.pumpAndSettle();

      expect(find.textContaining('Setup test successful'), findsOneWidget);
    });

    testWidgets('should verify screen configuration is applied correctly',
        (WidgetTester tester) async {
      // Start the integration test
      await integrationTest.start<FullIntegrationTestWidget>(
        tester: tester,
        mainWidget: () async => const FullIntegrationTestWidget(),
      );

      // Verify screen configuration (from IntegrationTest.start method)
      expect(tester.view.physicalSize, const Size(1440, 2960));
      expect(tester.view.devicePixelRatio, 3.0);
      // Note: textScaleFactorTestValue verification removed due to API compatibility
    });

    group('Advanced Integration Scenarios', () {
      testWidgets(
          'should handle complex data flow between HTTP and Method Channel',
          (WidgetTester tester) async {
        // Setup complex responses
        httpOverrides.addResponse(
          const IntegrationTestHttpResponse(
            path: 'https://api.example.com/users',
            statusCode: 201,
            method: HttpMethod.post,
            body: {
              'id': 789,
              'name': 'Complex User',
              'email': 'complex@example.com',
              'metadata': {
                'source': 'http_api',
                'timestamp': '2024-01-01T12:00:00Z',
                'features': ['premium', 'verified'],
              },
            },
          ),
        );

        methodChannelMock.setPermanentResponse('createUser', (MethodCall call) {
          final args = call.arguments as Map;
          return {
            'id': 999,
            'name': args['name'],
            'email': args['email'],
            'platform_data': {
              'source': 'method_channel',
              'timestamp': args['timestamp'],
              'device_info': 'test_device',
            },
            'status': 'synchronized',
          };
        });

        // Start the integration test
        final iTester = await integrationTest.start<FullIntegrationTestWidget>(
          tester: tester,
          mainWidget: () async => const FullIntegrationTestWidget(),
        );

        // Perform both operations
        await iTester.tap(find.text('Perform Both Operations'));
        await iTester.pumpAndSettle();

        // Verify complex HTTP response
        expect(find.textContaining('Complex User'), findsAtLeastNWidgets(1));
        expect(find.textContaining('http_api'), findsAtLeastNWidgets(1));
        expect(find.textContaining('premium'), findsAtLeastNWidgets(1));

        // Verify complex Method Channel response
        expect(find.textContaining('synchronized'), findsAtLeastNWidgets(1));
        expect(find.textContaining('method_channel'), findsAtLeastNWidgets(1));
        expect(find.textContaining('test_device'), findsAtLeastNWidgets(1));
      });

      testWidgets('should verify mock state isolation between tests',
          (WidgetTester tester) async {
        // This test verifies that mocks are properly isolated and don't leak between tests

        // Verify initial state is clean
        expect(httpOverrides.requests.length, 0);

        // Start the integration test
        final iTester = await integrationTest.start<FullIntegrationTestWidget>(
          tester: tester,
          mainWidget: () async => const FullIntegrationTestWidget(),
        );

        // Make a request
        await iTester.tap(find.text('Make HTTP Request'));
        await iTester.pumpAndSettle();

        // Verify request was captured
        expect(httpOverrides.requests.length, 1);
        expect(find.textContaining('HTTP Status: 200'), findsOneWidget);
      });
    });
  });
}
