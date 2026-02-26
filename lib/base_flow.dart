import 'package:dartvm_integration_tests/network/integration_test_http_overrides.dart';
import 'package:dartvm_integration_tests/tester/tester_interface.dart';


abstract class BaseFlow {
  final ITester $;
  final IntegrationTestHttpOverrides httpOverrides;

  BaseFlow(this.$, this.httpOverrides);
}
