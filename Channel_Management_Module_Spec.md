# MyStreamTV - Especificación: Módulo de Mantenimiento de Canales

## 🎯 Objetivo

Crear una interfaz de administración (UI + API) que permita crear, editar y eliminar canales dinámicamente sin tocar código, usando formularios que generen el JSON necesario para que el sistema automáticamente llene la programación.

---

## 📋 Contexto

Actualmente los canales se definen en `data/channel_templates.json`. El objetivo es crear un módulo de administración que:

1. **Permita crear canales nuevos** sin editar JSON manualmente
2. **Valide los criterios** para asegurar que el canal se pueda llenar
3. **Preview del resultado** antes de activar el canal
4. **Activar/Desactivar canales** temporalmente
5. **Clonar canales existentes** para crear variaciones

---

## 🏗️ Componentes del Sistema

### 1. API Backend (FastAPI)

**Archivo:** `routers/channel_management.py`

#### Endpoints Requeridos:

```python
# CRUD Básico
GET    /api/channels              # Listar todos los canales
GET    /api/channels/{channel_id} # Obtener un canal específico
POST   /api/channels              # Crear nuevo canal
PUT    /api/channels/{channel_id} # Actualizar canal existente
DELETE /api/channels/{channel_id} # Eliminar canal
PATCH  /api/channels/{channel_id}/toggle  # Activar/Desactivar

# Utilidades
POST   /api/channels/{channel_id}/clone   # Clonar canal
POST   /api/channels/{channel_id}/preview # Preview de contenido
GET    /api/channels/icons                # Lista de iconos disponibles
GET    /api/channels/validation-rules     # Reglas de validación

# Metadata helpers
GET    /api/tmdb/genres           # Lista de géneros TMDB
GET    /api/tmdb/keywords/search  # Buscar keywords
GET    /api/universes             # Lista de universos detectables
```

---

### 2. Modelo de Datos: Canal

Basado en el JSON actual, el formulario necesita capturar:

```typescript
interface Channel {
  // Identificación
  id: string;                    // Slug único (auto-generado o manual)
  name: string;                  // Nombre del canal (ej: "🚀 Sci-Fi Channel")
  icon: string;                  // Emoji o código del icono
  
  // Configuración
  enabled: boolean;              // Activo/Inactivo (default: true)
  priority: number;              // Orden en el EPG (1-100)
  
  // Metadata
  description?: string;          // Descripción opcional del canal
  created_at: string;            // ISO timestamp
  updated_at: string;            // ISO timestamp
  
  // Programación
  day_of_week?: number;          // 0-6 (opcional, para rotación semanal)
  slots: TimeSlot[];             // Lista de bloques de tiempo
}

interface TimeSlot {
  // Horario
  start: string;                 // HH:MM formato 24h (ej: "14:00")
  end: string;                   // HH:MM formato 24h (ej: "18:00")
  label: string;                 // Etiqueta del slot (ej: "Sci-Fi Clásico")
  
  // Filtros de Contenido
  content_type?: "movie" | "tv"; // Tipo de contenido
  
  // Filtros por Género
  genres?: number[];             // IDs de género TMDB (ej: [878, 28])
  
  // Filtros Temporales
  decade?: [number, number];     // Rango de años (ej: [1980, 1989])
  release_year_min?: number;     // Año mínimo
  release_year_max?: number;     // Año máximo
  
  // Filtros de Calidad
  vote_average_min?: number;     // Rating mínimo (0-10)
  vote_count_min?: number;       // Votos mínimos (default: 100)
  
  // Filtros por Keywords
  keywords?: string[];           // Keywords TMDB o texto libre
  exclude_keywords?: string[];   // Keywords a excluir (blacklist)
  
  // Filtros por Universo/Franchise
  universes?: string[];          // Universos detectados (ej: ["Star Wars", "Marvel"])
  
  // Filtros Geográficos
  origin_country?: string[];     // Códigos ISO (ej: ["MX", "ES"])
  original_language?: string;    // Código ISO (ej: "es", "en")
  
  // Filtros de Personas
  director_id?: number;          // ID TMDB del director
  
  // Lista Manual (override)
  custom_tmdb_ids?: number[];    // IDs específicos de TMDB (curaduría manual)
  
  // Configuración Avanzada
  mood_tag?: string;             // Para canal Mood Match (ej: "comfort", "cry")
  seasonal_dates?: [string, string]; // Rango de fechas (ej: ["12-01", "12-31"])
}
```

---

## 🎨 UI/UX del Módulo de Administración

### Pantalla 1: Lista de Canales

**Vista:** Grid o tabla con todos los canales

| Canal | Icono | Slots | Estado | Acciones |
|-------|-------|-------|--------|----------|
| 🚀 Sci-Fi Channel | 🚀 | 5 slots | ✅ Activo | [Editar] [Desactivar] [Clonar] [Eliminar] |
| 🎓 Life Lessons | 🎓 | 4 slots | ✅ Activo | [Editar] [Desactivar] [Clonar] [Eliminar] |
| 📅 Navidad 2024 | 🎄 | 2 slots | ⏸️ Inactivo | [Editar] [Activar] [Clonar] [Eliminar] |

**Botones:**
- [+ Nuevo Canal]
- [Importar JSON]
- [Exportar Todos]

---

### Pantalla 2: Crear/Editar Canal

#### Sección A: Información Básica

```
┌─────────────────────────────────────────────┐
│ INFORMACIÓN DEL CANAL                        │
├─────────────────────────────────────────────┤
│                                              │
│ ID del Canal*                                │
│ [scifi-channel____________] Auto-generar ☐  │
│                                              │
│ Nombre del Canal*                            │
│ [🚀 Sci-Fi Channel_____________________]    │
│                                              │
│ Icono*                                       │
│ [🚀] [Selector de Emoji ▼]                  │
│                                              │
│ Descripción (opcional)                       │
│ [Canal dedicado a ciencia ficción de       │
│  todas las épocas_________________________] │
│                                              │
│ Prioridad (orden en EPG)                     │
│ [5___] (1-100)                              │
│                                              │
│ Estado                                       │
│ ○ Activo  ○ Inactivo                        │
│                                              │
└─────────────────────────────────────────────┘
```

**Validaciones:**
- ID debe ser único, lowercase, sin espacios
- Nombre es requerido
- Icono es requerido

---

#### Sección B: Selector de Icono

**Modal/Dropdown con categorías:**

```
🎬 Cine & TV
  🎬 🎥 📺 📹 🎞️ 📽️ 🎦

🎭 Géneros
  🚀 (Sci-Fi)
  💥 (Acción)
  😂 (Comedia)
  👻 (Terror)
  🎓 (Drama/Educativo)
  ❤️ (Romance)

⭐ Universos
  ⭐ (Star Wars)
  🦸 (Superhéroes)
  🧙 (Fantasía)
  🤖 (Robots/Tech)

🌍 Geografía
  🇲🇽 (México)
  🇪🇸 (España)
  🇺🇸 (USA)
  🌎 (Latinoamérica)

🎨 Temáticas
  🎓 (Educativo)
  🔥 (Épico)
  🍿 (Cult)
  📼 (Retro)
  🎵 (Musical)
  📅 (Calendario)

🎭 Mood
  😊 (Feliz)
  😢 (Triste)
  😠 (Rebelde)
  💪 (Inspiracional)
```

**Opción:** Input libre para emojis personalizados

---

#### Sección C: Slots de Programación

```
┌─────────────────────────────────────────────┐
│ BLOQUES DE PROGRAMACIÓN                      │
├─────────────────────────────────────────────┤
│                                              │
│ [+ Agregar Slot]                            │
│                                              │
│ ┌───────────────────────────────────────┐   │
│ │ SLOT 1: Clásicos Sci-Fi        [▲][▼]│   │
│ ├───────────────────────────────────────┤   │
│ │ Horario:  [06:00] a [12:00]          │   │
│ │ Etiqueta: [Clásicos Sci-Fi________]  │   │
│ │                                       │   │
│ │ [Ver Filtros ▼]                      │   │
│ │                                       │   │
│ │ [Duplicar Slot] [Eliminar]           │   │
│ └───────────────────────────────────────┘   │
│                                              │
│ ┌───────────────────────────────────────┐   │
│ │ SLOT 2: Series Sci-Fi          [▲][▼]│   │
│ ├───────────────────────────────────────┤   │
│ │ Horario:  [12:00] a [18:00]          │   │
│ │ Etiqueta: [Series Sci-Fi__________]  │   │
│ │                                       │   │
│ │ [Ver Filtros ▼]                      │   │
│ │                                       │   │
│ │ [Duplicar Slot] [Eliminar]           │   │
│ └───────────────────────────────────────┘   │
│                                              │
└─────────────────────────────────────────────┘
```

**Funcionalidad:**
- Drag & drop para reordenar slots
- Botones [▲][▼] para mover arriba/abajo
- Click en "Ver Filtros" expande formulario de criterios

---

#### Sección D: Filtros de Slot (Expandible)

Cuando usuario hace click en "Ver Filtros" de un slot:

```
┌─────────────────────────────────────────────────────────┐
│ FILTROS DE CONTENIDO - Slot: "Clásicos Sci-Fi"         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│ ▸ TIPO DE CONTENIDO                                     │
│   ☐ Películas  ☐ Series  ☐ Ambos                       │
│                                                          │
│ ▸ GÉNEROS (TMDB) - Debe tener AL MENOS UNO             │
│   ☐ Acción (28)                                         │
│   ☑ Ciencia Ficción (878)                              │
│   ☐ Aventura (12)                                       │
│   ☐ Comedia (35)                                        │
│   [+ Ver todos los géneros]                             │
│                                                          │
│ ▸ DÉCADA / AÑO                                          │
│   ○ Por década:  [1970] a [1999]                       │
│   ○ Por año:     [____] a [____]                       │
│                                                          │
│ ▸ CALIDAD                                               │
│   Rating mínimo (TMDB):  [7.0__] (0-10)                │
│   Votos mínimos:         [100__]                       │
│                                                          │
│ ▸ KEYWORDS                                              │
│   Incluir: [space opera____] [+ Agregar]               │
│            [time travel____] [× Eliminar]              │
│                                                          │
│   Excluir: [horror_________] [+ Agregar]               │
│            [comedy_________] [× Eliminar]              │
│                                                          │
│ ▸ UNIVERSOS                                             │
│   ☐ Star Wars                                           │
│   ☐ Star Trek                                           │
│   ☐ Marvel Cinematic Universe                          │
│   ☐ DC Extended Universe                               │
│   [+ Ver todos]                                         │
│                                                          │
│ ▸ GEOGRAFÍA                                             │
│   País de origen: [MX ▼] [+ Agregar]                   │
│   Idioma original: [es ▼]                              │
│                                                          │
│ ▸ PERSONAS                                              │
│   Director: [Buscar director...___] 🔍                 │
│                                                          │
│ ▸ CURADURÍA MANUAL (OVERRIDE)                           │
│   IDs TMDB específicos:                                 │
│   [550____] (Fight Club)        [× Eliminar]           │
│   [278____] (Shawshank)         [× Eliminar]           │
│   [Buscar película/serie...] [+ Agregar]               │
│                                                          │
│ ▸ AVANZADO                                              │
│   Mood Tag: [comfort ▼] (para Mood Match)              │
│   Fechas estacionales: [12-01] a [12-31]               │
│                                                          │
│ [Guardar Filtros] [Cancelar]                           │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

### Sección E: Preview & Validación

**Botón:** [🔍 Preview de Contenido]

Al hacer click, se ejecuta:

```python
POST /api/channels/{channel_id}/preview
```

**Modal de Preview:**

```
┌─────────────────────────────────────────────────┐
│ PREVIEW: 🚀 Sci-Fi Channel                      │
├─────────────────────────────────────────────────┤
│                                                  │
│ ✅ SLOT 1: Clásicos Sci-Fi (06:00-12:00)        │
│    Contenido encontrado: 47 películas           │
│    Ejemplos:                                     │
│    • Blade Runner (1982) - ⭐ 8.1               │
│    • The Terminator (1984) - ⭐ 7.9             │
│    • Alien (1979) - ⭐ 8.4                       │
│                                                  │
│ ✅ SLOT 2: Series Sci-Fi (12:00-18:00)          │
│    Contenido encontrado: 23 series              │
│    Ejemplos:                                     │
│    • The Expanse - ⭐ 8.5                        │
│    • Battlestar Galactica - ⭐ 8.7              │
│    • Firefly - ⭐ 9.0                            │
│                                                  │
│ ⚠️ SLOT 3: Sci-Fi Premium (22:00-00:00)         │
│    Contenido encontrado: 8 películas            │
│    ⚠️ Advertencia: Pocos resultados. Considera │
│       relajar filtros (bajar rating mínimo).    │
│                                                  │
│ ❌ SLOT 4: Westerns Espaciales (00:00-06:00)    │
│    Contenido encontrado: 0 películas            │
│    ❌ Error: No hay contenido disponible.       │
│       Revisa tus filtros.                       │
│                                                  │
│ [Cerrar] [Ajustar Filtros] [Guardar de Todos…] │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Validaciones automáticas:**
- ✅ Verde: >20 items encontrados
- ⚠️ Amarillo: 5-20 items (funciona pero poca variedad)
- ❌ Rojo: <5 items (canal no viable)

---

## 📊 Lógica de Validación

### Backend: Validador de Slots

**Archivo:** `services/channel_validator.py`

```python
class ChannelValidator:
    """
    Valida que un canal sea viable antes de guardarlo
    """
    
    def validate_channel(self, channel: Channel) -> ValidationResult:
        """
        Valida canal completo
        """
        errors = []
        warnings = []
        
        # 1. Validar estructura básica
        if not channel.id:
            errors.append("ID es requerido")
        
        if not channel.name:
            errors.append("Nombre es requerido")
        
        if not channel.slots or len(channel.slots) == 0:
            errors.append("Canal debe tener al menos 1 slot")
        
        # 2. Validar slots
        for i, slot in enumerate(channel.slots):
            slot_result = self.validate_slot(slot)
            
            if slot_result.content_count == 0:
                errors.append(f"Slot {i+1} '{slot.label}': Sin contenido disponible")
            
            elif slot_result.content_count < 5:
                warnings.append(f"Slot {i+1} '{slot.label}': Poco contenido ({slot_result.content_count} items)")
            
            elif slot_result.content_count < 20:
                warnings.append(f"Slot {i+1} '{slot.label}': Contenido limitado ({slot_result.content_count} items)")
        
        # 3. Validar horarios (no overlap)
        overlaps = self.check_time_overlaps(channel.slots)
        if overlaps:
            errors.append(f"Slots con horarios superpuestos: {overlaps}")
        
        return ValidationResult(
            valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )
    
    def validate_slot(self, slot: TimeSlot) -> SlotValidationResult:
        """
        Valida un slot individual y cuenta contenido disponible
        """
        # Simular query al content pool
        eligible_content = self.content_pool_builder.filter_by_slot(slot)
        
        return SlotValidationResult(
            content_count=len(eligible_content),
            sample_items=eligible_content[:5]  # Primeros 5 para preview
        )
    
    def check_time_overlaps(self, slots: List[TimeSlot]) -> List[str]:
        """
        Detecta si hay slots con horarios superpuestos
        """
        overlaps = []
        
        for i, slot_a in enumerate(slots):
            for j, slot_b in enumerate(slots[i+1:], start=i+1):
                if self.times_overlap(slot_a.start, slot_a.end, 
                                     slot_b.start, slot_b.end):
                    overlaps.append(f"{slot_a.label} y {slot_b.label}")
        
        return overlaps
```

---

## 🔧 Helpers para el Formulario

### 1. Selector de Géneros

**Endpoint:** `GET /api/tmdb/genres`

```json
{
  "movie_genres": [
    {"id": 28, "name": "Acción"},
    {"id": 12, "name": "Aventura"},
    {"id": 16, "name": "Animación"},
    {"id": 35, "name": "Comedia"},
    {"id": 80, "name": "Crimen"},
    {"id": 99, "name": "Documental"},
    {"id": 18, "name": "Drama"},
    {"id": 10751, "name": "Familiar"},
    {"id": 14, "name": "Fantasía"},
    {"id": 36, "name": "Historia"},
    {"id": 27, "name": "Terror"},
    {"id": 10402, "name": "Música"},
    {"id": 9648, "name": "Misterio"},
    {"id": 10749, "name": "Romance"},
    {"id": 878, "name": "Ciencia ficción"},
    {"id": 10770, "name": "Película de TV"},
    {"id": 53, "name": "Suspenso"},
    {"id": 10752, "name": "Bélica"},
    {"id": 37, "name": "Western"}
  ],
  "tv_genres": [
    {"id": 10759, "name": "Acción y Aventura"},
    {"id": 16, "name": "Animación"},
    {"id": 35, "name": "Comedia"},
    {"id": 80, "name": "Crimen"},
    {"id": 99, "name": "Documental"},
    {"id": 18, "name": "Drama"},
    {"id": 10751, "name": "Familiar"},
    {"id": 10762, "name": "Infantil"},
    {"id": 9648, "name": "Misterio"},
    {"id": 10763, "name": "Noticias"},
    {"id": 10764, "name": "Reality"},
    {"id": 10765, "name": "Ciencia ficción y fantasía"},
    {"id": 10766, "name": "Telenovela"},
    {"id": 10767, "name": "Talk show"},
    {"id": 10768, "name": "Guerra y Política"},
    {"id": 37, "name": "Western"}
  ]
}
```

---

### 2. Buscador de Keywords

**Endpoint:** `GET /api/tmdb/keywords/search?q=robot`

```json
{
  "results": [
    {"id": 3616, "name": "robot"},
    {"id": 9951, "name": "robotics"},
    {"id": 14543, "name": "robot uprising"},
    {"id": 180547, "name": "robot cop"}
  ]
}
```

**UI:** Autocomplete que busca mientras el usuario escribe

---

### 3. Lista de Universos

**Endpoint:** `GET /api/universes`

```json
{
  "universes": [
    "Star Wars",
    "Star Trek",
    "Marvel Cinematic Universe",
    "DC Extended Universe",
    "James Bond",
    "Rocky-verse",
    "Planet of the Apes",
    "Matrix",
    "Mission Impossible",
    "Terminator",
    "Fast & Furious",
    "Harry Potter",
    "Lord of the Rings",
    "Jurassic Park"
  ]
}
```

---

### 4. Buscador de Director

**Endpoint:** `GET /api/tmdb/people/search?q=spielberg&role=director`

```json
{
  "results": [
    {
      "id": 488,
      "name": "Steven Spielberg",
      "profile_path": "/abc123.jpg",
      "known_for": ["Jaws", "E.T.", "Jurassic Park"]
    }
  ]
}
```

**UI:** Autocomplete con foto y filmografía

---

### 5. Buscador de Contenido (para curaduría manual)

**Endpoint:** `GET /api/tmdb/search?q=fight+club`

```json
{
  "results": [
    {
      "id": 550,
      "title": "Fight Club",
      "media_type": "movie",
      "year": 1999,
      "poster_path": "/abc.jpg",
      "vote_average": 8.4
    }
  ]
}
```

---

## 💾 Persistencia

### Guardar Canal

**Endpoint:** `POST /api/channels`

**Request Body:**

```json
{
  "id": "scifi-channel",
  "name": "🚀 Sci-Fi Channel",
  "icon": "🚀",
  "enabled": true,
  "priority": 5,
  "description": "Canal dedicado a ciencia ficción",
  "slots": [
    {
      "start": "06:00",
      "end": "12:00",
      "label": "Clásicos Sci-Fi",
      "content_type": "movie",
      "genres": [878],
      "decade": [1970, 1999],
      "vote_average_min": 7.0
    },
    {
      "start": "12:00",
      "end": "18:00",
      "label": "Series Sci-Fi",
      "content_type": "tv",
      "genres": [878, 10765]
    }
  ]
}
```

**Response:**

```json
{
  "status": "created",
  "channel": { /* canal completo */ },
  "validation": {
    "valid": true,
    "warnings": [
      "Slot 1: Contenido limitado (18 items)"
    ]
  }
}
```

---

## 🎯 Flujo de Usuario Completo

### Crear Canal de "Directores: Spielberg Week"

**Paso 1:** Click en [+ Nuevo Canal]

**Paso 2:** Llenar información básica
- Nombre: `🎬 Spielberg Week`
- Icono: 🎬 (selector)
- Descripción: `Ciclo semanal dedicado a Steven Spielberg`

**Paso 3:** Agregar slot
- Click [+ Agregar Slot]
- Horario: 00:00 a 08:00
- Label: "Spielberg: Early Works"
- Expandir filtros:
  - Director: Buscar "Spielberg" → Seleccionar "Steven Spielberg (ID: 488)"
  - Década: 1970-1979

**Paso 4:** Agregar más slots
- Slot 2: "Spielberg: Blockbusters" (1980-1989)
- Slot 3: "Spielberg: Masterpieces" (1990-2000)
- Slot 4: "Spielberg: Recent Work" (2000-2030)

**Paso 5:** Preview
- Click [🔍 Preview de Contenido]
- Ver que cada slot tiene contenido:
  - Slot 1: Jaws, Close Encounters (5 películas) ⚠️
  - Slot 2: E.T., Raiders, Jurassic Park (8 películas) ✅
  - Slot 3: Schindler's List, Saving Private Ryan (6 películas) ✅
  - Slot 4: Munich, Lincoln, Ready Player One (9 películas) ✅

**Paso 6:** Guardar
- Click [💾 Guardar Canal]
- Sistema valida y guarda en `channel_templates.json`
- Muestra mensaje: "Canal creado exitosamente. Recargando EPG..."

**Paso 7:** Ver en EPG
- EPG se recarga automáticamente
- Nuevo canal 🎬 aparece en la lista
- Programación se genera automáticamente

---

## 🔄 Funciones Especiales

### 1. Clonar Canal

**Uso:** Crear variación de un canal existente

**Ejemplo:**
- Tengo "🚀 Sci-Fi Channel" (general)
- Quiero crear "🚀 Sci-Fi Classics Only" (solo películas pre-2000)
- Click [Clonar] en el canal original
- Sistema crea copia con ID `scifi-channel-2`
- Edito: cambio nombre, ajusto filtros de década en todos los slots
- Guardo

---

### 2. Activar/Desactivar Canal

**Uso:** Canales estacionales o temporales

**Ejemplo:**
- Tengo canal "🎄 Navidad 2024"
- En enero, lo desactivo: PATCH `/api/channels/navidad-2024/toggle`
- Canal desaparece del EPG pero se mantiene en JSON
- En diciembre, lo reactivo con otro toggle

---

### 3. Importar/Exportar

**Importar:**
- Click [Importar JSON]
- Upload archivo .json
- Sistema valida estructura
- Agrega canales sin duplicar IDs

**Exportar:**
- Click [Exportar Todos]
- Descarga `channel_templates.json` actualizado
- Puede usarse como backup

---

## ⚙️ Configuración Avanzada (Opcional)

### Sistema de Templates Predefinidos

**Endpoint:** `GET /api/channel-templates`

Ofrece templates comunes:

```json
{
  "templates": [
    {
      "id": "genre-basic",
      "name": "Canal de Género Básico",
      "description": "Canal simple por género con 3 slots (clásicos, modernos, premium)",
      "slots_template": [ /* pre-configurado */ ]
    },
    {
      "id": "universe-franchise",
      "name": "Canal de Universo/Franchise",
      "description": "Canal dedicado a una saga (Star Wars, Marvel, etc.)",
      "slots_template": [ /* pre-configurado */ ]
    },
    {
      "id": "director-cycle",
      "name": "Ciclo de Director",
      "description": "Semana dedicada a un director",
      "slots_template": [ /* pre-configurado */ ]
    },
    {
      "id": "seasonal",
      "name": "Canal Estacional",
      "description": "Canal activo solo en fechas específicas",
      "slots_template": [ /* pre-configurado */ ]
    }
  ]
}
```

**UI:** Al crear canal, opción "Partir de template"

---

## 📱 UI Mobile/Responsive

El módulo de administración debe ser responsive:

- **Desktop:** Formulario completo con todas las opciones
- **Tablet:** Layout adaptado, menos columnas
- **Mobile:** Formulario en pasos (wizard):
  1. Info básica
  2. Slots (uno a la vez)
  3. Preview
  4. Guardar

---

## 🎯 Criterios de Éxito

El módulo es exitoso cuando:

1. ✅ Usuario puede crear canal nuevo en <5 minutos
2. ✅ Preview muestra contenido real antes de guardar
3. ✅ Validaciones previenen canales vacíos
4. ✅ No requiere editar JSON manualmente
5. ✅ Canales se activan inmediatamente en EPG
6. ✅ Puede clonar/modificar canales existentes fácilmente

---

## 📝 Notas Técnicas para Implementación

### Stack Recomendado (Frontend)

**Opción A: React + TypeScript**
- Formularios con React Hook Form
- Validación con Zod
- UI con shadcn/ui o MUI

**Opción B: Vue + TypeScript**
- Formularios con VeeValidate
- UI con Vuetify o PrimeVue

### Backend (ya existente)

- FastAPI
- Pydantic models para validación
- JSON file storage (simple, funciona)

### Mejoras Futuras

1. **Histórico de cambios:** Git-like tracking de ediciones
2. **A/B Testing:** Probar dos versiones de un canal
3. **Analytics:** Qué canales se sintonizan más
4. **Recomendaciones:** "Este slot tiene poco contenido, sugerencia: agregar género X"
5. **Colaboración:** Múltiples admins editando canales

---

## 🚀 Roadmap de Implementación

### Fase 1: API Backend (1-2 días)
- ✅ CRUD endpoints
- ✅ Validador de canales
- ✅ Preview endpoint
- ✅ Helpers (géneros, keywords, etc.)

### Fase 2: UI Básica (2-3 días)
- ✅ Lista de canales
- ✅ Formulario crear/editar
- ✅ Selector de icono
- ✅ Formulario de slots

### Fase 3: Filtros Avanzados (2-3 días)
- ✅ Todos los tipos de filtros
- ✅ Autocompletes
- ✅ Validación en tiempo real

### Fase 4: Preview & Polish (1-2 días)
- ✅ Preview de contenido
- ✅ Clonar canales
- ✅ Importar/Exportar
- ✅ UX improvements

**Total: ~1-2 semanas de desarrollo**

---

Fin de especificación. 📋✨
