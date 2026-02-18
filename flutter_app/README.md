# MyStreamTV Flutter App

Aplicación Flutter para Google TV y móvil que consume la API REST del backend MyStreamTV.

## Estructura del proyecto

```
flutter_app/
├── lib/
│   ├── main.dart                    # Entry point + routing
│   ├── core/
│   │   ├── api_service.dart         # HTTP client para la API
│   │   ├── server_config.dart       # Persistencia de la URL del servidor
│   │   └── constants.dart           # Colores, tamaños, helpers TMDB
│   ├── models/
│   │   ├── channel.dart
│   │   ├── program.dart
│   │   ├── guide_response.dart
│   │   └── provider_info.dart
│   ├── providers/
│   │   ├── epg_provider.dart        # Estado de la guía EPG
│   │   └── focus_provider.dart      # Estado del foco D-pad
│   ├── screens/
│   │   ├── server_setup_screen.dart # Primera configuración del servidor
│   │   ├── epg_screen.dart          # Pantalla principal EPG
│   │   └── settings_screen.dart     # Cambiar URL del servidor
│   └── widgets/
│       ├── channel_sidebar.dart
│       ├── time_ruler.dart
│       ├── program_card.dart
│       └── program_detail_overlay.dart
└── android/
    └── app/src/main/AndroidManifest.xml
```

## Requisitos previos

- Flutter SDK 3.x ([flutter.dev](https://flutter.dev/docs/get-started/install))
- Android Studio (para el SDK de Android y emulador)
- El backend de MyStreamTV corriendo en la red local

## Instalación rápida

### Linux (casa)
```bash
# Instalar Flutter
sudo snap install flutter --classic
# O descargar y extraer manualmente en ~/flutter

# Verificar instalación
flutter doctor

# Instalar dependencias del proyecto
cd mystreamtv/flutter_app
flutter pub get

# Correr en emulador o dispositivo conectado
flutter run
```

### Windows (trabajo)
```powershell
# Después de instalar Flutter y agregar al PATH:
cd c:\tempop\antigravity\mystreamtv\flutter_app
flutter pub get
flutter run
```

## Iniciar el backend para que la TV pueda conectarse

**Importante:** usar `--host 0.0.0.0` para que otros dispositivos en la red puedan acceder:

```bash
cd mystreamtv/backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

## Primera vez que corres la app

La app te pedirá la IP del servidor. Escribe la IP de tu computadora en la red local, por ejemplo: `192.168.1.50`

La app valida la conexión con `/health` antes de guardar.

## Build para Android TV / Google TV

```bash
# APK para instalar en la TV (sideload)
flutter build apk --release --target-platform android-arm64

# El APK queda en: build/app/outputs/flutter-apk/app-release.apk
```

Para instalar en la TV via ADB:
```bash
adb connect <IP_DE_LA_TV>
adb install build/app/outputs/flutter-apk/app-release.apk
```
