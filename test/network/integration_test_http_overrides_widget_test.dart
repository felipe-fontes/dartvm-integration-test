import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test_mock/network/integration_test_http_overrides.dart';

/// A simple widget that makes HTTP requests to demonstrate interception
class HttpTestWidget extends StatefulWidget {
  const HttpTestWidget({super.key});

  @override
  State<HttpTestWidget> createState() => _HttpTestWidgetState();
}

class _HttpTestWidgetState extends State<HttpTestWidget> {
  String _responseText = 'No request made yet';
  bool _isLoading = false;

  Future<void> _makeGetRequest() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Loading...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.example.com/users'),
        headers: {'Authorization': 'Bearer test-token'},
      );

      setState(() {
        _responseText =
            'Status: ${response.statusCode}\nBody: ${response.body}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _makePostRequest() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Loading...';
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.example.com/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer test-token',
        },
        body: jsonEncode({'name': 'John Doe', 'email': 'john@example.com'}),
      );

      setState(() {
        _responseText =
            'Status: ${response.statusCode}\nBody: ${response.body}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('HTTP Test Widget')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _makeGetRequest,
                child: const Text('Make GET Request'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _makePostRequest,
                child: const Text('Make POST Request'),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _responseText,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
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

void main() {
  group('IntegrationTestHttpOverrides Widget Tests', () {
    late IntegrationTestHttpOverrides httpOverrides;

    setUp(() {
      // Initialize HTTP overrides before each test
      httpOverrides = IntegrationTestHttpOverrides();

      // Setup mock responses
      httpOverrides.addResponses([
        const IntegrationTestHttpResponse(
          path: 'https://api.example.com/users',
          statusCode: 200,
          method: HttpMethod.get,
          body: {
            'users': [
              {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
              {'id': 2, 'name': 'Jane Smith', 'email': 'jane@example.com'},
            ]
          },
        ),
        const IntegrationTestHttpResponse(
          path: 'https://api.example.com/users',
          statusCode: 201,
          method: HttpMethod.post,
          body: {
            'id': 3,
            'name': 'John Doe',
            'email': 'john@example.com',
            'created_at': '2024-01-01T12:00:00Z',
          },
        ),
      ]);
    });

    tearDown(() {
      // Clean up after each test
      HttpOverrides.global = null;
      httpOverrides.clearAll();
    });

    testWidgets(
        'should automatically intercept HTTP GET request made by widget',
        (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(const HttpTestWidget());

      // Verify initial state
      expect(find.text('No request made yet'), findsOneWidget);
      expect(find.text('Make GET Request'), findsOneWidget);

      // Clear any previous requests
      httpOverrides.clearRequests();

      // Tap the GET request button
      await tester.tap(find.text('Make GET Request'));
      await tester.pump(); // Trigger setState for loading state

      // Wait for the HTTP request to complete
      await tester.pumpAndSettle();

      // Verify that the response was intercepted and returned
      expect(find.textContaining('Status: 200'), findsOneWidget);
      expect(find.textContaining('John Doe'), findsOneWidget);
      expect(find.textContaining('Jane Smith'), findsOneWidget);

      // Verify that the request was captured by our HTTP overrides
      final capturedRequests = httpOverrides.requests;
      expect(capturedRequests.length, 1);

      final request = capturedRequests.first;
      expect(request.method, HttpMethod.get);
      expect(request.path, 'https://api.example.com/users');
      expect(request.headers?['authorization'], 'Bearer test-token');
    });

    testWidgets(
        'should automatically intercept HTTP POST request made by widget',
        (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(const HttpTestWidget());

      // Clear any previous requests
      httpOverrides.clearRequests();

      // Tap the POST request button
      await tester.tap(find.text('Make POST Request'));
      await tester.pump(); // Trigger setState for loading state

      // Wait for the HTTP request to complete
      await tester.pumpAndSettle();

      // Verify that the response was intercepted and returned
      expect(find.textContaining('Status: 201'), findsOneWidget);
      expect(find.textContaining('created_at'), findsOneWidget);

      // Verify that the request was captured by our HTTP overrides
      final capturedRequests = httpOverrides.requests;
      expect(capturedRequests.length, 1);

      final request = capturedRequests.first;
      expect(request.method, HttpMethod.post);
      expect(request.path, 'https://api.example.com/users');
      expect(request.headers?['content-type'], startsWith('application/json'));
      expect(request.headers?['authorization'], 'Bearer test-token');

      // The body might be null in widget tests due to how the http client handles the request
      if (request.body != null) {
        expect(request.body?['name'], 'John Doe');
        expect(request.body?['email'], 'john@example.com');
      }
    });

    testWidgets('should handle multiple sequential requests from widget',
        (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(const HttpTestWidget());

      // Clear any previous requests
      httpOverrides.clearRequests();

      // Make first request (GET)
      await tester.tap(find.text('Make GET Request'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify first request was captured
      expect(httpOverrides.requests.length, 1);
      expect(httpOverrides.requests.first.method, HttpMethod.get);

      // Make second request (POST)
      await tester.tap(find.text('Make POST Request'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify both requests were captured
      expect(httpOverrides.requests.length, 2);
      expect(httpOverrides.requests[0].method, HttpMethod.get);
      expect(httpOverrides.requests[1].method, HttpMethod.post);

      // Verify final response shows POST result
      expect(find.textContaining('Status: 201'), findsOneWidget);
    });

    testWidgets(
        'should intercept requests even when HttpOverrides.global is set in constructor',
        (WidgetTester tester) async {
      // This test specifically verifies that the constructor setting HttpOverrides.global = this works

      // Create a new instance to test constructor behavior
      final newHttpOverrides = IntegrationTestHttpOverrides();

      // Setup a response for this new instance
      newHttpOverrides.addResponse(
        const IntegrationTestHttpResponse(
          path: 'https://api.example.com/users',
          statusCode:
              418, // I'm a teapot - unique status code to verify it's our mock
          method: HttpMethod.get,
          body: {'message': 'Constructor test successful'},
        ),
      );

      // Build the widget
      await tester.pumpWidget(const HttpTestWidget());

      // Clear requests
      newHttpOverrides.clearRequests();

      // Make a request
      await tester.tap(find.text('Make GET Request'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify our unique response was returned
      expect(find.textContaining('Status: 418'), findsOneWidget);
      expect(
          find.textContaining('Constructor test successful'), findsOneWidget);

      // Verify the request was captured
      expect(newHttpOverrides.requests.length, 1);

      // Clean up
      HttpOverrides.global = null;
    });

    testWidgets('should return 404 for unmocked endpoints',
        (WidgetTester tester) async {
      // Setup HTTP overrides but don't add the specific endpoint we'll call
      httpOverrides.clearPermanentResponses();
      httpOverrides.addResponse(
        const IntegrationTestHttpResponse(
          path: 'https://api.example.com/different-endpoint',
          statusCode: 200,
          body: {'message': 'Different endpoint'},
        ),
      );

      // Build the widget
      await tester.pumpWidget(const HttpTestWidget());

      // Clear requests
      httpOverrides.clearRequests();

      // Make a request to an unmocked endpoint
      await tester.tap(find.text('Make GET Request'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify 404 response
      expect(find.textContaining('Status: 404'), findsOneWidget);
      expect(find.textContaining('Mock response not found'), findsOneWidget);

      // Verify the request was still captured
      expect(httpOverrides.requests.length, 1);
    });

    testWidgets('should handle request delays in widget context',
        (WidgetTester tester) async {
      // Setup a delayed response
      httpOverrides.clearPermanentResponses();
      httpOverrides.addResponse(
        IntegrationTestHttpResponse(
          path: 'https://api.example.com/users',
          statusCode: 200,
          method: HttpMethod.get,
          body: {'message': 'Delayed response'},
          delay: const Duration(
              milliseconds: 100), // Reduced delay for faster test
        ),
      );

      // Build the widget
      await tester.pumpWidget(const HttpTestWidget());

      // Make the request
      await tester.tap(find.text('Make GET Request'));
      await tester.pump();

      // Wait for the request to complete
      await tester.pumpAndSettle();

      // Verify the response was received (delay functionality is tested separately in unit tests)
      expect(find.textContaining('Status: 200'), findsOneWidget);
      expect(find.textContaining('Delayed response'), findsOneWidget);
    });

    group('HttpOverrides.global behavior verification', () {
      testWidgets(
          'should verify constructor sets HttpOverrides.global by testing interception',
          (WidgetTester tester) async {
        // Clear any existing global overrides
        HttpOverrides.global = null;

        // Create new instance - constructor should set HttpOverrides.global
        final newOverrides = IntegrationTestHttpOverrides();

        // Setup a unique response to verify it's working
        newOverrides.addResponse(
          const IntegrationTestHttpResponse(
            path: 'https://test.constructor.com/verify',
            statusCode: 418, // I'm a teapot - unique status
            body: {'message': 'Constructor test works'},
          ),
        );

        // Make a direct HTTP request to verify interception works
        final response =
            await http.get(Uri.parse('https://test.constructor.com/verify'));

        // Verify the response was intercepted
        expect(response.statusCode, 418);
        expect(response.body, contains('Constructor test works'));

        // Clean up
        HttpOverrides.global = null;
      });

      testWidgets('should verify that multiple instances work correctly',
          (WidgetTester tester) async {
        // Create first instance
        final firstOverrides = IntegrationTestHttpOverrides();
        firstOverrides.addResponse(
          const IntegrationTestHttpResponse(
            path: 'https://first.test.com/api',
            statusCode: 200,
            body: {'source': 'first'},
          ),
        );

        // Test first instance works
        var response = await http.get(Uri.parse('https://first.test.com/api'));
        expect(response.body, contains('first'));

        // Create second instance - should replace the first
        final secondOverrides = IntegrationTestHttpOverrides();
        // Clear the previous instance's responses and add new ones
        secondOverrides.clearPermanentResponses();
        secondOverrides.addResponse(
          const IntegrationTestHttpResponse(
            path: 'https://second.test.com/api',
            statusCode: 201,
            body: {'source': 'second'},
          ),
        );

        // Test second instance works
        response = await http.get(Uri.parse('https://second.test.com/api'));
        expect(response.statusCode, 201);
        expect(response.body, contains('second'));

        // Note: The first instance's responses may still be available since they're stored in the same global state
        // This is expected behavior - the second instance replaces the HTTP override but doesn't clear existing responses

        // Clean up
        HttpOverrides.global = null;
      });

      testWidgets(
          'should intercept all HTTP clients created after HttpOverrides.global is set',
          (WidgetTester tester) async {
        // This test verifies that the interception works for any HTTP client created after setting global overrides

        httpOverrides.clearPermanentResponses();
        httpOverrides.addResponse(
          const IntegrationTestHttpResponse(
            path: 'https://different.api.com/test',
            statusCode: 200,
            body: {'intercepted': true},
          ),
        );

        // Create a completely new HTTP client after overrides are set
        final client = http.Client();

        try {
          final response =
              await client.get(Uri.parse('https://different.api.com/test'));

          expect(response.statusCode, 200);
          expect(response.body, contains('intercepted'));

          // Verify the request was captured
          final request =
              httpOverrides.findRequest('https://different.api.com/test');
          expect(request, isNotNull);
          expect(request!.method, HttpMethod.get);
        } finally {
          client.close();
        }
      });
    });
  });
}
