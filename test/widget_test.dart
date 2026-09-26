import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/app/app.dart';
import 'package:papatzoa_mobile/features/auth/presentation/pages/login_page.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets('Loading disables submit and prevents duplicate requests', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = AuthRepository(
      apiClient: ApiClient(
        client: MockClient((_) {
          requests++;
          return response.future;
        }),
      ),
    );
    addTearDown(repository.close);
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(repository: repository)),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'usuario@example.com');
    await tester.enterText(fields.at(1), 'test-password');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(requests, 1);
    response.complete(http.Response(jsonEncode(loginJson), 200));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Sesión iniciada correctamente.'), findsOneWidget);
  });
  testWidgets('Papatzoa app starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const PapatzoaApp());

    expect(find.text('Papatzoa'), findsOneWidget);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
  });

  testWidgets('Login validates and signs in without leaving the page', (
    WidgetTester tester,
  ) async {
    final repository = testRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(repository: repository)),
    );

    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'correo-invalido');
    await tester.enterText(fields.at(1), 'clave');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsNothing);

    await tester.enterText(fields.at(0), 'persona@ejemplo.com');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido.'), findsNothing);
    expect(find.text('Sesión iniciada correctamente.'), findsOneWidget);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
  });

  testWidgets('Next focuses password and Done validates and closes keyboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PapatzoaApp());
    final fields = find.byType(TextFormField);

    await tester.tap(fields.at(0));
    await tester.enterText(fields.at(0), 'persona@ejemplo.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    final passwordInput = find.descendant(
      of: fields.at(1),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(passwordInput).focusNode.hasFocus,
      isTrue,
    );

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    expect(
      tester.widget<EditableText>(passwordInput).focusNode.hasFocus,
      isFalse,
    );
  });

  testWidgets('Login remains scrollable with a small keyboard viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const PapatzoaApp());
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
