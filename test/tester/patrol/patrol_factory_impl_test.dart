import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/tester/patrol/patrol_factory_impl.dart';
import 'package:patrol_finders/patrol_finders.dart';

void main() {
  group('PatrolImpl waitUntilVisible', () {
    testWidgets(
        'should throw timeout exception when widget never becomes visible',
        (WidgetTester tester) async {
      // Create a test PatrolTester
      final patrolTester = PatrolTester(
        tester: tester,
        config: const PatrolTesterConfig(
          settlePolicy: SettlePolicy.noSettle,
        ),
      );
      final patrolImpl = PatrolImpl(patrolTester);

      // Create a finder that will never find anything
      final nonExistentFinder =
          find.byKey(const ValueKey('non_existent_widget'));

      // Act & Assert
      expect(
        () async => await patrolImpl.waitUntilVisible(
          nonExistentFinder,
          timeout: const Duration(milliseconds: 200),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Timeout waiting for widget to become visible'),
        )),
      );
    });

    testWidgets('should use default timeout when none provided',
        (WidgetTester tester) async {
      // Create a test PatrolTester
      final patrolTester = PatrolTester(
        tester: tester,
        config: const PatrolTesterConfig(
          settlePolicy: SettlePolicy.noSettle,
        ),
      );
      final patrolImpl = PatrolImpl(patrolTester);

      // Create a finder that will never find anything
      final nonExistentFinder =
          find.byKey(const ValueKey('non_existent_widget'));

      // Act & Assert - This test uses a very short timeout to avoid long test runs
      final stopwatch = Stopwatch()..start();

      try {
        await patrolImpl.waitUntilVisible(nonExistentFinder);
        fail('Expected exception to be thrown');
      } catch (e) {
        stopwatch.stop();
        expect(e.toString(),
            contains('Timeout waiting for widget to become visible'));
        expect(
            e.toString(), contains('after 100 attempts over 0:00:10.000000'));
        // Should have waited for some time (at least a few milliseconds)
        expect(stopwatch.elapsedMilliseconds, greaterThan(0));
      }
    });

    testWidgets('should return finder when widget becomes visible',
        (WidgetTester tester) async {
      // Create a test widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Visible Widget'),
                Container(
                  key: const ValueKey('test_widget'),
                  height: 100,
                  width: 100,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
      );

      // Create PatrolTester and PatrolImpl
      final patrolTester = PatrolTester(
        tester: tester,
        config: const PatrolTesterConfig(
          settlePolicy: SettlePolicy.noSettle,
        ),
      );
      final patrolImpl = PatrolImpl(patrolTester);

      // Create a finder for the visible widget
      final visibleFinder = find.byKey(const ValueKey('test_widget'));

      // Act
      final result = await patrolImpl.waitUntilVisible(
        visibleFinder,
        timeout: const Duration(seconds: 2),
      );

      // Assert
      expect(result, equals(visibleFinder));
      expect(result.evaluate().length, equals(1));
    });

    testWidgets('should respect custom timeout duration',
        (WidgetTester tester) async {
      // Create a test PatrolTester
      final patrolTester = PatrolTester(
        tester: tester,
        config: const PatrolTesterConfig(
          settlePolicy: SettlePolicy.noSettle,
        ),
      );
      final patrolImpl = PatrolImpl(patrolTester);

      // Create a finder that will never find anything
      final nonExistentFinder =
          find.byKey(const ValueKey('non_existent_widget'));
      final customTimeout = const Duration(milliseconds: 300);

      final stopwatch = Stopwatch()..start();

      // Act & Assert
      try {
        await patrolImpl.waitUntilVisible(
          nonExistentFinder,
          timeout: customTimeout,
        );
        fail('Expected exception to be thrown');
      } catch (e) {
        stopwatch.stop();
        expect(e.toString(),
            contains('Timeout waiting for widget to become visible'));
        expect(e.toString(),
            contains('after 3 attempts over ${customTimeout.toString()}'));
      }
    });

    testWidgets('should handle widget that exists and becomes hittestable',
        (WidgetTester tester) async {
      // Create a widget that exists and should be hittestable
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              key: const ValueKey('visible_widget'),
              height: 100,
              width: 100,
              color: Colors.red,
              child: const Text('Visible'),
            ),
          ),
        ),
      );

      final patrolTester = PatrolTester(
        tester: tester,
        config: const PatrolTesterConfig(
          settlePolicy: SettlePolicy.noSettle,
        ),
      );
      final patrolImpl = PatrolImpl(patrolTester);

      final visibleFinder = find.byKey(const ValueKey('visible_widget'));

      // This should work as the widget exists and is hittestable
      final result = await patrolImpl.waitUntilVisible(
        visibleFinder,
        timeout: const Duration(seconds: 1),
      );

      expect(result, equals(visibleFinder));
      expect(result.evaluate().length, equals(1));
    });
  });

  group('PatrolImpl basic functionality', () {
    testWidgets('should expose PatrolTester through tester getter',
        (WidgetTester tester) async {
      final patrolTester = PatrolTester(
        tester: tester,
        config: const PatrolTesterConfig(
          settlePolicy: SettlePolicy.noSettle,
        ),
      );
      final patrolImpl = PatrolImpl(patrolTester);

      expect(patrolImpl.tester, equals(tester));
    });

    testWidgets('should delegate call method to PatrolTester',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              key: const ValueKey('test_key'),
              child: const Text('Test Widget'),
            ),
          ),
        ),
      );

      final patrolTester = PatrolTester(
        tester: tester,
        config: const PatrolTesterConfig(
          settlePolicy: SettlePolicy.noSettle,
        ),
      );
      final patrolImpl = PatrolImpl(patrolTester);

      // Test calling with a key
      final finder = patrolImpl(const ValueKey('test_key'));
      expect(finder.evaluate().length, equals(1));

      // Test calling with a string
      final textFinder = patrolImpl('Test Widget');
      expect(textFinder.evaluate().length, equals(1));
    });
  });
}
