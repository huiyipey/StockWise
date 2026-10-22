import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_wise/services/image_upload.dart';
import 'package:stock_wise/screens/edit_profile_screen.dart';
import 'package:stock_wise/widgets/report_email_preference.dart';
import 'package:stock_wise/widgets/glass_bottom_nav.dart';

void main() {
  test(
    'Images infer MIME from bytes and reject unsupported/oversize input',
    () {
      expect(
        ImageUpload.fromBytes(
          Uint8List.fromList([255, 216, 255, 0]),
        ).contentType,
        'image/jpeg',
      );
      expect(
        ImageUpload.fromBytes(
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ).extension,
        'png',
      );
      expect(
        () => ImageUpload.fromBytes(Uint8List(5 * 1024 * 1024)),
        throwsArgumentError,
      );
      expect(
        () => ImageUpload.fromBytes(Uint8List.fromList([1, 2, 3])),
        throwsArgumentError,
      );
    },
  );
  testWidgets(
    'Profile form validates username without writing and keeps email read-only',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditProfileScreen(
            initial: {'displayName': 'Tester'},
            email: 'test@example.invalid',
          ),
        ),
      );
      final username = find.widgetWithText(TextFormField, 'Username');
      await tester.enterText(username, '   ');
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pump();
      expect(find.text('Enter a username.'), findsOneWidget);
      final email = tester.widget<TextField>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Sign-in email'),
          matching: find.byType(TextField),
        ),
      );
      expect(email.readOnly, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Password form rejects short and mismatched passwords', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'old-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'short',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'different',
    );
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Email preference is on by default and saves off; errors are visible',
    (tester) async {
      final values = StreamController<bool>();
      addTearDown(values.close);
      bool? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportEmailPreference(
              values: values.stream,
              save: (v) async {
                saved = v;
                values.add(v);
              },
            ),
          ),
        ),
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      values.add(true);
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(saved, false);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportEmailPreference(
              values: Stream.value(true),
              save: (v) async {
                throw StateError('offline');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save email preference. Please try again.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Floating actions stay above navigation with Android safe inset',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final count in [4, 5]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.only(bottom: 24)),
              child: Scaffold(
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: GlassBottomNav(
                    currentIndex: 0,
                    items: List.generate(
                      count,
                      (i) => NavItem(
                        icon: Icons.home,
                        activeIcon: Icons.home,
                        label: 'Tab $i',
                      ),
                    ),
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.add),
                ),
                body: const SizedBox.expand(),
              ),
            ),
          ),
        );
        expect(
          tester.getRect(find.byType(FloatingActionButton)).bottom,
          lessThan(tester.getRect(find.byType(GlassBottomNav)).top),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
