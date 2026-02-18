MyStreamTV Flutter App — Walkthrough
✅ Lo que se construyó
App Flutter completa para Google TV / Sony Bravia (y móvil) que consume la API REST del backend MyStreamTV existente.

Estructura del proyecto creado
mystreamtv/flutter_app/          ← 25 archivos creados
├── pubspec.yaml                 # Dependencias
├── analysis_options.yaml        # Lint
├── README.md                    # Instrucciones de instalación
├── assets/images/               # Directorio para assets futuros
├── lib/
│   ├── main.dart                # Entry point + routing automático
│   ├── core/
│   │   ├── api_service.dart     # Cliente HTTP (todos los endpoints)
│   │   ├── server_config.dart   # Persistencia de URL (shared_preferences)
│   │   └── constants.dart       # Colores, tamaños, helpers TMDB
│   ├── models/
│   │   ├── channel.dart
│   │   ├── program.dart         # isNowPlaying, progressFraction helpers
│   │   ├── guide_response.dart
│   │   └── provider_info.dart
│   ├── providers/
│   │   ├── epg_provider.dart    # Estado EPG + caché de providers
│   │   └── focus_provider.dart  # Estado D-pad (channelIdx, programIdx)
│   ├── screens/
│   │   ├── server_setup_screen.dart  # Primera configuración de IP
│   │   ├── epg_screen.dart           # Pantalla principal EPG
│   │   └── settings_screen.dart      # Editar URL del servidor
│   └── widgets/
│       ├── channel_sidebar.dart         # Lista de canales con foco activo
│       ├── time_ruler.dart              # Regla de tiempo sincronizada
│       ├── program_card.dart            # Tarjeta de programa (virtualized)
│       └── program_detail_overlay.dart  # Modal con backdrop + providers
└── android/
    ├── build.gradle / settings.gradle
    └── app/
        ├── build.gradle             # minSdk 21, targetSdk 34
        ├── src/main/
        │   ├── AndroidManifest.xml  # INTERNET + Leanback TV + Phone launcher
        │   └── kotlin/com/mystreamtv/app/MainActivity.kt
Funcionalidades implementadas
Feature	Estado
Setup screen (primera configuración de IP)	✅
Validación de conexión con /health	✅
URL persistida en shared_preferences	✅
Settings screen para cambiar servidor	✅
Guía EPG con grid virtualizado (ListView.builder)	✅
Sidebar de canales con highlight de canal activo	✅
Regla de tiempo sincronizada con el grid	✅
Poster thumbnails TMDB (CachedNetworkImage)	✅
Barra de progreso en programas "en vivo"	✅
Overlay de detalle: backdrop, sinopsis, metadata	✅
Botones de streaming con deep links (url_launcher)	✅
Navegación D-pad completa (↑↓←→ + Enter + Back)	✅
Scroll automático al elemento con foco	✅
Layout responsive TV/tablet/móvil	✅
Refresh de guía desde el top bar	✅
Auto-refresh cada 5 min	— (puede agregarse fácil)
App declarada como Leanback TV en AndroidManifest	✅
Cómo usar cuando llegues a casa
1. Instalar Flutter en Linux
sudo snap install flutter --classic
flutter doctor   # verificar que todo esté OK
2. Instalar dependencias del proyecto
cd ~/ruta/a/mystreamtv/flutter_app
flutter pub get
3. Iniciar el backend con acceso de red
cd ../backend
uvicorn main:app --host 0.0.0.0 --port 8000
# (el --host 0.0.0.0 es CRÍTICO para que la TV pueda conectarse)
4. Correr la app
flutter run   # en emulador Android TV o dispositivo conectado
5. Primera vez: ingresar la IP de tu laptop
La app muestra una pantalla de configuración. Escribe la IP de tu laptop, por ejemplo: 192.168.1.50

6. Instalar en la Sony Bravia via ADB
flutter build apk --release --target-platform android-arm64
adb connect <IP_DE_LA_TV>
adb install build/app/outputs/flutter-apk/app-release.apk