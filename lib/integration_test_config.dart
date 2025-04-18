import 'package:integration_test_mock/integration_test_mock.dart';
import 'package:integration_test_mock/method_channel_mocks.dart';

class IntegrationTestConfig {
  final IntegrationTestHttpOverrides httpOverrides;

  IntegrationTestConfig({
    required this.httpOverrides,
  });
}
