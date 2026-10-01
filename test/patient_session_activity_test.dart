import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papatzoa_mobile/core/network/api_client.dart';
import 'package:papatzoa_mobile/features/patient/data/models/patient_dashboard_data.dart';
import 'package:papatzoa_mobile/features/patient/data/repositories/patient_session_activity_repository.dart';
import 'package:papatzoa_mobile/features/patient/presentation/pages/patient_session_activity_page.dart';

class FakeActivityRepository extends PatientSessionActivityRepository {
  FakeActivityRepository() : super(apiClient: ApiClient(baseUrl: 'http://localhost/api'));
  DashboardActivity? activity = const DashboardActivity(id: 12, title: 'Prueba', instructions: 'Esto es una prueba', objective: 'Prueba', status: 'pendiente');
  bool fail = false;
  int calls = 0;
  String? sentStatus;
  String? sentComment;

  @override
  Future<DashboardActivity?> current() async => activity;

  @override
  Future<void> respond(int id, String status, String comment) async {
    calls++;
    if (fail) throw Exception('offline');
    sentStatus = status;
    sentComment = comment;
  }
}

void main() {
  test('activity parsing keeps real fields and nullable objective', () {
    final activity = DashboardActivity.fromJson({'id': 1, 'title': 'Prueba', 'instructions': 'Texto', 'objective': null, 'status': 'intentada', 'response': {'status': 'intentada', 'comment': null}});
    expect(activity.objective, isNull);
    expect(activity.status, 'intentada');
    expect(activity.response?.comment, isNull);
  });

  testWidgets('wizard keeps selection on back, allows empty comment, and sends response', (tester) async {
    final repo = FakeActivityRepository();
    await tester.binding.setSurfaceSize(const Size(375, 667));
    await tester.pumpWidget(MaterialApp(home: PatientSessionActivityPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Esto es una prueba'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('La intenté'));
    await tester.pump();
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 3 de 4'), findsOneWidget);
    expect(find.text('¿Cómo te fue?'), findsOneWidget);
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.text('La realicé'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('No agregaste comentarios.'), findsOneWidget);
    await tester.tap(find.text('Enviar respuesta'));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.sentStatus, 'realizada');
    expect(repo.sentComment, '');
    expect(find.text('Respuesta enviada'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('submit error keeps comment and allows retry', (tester) async {
    final repo = FakeActivityRepository()..fail = true;
    await tester.pumpWidget(MaterialApp(home: PatientSessionActivityPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('La intenté'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pude intentarlo');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar respuesta'));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos guardar tu respuesta.'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Pude intentarlo'), findsOneWidget);
  });
}
