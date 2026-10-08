import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/core/routing/app_routes.dart';
import 'package:papatzoa_mobile/features/auth/data/models/auth_user.dart';
import 'package:papatzoa_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_appointments_repository.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_diary_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/diary/patient_diary_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_account_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_appointments_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_dashboard_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_root_shell.dart';
import 'package:papatzoa_mobile/features/patient/presentation/widgets/patient_bottom_navigation.dart';

Finder selectedDestination(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.selected == true &&
      widget.properties.label == label,
);

const _user = AuthUser(
  id: 32,
  firstName: 'Ricardo',
  lastName: 'Cortez',
  email: 'ricardo@example.com',
  role: 'patient',
  isTherapist: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpShell(
    WidgetTester tester, {
    bool withEmotion = false,
  }) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/dashboard')) {
          return http.Response(
            jsonEncode({
              'patient': {'id': 32, 'nombre': 'Ricardo', 'apellido': 'Cortez'},
              'therapist': null,
              'next_appointment': null,
              'between_session_activity': null,
              'emotional_summary': {
                'total_records': withEmotion ? 1 : 0,
                'records': withEmotion
                    ? [
                        {
                          'id': 1,
                          'emotion': 'Miedo',
                          'intensity': 5,
                          'recorded_at': '2026-10-07',
                        },
                      ]
                    : [],
              },
              'sessions': [],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/diary')) {
          return http.Response('{"entries":[]}', 200);
        }
        if (request.url.path.endsWith('/appointments')) {
          return http.Response('{"upcoming":[],"history":[]}', 200);
        }
        return http.Response('{}', 200);
      }),
    );
    final auth = AuthRepository(apiClient: apiClient);
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PatientRootShell(
          user: _user,
          repository: auth,
          dashboardPage: PatientDashboardPage(user: _user, repository: auth),
          diaryPage: PatientDiaryPage(
            repository: auth,
            diaryRepository: PatientDiaryRepository(apiClient: apiClient),
          ),
          appointmentsPage: PatientAppointmentsPage(
            repository: auth,
            appointmentsRepository: PatientAppointmentsRepository(
              apiClient: apiClient,
            ),
          ),
          accountPage: PatientAccountPage(repository: auth),
        ),
        routes: {
          AppRoutes.patientBookAppointment: (_) =>
              const Scaffold(body: Text('SECONDARY SCREEN')),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeLeft(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const ValueKey('patient-root-page-view')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const ValueKey('patient-root-page-view')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('swipes through root tabs and keeps the bottom item in sync', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(PatientBottomNavigation), findsOneWidget);
    expect(find.text('Papatzoa'), findsOneWidget);
    await swipeLeft(tester);
    expect(find.text('Diario emocional'), findsWidgets);
    expect(selectedDestination('Diario'), findsOneWidget);
    expect(find.byType(PatientBottomNavigation), findsOneWidget);
    await swipeLeft(tester);
    expect(find.text('Mis citas'), findsWidgets);
    expect(selectedDestination('Mis sesiones'), findsOneWidget);
    expect(find.byType(PatientBottomNavigation), findsOneWidget);
    await swipeLeft(tester);
    expect(find.text('Mi cuenta'), findsWidgets);
    expect(selectedDestination('Mi cuenta'), findsOneWidget);
    expect(find.byType(PatientBottomNavigation), findsOneWidget);
    await swipeRight(tester);
    expect(find.text('Mis citas'), findsWidgets);
    await swipeRight(tester);
    expect(selectedDestination('Diario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard accepts vertical drags and exposes lower content', (
    tester,
  ) async {
    await pumpShell(tester);
    final scrollable = find.byType(SingleChildScrollView);
    final before = tester.getTopLeft(find.text('Próxima sesión')).dy;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Próxima sesión')).dy, lessThan(before));
    expect(
      tester.getTopLeft(find.text('Próxima sesión')).dy,
      lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
    );
    expect(selectedDestination('Inicio'), findsOneWidget);
  });

  testWidgets('horizontal drag starting outside cards changes the root page', (
    tester,
  ) async {
    await pumpShell(tester);
    final blank = find.text('¿Cómo te sientes hoy?');
    await tester.drag(blank, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(selectedDestination('Diario'), findsOneWidget);
  });

  testWidgets('quick action cards keep navigation inside the root pager', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Diario').first);
    await tester.pumpAndSettle();
    expect(selectedDestination('Diario'), findsOneWidget);
    await swipeLeft(tester);
    expect(selectedDestination('Mis sesiones'), findsOneWidget);
    await swipeRight(tester);
    await swipeRight(tester);
    expect(selectedDestination('Inicio'), findsOneWidget);
    await tester.tap(find.text('Mis sesiones').first);
    await tester.pumpAndSettle();
    expect(selectedDestination('Mis sesiones'), findsOneWidget);
    await swipeLeft(tester);
    expect(selectedDestination('Mi cuenta'), findsOneWidget);
  });

  testWidgets('bottom navigation taps move the page and edges do not wrap', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Mi perfil').last);
    await tester.pumpAndSettle();
    expect(selectedDestination('Mi cuenta'), findsOneWidget);
    await tester.tap(find.text('Diario').last);
    await tester.pumpAndSettle();
    expect(find.text('Diario emocional'), findsWidgets);
    expect(selectedDestination('Diario'), findsOneWidget);
    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    expect(find.text('Papatzoa'), findsOneWidget);
    await swipeRight(tester);
    expect(find.text('Papatzoa'), findsOneWidget);
  });

  testWidgets('dashboard emotional card selects the shared diary root tab', (
    tester,
  ) async {
    await pumpShell(tester, withEmotion: true);
    expect(selectedDestination('Inicio'), findsOneWidget);
    final semantics = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Seguimiento emocional, abrir Diario',
    );
    expect(semantics, findsOneWidget);
    await tester.ensureVisible(find.text('Ver diario').first);
    await tester.tap(find.text('Ver diario').first);
    await tester.pumpAndSettle();
    expect(selectedDestination('Diario'), findsOneWidget);
    expect(find.text('Diario emocional'), findsWidgets);
    expect(find.byType(PatientRootShell), findsOneWidget);
    await swipeLeft(tester);
    expect(selectedDestination('Mis sesiones'), findsOneWidget);
    await swipeRight(tester);
    expect(selectedDestination('Diario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'appointment tabs use taps while horizontal drag changes root page',
    (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Mis sesiones').last);
      await tester.pumpAndSettle();
      final tabs = tester.widget<TabBarView>(find.byType(TabBarView));
      expect(tabs.physics, isA<NeverScrollableScrollPhysics>());
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes citas anteriores.'), findsOneWidget);
      await tester.tap(find.text('Próximas'));
      await tester.pumpAndSettle();
      expect(find.text('No tienes próximas citas.'), findsOneWidget);
      await tester.drag(
        find.text('No tienes próximas citas.'),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(selectedDestination('Mi cuenta'), findsOneWidget);
      await swipeRight(tester);
      expect(find.text('No tienes próximas citas.'), findsOneWidget);
      expect(find.byType(PatientBottomNavigation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('root pages still open secondary routes through Navigator', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Mis sesiones').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solicitar cita'));
    await tester.pumpAndSettle();
    expect(find.text('SECONDARY SCREEN'), findsOneWidget);
  });
}
