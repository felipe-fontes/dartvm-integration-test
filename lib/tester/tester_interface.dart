import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test_mock/tester/binding_aware_pump.dart';
import 'package:patrol_finders/patrol_finders.dart';

abstract class ITester {
  Future<void> pumpWidgetAndSettle(
    Widget widget, {
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    Duration? timeout,
  });
  Finder call(dynamic finder);

  Future<Finder> scrollUntilVisible({
    required Finder matcher,
    AxisDirection? direction,
    SettlePolicy? settlePolicy,
  });

  Future<void> pump([
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]);

  Future<void> pumpAndSettle({
    Duration duration = const Duration(milliseconds: 100),
    Duration? timeout,
  });

  Future<Finder> waitUntilVisible(
    Finder finder, {
    Duration? timeout,
    Alignment alignment = Alignment.center,
    Duration? settleDuration,
  });

  /// Pumps for a total [duration], advancing time in steps.
  ///
  /// Works in both automated (fake async) and live/preview (real async)
  /// bindings. Use after a widget is visible to let animations/loading
  /// settle, or to drain pending timers at the end of a test.
  Future<void> pumpFor(Duration duration, {Duration step});

  Future<void> tap(
    Finder finder, {
    SettlePolicy? settlePolicy,
    Duration? visibleTimeout,
    Duration? settleTimeout,
  });

  WidgetTester get tester;

  Future<void> enterText(
    Finder finder,
    String text, {
    SettlePolicy? settlePolicy,
    Duration? visibleTimeout,
    Duration? settleTimeout,
  });

  Future<void> pumpAndTrySettle({
    Duration duration = const Duration(milliseconds: 100),
    Duration? timeout,
    EnginePhase? phase = EnginePhase.sendSemanticsUpdate,
  });
}

abstract class IFinder extends Finder {}

extension SymbolExtension on Symbol {
  String name() {
    final name = toString().replaceAll('Symbol("', '').replaceAll('")', '');
    return name;
  }
}
