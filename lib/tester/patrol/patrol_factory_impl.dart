import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/tester/binding_aware_pump.dart';
import 'package:dartvm_integration_tests/tester/tester_interface.dart';
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
      settlePolicy: settlePolicy,
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
    Duration? settleDuration,
  }) async {
    final effectiveTimeout = timeout ?? const Duration(seconds: 10);
    final live = isLiveBinding;
    debugPrint('⏳ [PatrolAction] Waiting for widget to become visible: $finder '
        '(timeout: $effectiveTimeout, liveBinding: $live)');

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < effectiveTimeout) {
      // Drain stray async exceptions early so they don't silently corrupt
      // test state (critical for PreviewTestBinding).
      drainAndRethrowException(patrolTester.tester);

      // Check if widget exists and is visible/hittestable.
      if (finder.evaluate().isNotEmpty) {
        final hittestable = finder.hitTestable();
        if (hittestable.evaluate().isNotEmpty) {
          debugPrint('✅ [PatrolAction] Widget became visible after '
              '${stopwatch.elapsed}: $finder');
          if (settleDuration != null) {
            debugPrint('⏳ [PatrolAction] Settling for $settleDuration...');
            await pumpForDuration(patrolTester.tester,
                duration: settleDuration);
          }
          return finder;
        }
      }

      // Pump in a binding-aware way:
      // - AutomatedTestWidgetsFlutterBinding: pump(100ms) advances the fake clock
      // - Live/Preview bindings: pump() renders immediately, real async progresses
      await bindingAwarePump(patrolTester.tester);
    }

    final timeoutMessage =
        'Timeout waiting for widget to become visible: $finder '
        'after ${stopwatch.elapsed}';
    debugPrint('❌ [PatrolAction] $timeoutMessage');
    throw Exception(timeoutMessage);
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

  @override
  Future<void> pumpFor(
    Duration duration, {
    Duration step = const Duration(milliseconds: 100),
  }) async {
    debugPrint('⏳ [PatrolAction] Pumping for $duration...');
    await pumpForDuration(patrolTester.tester, duration: duration, step: step);
  }
}
