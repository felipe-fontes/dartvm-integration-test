import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test_mock/tester/tester_interface.dart';
import 'package:patrol_finders/patrol_finders.dart';

class PatrolImpl implements ITester {
  PatrolImpl(this.patrolTester);

  final PatrolTester patrolTester;

  @override
  WidgetTester get tester => patrolTester.tester;

  @override
  Finder call(dynamic symbol) {
    final finder = patrolTester.call(symbol);
    debugPrint('🔍 [PatrolFinder] $symbol -> ${finder.toString()}');
    return finder;
  }

  @override
  Future<void> pumpWidgetAndSettle(
    Widget widget, {
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    Duration? timeout,
  }) async {
    await patrolTester.pumpWidgetAndSettle(
      widget,
      duration: duration,
      phase: phase,
      timeout: timeout,
    );
  }

  @override
  Future<Finder> scrollUntilVisible({
    required Finder matcher,
    AxisDirection? direction,
    SettlePolicy? settlePolicy,
  }) async {
    debugPrint(
        '🔄 [PatrolAction] Scrolling until visible: $matcher (direction: ${direction ?? AxisDirection.down})');
    final finder = await patrolTester.scrollUntilVisible(
      scrollDirection: direction ?? AxisDirection.down,
      finder: matcher,
      settlePolicy: settlePolicy ?? SettlePolicy.noSettle,
    );
    return finder;
  }

  @override
  Future<void> pump([
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]) async {
    debugPrint(
        '⏳ [PatrolAction] Pumping${duration != null ? ' for $duration' : ''}');
    await patrolTester.pump(duration, phase);
  }

  @override
  Future<void> pumpAndSettle({
    Duration duration = const Duration(milliseconds: 100),
    Duration? timeout,
  }) async {
    debugPrint(
        '⏳ [PatrolAction] Pumping and settling${timeout != null ? ' (timeout: $timeout)' : ''}');
    await patrolTester.pumpAndSettle(duration: duration);
  }

  @override
  Future<Finder> waitUntilVisible(
    Finder finder, {
    Duration? timeout,
    Alignment alignment = Alignment.center,
  }) async {
    debugPrint(
        '⏳ [PatrolAction] Waiting for widget to become visible: $finder${timeout != null ? ' (timeout: $timeout)' : ''}');
    final result = await patrolTester.waitUntilVisible(finder,
        timeout: timeout, alignment: alignment);
    return result;
  }

  @override
  Future<void> tap(
    Finder finder, {
    SettlePolicy? settlePolicy,
    Duration? visibleTimeout,
    Duration? settleTimeout,
  }) async {
    debugPrint('👆 [PatrolAction] Tapping: $finder');
    await patrolTester.tap(
      finder,
      settlePolicy: settlePolicy,
      visibleTimeout: visibleTimeout,
      settleTimeout: settleTimeout,
    );
  }

  @override
  Future<void> enterText(
    Finder finder,
    String text, {
    SettlePolicy? settlePolicy,
    Duration? visibleTimeout,
    Duration? settleTimeout,
  }) async {
    debugPrint('⌨️ [PatrolAction] Entering text "$text" into: $finder');
    await patrolTester.enterText(
      finder,
      text,
      settlePolicy: settlePolicy,
      visibleTimeout: visibleTimeout,
      settleTimeout: settleTimeout,
    );
  }

  @override
  Future<void> pumpAndTrySettle({
    Duration duration = const Duration(milliseconds: 100),
    Duration? timeout,
    EnginePhase? phase = EnginePhase.sendSemanticsUpdate,
  }) async {
    await patrolTester.pumpAndTrySettle(
      duration: duration,
      timeout: timeout,
      phase: phase ?? EnginePhase.sendSemanticsUpdate,
    );
  }
}
