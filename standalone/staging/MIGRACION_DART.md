# Migración de MyStreamTV: Python → Dart (Sin Servidor)

## 📋 Resumen de la Arquitectura

### Antes (Backend centralizado)
```
App Flutter ←→ FastAPI Backend ←→ TMDB API
                    ↓
                SQLite/JSON
```

### Después (Standalone)
```
App Flutter (Todo integrado)
├── Schedule Engine (Dart)
├── Content Pool (JSON local)
├── Cooldown Tracker (JSON local)
└── Channel Config (JSON local)
     ↓ (Actualización diaria)
  TMDB API
```

---

## 🎯 Archivos Dart Creados

1. **mystreamtv_dart_models.dart** 
   - Equivalente a `models.py`
   - Clases: `Program`, `TimeSlot`, `Channel`, `ContentMetadata`
   - Manejo de serialización JSON

2. **mystreamtv_dart_schedule_engine.dart**
   - Equivalente a `schedule_engine.py`
   - Lógica completa de generación de EPG
   - Deduplicación, cooldown (7 días), distribución en slots

3. **mystreamtv_dart_storage.dart**
   - Manejo de almacenamiento local
   - Persistencia de JSON en documentos del app
   - No necesita SQLite

4. **mystreamtv_dart_example.dart**
   - Ejemplo de integración en Flutter
   - `EPGViewModel` con patrón MVVM
   - Widgets para mostrar EPG

---

## 🚀 Pasos de Migración

### Paso 1: Preparar tu Flutter Project

```bash
# Crea nuevo proyecto Flutter (si no lo tienes)
flutter create mystreamtv_app --org com.mystreamtv

cd mystreamtv_app

# Agrega dependencias necesarias en pubspec.yaml
flutter pub add path_provider intl
```

**pubspec.yaml:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  path_provider: ^2.1.0
  intl: ^0.19.0
```

### Paso 2: Copiar los Archivos Dart

```
lib/
├── models/
│   └── models.dart                    (contenido de mystreamtv_dart_models.dart)
├── services/
│   ├── schedule_engine.dart           (contenido de mystreamtv_dart_schedule_engine.dart)
│   └── storage_service.dart           (contenido de mystreamtv_dart_storage.dart)
└── viewmodels/
    └── epg_viewmodel.dart             (contenido de mystreamtv_dart_example.dart)
```

### Paso 3: Preparar tus JSONs

**Exportar desde Python:**

```python
# En tu backend actual
from services.schedule_engine import ScheduleEngine
from models.models import Channel
import json

engine = ScheduleEngine()

# Guardar pool
with open('content_pool.json', 'w') as f:
    json.dump([m.to_dict() for m in engine._global_pool], f)

# Guardar cooldown
with open('cooldown.json', 'w') as f:
    json.dump({
        ch_id: {str(tid): d.isoformat() for tid, d in dates.items()}
        for ch_id, dates in engine._recently_played.items()
    }, f)

# Guardar canales
with open('channels.json', 'w') as f:
    json.dump({
        'channels': [c.to_dict() for c in engine.channels]
    }, f)
```

### Paso 4: Embeber JSONs en la App

Crea `assets/data/` en tu proyecto:

```
assets/
└── data/
    ├── content_pool.json       (tu pool actual de 2500 películas)
    ├── cooldown.json           (tracking de cooldown)
    └── channels.json           (tus canales configurados)
```

**En pubspec.yaml:**
```yaml
flutter:
  assets:
    - assets/data/
```

### Paso 5: Inicializar en main.dart

```dart
import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'viewmodels/epg_viewmodel.dart';
import 'screens/epg_grid_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storage = LocalStorageService();
  await storage.initialize();
  
  // Cargar JSONs iniciales desde assets si no existen
  await _setupInitialData(storage);
  
  runApp(const MyApp());
}

Future<void> _setupInitialData(LocalStorageService storage) async {
  // Si es la primera vez, copiar assets a almacenamiento
  try {
    final existingPool = await storage.loadContentPool();
    if (existingPool == '[]') {
      // Cargar desde assets
      final poolJson = await rootBundle.loadString('assets/data/content_pool.json');
      final channelsJson = await rootBundle.loadString('assets/data/channels.json');
      final cooldownJson = await rootBundle.loadString('assets/data/cooldown.json');
      
      final poolData = jsonDecode(poolJson) as List;
      await storage.saveContentPool(
        poolData.cast<Map<String, dynamic>>()
      );
      await storage.saveChannels(channelsJson);
      await storage.saveCooldownData(cooldownJson);
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

---

## 📊 Flujo de Actualización Diaria

Tu app necesita:

1. **Actualización automática del pool** (una vez al día)
2. **Regeneración de EPG**
3. **Sincronización de cooldown**

### Implementar actualización automática:

```dart
// En tu ViewModel o servicio
Future<void> scheduleDaily RefreshPool() async {
  // Usar WorkManager o similar para background tasks
  // En Android TV, simplemente checkear al startup
  
  final now = DateTime.now();
  final lastRefresh = await _prefs.getLastPoolRefresh() ?? DateTime(2020);
  
  final daysSinceRefresh = now.difference(lastRefresh).inDays;
  
  if (daysSinceRefresh >= 1) {
    // Descargar nuevas películas desde TMDB
    await _fetchNewContentFromTMDB();
    await _prefs.setLastPoolRefresh(now);
  }
}

Future<void> _fetchNewContentFromTMDB() async {
  // Llamar a tu backend o TMDB directamente
  // Obtener solo películas/series nuevas (últimas 24 horas)
  // Mergearlo con el pool existente
  // Guardar todo
}
```

---

## 🔑 Manejo de API Key de TMDB

**Opción 1: En la app (menos seguro pero simple)**
```dart
const String TMDB_API_KEY = 'tu_api_key_aqui';
// Riesgo: bots pueden encontrar la key en GitHub
```

**Opción 2: Cloudflare Worker (recomendado)**
```dart
// Tu app llama a un worker proxy
final response = await http.get(
  Uri.parse('https://mystreamtv-proxy.workers.dev/api/discover?genre=28')
);
```

**Cloudflare Worker (wrangler.toml):**
```toml
[env.production]
account_id = "tu_account_id"
name = "mystreamtv-proxy"
```

---

## 🧪 Testing

```dart
// test/schedule_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mystreamtv_app/services/schedule_engine.dart';
import 'package:mystreamtv_app/models/models.dart';

void main() {
  late ScheduleEngine engine;

  setUp(() {
    engine = ScheduleEngine();
  });

  test('Should generate schedule for channel', () async {
    // Load test data
    await engine.loadContentPool(_getTestPool());
    await engine.loadChannels(_getTestChannels());

    final channel = engine.getAllChannels().first;
    final schedule = await engine.generateScheduleForDate(
      channel: channel,
      targetDate: DateTime(2025, 2, 20),
    );

    expect(schedule, isNotEmpty);
    expect(schedule.first.startTime.isBefore(schedule.last.endTime), true);
  });

  test('Should respect cooldown (7 days)', () async {
    // Test cooldown logic
    final recentlyPlayed = {
      'tmdb_123': DateTime.now().subtract(Duration(days: 5))
    };
    
    // Movie should NOT appear in schedule (still in cooldown)
    // ... test logic
  });
}

String _getTestPool() => '''[...]'''; // JSON test data
String _getTestChannels() => '''[...]'''; // JSON test data
```

---

## 📈 Performance en TV Vieja

El Schedule Engine es optimizado para dispositivos bajos:

| Operación | Tiempo Esperado |
|-----------|-----------------|
| Cargar pool (2500 items) | < 500ms |
| Generar EPG (7 slots) | < 1000ms |
| Cambiar canal | < 100ms |
| Guardad cooldown | < 100ms |

Si es lento, optimizar:
```dart
// Usar `compute` para background
final schedule = await compute(
  _generateScheduleInBackground,
  (channel, date, engine),
);

static List<Program> _generateScheduleInBackground(
  (Channel, DateTime, ScheduleEngine) params,
) {
  return params.$3.generateScheduleForDateSync(
    channel: params.$1,
    targetDate: params.$2,
  );
}
```

---

## 🎨 Cambios en la UI

Tu HTML/Flutter web ya existe. Solo necesitas adaptar:

```dart
// mapping de tu interface actual
// Mostrar grid de canales
// Permitir seleccionar y ver detalles
// Botones de "Open in Netflix" con deepLinks
```

---

## 🚢 Publicar en Google Play

```bash
# Generar key signing
keytool -genkey -v -keystore ~/my-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias my-key-alias

# Configurar en android/key.properties
storeFile=/Users/username/my-release-key.jks
storePassword=password
keyPassword=password
keyAlias=my-key-alias

# Build release APK
flutter build apk --release

# O AAB para Play Store (recomendado)
flutter build appbundle --release
```

Subir a Google Play Console:
- Create app
- Subir AAB
- Configurar descripciones, screenshots
- Crear programa beta si quieres tester
- Publicar

---

## ❓ Preguntas Frecuentes

**Q: ¿Qué tamaño tendrá el APK?**
A: ~50-70MB sin assets. Con content_pool.json embebido:
- 2500 películas ~2.5MB (JSON comprimido)
- APK final: ~60-80MB

**Q: ¿Cada usuario tendrá su propio config?**
A: Sí. El almacenamiento es local, sin sincronización central.

**Q: ¿Qué pasa si el usuario desinstala?**
A: Todos los datos se pierden. Pero el pool de TMDB está disponible, así que puede rebuildearse.

**Q: ¿Puedo compartir canales entre usuarios en el mismo TV?**
A: Sí, guardando `channels.json` en almacenamiento externo compartido.

**Q: ¿Versiones futuras?**
A: Publica actualizaciones en Google Play. Los usuarios descargan la nueva versión con pool actualizado.

---

## 📚 Diferencias Clave Python ↔ Dart

| Python | Dart |
|--------|------|
| `dict` | `Map<String, dynamic>` |
| `list` | `List<T>` |
| `datetime` | `DateTime` |
| `@dataclass` | `class` + `toJson/fromJson` |
| `random.seed()` | `Random(seed)` |
| `async/await` | `async/await` |
| `json.dump()` | `jsonEncode()` |
| `pathlib.Path` | `dart:io` + `path_provider` |

---

## 🎬 Próximos Pasos

1. ✅ Copiar archivos Dart
2. ✅ Preparar JSONs desde Python
3. ✅ Configurar Flutter project
4. ✅ Implementar storage
5. ✅ Implementar refresh diario
6. ✅ Testear localmente
7. ✅ Publicar en Google Play

---

¿Necesitas ayuda con algo específico?
