import 'package:integration_test_mock/network/integration_test_http_overrides.dart';
import 'package:integration_test_mock/tester/tester_interface.dart';


abstract class BaseFlow {
  final ITester $;
  final IntegrationTestHttpOverrides httpOverrides;

  BaseFlow(this.$, this.httpOverrides);
}
