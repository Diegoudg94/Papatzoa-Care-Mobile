# Papatzoa Care Mobile

Cliente Flutter para pacientes y terapeutas. Incluye autenticación por correo y Google Sign-In en iOS, token Sanctum en almacenamiento seguro y restauración de sesión. El módulo de pacientes ofrece panel, citas, diario emocional, actividades de sesión, red de apoyo, notificaciones y cuenta. El dashboard de terapeutas sigue siendo provisional.

## Desarrollo

Entorno usado en desarrollo: Flutter 3.47.5 y Dart 3.13.4. El backend local debe ofrecer los endpoints de autenticación y del módulo de pacientes descritos en la documentación técnica, en el puerto 8000.

```sh
flutter pub get
flutter devices
flutter run -d ios --dart-define=ENV=development
```

Android Emulator usa `http://10.0.2.2:8000/api`; iOS Simulator usa `http://127.0.0.1:8000/api`. Para usar la API de producción:

```sh
flutter run --dart-define=ENV=production
```

## Verificación y documentación

```sh
dart format lib test
flutter analyze
flutter test
```

Consulta la [documentación técnica](docs/DOCUMENTACION_TECNICA.md) para arquitectura, contratos de API, configuración nativa, pruebas y pendientes.
