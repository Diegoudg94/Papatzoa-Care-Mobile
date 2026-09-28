# Papatzoa Care Mobile

Cliente Flutter para pacientes y terapeutas. Incluye login por correo y contraseña, Google Sign-In en iOS, token Sanctum en almacenamiento seguro, restauración de sesión, navegación por rol y logout. Los dashboards son provisionales.

## Desarrollo

Entorno verificado: Flutter 3.47.5 y Dart 3.13.4. El backend local debe ofrecer `/api/login`, `/api/login/google`, `/api/me` y `/api/logout` en el puerto 8000.

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
