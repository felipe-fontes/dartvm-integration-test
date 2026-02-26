import 'package:dartvm_integration_tests/dartvm_integration_tests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AutoRemoveWidget extends StatefulWidget {
  const _AutoRemoveWidget({required this.removeAfter});

  final Duration removeAfter;

  @override
  State<_AutoRemoveWidget> createState() => _AutoRemoveWidgetState();
}

class _AutoRemoveWidgetState extends State<_AutoRemoveWidget> {
  bool _show = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.removeAfter, () {
      if (!mounted) return;
      setState(() {
        _show = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: _show
              ? Container(key: const Key('to_remove'), width: 10, height: 10)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('pumpUntilNotFound returns when widget is removed',
      (tester) async {
    await tester.pumpWidget(
      const _AutoRemoveWidget(removeAfter: Duration(milliseconds: 200)),
    );

    expect(find.byKey(const Key('to_remove')), findsOneWidget);

    await pumpUntilNotFound(
      tester,
      find.byKey(const Key('to_remove')),
      timeout: const Duration(seconds: 2),
      step: const Duration(milliseconds: 50),
    );

    expect(find.byKey(const Key('to_remove')), findsNothing);
  });

  testWidgets('pumpUntilNotFound fails after timeout if widget remains',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(key: Key('still_here'), width: 10, height: 10),
          ),
        ),
      ),
    );

    expect(
      () => pumpUntilNotFound(
        tester,
        find.byKey(const Key('still_here')),
        timeout: const Duration(milliseconds: 200),
        step: const Duration(milliseconds: 50),
      ),
      throwsA(isA<TestFailure>()),
    );
  });
}
