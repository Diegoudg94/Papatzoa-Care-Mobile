# Papatzoa Care Mobile

Cliente móvil de Papatzoa para Android e iOS, desarrollado con Flutter. Implementa inicio de sesión por correo y contraseña, conexión a la API y almacenamiento seguro del token.

## Desarrollo

Entorno verificado: Flutter 3.47.5 y Dart 3.13.4. El backend local debe ofrecer `/api/login` en el puerto 8000.

```sh
flutter pub get
flutter devices
flutter run --dart-define=ENV=development
```

Android Emulator usa `http://10.0.2.2:8000/api`; iOS Simulator usa `http://127.0.0.1:8000/api`. Para usar la API de producción:

```sh
flutter run --dart-define=ENV=production
```

## Verificación y documentación

```sh
flutter analyze
flutter test
```

Consulta la [documentación técnica](docs/DOCUMENTACION_TECNICA.md) para arquitectura, contrato de API, configuración nativa, pruebas y pendientes.

El login exitoso permanece en la misma pantalla. Paneles por rol, registro, recuperación de contraseña y restauración de sesión están pendientes.
