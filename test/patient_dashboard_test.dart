import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/routing/app_routes.dart';
import 'package:papatzoa_mobile/core/theme/app_theme.dart';
import 'package:papatzoa_mobile/features/auth/data/models/auth_user.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_dashboard_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_dashboard_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/widgets/patient_bottom_navigation.dart';
import 'package:papatzoa_mobile/features/auth/presentation/widgets/logout_button.dart';

const emptyDashboard = {
  'patient': {'id': 32, 'nombre': 'Ricardo', 'apellido': 'Cortez'},
  'therapist': null,
  'next_appointment': null,
  'between_session_activity': null,
  'emotional_summary': {'total_records': 0, 'records': []},
  'sessions': [],
};

const populatedDashboard = {
  'patient': {'id': 32, 'nombre': 'Ricardo', 'apellido': 'Cortez'},
  'therapist': {
    'id': 8,
    'nombre': 'Ana',
    'apellido': 'López',
    'especialidad': 'Psicología',
    'modalidad': 'en línea',
    'profile_photo': null,
  },
  'next_appointment': {
    'id': 101,
    'date': '2026-10-05T14:30:00-06:00',
    'time': '14:30',
    'status': 'confirmada',
    'modality': 'virtual',
  },
  'between_session_activity': {
    'id': 7,
    'title': 'Registro breve',
    'instructions': 'Anota lo que ocurrió.',
    'objective': 'Observar la situación.',
    'suggested_date': '2026-10-02',
    'status': 'pendiente',
  },
  'emotional_summary': {
    'total_records': 1,
    'records': [
      {
        'id': 12,
        'emotion': 'calma',
        'intensity': 3,
        'recorded_at': '2026-09-28T10:15:00-06:00',
      },
    ],
  },
  'sessions': [
    {
      'id': 101,
      'date': '2026-10-05T14:30:00-06:00',
      'time': '14:30',
      'status': 'confirmada',
      'modality': 'virtual',
    },
  ],
};

const user = AuthUser(
  id: 32,
  firstName: 'Ricardo',
  lastName: 'Cortez',
  email: 'ricardo@example.com',
  role: 'patient',
  isTherapist: false,
);

Finder findDetail(String value) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == value,
);

Future<void> pumpDashboard(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request request) handler,
  bool includeLoginRoute = false,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'dashboard-token'});
  final apiClient = ApiClient(client: MockClient(handler));
  final authRepository = AuthRepository(apiClient: apiClient);
  final dashboardRepository = PatientDashboardRepository(apiClient: apiClient);
  addTearDown(authRepository.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routes: includeLoginRoute
          ? {AppRoutes.login: (_) => const Scaffold(body: Text('LOGIN'))}
          : const {},
      home: PatientDashboardPage(
        user: user,
        repository: authRepository,
        dashboardRepository: dashboardRepository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [320.0, 390.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets('Dashboard fits $width px, dark: $dark', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpDashboard(
          tester,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          handler: (_) async => http.Response(jsonEncode(emptyDashboard), 200),
        );
        expect(find.text('Hola, Ricardo'), findsOneWidget);
        expect(find.text('¿Cómo te sientes hoy?'), findsOneWidget);
        for (final action in ['Diario', 'Mis sesiones', 'Red de apoyo']) {
          expect(find.text(action).first, findsOneWidget);
        }
        expect(find.text('Perfil'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Mi cuenta',
          ),
          findsOneWidget,
        );
        expect(find.byTooltip('Notificaciones'), findsOneWidget);
        expect(find.text('Papatzoa'), findsOneWidget);
        expect(find.byType(LogoutButton), findsNothing);
        expect(find.byType(PatientBottomNavigation), findsOneWidget);
        for (final item in ['Inicio', 'Diario', 'Mis sesiones']) {
          expect(find.text(item), findsWidgets);
        }
        expect(find.text('Citas'), findsNothing);
        expect(
          find.text(
            'Cuando tu terapeuta te deje una actividad, aparecerá aquí.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('La información de tu terapeuta aparecerá aquí.'),
          findsOneWidget,
        );
        expect(
          find.text('Tus registros emocionales aparecerán aquí.'),
          findsOneWidget,
        );
        expect(find.text('Aquí aparecerá tu próxima sesión.'), findsOneWidget);
        expect(
          find.text('Tus sesiones agendadas aparecerán aquí.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final sections = [
          'Actividad entre sesiones',
          'Tu terapeuta',
          'Consejos para tu registro',
          'Ejercicios de respiración',
          'Seguimiento emocional',
          'Próxima sesión',
        ];
        final positions = sections
            .map((section) => tester.getTopLeft(find.text(section).first).dy)
            .toList();
        expect(positions, orderedEquals([...positions]..sort()));
        await tester.scrollUntilVisible(find.text('Mis sesiones').first, 250);
        expect(find.byType(PatientBottomNavigation), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'renders real therapist, activity, emotional and appointment data',
    (tester) async {
      await pumpDashboard(
        tester,
        handler: (_) async =>
            http.Response(jsonEncode(populatedDashboard), 200),
      );
      expect(find.text('Ana López'), findsOneWidget);
      expect(findDetail('Especialidad: Psicología'), findsOneWidget);
      expect(findDetail('Modalidad: en línea'), findsOneWidget);
      expect(find.text('Registro breve'), findsOneWidget);
      expect(findDetail('Estado: Pendiente'), findsOneWidget);
      expect(find.text('Ver actividad'), findsOneWidget);
      expect(findDetail('Fecha: 05/10/2026'), findsNWidgets(2));
      expect(findDetail('Hora: 14:30'), findsNWidgets(2));
      expect(findDetail('Estado: confirmada'), findsNWidgets(2));
      expect(findDetail('Modalidad: virtual'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text('calma · Intensidad: 3 · 28/09/2026'),
        250,
      );
      expect(find.text('calma · Intensidad: 3 · 28/09/2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('network error shows retry and does not clear local token', (
    tester,
  ) async {
    var calls = 0;
    await pumpDashboard(
      tester,
      handler: (_) async {
        calls++;
        return calls == 1
            ? http.Response('{}', 500)
            : http.Response(jsonEncode(emptyDashboard), 200);
      },
    );
    expect(find.text('No pudimos actualizar tu información.'), findsOneWidget);
    expect(
      await const FlutterSecureStorage().read(key: 'auth_token'),
      'dashboard-token',
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos actualizar tu información.'), findsNothing);
    expect(calls, 3);
  });

  testWidgets('401 clears invalid token and replaces dashboard with login', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      includeLoginRoute: true,
      handler: (_) async => http.Response('{}', 401),
    );
    expect(find.text('LOGIN'), findsOneWidget);
    expect(await const FlutterSecureStorage().read(key: 'auth_token'), isNull);
    expect(Navigator.of(tester.element(find.text('LOGIN'))).canPop(), isFalse);
  });

  testWidgets('403 displays a safe access state', (tester) async {
    await pumpDashboard(tester, handler: (_) async => http.Response('{}', 403));
    expect(find.text('No tienes acceso a este dashboard.'), findsOneWidget);
    expect(find.text('Hola, Ricardo'), findsNothing);
    expect(
      await const FlutterSecureStorage().read(key: 'auth_token'),
      'dashboard-token',
    );
  });
}
