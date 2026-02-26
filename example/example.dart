// ignore_for_file: depend_on_referenced_packages, unused_local_variable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/base_page_object.dart';
import 'package:dartvm_integration_tests/integration_test.dart';
import 'package:dartvm_integration_tests/integration_test_config.dart';
import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';
import 'package:dartvm_integration_tests/method_channels/base_method_channel_mock.dart';

// ---------------------------------------------------------------------------
// 1. Subclass IntegrationTest for your app
// ---------------------------------------------------------------------------

class AppIntegrationTest extends IntegrationTest {
  AppIntegrationTest({required super.config})
      : super(testerFactory: PatrolTesterFactory());

  factory AppIntegrationTest.create() {
    return AppIntegrationTest(
      config: IntegrationTestConfig(
        httpOverrides: IntegrationTestHttpOverrides(),
      ),
    );
  }

  // Method channel mocks
  final SharedPreferencesMock sharedPreferencesMock =
      SharedPreferencesMock.setup();

  Future<void> setup() async {
    HttpOverrides.global = config.httpOverrides;
  }

  Future<ITester> init({required WidgetTester tester}) async {
    await setup();
    return super.start(
      tester: tester,
      mainWidget: () async => const MaterialApp(
        home: Scaffold(body: Center(child: Text('Hello'))),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Method channel mocks
// ---------------------------------------------------------------------------

class SharedPreferencesMock extends BaseMethodChannelMock {
  SharedPreferencesMock._()
      : super(
            methodChannel:
                const MethodChannel('plugins.flutter.io/shared_preferences'));

  static SharedPreferencesMock? _instance;
  final Map<String, Object> _storage = {};

  static SharedPreferencesMock setup() {
    _instance?.dispose();
    _instance = SharedPreferencesMock._();
    return _instance!;
  }

  @override
  Future<dynamic> handleMethodCall(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'getAll':
        return Map<String, Object>.from(_storage);
      case 'setValue':
        final args = methodCall.arguments as Map<String, dynamic>;
        _storage[args['key'] as String] = args['value'] as Object;
        return true;
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// 3. Mock HTTP response groups
// ---------------------------------------------------------------------------

class HomeResponses {
  static List<IntegrationTestHttpResponse> build({
    IntegrationTestHttpResponse? profile,
    IntegrationTestHttpResponse? settings,
  }) {
    return [
      profile ?? _defaultProfile,
      settings ?? _defaultSettings,
    ];
  }

  static const _defaultProfile = IntegrationTestHttpResponse(
    path: '/api/profile',
    method: HttpMethod.get,
    body: {'id': 1, 'firstName': 'Test', 'lastName': 'User'},
  );

  static const _defaultSettings = IntegrationTestHttpResponse(
    path: '/api/settings',
    method: HttpMethod.get,
    body: {'theme': 'light', 'language': 'en'},
  );
}

// ---------------------------------------------------------------------------
// 4. Page objects
// ---------------------------------------------------------------------------

class HomePageObject extends BasePageObject {
  HomePageObject(super.$);

  Finder get _welcomeText => $(find.text('Hello'));

  Future<void> waitForHome() async {
    await $.waitUntilVisible(_welcomeText);
  }
}

// ---------------------------------------------------------------------------
// 5. Test
// ---------------------------------------------------------------------------

void main() {
  late AppIntegrationTest integrationTest;

  setUp(() {
    integrationTest = AppIntegrationTest.create();
  });

  testWidgets('user sees home screen', (tester) async {
    // Set up mocks
    integrationTest.config.httpOverrides.addResponses(
      HomeResponses.build(),
    );

    // Init app
    final $ = await integrationTest.init(tester: tester);

    // Use page object
    final homePage = HomePageObject($);
    await homePage.waitForHome();

    // Verify
    expect(find.text('Hello'), findsOneWidget);
  });
}
