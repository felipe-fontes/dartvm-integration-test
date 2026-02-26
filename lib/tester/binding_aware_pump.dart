import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the current test binding uses real async (e.g. LiveTestWidgetsFlutterBinding,
/// PreviewTestBinding). When true, `pump()` without a duration should be used so
/// frames render immediately and real async work progresses naturally. When false
/// (AutomatedTestWidgetsFlutterBinding), `pump(duration)` should be used to advance
/// the fake clock and fire pending timers.
bool get isLiveBinding {
  final binding = WidgetsBinding.instance;
  // AutomatedTestWidgetsFlutterBinding runs inside FakeAsync and needs
  // pump(duration) to advance the fake clock. All other test bindings
  // (LiveTestWidgetsFlutterBinding, PreviewTestBinding, etc.) use real
  // async and should call pump() without a duration.
  return binding is! AutomatedTestWidgetsFlutterBinding;
}

/// Pumps the tester in a way that works correctly in both
/// [AutomatedTestWidgetsFlutterBinding] (fake async) and live/preview bindings
/// (real async).
///
/// - **Automated binding**: calls `tester.pump(interval)` to advance the fake
///   clock by [interval], firing any timers scheduled within that window.
/// - **Live/Preview binding**: calls `tester.pump()` without a duration so the
///   frame renders immediately on the next vsync. Real timers fire naturally.
Future<void> bindingAwarePump(
  WidgetTester tester, {
  Duration interval = const Duration(milliseconds: 100),
}) async {
  if (isLiveBinding) {
    await tester.pump();
  } else {
    await tester.pump(interval);
  }
}

/// Drains any pending exception from [tester.takeException] and rethrows it.
/// This surfaces stray async errors (e.g. unhandled MissingPluginException)
/// early, preventing them from silently corrupting test state — especially
/// important in PreviewTestBinding where unhandled errors can prematurely
/// complete the test.
void drainAndRethrowException(WidgetTester tester) {
  final pendingException = tester.takeException();
  if (pendingException != null) {
    if (pendingException is Error) throw pendingException;
    if (pendingException is Exception) throw pendingException;
    throw Exception(pendingException.toString());
  }
}

/// Pumps for a total [duration], advancing time in steps of [step].
///
/// Works correctly in both binding types:
/// - **Automated binding (FakeAsync)**: advances the fake clock in [step]
///   increments until [duration] is reached, firing timers and rendering
///   frames along the way.
/// - **Live/Preview binding**: calls `tester.pump()` (no duration) in a tight
///   loop until [duration] wall-clock time has elapsed. Each `pump()` renders
///   immediately and yields to the event loop, letting real async work (API
///   responses, state updates) progress between frames.
///
///   **Why not `pump(duration)` or `Future.delayed` + `pump()`?**
///   PreviewTestBinding's `pump(duration)` creates a Timer but only sets
///   `_expectingFrame = true` after the Timer fires. If a framework-scheduled
///   frame (from setState/scheduleFrame) runs during the Timer wait, it sees
///   `_expectingFrame = false` with `fadePointers` frame policy, skips
///   `super.handleBeginFrame()`, and leaves `_hasScheduledFrame` stale.
///   This prevents subsequent `scheduleFrame()` calls from requesting a new
///   engine frame — deadlocking `pump()`. Calling `pump()` without duration
///   avoids this by setting `_expectingFrame = true` synchronously before
///   `scheduleFrame()`, so any engine frame callback sees it as expected.
///
/// Use this after a widget is visible to let animations/loading complete,
/// or to drain pending timers at the end of a test.
Future<void> pumpForDuration(
  WidgetTester tester, {
  required Duration duration,
  Duration step = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();
  if (isLiveBinding) {
    // In live/preview bindings: pump() without duration renders immediately
    // on the next vsync. Each await yields to the event loop, letting real
    // async work (API responses, Provider state updates, timers) progress.
    // The Stopwatch measures wall-clock time including rendering overhead,
    // so each iteration naturally takes some real time (~100-200ms with
    // gRPC frame capture), producing a reasonable number of frames.
    while (stopwatch.elapsed < duration) {
      await tester.pump();
    }
  } else {
    // In automated binding (FakeAsync): pump(step) advances the fake clock
    // synchronously, firing timers and rendering frames along the way.
    while (stopwatch.elapsed < duration) {
      final remaining = duration - stopwatch.elapsed;
      final pumpStep = remaining < step ? remaining : step;
      await tester.pump(pumpStep);
    }
  }
}

/// Pumps in a loop until [finder] is no longer found.
///
/// This is useful for waiting for transient UI (loading spinners, snackbars,
/// dialogs) to be removed.
///
/// The timeout is measured in *pumped* time (sum of [step] durations), making
/// it deterministic under FakeAsync widget tests.
Future<void> pumpUntilNotFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    await tester.pump(step);
    if (!tester.any(finder)) {
      return;
    }
    elapsed += step;
  }

  // One last pump to give a more stable failure state.
  await tester.pump();
  expect(
    tester.any(finder),
    isFalse,
    reason: 'Timed out waiting for widget to be removed: $finder',
  );
}
