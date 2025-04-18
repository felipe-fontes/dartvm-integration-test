import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test_mock/integration_test_mock.dart';
import 'package:integration_test_mock/tester/native_tester.dart';

abstract class TesterFactory {
  ITester createTester(WidgetTester tester);
}

class NativeTesterFactory implements TesterFactory {
  @override
  ITester createTester(WidgetTester tester) {
    return FlutterTestNativeImpl(tester);
  }
}
