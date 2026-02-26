import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/integration_test_config.dart';
import 'package:dartvm_integration_tests/tester/tester_factory.dart';
import 'package:dartvm_integration_tests/tester/tester_interface.dart';

class IntegrationTest {
  final IntegrationTestConfig _config;
  final TesterFactory _testerFactory;
  IntegrationTestConfig get config => _config;

  IntegrationTest({
    required TesterFactory testerFactory,
    required IntegrationTestConfig config,
  })  : _testerFactory = testerFactory,
        _config = config {
    create(
      testerFactory: testerFactory,
      config: config,
    );
  }

  static create({
    required TesterFactory testerFactory,
    required IntegrationTestConfig config,
  }) {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();

    // ignore: deprecated_member_use
    binding.window.physicalSizeTestValue = const Size(1440, 2960);
    // ignore: deprecated_member_use
    binding.window.devicePixelRatioTestValue = 3.0;
  }

  Future<ITester> start<T extends Widget>({
    required WidgetTester tester,
    required Future<T> Function() mainWidget,
    Future<void> Function()? setupPreWidgetCreated,
    Future<void> Function()? setupPrePumpedWidget,
  }) async {
    tester.view.physicalSize = const Size(1440, 2960);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;

    disableOverflowError();

    await setupPreWidgetCreated?.call();

    final app = await mainWidget();

    await setupPrePumpedWidget?.call();

    await tester.pumpWidget(app);

    return _testerFactory.createTester(tester);
  }
}

void disableOverflowError() {
  // FlutterError.onError != FlutterError.presentError in Widget Test
  // See test/error/disable_overflow_error_test.dart
  FlutterExceptionHandler? originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    bool isOverflowError = false;
    final exception = details.exception;
    if (exception is FlutterError) {
      isOverflowError = exception.diagnostics.any(
        (e) => e.value.toString().contains('A RenderFlex overflowed by'),
      );
    }
    if (isOverflowError) {
      debugPrint('A RenderFlex overflowed');
    } else if (originalOnError != null) {
      originalOnError(details);
    }
  };
}
