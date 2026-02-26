import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/method_channels/base_method_channel_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestMethodChannel mock;
  late MethodChannel channel;

  setUp(() {
    mock = TestMethodChannel();
    channel = const MethodChannel('test.channel');
  });

  tearDown(() {
    mock.dispose();
  });

  test('handles default implementation', () async {
    final result = await channel.invokeMethod<String>('test');
    expect(result, 'default response');
  });

  group('queued responses', () {
    test('returns queued responses in order', () async {
      mock.queueResponse('test', 'first');
      mock.queueResponse('test', 'second');
      mock.queueResponse('test', 'third');

      expect(await channel.invokeMethod<String>('test'), 'first');
      expect(await channel.invokeMethod<String>('test'), 'second');
      expect(await channel.invokeMethod<String>('test'), 'third');
      // Falls back to default implementation after queue is empty
      expect(await channel.invokeMethod<String>('test'), 'default response');
    });

    test('handles multiple methods with separate queues', () async {
      mock.queueResponse('test', 'first1');
      mock.setPermanentResponse('test2', 'first2');
      mock.queueResponse('test', 'second1');

      expect(await channel.invokeMethod<String>('test'), 'first1');
      expect(await channel.invokeMethod<String>('test2'), 'first2');
      expect(await channel.invokeMethod<String>('test'), 'second1');
      // Falls back to default implementation
      expect(await channel.invokeMethod<String>('test'), 'default response');
    });

    test('clears queued responses', () async {
      mock.queueResponse('test', 'first');
      mock.queueResponse('test', 'second');

      mock.clearQueuedResponses('test');

      // Should fall back to default implementation
      expect(await channel.invokeMethod<String>('test'), 'default response');
    });

    test('handles complex data types', () async {
      final complexData = {
        'string': 'value',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'list': ['a', 'b', 'c'],
        'map': {'key': 'value'},
        'nested': {
          'array': [1, 2, 3],
          'object': {'nested': 'value'}
        }
      };

      mock.queueResponse('complex', complexData);
      final result = await channel.invokeMethod('complex');
      expect(result, complexData);
    });
  });

  group('permanent responses', () {
    test('returns permanent response consistently', () async {
      mock.setPermanentResponse('test', 'permanent');

      expect(await channel.invokeMethod<String>('test'), 'permanent');
      expect(await channel.invokeMethod<String>('test'), 'permanent');
      expect(await channel.invokeMethod<String>('test'), 'permanent');
    });

    test('permanent response takes precedence over default implementation', () async {
      mock.setPermanentResponse('test', 'permanent');
      expect(await channel.invokeMethod<String>('test'), 'permanent');
    });

    test('queued response takes precedence over permanent response', () async {
      mock.setPermanentResponse('test', 'permanent');
      mock.queueResponse('test', 'queued');

      expect(await channel.invokeMethod<String>('test'), 'queued');
      expect(await channel.invokeMethod<String>('test'), 'permanent');
    });

    test('clears permanent response', () async {
      mock.setPermanentResponse('test', 'permanent');
      mock.clearPermanentResponse('test');

      // Should fall back to default implementation
      expect(await channel.invokeMethod<String>('test'), 'default response');
    });
  });

  group('method arguments', () {
    test('handles method arguments correctly', () async {
      mock.setPermanentResponse('echo', (MethodCall call) {
        return call.arguments;
      });

      expect(
        await channel.invokeMethod('echo', 'test string'),
        'test string',
      );

      expect(
        await channel.invokeMethod('echo', 42),
        42,
      );

      expect(
        await channel.invokeMethod('echo', {'key': 'value'}),
        {'key': 'value'},
      );
    });

    test('can access method arguments in queued responses', () async {
      mock.queueResponse('sum', (MethodCall call) {
        final args = call.arguments as Map;
        return (args['a'] as int) + (args['b'] as int);
      });

      final result = await channel.invokeMethod<int>(
        'sum',
        {'a': 40, 'b': 2},
      );
      expect(result, 42);
    });
  });

  group('error handling', () {
    test('handles PlatformException for unimplemented methods', () async {
      expect(
        () => channel.invokeMethod<String>('unknown'),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'Unimplemented',
        )),
      );
    });

    test('can queue error responses', () async {
      mock.queueResponse(
        'test',
        PlatformException(code: 'ERROR', message: 'Test error'),
      );

      expect(
        () => channel.invokeMethod<String>('test'),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'ERROR',
        )),
      );
    });

    test('handles errors in dynamic responses', () async {
      mock.setPermanentResponse('divide', (MethodCall call) {
        final args = call.arguments as Map;
        final a = args['a'] as int;
        final b = args['b'] as int;
        if (b == 0) {
          throw PlatformException(
            code: 'DIVIDE_BY_ZERO',
            message: 'Cannot divide by zero',
          );
        }
        return a / b;
      });

      expect(
        await channel.invokeMethod('divide', {'a': 10, 'b': 2}),
        5.0,
      );

      expect(
        () => channel.invokeMethod('divide', {'a': 10, 'b': 0}),
        throwsA(isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'DIVIDE_BY_ZERO',
        )),
      );
    });
  });

  group('cleanup and disposal', () {
    test('clearAllPermanentResponses removes all permanent responses', () async {
      mock.setPermanentResponse('test1', 'permanent1');
      mock.setPermanentResponse('test2', 'permanent2');

      mock.clearAllPermanentResponses();

      // Should fall back to default implementation for both
      expect(await channel.invokeMethod<String>('test1'), 'default response');
      expect(await channel.invokeMethod<String>('test2'), 'default response');
    });

    test('clearAllQueuedResponses removes all queued responses', () async {
      mock.queueResponse('test1', 'queued1');
      mock.queueResponse('test2', 'queued2');

      mock.clearAllQueuedResponses();

      // Should fall back to default implementation for both
      expect(await channel.invokeMethod<String>('test1'), 'default response');
      expect(await channel.invokeMethod<String>('test2'), 'default response');
    });

    test('dispose clears handlers and responses', () async {
      mock.setPermanentResponse('test1', 'permanent');
      mock.queueResponse('test2', 'queued');

      await mock.dispose();

      // Should throw MissingPluginException after disposal
      expect(
        () => channel.invokeMethod<String>('test1'),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });

  group('advanced error handling', () {
    test('converts non-PlatformException errors to PlatformExceptions', () async {
      mock.setPermanentResponse('test', (MethodCall call) {
        throw StateError('Regular error');
      });

      expect(
        () => channel.invokeMethod<String>('test'),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'ERROR')
            .having((e) => e.message, 'message', contains('Regular error'))),
      );
    });

    test('handles null responses', () async {
      mock.setPermanentResponse('test', null);

      final result = await channel.invokeMethod('test');
      expect(result, null);
    });

    test('handles void return types', () async {
      mock.setPermanentResponse('test', (MethodCall call) => null);

      final result = await channel.invokeMethod('test');
      expect(result, null);
    });
  });

  group('edge cases', () {
    test('handles empty method names', () async {
      mock.setPermanentResponse('', 'response');
      expect(await channel.invokeMethod<String>(''), 'response');
    });

    test('handles special characters in method names', () async {
      mock.setPermanentResponse('test/special#@!', 'response');
      expect(await channel.invokeMethod<String>('test/special#@!'), 'response');
    });

    test('handles large payloads', () async {
      final largePayload = List.generate(10000, (i) => 'item$i');
      mock.setPermanentResponse('test', largePayload);
      final result = await channel.invokeMethod('test');
      expect(result, largePayload);
    });
  });

  group('type safety', () {
    test('handles type mismatches gracefully', () async {
      mock.setPermanentResponse('test', 42);

      expect(
        () => channel.invokeMethod<String>('test'),
        throwsA(isA<TypeError>()),
      );
    });

    test('handles dynamic type responses', () async {
      mock.setPermanentResponse('test', (MethodCall call) => 42);
      final result = await channel.invokeMethod('test');
      expect(result, 42);
    });
  });

  group('concurrent access', () {
    test('handles multiple simultaneous method calls', () async {
      mock.setPermanentResponse('test', (MethodCall call) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'response';
      });

      final futures = List.generate(
        5,
        (_) => channel.invokeMethod<String>('test'),
      );

      final results = await Future.wait(futures);
      expect(results, List.filled(5, 'response'));
    });

    test('maintains queue order under concurrent access', () async {
      for (var i = 0; i < 5; i++) {
        mock.queueResponse('test', 'response$i');
      }

      final futures = List.generate(
        5,
        (_) => channel.invokeMethod<String>('test'),
      );

      final results = await Future.wait(futures);
      for (var i = 0; i < 5; i++) {
        expect(results[i], 'response$i');
      }
    });
  });

  group('response chaining', () {
    test('handles mixed permanent and queued responses correctly', () async {
      mock.setPermanentResponse('test', 'permanent');
      mock.queueResponse('test', 'queued1');
      mock.queueResponse('test', 'queued2');

      expect(await channel.invokeMethod<String>('test'), 'queued1');
      expect(await channel.invokeMethod<String>('test'), 'queued2');
      expect(await channel.invokeMethod<String>('test'), 'permanent');
    });

    test('handles chained function responses', () async {
      var counter = 0;
      mock.setPermanentResponse('test', (MethodCall call) => ++counter);

      expect(await channel.invokeMethod('test'), 1);
      expect(await channel.invokeMethod('test'), 2);
      expect(await channel.invokeMethod('test'), 3);
    });
  });
}

/// Test implementation of a method channel mock
class TestMethodChannel extends BaseMethodChannelMock {
  TestMethodChannel()
      : super(
          methodChannel: const MethodChannel('test.channel'),
        );

  @override
  Future<dynamic> handleMethodCall(MethodCall call) async {
    if (call.method == 'test' || call.method == 'test1' || call.method == 'test2') {
      return 'default response';
    }
    return super.handleMethodCall(call);
  }
}
