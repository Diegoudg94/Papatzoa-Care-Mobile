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
import 'package:papatzoa_mobile/features/patient/data/repositories/notification_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_dashboard_page.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_notifications_page.dart';

const _user = AuthUser(
  id: 1,
  firstName: 'R',
  lastName: 'C',
  email: 'r@example.com',
  role: 'patient',
  isTherapist: false,
);
const _emptyDashboard = {
  'patient': {'id': 1, 'nombre': 'R', 'apellido': 'C'},
  'therapist': null,
  'next_appointment': null,
  'between_session_activity': null,
  'emotional_summary': {'total_records': 0, 'records': []},
  'sessions': [],
};

Map<String, dynamic> _notification({
  bool read = false,
  dynamic action,
  String id = 'notice-1',
  String title = 'Tu cita está confirmada',
}) => {
  'id': id,
  'event': 'appointment_confirmed',
  'title': title,
  'message': 'Nos vemos pronto.',
  'read': read,
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'action': action,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'dashboard badge displays exact unread count and opens notifications',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/patient/dashboard')) {
            return http.Response(jsonEncode(_emptyDashboard), 200);
          }
          if (request.url.path.endsWith('/unread-count')) {
            return http.Response('{"unread_count":11}', 200);
          }
          return http.Response(
            jsonEncode({'notifications': [], 'unread_count': 0}),
            200,
          );
        }),
      );
      final auth = AuthRepository(apiClient: client);
      addTearDown(auth.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PatientDashboardPage(user: _user, repository: auth),
          routes: {
            AppRoutes.patientNotifications: (_) => PatientNotificationsPage(
              repository: auth,
              notificationRepository: NotificationRepository(apiClient: client),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('11'), findsOneWidget);
      await tester.tap(find.byTooltip('Notificaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Notificaciones'), findsOneWidget);
    },
  );

  for (final count in [0, 120]) {
    testWidgets('dashboard badge renders unread count $count', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/patient/dashboard')) {
            return http.Response(jsonEncode(_emptyDashboard), 200);
          }
          return http.Response('{"unread_count":$count}', 200);
        }),
      );
      final auth = AuthRepository(apiClient: client);
      addTearDown(auth.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PatientDashboardPage(user: _user, repository: auth),
        ),
      );
      await tester.pumpAndSettle();
      if (count == 0) {
        expect(find.byTooltip('Notificaciones'), findsOneWidget);
        expect(find.text('99+'), findsNothing);
      } else {
        expect(find.text('99+'), findsOneWidget);
        expect(find.text('120'), findsNothing);
      }
    });
  }

  testWidgets('shows empty and error retry states', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    var fail = false;
    var listCalls = 0;
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/notifications')) {
          listCalls++;
          if (fail && listCalls == 2) return http.Response('{}', 500);
          return http.Response('{"notifications":[],"unread_count":0}', 200);
        }
        return http.Response('{"unread_count":0}', 200);
      }),
    );
    final auth = AuthRepository(apiClient: client);
    addTearDown(auth.close);
    final repository = NotificationRepository(apiClient: client);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PatientNotificationsPage(
          repository: auth,
          notificationRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes notificaciones'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    fail = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PatientNotificationsPage(
          repository: auth,
          notificationRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tus notificaciones.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes notificaciones'), findsOneWidget);
  });

  testWidgets(
    'unread tile marks read; null action stays and mark all clears list state',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      var markedAll = false;
      final client = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/notifications') &&
              request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'notifications': [
                  _notification(action: null),
                  _notification(
                    action: null,
                    id: 'notice-2',
                    title: 'Otra novedad',
                  ),
                ],
                'unread_count': markedAll ? 0 : 2,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/read-all')) markedAll = true;
          return http.Response('{}', 200);
        }),
      );
      final auth = AuthRepository(apiClient: client);
      addTearDown(auth.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PatientNotificationsPage(
            repository: auth,
            notificationRepository: NotificationRepository(apiClient: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Marcar todas como leídas'), findsOneWidget);
      await tester.tap(find.text('Tu cita está confirmada'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar todas como leídas'), findsOneWidget);
      await tester.tap(find.text('Marcar todas como leídas'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar todas como leídas'), findsNothing);
    },
  );

  testWidgets(
    'appointment notification marks read before opening existing detail route',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
      final requests = <String>[];
      final client = ApiClient(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/notifications')) {
            return http.Response(
              jsonEncode({
                'notifications': [
                  _notification(action: {'kind': 'appointment', 'id': 34}),
                ],
                'unread_count': 1,
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      final auth = AuthRepository(apiClient: client);
      addTearDown(auth.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PatientNotificationsPage(
            repository: auth,
            notificationRepository: NotificationRepository(apiClient: client),
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('Cita ${settings.arguments}')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tu cita está confirmada'));
      await tester.pumpAndSettle();
      expect(find.text('Cita 34'), findsOneWidget);
      expect(requests, contains('POST /api/notifications/notice-1/read'));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Notificaciones'), findsOneWidget);
    },
  );
}
