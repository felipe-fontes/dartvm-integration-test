import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/tester/binding_aware_pump.dart';
import 'package:dartvm_integration_tests/tester/tester_interface.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Common configuration for [FlutterTestNativeImpl]
class FlutterTestNativeConfig {
  /// Creates a new [FlutterTestNativeConfig]
  const FlutterTestNativeConfig({
    this.existsTimeout = const Duration(seconds: 10),
    this.visibleTimeout = const Duration(seconds: 10),
    this.settleTimeout = const Duration(seconds: 10),
    this.settlePolicy = SettlePolicy.noSettle,
    this.dragDuration = const Duration(milliseconds: 100),
    this.settleBetweenScrollsTimeout = const Duration(seconds: 5),
  });

  /// Time after which [FlutterTestNativeImpl.waitUntilExists] fails if it doesn't find
  /// an existing widget.
  final Duration existsTimeout;

  /// Time after which [FlutterTestNativeImpl.waitUntilVisible] fails if it doesn't find
  /// a visible widget.
  final Duration visibleTimeout;

  /// Time after which [FlutterTestNativeImpl.pumpAndSettle] fails.
  final Duration settleTimeout;

  /// Defines which pump method should be called after actions
  final SettlePolicy settlePolicy;

  /// Time that it takes to perform drag gesture in scrolling methods
  final Duration dragDuration;

  /// Timeout used to settle in between drag gestures in scrolling methods
  final Duration settleBetweenScrollsTimeout;

  /// Creates a copy of this config but with the given fields replaced with the
  /// new values.
  FlutterTestNativeConfig copyWith({
    Duration? existsTimeout,
    Duration? visibleTimeout,
    Duration? settleTimeout,
    SettlePolicy? settlePolicy,
    Duration? dragDuration,
    Duration? settleBetweenScrollsTimeout,
  }) {
    return FlutterTestNativeConfig(
      existsTimeout: existsTimeout ?? this.existsTimeout,
      visibleTimeout: visibleTimeout ?? this.visibleTimeout,
      settleTimeout: settleTimeout ?? this.settleTimeout,
      settlePolicy: settlePolicy ?? this.settlePolicy,
      dragDuration: dragDuration ?? this.dragDuration,
      settleBetweenScrollsTimeout: settleBetweenScrollsTimeout ?? this.settleBetweenScrollsTimeout,
    );
  }
}

class FlutterTestNativeImpl implements ITester {
  FlutterTestNativeImpl(this._tester, {this.config = const FlutterTestNativeConfig()});

  final WidgetTester _tester;
  final FlutterTestNativeConfig config;

  @override
  WidgetTester get tester => _tester;

  @override
  Finder call(dynamic matching) {
    final finder = _find(matching);
    debugPrint('🔍 [NativeFinder] $matching -> ${finder.toString()}');
    return finder;
  }

  Finder _find(dynamic matcher) {
    if (matcher is Type) {
      return find.byType(matcher);
    }

    if (matcher is Key) {
      return find.byKey(matcher);
    }

    if (matcher is Symbol) {
      return find.byKey(Key(matcher.name()));
    }

    if (matcher is Finder) {
      return matcher;
    }

    if (matcher is String) {
      return find.text(matcher);
    }

    if (matcher is Widget) {
      return find.byWidget(matcher);
    }

    debugPrint('❌ [NativeFinder] Invalid matcher type: $matcher');
    throw Exception('Invalid matching type');
  }

  @override
  Future<void> pumpWidgetAndSettle(
    Widget widget, {
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    Duration? timeout,
  }) async {
    await _tester.pumpWidget(widget, duration: duration, phase: phase);
    await _performPump(settlePolicy: config.settlePolicy, settleTimeout: timeout ?? config.settleTimeout);
  }

  @override
  Future<Finder> scrollUntilVisible({
    required Finder matcher,
    AxisDirection? direction,
    SettlePolicy? settlePolicy,
  }) async {
    debugPrint('🔄 [NativeAction] Scrolling until visible: $matcher (direction: ${direction ?? AxisDirection.down})');
    final finder = _find(matcher);
    final scrollable = find.byType(Scrollable).first;
    final moveStep = _getScrollOffset(direction ?? AxisDirection.down);

    await _tester.dragUntilVisible(
      finder,
      scrollable,
      moveStep,
    );

    await _performPump(settlePolicy: settlePolicy ?? config.settlePolicy);
    return finder;
  }

  Offset _getScrollOffset(AxisDirection direction) {
    switch (direction) {
      case AxisDirection.up:
        return const Offset(0, 100);
      case AxisDirection.down:
        return const Offset(0, -100);
      case AxisDirection.left:
        return const Offset(100, 0);
      case AxisDirection.right:
        return const Offset(-100, 0);
    }
  }

  @override
  Future<void> pump([
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]) async {
    debugPrint('⏳ [NativeAction] Pumping${duration != null ? ' for $duration' : ''}');
    await _tester.pump(duration, phase);
  }

  @override
  Future<void> pumpAndSettle({
    Duration duration = const Duration(milliseconds: 100),
    Duration? timeout,
  }) async {
    debugPrint('⏳ [NativeAction] Pumping and settling${timeout != null ? ' (timeout: $timeout)' : ''}');
    await _tester.pumpAndSettle(
      duration,
      EnginePhase.sendSemanticsUpdate,
      timeout ?? config.settleTimeout,
    );
  }

  @override
  Future<Finder> waitUntilVisible(
    Finder finder, {
    Duration? timeout,
    Alignment alignment = Alignment.center,
    Duration? settleDuration,
  }) async {
    final effectiveTimeout = timeout ?? config.visibleTimeout;
    final live = isLiveBinding;
    debugPrint('⏳ [NativeAction] Waiting for widget to become visible: $finder '
        '(timeout: $effectiveTimeout, liveBinding: $live)');

    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < effectiveTimeout) {
      // Drain stray async exceptions early so they don't silently corrupt
      // test state (critical for PreviewTestBinding).
      drainAndRethrowException(_tester);

      if (finder.evaluate().isNotEmpty && finder.hitTestable().evaluate().isNotEmpty) {
        debugPrint('✅ [NativeAction] Widget became visible after '
            '${stopwatch.elapsed}: $finder');
        if (settleDuration != null) {
          debugPrint('⏳ [NativeAction] Settling for $settleDuration...');
          await pumpForDuration(_tester, duration: settleDuration);
        }
        return finder;
      }

      // Pump in a binding-aware way:
      // - AutomatedTestWidgetsFlutterBinding: pump(100ms) advances the fake clock
      // - Live/Preview bindings: pump() renders immediately, real async progresses
      await bindingAwarePump(_tester);
    }

    throw Exception('Timeout waiting for widget to become visible: $finder '
        'after ${stopwatch.elapsed}');
  }

  @override
  Future<void> tap(
    Finder finder, {
    SettlePolicy? settlePolicy,
    Duration? visibleTimeout,
    Duration? settleTimeout,
  }) async {
    debugPrint('👆 [NativeAction] Tapping: $finder');
    await waitUntilVisible(finder, timeout: visibleTimeout);
    await _tester.tap(finder.first);
    await _performPump(settlePolicy: settlePolicy ?? config.settlePolicy);
  }

  @override
  Future<void> enterText(
    Finder finder,
    String text, {
    SettlePolicy? settlePolicy,
    Duration? visibleTimeout,
    Duration? settleTimeout,
  }) async {
    debugPrint('⌨️ [NativeAction] Entering text "$text" into: $finder');
    if (!kIsWeb) {
      _tester.testTextInput.register();
    }

    await waitUntilVisible(finder, timeout: visibleTimeout);
    await _tester.tap(finder.first);
    await _tester.enterText(finder.first, text);

    if (!kIsWeb) {
      _tester.testTextInput.unregister();
    }

    await _performPump(
      settlePolicy: settlePolicy ?? config.settlePolicy,
      settleTimeout: settleTimeout,
    );
  }

  @override
  Future<void> pumpAndTrySettle({
    Duration duration = const Duration(milliseconds: 100),
    Duration? timeout = const Duration(seconds: 2),
    EnginePhase? phase = EnginePhase.sendSemanticsUpdate,
  }) async {
    try {
      await _tester.pumpAndSettle(
        duration,
        phase ?? EnginePhase.sendSemanticsUpdate,
        timeout ?? config.settleTimeout,
      );
    } on FlutterError catch (err) {
      if (err.message == 'pumpAndSettle timed out') {
        // This is fine. This method ignores pumpAndSettle timeouts on purpose
      } else {
        rethrow;
      }
    }
  }

  Future<void> _performPump({
    required SettlePolicy? settlePolicy,
    Duration? settleTimeout,
  }) async {
    final settle = settlePolicy ?? config.settlePolicy;
    final timeout = settleTimeout ?? config.settleTimeout;

    if (settle == SettlePolicy.trySettle) {
      await pumpAndTrySettle(timeout: timeout);
    } else if (settle == SettlePolicy.settle) {
      await pumpAndSettle(timeout: timeout);
    } else {
      await _tester.pump();
    }
  }

  @override
  Future<void> pumpFor(
    Duration duration, {
    Duration step = const Duration(milliseconds: 100),
  }) async {
    debugPrint('⏳ [NativeAction] Pumping for $duration...');
    await pumpForDuration(_tester, duration: duration, step: step);
  }
}
