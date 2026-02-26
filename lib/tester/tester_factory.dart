import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';
import 'package:dartvm_integration_tests/tester/native_tester.dart';

abstract class TesterFactory {
  ITester createTester(WidgetTester tester);
}

class NativeTesterFactory implements TesterFactory {
  @override
  ITester createTester(WidgetTester tester) {
    return FlutterTestNativeImpl(tester);
  }
}
