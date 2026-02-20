# ✅ Checklist de Implementación - MyStreamTV Dart

## Fase 0: Preparación (30 min)

- [ ] Lee `RESUMEN_EJECUTIVO.md` completamente
- [ ] Lee `MIGRACION_DART.md` completamente
- [ ] Entiende la arquitectura final (sin servidor)
- [ ] Verifica que tienes Flutter instalado: `flutter --version`
- [ ] Verifica que tienes 2500+ películas en `content_pool.json`

---

## Fase 1: Exportar datos desde Python (1h)

### 1.1 Exportar content_pool.json
```python
# En tu backend actual (Python)
from services.schedule_engine import ScheduleEngine
import json

engine = ScheduleEngine()

# Guardar el pool actual
with open('content_pool_export.json', 'w', encoding='utf-8') as f:
    json.dump(
        [m.to_dict() for m in engine._global_pool], 
        f, 
        indent=2, 
        ensure_ascii=False
    )

print(f"✅ Exportado {len(engine._global_pool)} items")
```

- [ ] Script ejecutado
- [ ] `content_pool_export.json` creado (~2-3MB)
- [ ] Contiene 2500+ items
- [ ] Cada item tiene `tmdb_id`, `title`, `providers`, etc.

### 1.2 Exportar channels.json
```python
with open('channels_export.json', 'w', encoding='utf-8') as f:
    json.dump({
        'channels': [c.to_dict() for c in engine.channels]
    }, f, indent=2, ensure_ascii=False)

print(f"✅ Exportado {len(engine.channels)} canales")
```

- [ ] Script ejecutado
- [ ] `channels_export.json` creado
- [ ] Contiene todos tus canales con slots
- [ ] Cada slot tiene filtros (genres, decade, keywords, etc.)

### 1.3 Exportar cooldown.json
```python
cooldown_data = {}
for channel_id, played_dict in engine._recently_played.items():
    cooldown_data[channel_id] = {
        str(tmdb_id): date.isoformat() 
        for tmdb_id, date in played_dict.items()
    }

with open('cooldown_export.json', 'w') as f:
    json.dump(cooldown_data, f, indent=2)

print(f"✅ Exportado cooldown para {len(cooldown_data)} canales")
```

- [ ] Script ejecutado
- [ ] `cooldown_export.json` creado
- [ ] Contiene tracking de últimas reproduciones por canal
- [ ] Formato: `{channel_id: {tmdb_id: "2025-02-20"}}`

---

## Fase 2: Preparar Flutter Project (1h)

### 2.1 Crear nuevo proyecto (si no lo tienes)
```bash
flutter create mystreamtv_app \
  --org com.mystreamtv \
  --description "MyStreamTV - Tu guía personalizada"
cd mystreamtv_app
```

- [ ] Proyecto creado
- [ ] `flutter run` funciona en emulator/device
- [ ] No hay errores iniciales

### 2.2 Agregar dependencias en pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  path_provider: ^2.1.0
  intl: ^0.19.0
```

```bash
flutter pub get
```

- [ ] `pubspec.yaml` actualizado
- [ ] `flutter pub get` ejecutado sin errores
- [ ] Dependencias instaladas

### 2.3 Crear estructura de carpetas
```bash
mkdir -p lib/{models,services,viewmodels,screens}
mkdir -p assets/data
mkdir -p test
```

- [ ] Carpetas creadas

---

## Fase 3: Copiar archivos Dart (30 min)

### 3.1 Copiar archivos
```bash
# Copiar desde los archivos que te dimos
cp mystreamtv_dart_models.dart lib/models/models.dart
cp mystreamtv_dart_schedule_engine.dart lib/services/schedule_engine.dart
cp mystreamtv_dart_storage.dart lib/services/storage_service.dart
cp mystreamtv_dart_example.dart lib/viewmodels/epg_viewmodel.dart
```

- [ ] `lib/models/models.dart` copiado
- [ ] `lib/services/schedule_engine.dart` copiado
- [ ] `lib/services/storage_service.dart` copiado
- [ ] `lib/viewmodels/epg_viewmodel.dart` copiado

### 3.2 Verificar que compila
```bash
flutter analyze
```

- [ ] Sin errores de análisis
- [ ] Sin warnings críticos
- [ ] Imports correctos

---

## Fase 4: Copiar JSONs a assets (30 min)

### 4.1 Copiar archivos JSON exportados
```bash
cp content_pool_export.json assets/data/content_pool.json
cp channels_export.json assets/data/channels.json
cp cooldown_export.json assets/data/cooldown.json
```

- [ ] `assets/data/content_pool.json` copiado
- [ ] `assets/data/channels.json` copiado
- [ ] `assets/data/cooldown.json` copiado

### 4.2 Declarar assets en pubspec.yaml
```yaml
flutter:
  assets:
    - assets/data/
```

```bash
flutter pub get
```

- [ ] `pubspec.yaml` actualizado
- [ ] Assets declarados
- [ ] Sin errores

---

## Fase 5: Crear main.dart (1h)

### 5.1 Implementar main.dart básico
Crea `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'services/storage_service.dart';
import 'viewmodels/epg_viewmodel.dart';
import 'screens/epg_grid_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storage = LocalStorageService();
  await storage.initialize();
  
  // Copiar JSONs desde assets a storage en primera ejecución
  await _setupInitialData(storage);
  
  runApp(const MyApp());
}

Future<void> _setupInitialData(LocalStorageService storage) async {
  try {
    final poolContent = await storage.loadContentPool();
    
    // Si está vacío (primera vez), copiar desde assets
    if (poolContent == '[]') {
      print('📦 Copying initial data from assets...');
      
      final poolJson = await rootBundle.loadString('assets/data/content_pool.json');
      final channelsJson = await rootBundle.loadString('assets/data/channels.json');
      final cooldownJson = await rootBundle.loadString('assets/data/cooldown.json');
      
      final poolData = (jsonDecode(poolJson) as List)
          .cast<Map<String, dynamic>>();
      
      await storage.saveContentPool(poolData);
      await storage.saveChannels(channelsJson);
      await storage.saveCooldownData(cooldownJson);
      
      print('✅ Initial data setup complete');
    }
  } catch (e) {
    print('⚠️ Error setting up initial data: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyStreamTV',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: EPGGridScreen(),
    );
  }
}
```

- [ ] `lib/main.dart` creado
- [ ] Implementa `_setupInitialData`
- [ ] No hay errores de compilación

### 5.2 Crear EPGGridScreen básica
Crea `lib/screens/epg_grid_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../viewmodels/epg_viewmodel.dart';

class EPGGridScreen extends StatefulWidget {
  @override
  State<EPGGridScreen> createState() => _EPGGridScreenState();
}

class _EPGGridScreenState extends State<EPGGridScreen> {
  late EPGViewModel viewModel;

  @override
  void initState() {
    super.initState();
    final storage = LocalStorageService();
    viewModel = EPGViewModel(storage: storage);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await viewModel.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyStreamTV'),
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${viewModel.errorMessage}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.initialize(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: viewModel.channels.length,
            itemBuilder: (context, index) {
              final channel = viewModel.channels[index];
              return ListTile(
                title: Text('${channel.icon} ${channel.name}'),
                subtitle: Text('${channel.slots.length} slots'),
                onTap: () {
                  // TODO: Navigate to channel detail
                },
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] `lib/screens/epg_grid_screen.dart` creado
- [ ] Muestra lista de canales
- [ ] Carga viewModel correctamente

---

## Fase 6: Testing (2h)

### 6.1 Run en emulator
```bash
flutter run
```

- [ ] App inicia sin crashes
- [ ] Se ve la lista de canales
- [ ] Se cargan sin errores

### 6.2 Verificar datos cargados
En logs debería ver:
```
✅ Storage initialized at: /data/user/0/com.mystreamtv/app_mystreamtv_data
📦 Copying initial data from assets...
✅ Content pool loaded: 2500 items
✅ Cooldown data loaded
✅ Channels configuration loaded: X channels
✅ EPG initialized
```

- [ ] Logs muestran setup correcto
- [ ] 2500 items cargados
- [ ] Canales cargados

### 6.3 Generar una EPG
Agrega botón de test:

```dart
ElevatedButton(
  onPressed: () async {
    final schedule = await viewModel.getScheduleForChannel(
      viewModel.channels[0],
      DateTime.now(),
    );
    print('✅ Generated ${schedule.length} programs');
  },
  child: const Text('Generate EPG'),
)
```

- [ ] EPG se genera sin errores
- [ ] Retorna programas (20-50 por día típicamente)
- [ ] Tiempos están correctos

### 6.4 Verificar cooldown
```dart
// Verificar que movies no se repiten en 7 días
final program1 = schedule[0];
final program2 = schedule.firstWhere(
  (p) => p.tmdbId == program1.tmdbId,
  orElse: () => null,
);
assert(program2 == null, "Movie repeated!");
```

- [ ] Películas no se repiten en el mismo canal
- [ ] Cooldown persiste entre regeneraciones

### 6.5 Testing de persistencia
Cierra app, vuelve a abrir:

```bash
flutter run
# Cierra (exit)
flutter run
```

- [ ] Data persiste
- [ ] Cooldown se mantiene
- [ ] Sin re-downloads

---

## Fase 7: Optimización (1h)

### 7.1 Performance en Android TV
```bash
flutter run -d android_tv_emulator
```

- [ ] App se ve bien en pantalla grande
- [ ] Scroll es smooth (60fps)
- [ ] Cambios de canal rápidos

### 7.2 Optimizar imports en viewmodels
Si hay warnings de imports no usados:

```bash
flutter clean
flutter pub get
flutter analyze
```

- [ ] Sin warnings
- [ ] Análisis limpio

---

## Fase 8: Construir APK/AAB (1h)

### 8.1 Crear key signing
```bash
keytool -genkey -v -keystore ~/my-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias
```

- [ ] Key creada
- [ ] Guardada de forma segura

### 8.2 Configurar signing en Flutter
Crea `android/key.properties`:

```properties
storeFile=/Users/tu_usuario/my-release-key.jks
storePassword=tu_password
keyPassword=tu_password
keyAlias=my-key-alias
```

- [ ] `key.properties` creado
- [ ] Ruta correcta
- [ ] Permisos correctos (600)

### 8.3 Build APK
```bash
flutter build apk --release
```

- [ ] APK creado en `build/app/outputs/flutter-apk/app-release.apk`
- [ ] Tamaño ~60-80MB (normal)
- [ ] Sin errores de build

### 8.4 Build AAB (para Google Play)
```bash
flutter build appbundle --release
```

- [ ] AAB creado en `build/app/outputs/bundle/release/app-release.aab`
- [ ] Listo para Google Play

---

## Fase 9: Google Play Setup (2h)

### 9.1 Crear cuenta developer
- [ ] Cuenta Google creada / validada
- [ ] Pago de $25 completado
- [ ] Google Play Console accesible

### 9.2 Crear aplicación
En Google Play Console:
- [ ] Click "Create app"
- [ ] Nombre: "MyStreamTV"
- [ ] Idioma: Español o Inglés
- [ ] Categoría: "Entertainment" o "Utilities"
- [ ] Tipo de app: "App"

### 9.3 Cargar AAB
En Release → Production (o Beta primero):
- [ ] Upload `app-release.aab`
- [ ] Esperar que procese (~5min)
- [ ] Sin errores

### 9.4 Completar información
En Listing:
- [ ] Título (máx 50 chars)
- [ ] Descripción breve (máx 80 chars)
- [ ] Descripción completa
- [ ] Screenshots (4+)
- [ ] Icono (512x512)
- [ ] Feature graphic (1024x500)

### 9.5 Establecer privacidad
- [ ] Politica de privacidad (enlace)
- [ ] Permisos declarados
- [ ] Contenido: Sin contenido sensible

- [ ] Content rating completado
- [ ] Permisos correctos
- [ ] Información de contacto

---

## Fase 10: Publicación (30 min)

### 10.1 Publicar como Beta (recomendado primero)
- [ ] En "Testing" → "Internal Testing"
- [ ] Invita 5-10 testers
- [ ] Espera 1 semana de feedback

### 10.2 Si todo ok, publicar en producción
En Release → Production:
- [ ] Subir mismo AAB
- [ ] Escribir release notes
- [ ] Click "Review release"
- [ ] Click "Start rollout to Production"

- [ ] App enviada a revisión
- [ ] Esperar aprobación (24-48h)
- [ ] App disponible en Google Play

---

## Fase 11: Post-Publicación (1h)

### 11.1 Actualización diaria automática
Implementa en `epg_viewmodel.dart`:

```dart
Future<void> scheduleDaily RefreshPool() async {
  // Placeholder - implementar WorkManager después
  print('TODO: Schedule daily refresh');
}
```

- [ ] Función esqueletizada
- [ ] TODO documentado para después

### 11.2 Monitorear ratings
En Google Play Console:
- [ ] Revisar ratings diariamente
- [ ] Responder a comentarios negativos
- [ ] Iterar basado en feedback

---

## Checklist Final de Validación

### Funcionalidad
- [ ] App abre sin crashes
- [ ] Canales cargan correctamente
- [ ] EPG se genera en < 2 segundos
- [ ] Deduplicación funciona (no hay repetidos)
- [ ] Cooldown persiste (7 días respetado)
- [ ] Data persiste después de cerrar app

### UI/UX
- [ ] Se ve bien en móvil (6" pantalla)
- [ ] Se ve bien en TV (55" pantalla)
- [ ] D-pad navigation funciona (si es Android TV)
- [ ] Botones accesibles
- [ ] Textos legibles

### Performance
- [ ] Startup < 3 segundos
- [ ] Generación de EPG < 1 segundo
- [ ] Scroll 60 fps en EPG grid
- [ ] Cambio de canal < 200ms
- [ ] Storage < 200MB en disco

### Distribución
- [ ] APK compila sin warnings
- [ ] AAB compila correctamente
- [ ] Google Play submission exitosa
- [ ] App aparece en Play Store
- [ ] Instalable en Android TV

---

## Tiempo Total Estimado

| Fase | Horas | Acumulado |
|------|-------|-----------|
| 0. Preparación | 0.5 | 0.5h |
| 1. Exportar datos | 1 | 1.5h |
| 2. Flutter setup | 1 | 2.5h |
| 3. Copiar Dart | 0.5 | 3h |
| 4. JSONs a assets | 0.5 | 3.5h |
| 5. main.dart | 1 | 4.5h |
| 6. Testing | 2 | 6.5h |
| 7. Optimización | 1 | 7.5h |
| 8. Build APK/AAB | 1 | 8.5h |
| 9. Google Play | 2 | 10.5h |
| 10. Publicación | 0.5 | 11h |
| 11. Post-pub | 1 | 12h |
| **TOTAL** | **12h** | |

**Con experiencia previa en Flutter: 8-10h**
**Sin experiencia: 15-20h**

---

## Notas Importantes

⚠️ **Primero lee TODO este checklist antes de empezar**

⚠️ **Guarda copias de backup de:**
- `content_pool.json` (tu data más valiosa)
- `channels.json` (tu configuración)
- `key.properties` (tu key de signing)

⚠️ **Para Google Play:**
- Account developer = $25 única vez
- App name debe ser único
- Espera 24-48h para aprobación

⚠️ **Testing es crítico:**
- Prueba en múltiples dispositivos
- Prueba en TV específicamente
- Prueba después de actualizar (persistencia)

---

¿Necesitas help con algún paso específico?

Contáctame cuando llegues al paso X y te ayudo a debuggear.
