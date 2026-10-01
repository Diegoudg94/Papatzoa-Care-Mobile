# Documentación técnica de Papatzoa Care Mobile

Revisión: 30 de septiembre de 2026. Describe el código móvil local. La API se desarrolla en otro repositorio; los contratos de esta página están respaldados por los modelos y las pruebas con HTTP simulado, no por una prueba de integración contra el servidor desplegado.

## 1. Alcance y tecnologías

Cliente Flutter para pacientes y terapeutas. Implementa login por correo y contraseña, Google Sign-In en iOS, persistencia del token Sanctum, restauración de sesión, navegación por rol y logout. El módulo de pacientes incluye panel, citas, diario emocional, actividad de sesión, red de apoyo, notificaciones y cuenta. El dashboard del terapeuta sigue siendo provisional.

| Componente | Configuración |
| --- | --- |
| Flutter verificado | 3.47.5 stable |
| Dart verificado | 3.13.4; restricción `^3.13.4` |
| Versión de aplicación | `1.0.0+1` |
| UI | Material 3, tema claro/oscuro según sistema |
| HTTP | `http: ^1.0.0` |
| Almacenamiento | `flutter_secure_storage: ^11.2.0` |
| Google | `google_sign_in: ^7.2.0` |
| Contactos | `flutter_contacts: ^2.5.0` |
| Enlaces externos | `url_launcher: ^6.3.2` |
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
    routing/app_router.dart                  Builders de login, pacientes y terapeuta
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
  features/patient/
    data/models/                           DTO de panel, citas, diario, red y avisos
    data/repositories/                     Acceso autenticado a la API de pacientes
    presentation/pages/                    Panel, citas, actividad, avisos y cuenta
    presentation/diary/                    Lista, detalle y asistente del diario
    presentation/support_network/          CRUD, selector nativo y WhatsApp
    presentation/widgets/                  Navegación inferior compartida
  features/therapist/presentation/pages/therapist_dashboard_page.dart
```

La UI usa `StatefulWidget` y `setState`, sin Provider, Riverpod ni BLoC. `PapatzoaApp` crea un `AuthRepository` para el gate y las rutas, y lo cierra al desmontarse. Los repositorios de pacientes comparten el `ApiClient` y leen `auth_token` de almacenamiento seguro para cada solicitud. Repositorio, cliente HTTP y almacenamiento admiten inyección para pruebas. `currentUser` vive en memoria dentro del repositorio.

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

En desarrollo, Laravel debe escuchar en el puerto 8000 y ofrecer los endpoints de autenticación y pacientes de esta página. En dispositivos físicos las direcciones de desarrollo no apuntan al equipo anfitrión: configurar una dirección accesible y revisar el transporte nativo.

## 4. Cliente HTTP

`ApiClient` normaliza la URL con barra final para preservar `/api/`. Sus consumidores usan rutas relativas, como `login` o `me`; se rechazan rutas con barra inicial o esquema. Ofrece GET, POST, PUT, PATCH y DELETE. GET, POST, PUT y DELETE aceptan un token opcional por llamada y añaden `Authorization: Bearer <token>` solo cuando se proporciona. No hay token global ni otro cliente HTTP para autenticación.

Todas las solicitudes envían `Accept: application/json`. Los cuerpos se serializan con `jsonEncode` y `Content-Type: application/json`. El timeout de 20 segundos cubre envío y lectura. Los códigos fuera de 200–299 producen `ApiException` con código HTTP, cuerpo de respuesta para interpretar errores de validación y mensaje genérico. Socket, `http.ClientException` y timeout producen `NetworkException`. Ni el token ni el cuerpo de error del servidor se imprimen. No hay refresh token ni reintentos automáticos en el cliente.

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

`AuthUser` convierte `apellido: null` en cadena vacía y admite `avatar_url` opcional. La navegación usa `role`, no el booleano `terapeuta`.

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

Ambos roles ofrecen «Cerrar sesión»; el paciente también lo encuentra en su cuenta. El botón se deshabilita durante el proceso. `AuthRepository.logout()` lee el token y, si existe, envía `POST /api/logout` con Bearer. En `finally` borra `auth_token` y limpia `currentUser`. Un 401 o un fallo de red no impiden el cierre local. Después se abre `/login` con `pushNamedAndRemoveUntil`, eliminando las rutas anteriores para que «atrás» no regrese al dashboard. El logout remoto durante un fallo de red queda sin confirmar, aunque el token local se elimina.

## 6. Interfaz y rutas

`AppRouter` registra `/login`, `/patient`, `/therapist` y las rutas de pacientes de la tabla siguiente. Los dashboards resuelven `AuthUser` desde el argumento o `currentUser`; si falta, muestran el login. Las rutas de pacientes construyen sus repositorios con el cliente HTTP compartido. Registro y recuperación de contraseña siguen deshabilitados. El formulario conserva `SafeArea`, desplazamiento con teclado abierto, Next/Done, visibilidad de contraseña y liberación de controladores en `dispose`.

| Ruta | Pantalla |
| --- | --- |
| `/patient` | Panel con terapeuta, próxima cita, actividad y resumen emocional |
| `/patient/citas` | Próximas citas e historial |
| `/patient/citas/nueva` | Selección de horario y solicitud de cita |
| `/patient/citas/detalle` | Detalle; requiere ID entero como argumento de ruta |
| `/patient/diario` | Lista y flujo de registros emocionales |
| `/patient/red-apoyo` | Contactos de apoyo |
| `/patient/notificaciones` | Notificaciones y acciones vinculadas |
| `/patient/mi-cuenta` | Datos de cuenta y cierre de sesión |

El flujo de reagendar y la actividad de sesión tienen pantallas que se abren desde las vistas de pacientes. `patient_bottom_navigation.dart` comparte la navegación principal.

## 7. API del módulo de pacientes

Todas las rutas de esta sección son relativas a `/api/` y llevan token Bearer. Los repositorios rechazan localmente un token ausente con 401. Un 401 en el panel invalida la sesión local y vuelve al login.

| Área | Solicitudes | Contrato que consume el cliente |
| --- | --- | --- |
| Panel | `GET patient/dashboard` | `patient`, `therapist`, `next_appointment`, `between_session_activity`, `emotional_summary`, `sessions` |
| Actividad | `GET patient/session-activity`; `POST patient/session-activity/{id}/response` | `activity`; respuesta con `estado` y `comentario_paciente` |
| Citas | `GET patient/appointments`; `GET patient/appointments/{id}` | `upcoming`, `history`; detalle en `appointment` |
| Disponibilidad | `GET patient/appointments/availability?from=YYYY-MM-DD&to=YYYY-MM-DD` | Terapeuta, zona horaria, modalidades y horarios; rango máximo de 31 días |
| Solicitud | `POST patient/appointments` | `start`, `end`, `motivo`, `modalidad`; lee `appointment` |
| Reagenda | `POST patient/appointments/{id}/reschedule` | `start`, `end`; exige cita nueva en respuesta 201 |
| Propuesta | `POST patient/appointments/{id}/reschedule-proposal/accept` | Exige respuesta 201 con cita nueva vinculada a la anterior |
| Cancelación | `POST patient/appointments/{id}/cancel` | `reason` opcional; exige `appointment.status = cancelada` |
| Diario | `GET patient/diary`; `GET patient/diary/options`; `GET patient/diary/{id}` | `entries`, opciones de emociones e intensidad, detalle en `entry` |
| Registro emocional | `POST patient/diary` | `emocion` obligatoria; `emocion_otro`, `intensidad`, `situacion`, `pensamiento`, `conducta`, `interpretacion`, `reestructuracion` opcionales; respuesta 201 con `entry` |
| Seguimiento | `POST patient/diary/{id}/follow-ups` | `nota` de 1 a 2000 caracteres; respuesta 201 con `follow_up` |
| Red de apoyo | `GET patient/support-network`; `GET patient/support-network/options`; `POST patient/support-network`; `PUT patient/support-network/{id}`; `DELETE patient/support-network/{id}` | `contacts`, opciones de confianza y tipos de apoyo; escritura en `contact`; alta 201, actualización 200 y baja 204 |
| Notificaciones | `GET notifications`; `GET notifications/unread-count`; `POST notifications/{id}/read`; `POST notifications/read-all` | `notifications`, `unread_count`, acción opcional por aviso |

### Actividad entre sesiones

El panel muestra una tarjeta compacta con el título real y el estado. Si
`between_session_activity` es `null`, muestra el estado vacío. «Ver actividad»
abre una pantalla completa y consulta `GET patient/session-activity` de nuevo;
así recibe cambios recientes del terapeuta. La respuesta es `{"activity": null}`
o un objeto con `id`, `title`, `instructions`, `objective` opcional,
`suggested_date`, `status` y `response` opcional. No hay acceso directo a
Supabase desde Flutter.

El wizard muestra actividad, selección de avance, comentario opcional y
revisión. Envía `estado: intentada` para «La intenté» o `estado: realizada`
para «La realicé», junto con `comentario_paciente` (cadena vacía permitida),
mediante `POST patient/session-activity/{id}/response`. Deshabilita el envío
mientras espera, conserva el borrador si falla y recarga el panel al salir.
Una respuesta `intentada` puede actualizarse porque la web lo permite; una
actividad `realizada` deja de ser la actividad actual. El backend valida
pertenencia, visibilidad y límite de 3000 caracteres, cifra el comentario y
notifica al terapeuta con `session_activity_responded`.

Los errores 409 de horarios ocupados y los 422 de validación se convierten en mensajes de usuario. El diario valida emoción personalizada de hasta 100 caracteres e intensidad de 1 a 10. La red de apoyo envía nombre, relación, nivel de confianza, tipos de apoyo y datos opcionales de teléfono y nota; sus límites y opciones se obtienen del backend. Las operaciones del cliente no hacen reintentos automáticos.

La red de apoyo puede importar un contacto elegido por el usuario mediante el selector nativo. Se pide permiso de contactos cuando se usa esa función y se ofrece abrir ajustes si queda denegado permanentemente. El enlace de WhatsApp se construye con lada, teléfono y mensaje editable; abrirlo requiere una aplicación compatible. El acceso nativo a contactos y la apertura de enlaces deben comprobarse en dispositivos reales.

## 8. Configuración nativa y compilación

### iOS

Bundle ID: `com.papatzoa.papatzoaMobile`. Deployment target: iOS 15.0. `Runner.entitlements` declara `keychain-access-groups` vacío y está referenciado por Debug, Profile y Release. `Info.plist` incluye los IDs y esquema de Google y `NSContactsUsageDescription` para el selector de contactos. Verificar firma, equipo de desarrollo, retorno OAuth, acceso real a Keychain y conectividad en dispositivo antes de distribuir.

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

Release usa actualmente firma debug. El manifest principal declara `READ_CONTACTS`. El permiso `INTERNET` está en manifests debug/profile, pero falta en el principal. Antes de distribuir, configurar firma release, permiso de red principal y transporte de cada variante. Estos comandos describen el proceso; no certifican una compilación release validada.

## 9. Pruebas y verificación

```sh
dart format lib test
flutter analyze
flutter test
git diff --check
```

Validación del 30 de septiembre de 2026: `flutter analyze` sin incidencias, 146 tests aprobados y `git diff --check` sin errores. Los tests usan `MockClient` y almacenamiento simulado; no hacen solicitudes reales ni certifican Google OAuth, Keychain, contactos o enlaces externos en un dispositivo.

| Archivo | Cobertura principal |
| --- | --- |
| `test/api_client_test.dart` | URL y excepciones |
| `test/auth_repository_test.dart` | Contrato de login, token, errores y red |
| `test/google_login_test.dart` | Google, cancelación y navegación por rol |
| `test/login_navigation_test.dart` | Navegación y mensajes del login por correo |
| `test/session_gate_test.dart` | Sin token, ambos roles, 401, retry y logout sin red |
| `test/widget_test.dart` | Formulario, carga, teclado y arranque |
| `test/auth_test_support.dart` | Fixtures y cliente simulado |
| `test/patient_*_repository_test.dart`, `test/notification_repository_test.dart` | Contratos HTTP y errores de pacientes |
| `test/patient_*_test.dart`, `test/support_network_phase_10c_test.dart` | Navegación y flujos de pacientes |

## 10. Mantenimiento y pendientes

Añadir módulos en `features`, reutilizar `ApiClient`, registrar nuevas rutas y mantener contratos cubiertos por pruebas. No versionar tokens, contraseñas ni claves de firma. Pendientes funcionales: dashboard del terapeuta, registro y recuperación de contraseña. Pendientes de plataforma: Android OAuth, firma Android release, permiso de red release y pruebas nativas de OAuth, almacenamiento, contactos, enlaces y conectividad.
