import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test_mock/network/integration_test_http_overrides.dart';


void main() {
  late IntegrationTestHttpOverrides httpOverrides;

  setUp(() {
    httpOverrides = IntegrationTestHttpOverrides();
    httpOverrides.addResponses([
      const IntegrationTestHttpResponse(
        path: '/api/permanent',
        statusCode: 200,
        body: {'message': 'permanent response'},
      ),
      const IntegrationTestHttpResponse(
        path: '/api/with-query?param=value',
        statusCode: 200,
        body: {'message': 'specific query response'},
      ),
      const IntegrationTestHttpResponse(
        path: '/api/ignore-query',
        statusCode: 200,
        body: {'message': 'ignore query response'},
        ignoreQuery: true,
      ),
    ]);
    HttpOverrides.global = httpOverrides;
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  group('TesterHttpOverrides', () {
    group('Basic response handling', () {
      test('should return permanent response', () async {
        final response = await http.get(Uri.parse('http://test.com/api/permanent'));

        expect(response.statusCode, 200);
        expect(response.body, '{"message":"permanent response"}');
      });

      test('should return 404 for unknown endpoint', () async {
        final response = await http.get(Uri.parse('http://test.com/api/unknown'));

        expect(response.statusCode, 404);
        expect(response.body.contains('Mock response not found'), true);
      });

      test('should handle custom headers', () async {
        httpOverrides.addResponse(
          const IntegrationTestHttpResponse(
            path: '/api/headers',
            statusCode: 200,
            body: {'message': 'test'},
            headers: {
              'x-custom-header': 'test-value',
              'authorization': 'Bearer token',
            },
          ),
        );

        final response = await http.get(Uri.parse('http://test.com/api/headers'));
        expect(response.headers['x-custom-header'], 'test-value');
        expect(response.headers['authorization'], 'Bearer token');
      });
    });

    group('Query string handling', () {
      test('should match exact query string', () async {
        final response = await http.get(
          Uri.parse('http://test.com/api/with-query?param=value'),
        );

        expect(response.statusCode, 200);
        expect(response.body, '{"message":"specific query response"}');
      });

      test('should not match different query string when ignoreQuery is false', () async {
        final response = await http.get(
          Uri.parse('http://test.com/api/with-query?param=different'),
        );

        expect(response.statusCode, 404);
      });

      test('should match any query string when ignoreQuery is true', () async {
        final response = await http.get(
          Uri.parse('http://test.com/api/ignore-query?any=param'),
        );

        expect(response.statusCode, 200);
        expect(response.body, '{"message":"ignore query response"}');
      });
    });

    group('Response queue management', () {
      test('should use queued response before permanent response', () async {
        httpOverrides.queueResponse(
          const IntegrationTestHttpResponse(
            path: '/api/permanent',
            statusCode: 201,
            body: {'message': 'queued response'},
          ),
        );

        final firstResponse = await http.get(Uri.parse('http://test.com/api/permanent'));
        expect(firstResponse.statusCode, 201);
        expect(firstResponse.body, '{"message":"queued response"}');

        final secondResponse = await http.get(Uri.parse('http://test.com/api/permanent'));
        expect(secondResponse.statusCode, 200);
        expect(secondResponse.body, '{"message":"permanent response"}');
      });

      test('should handle multiple queued responses in order', () async {
        httpOverrides.queueResponse(
          const IntegrationTestHttpResponse(
            path: '/api/test',
            statusCode: 200,
            body: {'message': 'first'},
          ),
        );
        httpOverrides.queueResponse(
          const IntegrationTestHttpResponse(
            path: '/api/test',
            statusCode: 200,
            body: {'message': 'second'},
          ),
        );

        final firstResponse = await http.get(Uri.parse('http://test.com/api/test'));
        expect(firstResponse.body, '{"message":"first"}');

        final secondResponse = await http.get(Uri.parse('http://test.com/api/test'));
        expect(secondResponse.body, '{"message":"second"}');

        final thirdResponse = await http.get(Uri.parse('http://test.com/api/test'));
        expect(thirdResponse.statusCode, 404);
      });

      test('should replace all queued responses with replaceResponse', () async {
        httpOverrides.queueResponse(
          const IntegrationTestHttpResponse(
            path: '/api/test',
            statusCode: 200,
            body: {'message': 'first'},
          ),
        );
        httpOverrides.queueResponse(
          const IntegrationTestHttpResponse(
            path: '/api/test',
            statusCode: 200,
            body: {'message': 'second'},
          ),
        );

        httpOverrides.replaceResponse(
          const IntegrationTestHttpResponse(
            path: '/api/test',
            statusCode: 200,
            body: {'message': 'replaced'},
          ),
        );

        final response = await http.get(Uri.parse('http://test.com/api/test'));
        expect(response.body, '{"message":"replaced"}');
      });
    });

    group('Response body manipulation', () {
      test('should merge response body with bodyMerge', () async {
        const originalResponse = IntegrationTestHttpResponse(
          path: '/api/merge',
          statusCode: 200,
          body: {
            'data': {'id': 1, 'name': 'original'},
            'status': 'ok',
          },
        );

        httpOverrides.addResponse(originalResponse);

        final modifiedResponse = originalResponse.withOverrides(
          bodyMerge: {
            'data': {'name': 'modified'},
          },
        );

        httpOverrides.queueResponse(modifiedResponse);

        final response = await http.get(Uri.parse('http://test.com/api/merge'));
        expect(
          response.body,
          '{"data":{"id":1,"name":"modified"},"status":"ok"}',
        );
      });
    });

    group('Request verification', () {
      setUp(() {
        httpOverrides.clearRequests();
      });

      group('Request tracking', () {
        test('should find all matching requests', () async {
          await http.get(Uri.parse('http://test.com/api/permanent'));
          await http.get(Uri.parse('http://test.com/api/permanent'));
          await http.post(Uri.parse('http://test.com/api/permanent'));

          final allRequests = httpOverrides.findAllRequests('/api/permanent');
          expect(allRequests.length, 3);

          final getRequests =
              httpOverrides.findAllRequests('/api/permanent', method: HttpMethod.get);
          expect(getRequests.length, 2);

          final postRequests =
              httpOverrides.findAllRequests('/api/permanent', method: HttpMethod.post);
          expect(postRequests.length, 1);
        });

        test('should clear request history', () async {
          await http.get(Uri.parse('http://test.com/api/permanent'));
          expect(httpOverrides.requests.length, 1);

          httpOverrides.clearRequests();
          expect(httpOverrides.requests.length, 0);
        });

        test('should return null for non-existent request', () async {
          final request = httpOverrides.findRequest('/non-existent');
          expect(request, isNull);
        });
      });

      group('Request details capture', () {
        test('should capture GET request details', () async {
          await http.get(
            Uri.parse('http://test.com/api/permanent'),
            headers: {'custom-header': 'test-value'},
          );

          final request = httpOverrides.findRequest('/api/permanent', method: HttpMethod.get);
          expect(request, isNotNull);
          expect(request!.method, HttpMethod.get);
          expect(request.path, contains('/api/permanent'));
          expect(request.headers!['custom-header'], 'test-value');
          expect(request.body, isNull);
        });

        test('should capture request with query parameters', () async {
          await http.get(Uri.parse('http://test.com/api/test?param=value&other=123'));

          final request = httpOverrides.findRequest('/api/test');
          expect(request, isNotNull);
          expect(request!.path, contains('param=value'));
          expect(request.path, contains('other=123'));
        });
      });

      group('Request body handling', () {
        test('should capture POST request with body', () async {
          final body = {'test': 'value'};
          final debugOutput = StringBuffer();

          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 200,
              body: {'status': 'ok'},
            ),
          );

          debugOutput.writeln('\n=== Starting POST request test ===');

          final response = await http.post(
            Uri.parse('http://test.com/api/test'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          );

          debugOutput.writeln('Response status: ${response.statusCode}');
          debugOutput.writeln('Response body: ${response.body}');
          debugOutput.writeln('Response headers: ${response.headers}');

          final capturedRequest = httpOverrides.findRequest('/api/test', method: HttpMethod.post);

          debugOutput.writeln('Captured request: $capturedRequest');
          if (capturedRequest != null) {
            debugOutput.writeln('Captured method: ${capturedRequest.method}');
            debugOutput.writeln('Captured path: ${capturedRequest.path}');
            debugOutput.writeln('Captured body: ${capturedRequest.body}');
            debugOutput.writeln('Captured headers: ${capturedRequest.headers}');
          }

          printOnFailure(debugOutput.toString());

          expect(capturedRequest, isNotNull);
          expect(capturedRequest!.method, HttpMethod.post);
          expect(capturedRequest.path, contains('/api/test'));
          expect(capturedRequest.body, equals(body));
        });

        test('should handle form-encoded body', () async {
          httpOverrides.addResponse(const IntegrationTestHttpResponse(
            path: '/api/form',
            statusCode: 200,
            body: {'status': 'ok'},
          ));

          final formData = {'key1': 'value1', 'key2': 'value2'};
          await http.post(
            Uri.parse('http://test.com/api/form'),
            headers: {'content-type': 'application/x-www-form-urlencoded'},
            body: formData,
          );

          final capturedRequest = httpOverrides.findRequest('/api/form', method: HttpMethod.post);
          expect(capturedRequest, isNotNull);
          expect(capturedRequest!.body, equals(formData));
        });

        test('should handle empty body', () async {
          httpOverrides.addResponse(const IntegrationTestHttpResponse(
            path: '/api/empty',
            statusCode: 200,
            body: {'status': 'ok'},
          ));

          await http.post(
            Uri.parse('http://test.com/api/empty'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({}),
          );

          final capturedRequest = httpOverrides.findRequest('/api/empty', method: HttpMethod.post);
          expect(capturedRequest, isNotNull);
          expect(capturedRequest!.body, isNull);
        });

        test('should handle complex JSON body', () async {
          httpOverrides.addResponse(const IntegrationTestHttpResponse(
            path: '/api/complex',
            statusCode: 200,
            body: {'status': 'ok'},
          ));

          final complexBody = {
            'string': 'value',
            'number': 42,
            'boolean': true,
            'array': [1, 2, 3],
            'nested': {
              'key': 'value',
              'list': ['a', 'b', 'c'],
              'object': {'inner': 'value'}
            }
          };

          await http.post(
            Uri.parse('http://test.com/api/complex'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(complexBody),
          );

          final capturedRequest =
              httpOverrides.findRequest('/api/complex', method: HttpMethod.post);
          expect(capturedRequest, isNotNull);
          expect(capturedRequest!.body, equals(complexBody));
        });

        test('should handle malformed JSON body', () async {
          httpOverrides.addResponse(const IntegrationTestHttpResponse(
            path: '/api/malformed',
            statusCode: 200,
            body: {'status': 'ok'},
          ));

          await http.post(
            Uri.parse('http://test.com/api/malformed'),
            headers: {'content-type': 'application/json'},
            body: '{invalid json}',
          );

          final capturedRequest =
              httpOverrides.findRequest('/api/malformed', method: HttpMethod.post);
          expect(capturedRequest, isNotNull);
          expect(capturedRequest!.body, isNull);
        });
      });

      group('HTTP methods', () {
        test('should handle different HTTP methods for the same path', () async {
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/users',
              statusCode: 200,
              body: {'message': 'get response'},
              method: HttpMethod.get,
            ),
          );

          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/users',
              statusCode: 201,
              body: {'message': 'post response'},
              method: HttpMethod.post,
            ),
          );

          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/users',
              statusCode: 200,
              body: {'message': 'put response'},
              method: HttpMethod.put,
            ),
          );

          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/users',
              statusCode: 200,
              body: {'message': 'patch response'},
              method: HttpMethod.patch,
            ),
          );

          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/users',
              statusCode: 204,
              body: null,
              method: HttpMethod.delete,
            ),
          );

          // Test GET request
          final getResponse = await http.get(Uri.parse('http://test.com/api/users'));
          expect(getResponse.statusCode, 200);
          expect(getResponse.body, '{"message":"get response"}');

          // Test POST request
          final postResponse = await http.post(Uri.parse('http://test.com/api/users'));
          expect(postResponse.statusCode, 201);
          expect(postResponse.body, '{"message":"post response"}');

          // Test PUT request
          final putResponse = await http.put(Uri.parse('http://test.com/api/users'));
          expect(putResponse.statusCode, 200);
          expect(putResponse.body, '{"message":"put response"}');

          // Test PATCH request
          final patchResponse = await http.patch(Uri.parse('http://test.com/api/users'));
          expect(patchResponse.statusCode, 200);
          expect(patchResponse.body, '{"message":"patch response"}');

          // Test DELETE request
          final deleteResponse = await http.delete(Uri.parse('http://test.com/api/users'));
          expect(deleteResponse.statusCode, 204);
          expect(deleteResponse.body, 'null');
        });

        test('should match any HTTP method when method is not specified', () async {
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/any-method',
              statusCode: 200,
              body: {'message': 'any method response'},
            ),
          );

          // Test GET request
          final getResponse = await http.get(Uri.parse('http://test.com/api/any-method'));
          expect(getResponse.statusCode, 200);
          expect(getResponse.body, '{"message":"any method response"}');

          // Test POST request
          final postResponse = await http.post(Uri.parse('http://test.com/api/any-method'));
          expect(postResponse.statusCode, 200);
          expect(postResponse.body, '{"message":"any method response"}');

          // Test PUT request
          final putResponse = await http.put(Uri.parse('http://test.com/api/any-method'));
          expect(putResponse.statusCode, 200);
          expect(putResponse.body, '{"message":"any method response"}');

          // Test PATCH request
          final patchResponse = await http.patch(Uri.parse('http://test.com/api/any-method'));
          expect(patchResponse.statusCode, 200);
          expect(patchResponse.body, '{"message":"any method response"}');

          // Test DELETE request
          final deleteResponse = await http.delete(Uri.parse('http://test.com/api/any-method'));
          expect(deleteResponse.statusCode, 200);
          expect(deleteResponse.body, '{"message":"any method response"}');
        });

        test('should prioritize method-specific responses over method-agnostic ones', () async {
          // Add a method-agnostic response
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/priority',
              statusCode: 200,
              body: {'message': 'any method response'},
            ),
          );

          // Add a method-specific response
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/priority',
              statusCode: 201,
              body: {'message': 'get specific response'},
              method: HttpMethod.get,
            ),
          );

          // Test GET request - should use method-specific response
          final getResponse = await http.get(Uri.parse('http://test.com/api/priority'));
          expect(getResponse.statusCode, 201);
          expect(getResponse.body, '{"message":"get specific response"}');

          // Test POST request - should use method-agnostic response
          final postResponse = await http.post(Uri.parse('http://test.com/api/priority'));
          expect(postResponse.statusCode, 200);
          expect(postResponse.body, '{"message":"any method response"}');
        });

        test('should handle queued responses with different HTTP methods', () async {
          httpOverrides.queueResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 200,
              body: {'message': 'first get'},
              method: HttpMethod.get,
            ),
          );

          httpOverrides.queueResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 201,
              body: {'message': 'first post'},
              method: HttpMethod.post,
            ),
          );

          // Test GET request
          final getResponse = await http.get(Uri.parse('http://test.com/api/test'));
          expect(getResponse.statusCode, 200);
          expect(getResponse.body, '{"message":"first get"}');

          // Test POST request
          final postResponse = await http.post(Uri.parse('http://test.com/api/test'));
          expect(postResponse.statusCode, 201);
          expect(postResponse.body, '{"message":"first post"}');

          // Both methods should now return 404 as queued responses are consumed
          final secondGetResponse = await http.get(Uri.parse('http://test.com/api/test'));
          expect(secondGetResponse.statusCode, 404);

          final secondPostResponse = await http.post(Uri.parse('http://test.com/api/test'));
          expect(secondPostResponse.statusCode, 404);
        });

        test('should handle replaceResponse with different HTTP methods', () async {
          // Add initial responses
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 200,
              body: {'message': 'permanent get'},
              method: HttpMethod.get,
            ),
          );

          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 201,
              body: {'message': 'permanent post'},
              method: HttpMethod.post,
            ),
          );

          // Replace GET response
          httpOverrides.replaceResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 200,
              body: {'message': 'replaced get'},
              method: HttpMethod.get,
            ),
          );

          // Replace POST response
          httpOverrides.replaceResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 201,
              body: {'message': 'replaced post'},
              method: HttpMethod.post,
            ),
          );

          // Test GET request
          final getResponse = await http.get(Uri.parse('http://test.com/api/test'));
          expect(getResponse.statusCode, 200);
          expect(getResponse.body, '{"message":"replaced get"}');

          // Test POST request
          final postResponse = await http.post(Uri.parse('http://test.com/api/test'));
          expect(postResponse.statusCode, 201);
          expect(postResponse.body, '{"message":"replaced post"}');
        });

        test('should handle method-specific responses with query parameters', () async {
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/search',
              statusCode: 200,
              body: {'message': 'get search'},
              method: HttpMethod.get,
            ),
          );

          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/search',
              statusCode: 200,
              body: {'message': 'post search'},
              ignoreQuery: true,
              method: HttpMethod.post,
            ),
          );

          // Test GET with query
          final getResponse = await http.get(
            Uri.parse('http://test.com/api/search?q=test'),
          );
          expect(getResponse.statusCode, 404); // Should not match exact query

          // Test POST with query
          final postResponse = await http.post(
            Uri.parse('http://test.com/api/search?q=test'),
          );
          expect(postResponse.statusCode, 200);
          expect(postResponse.body, '{"message":"post search"}');
        });

        test('should handle same endpoint with and without method specification', () async {
          // Add a method-agnostic response
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 200,
              body: {'message': 'any method response'},
            ),
          );

          // Add a GET-specific response for the same endpoint
          httpOverrides.addResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 201,
              body: {'message': 'get specific response'},
              method: HttpMethod.get,
            ),
          );

          // Test GET request - should use method-specific response
          final getResponse = await http.get(Uri.parse('http://test.com/api/test'));
          expect(getResponse.statusCode, 201);
          expect(getResponse.body, '{"message":"get specific response"}');

          // Test POST request - should use method-agnostic response
          final postResponse = await http.post(Uri.parse('http://test.com/api/test'));
          expect(postResponse.statusCode, 200);
          expect(postResponse.body, '{"message":"any method response"}');

          // Test PUT request - should use method-agnostic response
          final putResponse = await http.put(Uri.parse('http://test.com/api/test'));
          expect(putResponse.statusCode, 200);
          expect(putResponse.body, '{"message":"any method response"}');

          // Test DELETE request - should use method-agnostic response
          final deleteResponse = await http.delete(Uri.parse('http://test.com/api/test'));
          expect(deleteResponse.statusCode, 200);
          expect(deleteResponse.body, '{"message":"any method response"}');
        });

        test(
            'should handle queued responses with method-specific and method-agnostic for same endpoint',
            () async {
          // Queue a method-agnostic response
          httpOverrides.queueResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 200,
              body: {'message': 'queued any method'},
            ),
          );

          // Queue a GET-specific response
          httpOverrides.queueResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 201,
              body: {'message': 'queued get specific'},
              method: HttpMethod.get,
            ),
          );

          // Queue another method-agnostic response
          httpOverrides.queueResponse(
            const IntegrationTestHttpResponse(
              path: '/api/test',
              statusCode: 202,
              body: {'message': 'queued any method 2'},
            ),
          );

          // Test GET request - should use method-specific response
          final getResponse = await http.get(Uri.parse('http://test.com/api/test'));
          expect(getResponse.statusCode, 201);
          expect(getResponse.body, '{"message":"queued get specific"}');

          // Test POST request - should use first method-agnostic response
          final postResponse = await http.post(Uri.parse('http://test.com/api/test'));
          expect(postResponse.statusCode, 200);
          expect(postResponse.body, '{"message":"queued any method"}');

          // Test PUT request - should use second method-agnostic response
          final putResponse = await http.put(Uri.parse('http://test.com/api/test'));
          expect(putResponse.statusCode, 202);
          expect(putResponse.body, '{"message":"queued any method 2"}');

          // Test DELETE request - should return 404 as all queued responses are consumed
          final deleteResponse = await http.delete(Uri.parse('http://test.com/api/test'));
          expect(deleteResponse.statusCode, 404);
        });
      });
    });

    group('Response delay handling', () {
      test('should respect delay in permanent response', () async {
        final stopwatch = Stopwatch()..start();

        httpOverrides.addResponse(
          IntegrationTestHttpResponse(
            path: '/api/delayed',
            statusCode: 200,
            body: {'message': 'delayed response'},
            delay: const Duration(milliseconds: 500),
          ),
        );

        final response = await http.get(Uri.parse('http://test.com/api/delayed'));
        stopwatch.stop();

        expect(response.statusCode, 200);
        expect(response.body, '{"message":"delayed response"}');
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(500));
      });

      test('should respect delay in queued response', () async {
        final stopwatch = Stopwatch()..start();

        httpOverrides.queueResponse(
          IntegrationTestHttpResponse(
            path: '/api/delayed-queue',
            statusCode: 200,
            body: {'message': 'delayed queue response'},
            delay: const Duration(milliseconds: 300),
          ),
        );

        final response = await http.get(Uri.parse('http://test.com/api/delayed-queue'));
        stopwatch.stop();

        expect(response.statusCode, 200);
        expect(response.body, '{"message":"delayed queue response"}');
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(300));
      });

      test('should override delay with withOverrides', () async {
        final originalResponse = IntegrationTestHttpResponse(
          path: '/api/delay-override',
          statusCode: 200,
          body: {'message': 'original'},
          delay: const Duration(milliseconds: 1000),
        );

        final modifiedResponse = originalResponse.withOverrides(
          delayOverride: const Duration(milliseconds: 200),
        );

        httpOverrides.queueResponse(modifiedResponse);

        final stopwatch = Stopwatch()..start();
        final response = await http.get(Uri.parse('http://test.com/api/delay-override'));
        stopwatch.stop();

        expect(response.statusCode, 200);
        expect(response.body, '{"message":"original"}');
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(200));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('should handle multiple delayed responses in sequence', () async {
        final stopwatch = Stopwatch()..start();

        httpOverrides.queueResponse(
          IntegrationTestHttpResponse(
            path: '/api/sequence',
            statusCode: 200,
            body: {'message': 'first'},
            delay: const Duration(milliseconds: 200),
          ),
        );

        httpOverrides.queueResponse(
          IntegrationTestHttpResponse(
            path: '/api/sequence',
            statusCode: 200,
            body: {'message': 'second'},
            delay: const Duration(milliseconds: 300),
          ),
        );

        final firstResponse = await http.get(Uri.parse('http://test.com/api/sequence'));
        final firstElapsed = stopwatch.elapsedMilliseconds;

        final secondResponse = await http.get(Uri.parse('http://test.com/api/sequence'));
        final secondElapsed = stopwatch.elapsedMilliseconds - firstElapsed;

        stopwatch.stop();

        expect(firstResponse.body, '{"message":"first"}');
        expect(secondResponse.body, '{"message":"second"}');
        expect(firstElapsed, greaterThanOrEqualTo(200));
        expect(secondElapsed, greaterThanOrEqualTo(300));
      });

      test('should not delay when delay is null', () async {
        final stopwatch = Stopwatch()..start();

        httpOverrides.addResponse(
          const IntegrationTestHttpResponse(
            path: '/api/no-delay',
            statusCode: 200,
            body: {'message': 'immediate response'},
          ),
        );

        final response = await http.get(Uri.parse('http://test.com/api/no-delay'));
        stopwatch.stop();

        expect(response.statusCode, 200);
        expect(response.body, '{"message":"immediate response"}');
        expect(
            stopwatch.elapsedMilliseconds, lessThan(100)); // Allow some buffer for execution time
      });
    });
  });
}
