import 'package:discipletrack/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  group('AppTextField', () {
    late TextEditingController controller;

    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    testWidgets('shows its label and accepts input', (tester) async {
      await tester.pumpWidget(
        host(AppTextField(label: 'FULL NAME', controller: controller)),
      );

      expect(find.text('FULL NAME'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Juan dela Cruz');
      expect(controller.text, 'Juan dela Cruz');
    });

    testWidgets('shows the error message when given one', (tester) async {
      await tester.pumpWidget(
        host(
          AppTextField(
            label: 'FULL NAME',
            controller: controller,
            errorText: 'Enter your full name',
          ),
        ),
      );

      expect(find.text('Enter your full name'), findsOneWidget);
    });

    testWidgets('the error slot reserves height so the form never jumps', (
      tester,
    ) async {
      // This is the whole point of the reserved slot: showing or clearing a
      // validation message must not change the field's height.
      await tester.pumpWidget(
        host(AppTextField(label: 'EMAIL', controller: controller)),
      );
      final withoutError = tester.getSize(find.byType(AppTextField));

      await tester.pumpWidget(
        host(
          AppTextField(
            label: 'EMAIL',
            controller: controller,
            errorText: 'Enter a valid email',
          ),
        ),
      );
      await tester.pump();
      final withError = tester.getSize(find.byType(AppTextField));

      expect(
        withError.height,
        withoutError.height,
        reason: 'the reserved error slot must keep the height constant',
      );
    });

    testWidgets('obscureText hides the value', (tester) async {
      await tester.pumpWidget(
        host(
          AppTextField(
            label: 'PASSWORD',
            controller: controller,
            obscureText: true,
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });

    testWidgets('disabled blocks input', (tester) async {
      await tester.pumpWidget(
        host(
          AppTextField(label: 'EMAIL', controller: controller, enabled: false),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });
}
