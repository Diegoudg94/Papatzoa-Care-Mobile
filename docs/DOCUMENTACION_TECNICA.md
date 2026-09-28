# Documentación técnica de Papatzoa Care Mobile

Revisión: 27 de septiembre de 2026. Describe el código móvil local. La API se desarrolla en otro repositorio; los contratos de esta página están respaldados por los modelos y las pruebas con HTTP simulado, no por una prueba de integración contra el servidor desplegado.

## 1. Alcance y tecnologías

Cliente Flutter para pacientes y terapeutas. Implementa login por correo y contraseña, Google Sign-In en iOS, persistencia del token Sanctum, restauración de sesión, navegación por rol y logout. Los dashboards son pantallas provisionales.

| Componente | Configuración |
| --- | --- |
| Flutter verificado | 3.47.5 stable |
| Dart verificado | 3.13.4; restricción `^3.13.4` |
| Versión de aplicación | `1.0.0+1` |
| UI | Material 3, tema claro/oscuro según sistema |
| HTTP | `http: ^1.0.0` |
| Almacenamiento | `flutter_secure_storage: ^11.2.0` |
| Google | `google_sign_in: ^7.2.0` |
| Validación | `flutter_test`, `flutter_lints: ^6.0.0` |
| Plataformas presentes | Android e iOS |

`pubspec.yaml` declara restricciones y `pubspec.lock` fija versiones resueltas. No hay proyecto web; la configuración usa `dart:io`.

## 2. Arquitectura y estructura

```text
lib/
  main.dart                                  Entrada y runApp
  app/app.dart                               MaterialApp y repositorio compartido
  core/
    config/app_environment.dart              Entorno y URL base
    network/api_client.dart                  Transporte HTTP y Bearer opcional
    network/api_exceptions.dart              Errores de API y red
    routing/app_router.dart                  Builders de login y dashboards
    routing/app_routes.dart                  Constantes de rutas
    theme/app_theme.dart                     Paleta y temas
  features/auth/
    data/models/auth_result.dart             Resultado de login
    data/models/auth_user.dart               Usuario de login y /me
    data/repositories/auth_repository.dart   Login, restauración y logout
    data/services/google_sign_in_service.dart
    presentation/pages/auth_gate.dart        Decisión de arranque
    presentation/pages/login_page.dart       Login por correo o Google
    presentation/widgets/logout_button.dart
  features/patient/presentation/pages/patient_dashboard_page.dart
  features/therapist/presentation/pages/therapist_dashboard_page.dart
```

La UI usa `StatefulWidget` y `setState`, sin Provider, Riverpod ni BLoC. `PapatzoaApp` crea un `AuthRepository` para el gate y las rutas, y lo cierra al desmontarse. Repositorio, cliente HTTP y almacenamiento admiten inyección para pruebas. `currentUser` vive en memoria dentro del repositorio.

## 3. Entornos y ejecución

`ENV` se define al compilar con `--dart-define`. Solo `production` selecciona producción; cualquier otro valor usa desarrollo. No se carga `.env` ni existe una variable de compilación para sobrescribir la URL.

| Entorno | Destino | URL base |
| --- | --- | --- |
| Desarrollo (predeterminado) | Android Emulator | `http://10.0.2.2:8000/api` |
| Desarrollo | iOS Simulator y otras plataformas nativas | `http://127.0.0.1:8000/api` |
| Producción | Android e iOS | `https://papatzoa.onrender.com/api` |

```sh
flutter pub get
flutter devices
flutter run -d ios --dart-define=ENV=development
flutter run --dart-define=ENV=production
```

En desarrollo, Laravel debe escuchar en el puerto 8000 y ofrecer `/api/login`, `/api/login/google`, `/api/me` y `/api/logout`. En dispositivos físicos las direcciones de desarrollo no apuntan al equipo anfitrión: configurar una dirección accesible y revisar el transporte nativo.

## 4. Cliente HTTP

`ApiClient` normaliza la URL con barra final para preservar `/api/`. Sus consumidores usan rutas relativas, como `login` o `me`; se rechazan rutas con barra inicial o esquema. Ofrece GET, POST, PUT, PATCH y DELETE. GET y POST aceptan un token opcional por llamada y añaden `Authorization: Bearer <token>` solo cuando se proporciona. No hay token global ni otro cliente HTTP para autenticación.

Todas las solicitudes envían `Accept: application/json`. Los cuerpos se serializan con `jsonEncode` y `Content-Type: application/json`. El timeout de 20 segundos cubre envío y lectura. Los códigos fuera de 200–299 producen `ApiException` con código HTTP y mensaje genérico. Socket, `http.ClientException` y timeout producen `NetworkException`. Ni el token ni el cuerpo de error del servidor se imprimen. No hay refresh token ni reintentos automáticos en el cliente.

## 5. Contratos y flujo de autenticación

### Correo y contraseña

`POST /api/login` recibe `{"email":"usuario@example.com","password":"contraseña"}`. Una respuesta 2xx contiene `message`, `token` no vacío y `user`. El repositorio guarda `auth_token` en `FlutterSecureStorage`, actualiza `currentUser` y devuelve `AuthResult`. La contraseña no se persiste.

El formulario valida correo requerido con formato básico y contraseña no vacía. Recorta el correo antes de enviarlo. Bloquea envíos duplicados, muestra progreso, limpia la contraseña tras éxito y navega según `user.role`: `patient` a `/patient`, `therapist` a `/therapist`. Un rol desconocido conserva el login y muestra un mensaje legible. HTTP 401 y 422 tienen mensajes específicos; los demás errores muestran mensajes seguros.

### Google Sign-In

En iOS, `GoogleSignInService` inicializa el SDK, solicita autenticación y envía el ID token mediante `POST /api/login/google` con `{"id_token":"..."}`. Usa el mismo parser, almacenamiento y navegación por rol que el login por contraseña. La cancelación no crea sesión. El botón de Google y el de correo se bloquean mutuamente durante una solicitud. La configuración iOS incluye `GIDClientID`, `GIDServerClientID` y el esquema de retorno en `Info.plist`. Android OAuth aún no está configurado como flujo validado.

### Usuario y `/api/me`

La forma esperada de `user` es:

```json
{
  "id": 32,
  "nombre": "Ricardo",
  "apellido": null,
  "correo": "usuario@example.com",
  "terapeuta": false,
  "role": "patient"
}
```

`AuthUser` convierte `apellido: null` en cadena vacía. La navegación usa `role`, no el booleano `terapeuta`.

### Restauración de sesión

`AuthGate` es la primera pantalla. Mientras decide, muestra una carga discreta de Papatzoa y no construye `LoginPage`. `AuthRepository.restoreSession()` lee `auth_token`:

| Resultado | Acción |
| --- | --- |
| No hay token | Abre `/login` sin solicitud HTTP |
| `GET /api/me` devuelve 200 | Parsea `user`, actualiza `currentUser` y abre el dashboard del rol |
| `/api/me` devuelve 401 | Borra `auth_token`, limpia `currentUser` y abre `/login` |
| Falla la red | Conserva el token y muestra «No pudimos conectar con Papatzoa.» y «Reintentar» |
| Otro error de validación | Muestra la misma pantalla de reintento sin descartar el token |

La llamada a `/me` incluye Bearer. El gate reemplaza el stack al navegar. No hay refresh token, expiración personalizada, biometría ni toggle de recordar sesión.

### Logout

Ambos dashboards provisionales muestran «Cerrar sesión». El botón se deshabilita durante el proceso. `AuthRepository.logout()` lee el token y, si existe, envía `POST /api/logout` con Bearer. En `finally` borra `auth_token` y limpia `currentUser`. Un 401 o un fallo de red no impiden el cierre local. Después se abre `/login` con `pushNamedAndRemoveUntil`, eliminando las rutas anteriores para que «atrás» no regrese al dashboard. El logout remoto durante un fallo de red queda sin confirmar, aunque el token local se elimina.

## 6. Interfaz y rutas

`AppRouter` registra `/login`, `/patient` y `/therapist`. Los dashboards reciben `AuthUser` como argumento y muestran solo una bienvenida provisional y el botón de logout. Las constantes de citas, diario, red de apoyo, pacientes y cuenta existen, pero no tienen pantallas ni builders. Registro y recuperación de contraseña siguen deshabilitados. El formulario conserva `SafeArea`, desplazamiento con teclado abierto, Next/Done, visibilidad de contraseña y liberación de controladores en `dispose`.

## 7. Configuración nativa y compilación

### iOS

Bundle ID: `com.papatzoa.papatzoaMobile`. Deployment target: iOS 15.0. `Runner.entitlements` declara `keychain-access-groups` vacío y está referenciado por Debug, Profile y Release. `Info.plist` incluye los IDs y esquema de Google. Verificar firma, equipo de desarrollo, retorno OAuth, acceso real a Keychain y conectividad en dispositivo antes de distribuir.

```sh
flutter build ios --simulator --debug --dart-define=ENV=development
flutter build ios --release --dart-define=ENV=production
```

Requiere macOS y Xcode; distribución requiere firma. La configuración de transporte HTTP local debe comprobarse en el destino concreto.

### Android

Application ID y namespace: `com.papatzoa.papatzoa_mobile`. Java y objetivo Kotlin: 17. compileSdk, minSdk, targetSdk y NDK se delegan a Flutter.

```sh
flutter build apk --debug --dart-define=ENV=development
flutter build appbundle --release --dart-define=ENV=production
```

Release usa actualmente firma debug. El permiso `INTERNET` está en manifests debug/profile, pero falta en el principal. Antes de distribuir, configurar firma release, permiso de red principal y transporte de cada variante. Estos comandos describen el proceso; no certifican una compilación release validada.

## 8. Pruebas y verificación

```sh
dart format lib test
flutter analyze
flutter test
git diff --check
```

Validación del 27 de septiembre de 2026: `flutter analyze` sin incidencias y 35 tests aprobados. Los tests usan `MockClient` y almacenamiento simulado; no hacen solicitudes reales ni certifican Google OAuth o Keychain en un dispositivo.

| Archivo | Cobertura principal |
| --- | --- |
| `test/api_client_test.dart` | URL y excepciones |
| `test/auth_repository_test.dart` | Contrato de login, token, errores y red |
| `test/google_login_test.dart` | Google, cancelación y navegación por rol |
| `test/login_navigation_test.dart` | Navegación y mensajes del login por correo |
| `test/session_gate_test.dart` | Sin token, ambos roles, 401, retry y logout sin red |
| `test/widget_test.dart` | Formulario, carga, teclado y arranque |
| `test/auth_test_support.dart` | Fixtures y cliente simulado |

## 9. Mantenimiento y pendientes

Añadir módulos en `features`, reutilizar `ApiClient`, registrar nuevas rutas y mantener contratos cubiertos por pruebas. No versionar tokens, contraseñas ni claves de firma. Pendientes funcionales: dashboards reales, citas, diario, red de apoyo, notificaciones, registro y recuperación de contraseña. Pendientes de plataforma: Android OAuth, firma Android release, permiso de red release y pruebas nativas de OAuth, almacenamiento y conectividad.
