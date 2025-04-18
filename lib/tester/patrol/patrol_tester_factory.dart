import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test_mock/tester/tester_factory.dart';
import 'package:integration_test_mock/tester/tester_interface.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'patrol_factory_impl.dart';

class PatrolTesterFactory implements TesterFactory {
  @override
  ITester createTester(WidgetTester tester) {
    return PatrolImpl(PatrolTester(
      tester: tester,
      config: const PatrolTesterConfig(
        settlePolicy: SettlePolicy.noSettle,
      ),
    ));
  }
}
