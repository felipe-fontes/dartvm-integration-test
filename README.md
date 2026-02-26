# dartvm_integration_tests

[![pub package](https://img.shields.io/pub/v/dartvm_integration_tests.svg)](https://pub.dev/packages/dartvm_integration_tests)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Run **full app integration tests entirely on the Dart VM** — no emulators, no devices, no drivers, no long build times. Just `flutter test`.

This package lets you execute complete user flows against your real widget tree using standard `testWidgets`, with HTTP and platform channels fully mocked out. Tests run at Dart VM speed (milliseconds, not minutes), need zero platform infrastructure, and can live alongside your unit tests in CI with no special setup.

### Why?

Traditional integration tests (`flutter drive`, `integration_test` package) require:
- A compiled app deployed to a real or emulated device
- Long build/install cycles on every change
- Expensive CI device farms or emulator fleets
- Flaky platform-dependent behavior

**dartvm_integration_tests** takes a different approach: your entire app runs as a widget test inside the Dart VM. HTTP calls never leave the process — they hit mock responses you define. Method channels return fake values you control. The result is a test that exercises your full widget tree, navigation, state management, and business logic **without any platform dependency**.

You get:
- **Instant feedback** — tests complete in seconds, not minutes
- **Zero infrastructure** — no simulators, emulators, or device farms
- **Deterministic results** — no network flakiness, no platform quirks
- **Full logic coverage** — test your real widgets, routes, and state from end to end
- **CI-friendly** — runs with `flutter test`, same as your unit tests

## Features

- **HTTP Mocking** — Intercept all HTTP requests via `HttpOverrides.global`. Match by path, query, and HTTP method. Support for queued (one-shot) and permanent mock responses, request verification, simulated latency, and selective pass-through for unmatched endpoints. HTTP and networking are completely removed from the equation.
- **Method Channel Mocking** — Mock platform channel calls with queued and permanent responses. Simulate any native plugin (Firebase, SharedPreferences, connectivity, secure storage, etc.) without the actual platform — tests never touch iOS/Android code.
- **Unified Tester Abstraction (`ITester`)** — A single API for widget interaction (`tap`, `enterText`, `scrollUntilVisible`, `waitUntilVisible`, `pump`, etc.) with two swappable implementations:
  - `FlutterTestNativeImpl` — uses raw `WidgetTester` and `find.*`
  - `PatrolImpl` — wraps [`patrol_finders`](https://pub.dev/packages/patrol_finders) for enhanced finder ergonomics
- **Binding-Aware Pumping** — Utilities that work correctly across `AutomatedTestWidgetsFlutterBinding`, `LiveTestWidgetsFlutterBinding`, and `PreviewTestBinding`.
- **Page Object & Flow Patterns** — Base classes (`BasePageObject`, `BaseFlow`) to structure tests using the Page Object pattern for better readability and reuse.

## Getting Started

### Installation

Add `dartvm_integration_tests` as a **dev dependency** in your `pubspec.yaml`:

```yaml
dev_dependencies:
  dartvm_integration_tests: ^0.0.1
```

Then run:

```bash
flutter pub get
```

### Import

```dart
import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';
```

## Usage

### 1. Subclass `IntegrationTest` for your app

Create a custom integration test class that extends `IntegrationTest` and wires up your app-specific configuration, method channel mocks, and setup logic:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/integration_test.dart';
import 'package:dartvm_integration_tests/integration_test_config.dart';
import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';

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

  // Instantiate all method channel mocks your app needs
  final SharedPreferencesMock sharedPreferencesMock = SharedPreferencesMock.setup();
  final FirebaseAnalyticsMock firebaseAnalyticsMock = FirebaseAnalyticsMock.setup();
  final ConnectivityMock connectivityMock = ConnectivityMock.setup();
  final PathProviderMock pathProviderMock = PathProviderMock.setup();
  final SecureStorageMock secureStorageMock = SecureStorageMock.setup();

  Future<void> setup() async {
    // Re-apply HTTP overrides after TestWidgetsFlutterBinding.ensureInitialized()
    // overwrites HttpOverrides.global with its own mock.
    HttpOverrides.global = config.httpOverrides;

    // App-specific setup: load env vars, configure DI, etc.
  }

  Future<ITester> init({required WidgetTester tester}) async {
    await setup();
    return super.start(
      tester: tester,
      mainWidget: () async {
        // Build and return your app's root widget
        return const MyApp();
      },
    );
  }
}
```

### 2. Mock method channels

Extend `BaseMethodChannelMock` and override `handleMethodCall` to simulate native plugin behavior. Use the singleton pattern with `setup()`/`tearDown()` for clean lifecycle management:

```dart
import 'package:flutter/services.dart';
import 'package:dartvm_integration_tests/method_channels/base_method_channel_mock.dart';

class SharedPreferencesMock extends BaseMethodChannelMock {
  SharedPreferencesMock._() : super(methodChannel: _channel);

  static const _channel = MethodChannel('plugins.flutter.io/shared_preferences');
  static SharedPreferencesMock? _instance;

  final Map<String, Object> _storage = {};

  static SharedPreferencesMock setup() {
    _instance?.dispose();
    _instance = SharedPreferencesMock._();
    return _instance!;
  }

  static void tearDown() {
    _instance?.dispose();
    _instance = null;
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
      case 'remove':
        _storage.remove(methodCall.arguments['key']);
        return true;
      default:
        return null;
    }
  }
}
```

You can also use `queueResponse` and `setPermanentResponse` inherited from `BaseMethodChannelMock` for simpler mocks:

```dart
class PathProviderMock extends BaseMethodChannelMock {
  PathProviderMock._() : super(methodChannel: _channel);
  static const _channel = MethodChannel('plugins.flutter.io/path_provider');
  static PathProviderMock? _instance;

  static PathProviderMock setup() {
    _instance?.dispose();
    _instance = PathProviderMock._();
    return _instance!;
  }

  @override
  Future<dynamic> handleMethodCall(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'getTemporaryDirectory':
        return '/data/user/0/com.example.app/cache';
      case 'getApplicationDocumentsDirectory':
        return '/data/user/0/com.example.app/app_flutter';
      default:
        return null;
    }
  }
}
```

### 3. Organize mock HTTP responses

Group your mock API responses into classes with default values and optional overrides. This keeps test setup DRY and makes it easy to customize individual responses per test:

```dart
import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';

class HomeScreenResponses {
  static const _profilePath = '/api/profile';
  static const _settingsPath = '/api/settings';
  static const _notificationsPath = '/api/notifications';

  /// Build a complete set of responses needed for the home screen.
  /// Override individual responses as needed per test.
  static List<IntegrationTestHttpResponse> build({
    IntegrationTestHttpResponse? profile,
    IntegrationTestHttpResponse? settings,
    IntegrationTestHttpResponse? notifications,
  }) {
    return [
      profile ?? _defaultProfile,
      settings ?? _defaultSettings,
      notifications ?? _defaultNotifications,
    ];
  }

  static const _defaultProfile = IntegrationTestHttpResponse(
    path: _profilePath,
    method: HttpMethod.get,
    body: {
      'id': 1,
      'firstName': 'Test',
      'lastName': 'User',
      'email': 'test@example.com',
    },
  );

  static const _defaultSettings = IntegrationTestHttpResponse(
    path: _settingsPath,
    method: HttpMethod.get,
    body: {'theme': 'light', 'language': 'en'},
  );

  static const _defaultNotifications = IntegrationTestHttpResponse(
    path: _notificationsPath,
    method: HttpMethod.get,
    body: {'unread': 0, 'items': <Map<String, dynamic>>[]},
  );
}
```

### 4. Build page objects

Extend `BasePageObject` (or use `ITester` directly) to encapsulate widget finders and interactions for each screen. This keeps your tests readable and your selectors reusable:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/base_page_object.dart';

class LoginPageObject extends BasePageObject {
  LoginPageObject(super.$);

  Finder get _emailField => $(find.byKey(const Key('email_field')));
  Finder get _passwordField => $(find.byKey(const Key('password_field')));
  Finder get _loginButton => $(find.text('LOG IN'));
  Finder get _loginPage => $(LoginPage);

  Future<void> waitForLoginPage() async {
    await $.waitUntilVisible(_loginPage);
  }

  Future<void> enterEmail(String email) async {
    await $.tap(_emailField);
    await $.enterText(_emailField, email);
  }

  Future<void> enterPassword(String password) async {
    await $.tap(_passwordField);
    await $.enterText(_passwordField, password);
  }

  Future<void> tapLoginButton() async {
    await $.tap(_loginButton);
    await $.pumpAndTrySettle();
  }
}
```

### 5. Build test flows

Extend `BaseFlow` to compose multi-step user journeys. Flows combine page objects, HTTP mocks, and method channel mocks to reproduce end-to-end scenarios:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartvm_integration_tests/base_flow.dart';
import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';

class LoginFlow extends BaseFlow {
  LoginFlow({required super.$, required super.httpOverrides});

  /// Set up all mocks needed for a logged-in user to land on the home screen.
  static Future<void> loggedInToHomeMocks({
    required IntegrationTestHttpOverrides httpOverrides,
    IntegrationTestHttpResponse? profile,
    IntegrationTestHttpResponse? settings,
  }) async {
    httpOverrides.addResponses(
      HomeScreenResponses.build(
        profile: profile,
        settings: settings,
      ),
    );
  }

  /// Wait until the home screen is fully visible.
  Future<void> loggedInToHome() async {
    await $.waitUntilVisible(
      find.byType(HomeScreen),
      timeout: const Duration(seconds: 30),
    );
  }
}
```

### 6. Write integration tests

Put it all together in a test file. The recommended structure: create your test class in `setUp`, configure mocks, initialize the app, and then exercise flows:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppIntegrationTest integrationTest;

  setUp(() {
    integrationTest = AppIntegrationTest.create();
  });

  testWidgets('user lands on home screen after login', (tester) async {
    // 1. Configure mock responses
    await LoginFlow.loggedInToHomeMocks(
      httpOverrides: integrationTest.config.httpOverrides,
    );

    // 2. Initialize the app
    final $ = await integrationTest.init(tester: tester);

    // 3. Run the flow
    final loginFlow = LoginFlow(
      $: $,
      httpOverrides: integrationTest.config.httpOverrides,
    );
    await loginFlow.loggedInToHome();

    // 4. Verify
    await $.pump();
    expect(find.text('Welcome, Test User'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

### Queued (one-shot) HTTP responses

Use queued responses when the same endpoint should return different results on subsequent calls:

```dart
// First call returns success, second call returns error
httpOverrides.queueResponse(
  IntegrationTestHttpResponse(
    path: '/api/data',
    body: {'status': 'ok'},
    statusCode: 200,
  ),
);
httpOverrides.queueResponse(
  IntegrationTestHttpResponse(
    path: '/api/data',
    body: {'error': 'rate limited'},
    statusCode: 429,
  ),
);
```

### Overriding individual responses with `withOverrides`

Use `withOverrides` to create a copy of a response with merged/overridden body fields — handy for testing edge cases without redefining the entire response:

```dart
final customProfile = HomeScreenResponses.defaultProfile.withOverrides(
  body: {'firstName': 'Custom', 'hasActiveContract': true},
);

httpOverrides.addResponses(
  HomeScreenResponses.build(profile: customProfile),
);
```

### Simulating network latency

```dart
httpOverrides.addResponse(
  IntegrationTestHttpResponse(
    path: '/api/slow-endpoint',
    body: {'data': 'value'},
    delay: const Duration(seconds: 2),
  ),
);
```

### Request verification

```dart
// After running your test flow:
final allApiCalls = httpOverrides.findAllRequests('/api/data');
expect(allApiCalls.length, 3);

final postCall = httpOverrides.findRequest('/api/data', method: HttpMethod.post);
expect(postCall?.body, containsPair('key', 'value'));

// Clear for next test phase
httpOverrides.clearRequests();
```

### Switching tester implementations

```dart
// Use native Flutter test tester (default)
final nativeFactory = NativeTesterFactory();

// Or use Patrol-based tester for enhanced finder ergonomics
final patrolFactory = PatrolTesterFactory();

final integration = IntegrationTest(
  testerFactory: patrolFactory,
  config: config,
);
```

## Recommended Project Structure

```
test/
  integration_tests/
    my_app_integration_test.dart        # Subclass of IntegrationTest
    my_app_integration_test_config.dart  # Subclass of IntegrationTestConfig
    features/
      login/
        login_integration_test.dart     # Test files per feature
      home/
        home_integration_test.dart
    flows/
      login_flow.dart                   # Multi-step user journeys
      onboarding_flow.dart
    page_objects/
      login_page_object.dart            # Screen-level abstractions  
      home_page_object.dart
    mocks/
      method_channels/                  # One file per plugin mock
        shared_preferences_mock.dart
        firebase_analytics_mock.dart
        connectivity_mock.dart
      responses/                        # Grouped mock HTTP responses
        home_screen_responses.dart
        login_responses.dart
      fixtures/                         # Static test data
        login_fixtures.dart
        user_fixtures.dart
```

## API Overview

| Class | Purpose |
|---|---|
| `IntegrationTest` | Sets up the test environment and launches the widget under test |
| `IntegrationTestConfig` | Configuration holder (HTTP overrides, etc.) — subclass to add app-specific config |
| `IntegrationTestHttpOverrides` | HTTP mocking engine with queued/permanent responses and request capture |
| `IntegrationTestHttpResponse` | Describes a single mock HTTP response (path, body, status, method, delay) |
| `TesterHttpClient` | Dual HTTP client — mock known endpoints, pass-through unknown |
| `BaseMethodChannelMock` | Base class for mocking platform method channels with queued/permanent responses |
| `MethodChannelMocks` | Wrapper for registering a batch of method channel mocks |
| `ITester` | Unified widget interaction API (`tap`, `enterText`, `waitUntilVisible`, etc.) |
| `FlutterTestNativeImpl` | `ITester` implementation using raw `WidgetTester` |
| `PatrolImpl` | `ITester` implementation wrapping `PatrolTester` |
| `TesterFactory` / `NativeTesterFactory` | Factory abstraction for creating `ITester` instances |
| `PatrolTesterFactory` | Factory that creates `PatrolImpl` instances |
| `BasePageObject` | Base class for page objects — holds an `ITester` reference |
| `BaseFlow` | Base class for multi-step test flows — holds `ITester` + `httpOverrides` |
| `bindingAwarePump` | Pump utility that works in both automated and live bindings |
| `pumpForDuration` | Pump in a loop for a given duration, binding-aware |

## Additional Information

- **Issues & contributions**: File issues or submit pull requests on [GitHub](https://github.com/felipe-fontes/dartvm-integration-test).
- **License**: This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
