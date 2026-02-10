# MyStreamTV - Especificación Funcional: Refactor del Motor de Canales y Recomendaciones

## 🎯 Objetivo

Refactorizar el sistema de canales y recomendaciones para que el contenido sea **multi-canal** y **dinámico**, eliminando las limitaciones actuales donde el contenido está atado a un solo canal o requiere curaduría manual exhaustiva.

---

## 📋 Contexto Actual

### Lo que YA funciona:
- EPG grid visual estilo TV de los 90s
- Integración con TMDB API
- Validación de disponibilidad en plataformas de streaming (región MX)
- Canales con slots horarios definidos en `channel_templates.json`
- Deep links a plataformas

### El Problema Actual:
1. **Contenido repetitivo**: El contenido se repite, a pesar de que hay miles de contenidos disponibles en las plataformas seleccionadas.
2. **Plataformas erróneas**: Se muestra contenido no disponible, o en plataformas no seleccionadas.
3. **Contenido finito**: Los canales se quedan sin contenido rápidamente
4. **Pobre matching**: Keywords de TMDB son problemáticas (ej: "Mandalorian" matchea con "western" y trae westerns chinos no disponibles)

---

## 🎯 Solución Propuesta: Canales Temáticos con Curación Inteligente

### Concepto Core:

**"Canales temáticos agrupados inteligentemente que revelan conexiones emocionales y narrativas, no solo por género"**

El usuario no quiere ver "todo el sci-fi" en un canal - quiere descubrir que:
- **Andor** conecta con **The Expanse** (por hard sci-fi político)
- **Rocky** conecta con **Karate Kid** (por mentor/underdog)
- **Lawrence of Arabia** conecta con **RRR** (por épica visual sincera)
- **The Holdovers** conecta con **Cinema Paradiso** (por nostalgia genuina)

### Filosofía de Diseño:

```
CONTENIDO = Múltiples dimensiones emocionales/narrativas/estéticas
         ↓
CANALES = Agrupaciones temáticas que revelan esas conexiones
         ↓
UN CONTENIDO APARECE EN MÚLTIPLES CANALES
(porque las buenas historias funcionan en múltiples niveles)
```

### Arquitectura Técnica (para lograr la filosofía):

```
Pool Global de Contenido
         ↓
Contenido tiene MÚLTIPLES ATRIBUTOS (géneros, universos, keywords, década, rating, temas)
         ↓
CANALES definen FILTROS multi-dimensionales (no solo género)
         ↓
Contenido aparece en TODOS los canales cuyos filtros matcheen
```

**Ejemplo Real:**
- **Andor** tiene atributos: `[Sci-Fi, Star Wars Universe, 2020s, Rating 8.4, Series, Temas: Rebelión/Sistema Corrupto]`
- Aparece en:
  - 🚀 Sci-Fi Channel (por género sci-fi)
  - ⭐ Star Wars Universe (por pertenecer a ese mundo narrativo)
  - 📺 Series Premium (por rating alto)
  - 🎭 Fuck The System (por tema de rebelión contra injusticia)

---

## 🏗️ Arquitectura de la Solución

### 1. Content Metadata Layer (Nueva)

**Archivo:** `services/content_metadata.py`

Cada item de contenido (película o serie) tiene metadata expandida:

```python
ContentMetadata:
    - tmdb_id: int
    - title: str
    - media_type: str  # "movie" o "tv"
    
    # De TMDB directamente
    - genres: List[int]  # [878, 28] = Sci-Fi + Action
    - year: int
    - vote_average: float
    - vote_count: int
    - keywords: List[str]  # De TMDB Keywords API
    
    # Calculado/Detectado
    - universes: List[str]  # ["Star Wars", "Marvel Cinematic Universe"]
    - decade: int  # 2020
    - is_premium: bool  # vote_average >= 7.5
    
    # Availability (del validator existente)
    - providers: List[dict]  # [{name: "Netflix", logo: "...", link: "..."}]
    
    # Método clave
    - matches_slot_filters(slot: dict) -> bool
```

**Función `matches_slot_filters()`:**
- Verifica si el contenido cumple TODOS los filtros del slot
- Filtros posibles:
  - `genres`: Lista de genre IDs de TMDB
  - `decade`: Rango [año_inicio, año_fin]
  - `vote_average_min`: Rating mínimo
  - `keywords`: Keywords requeridas (flexible matching)
  - `universes`: Universos/franchises requeridos
  - `content_type`: "movie" o "tv"

---

### 2. Universe Detector (Nueva)

**Archivo:** `services/universe_detector.py`

**Propósito:** Detectar automáticamente a qué universos/franchises pertenece cada contenido.

**Reglas de Detección:**

```python
UNIVERSE_RULES = {
    "Star Wars": {
        "keywords": ["star wars", "jedi", "sith"],
        "collections": [10],  # Star Wars Collection ID en TMDB
        "titles_contain": ["Star Wars", "Mandalorian", "Andor", "Ahsoka"]
    },
    "Star Trek": {
        "keywords": ["star trek", "starfleet"],
        "titles_contain": ["Star Trek", "Strange New Worlds", "Lower Decks"]
    },
    "Marvel Cinematic Universe": {
        "keywords": ["marvel cinematic universe"],
        "companies": [420],  # Marvel Studios
        "titles_contain": ["Avengers", "Iron Man", "Captain America"]
    },
    "DC Extended Universe": {
        "keywords": ["dc extended universe"],
        "companies": [9993],
        "titles_contain": ["Batman", "Superman", "Justice League"]
    },
    "James Bond": {
        "keywords": ["james bond", "007"],
        "collections": [645]
    },
    "Rocky-verse": {
        "collections": [1575],
        "titles_contain": ["Rocky", "Creed"]
    },
    "Planet of the Apes": {
        "collections": [1709],
        "keywords": ["planet of the apes"]
    },
    "Matrix": {
        "collections": [2344],
        "keywords": ["the matrix"]
    },
    "Mission Impossible": {
        "keywords": ["mission impossible"],
        "collections": [87359]
    }
    // ... agregar más según necesidad
}
```

**Método Principal:**
```python
def detect_universes(content_data: dict, tmdb_client) -> List[str]:
    """
    Retorna lista de strings con nombres de universos detectados
    Puede retornar lista vacía si no pertenece a ningún universo conocido
    """
```

**Estrategia de Detección:**
1. Obtener detalles completos de TMDB (movie/tv details)
2. Obtener keywords de TMDB
3. Para cada universo en UNIVERSE_RULES:
   - Verificar keywords
   - Verificar collection membership
   - Verificar título (contains match)
   - Verificar production companies
4. Retornar lista de universos detectados

---

### 3. Content Pool Builder (Nueva)

**Archivo:** `services/content_pool_builder.py`

**Propósito:** Construir un pool global de contenido disponible que se usa para llenar TODOS los canales.

**Flujo:**

```
1. Hacer queries amplias a TMDB Discover API
   - Por género principal (Sci-Fi, Action, Comedy, Drama, Horror, Animation)
   - Por content_type (movie y tv separados)
   - Múltiples páginas (~100 items por query)

2. Para cada item retornado:
   a. Validar disponibilidad (usar validator existente)
   b. Si NO disponible en plataformas del usuario → skip
   c. Detectar universos (UniverseDetector)
   d. Obtener keywords de TMDB
   e. Crear objeto ContentMetadata completo
   f. Agregar al pool

3. Deduplicar por tmdb_id + media_type

4. Retornar pool (List[ContentMetadata])
```

**Método Principal:**
```python
def build_content_pool(max_items: int = 1000) -> List[ContentMetadata]:
    """
    Construye pool global de contenido disponible
    Este pool se reutiliza para llenar TODOS los canales
    """
```

**Queries Recomendadas:**
```python
BROAD_QUERIES = [
    # Movies
    {"genres": [878], "content_type": "movie"},  # Sci-Fi
    {"genres": [28], "content_type": "movie"},   # Action
    {"genres": [35], "content_type": "movie"},   # Comedy
    {"genres": [18], "content_type": "movie"},   # Drama
    {"genres": [27], "content_type": "movie"},   # Horror
    {"genres": [16], "content_type": "movie"},   # Animation
    {"genres": [53], "content_type": "movie"},   # Thriller
    
    # TV Series
    {"genres": [10765], "content_type": "tv"},   # Sci-Fi & Fantasy
    {"genres": [35], "content_type": "tv"},      # Comedy
    {"genres": [18], "content_type": "tv"},      # Drama
    {"genres": [16], "content_type": "tv"},      # Animation
    {"genres": [10759], "content_type": "tv"},   # Action & Adventure
]
```

**Parámetros TMDB Discover:**
```python
{
    "region": "MX",
    "watch_region": "MX",
    "with_watch_providers": "<IDs de las 18 plataformas del usuario>",
    "with_watch_monetization_types": "flatrate|ads|free",  # Incluir ad-supported
    "sort_by": "popularity.desc",
    "page": 1-5  # Iterar múltiples páginas
}
```

---

### 4. Schedule Engine Refactorizado

**Archivo:** `services/schedule_engine.py`

**Cambios Principales:**

#### Antes:
```python
fill_channel_schedule(channel):
    for slot in channel.slots:
        query_params = build_query_from_slot(slot)
        results = tmdb.discover(**query_params)
        validate_and_assign(results, slot)
```

#### Después:
```python
# Step 1: Build pool ONCE
content_pool = build_content_pool()

# Step 2: Fill ALL channels from shared pool
fill_all_channels(channels, content_pool):
    for channel in channels:
        for slot in channel.slots:
            eligible = filter_pool_by_slot(content_pool, slot)
            fill_slot(slot, eligible)
```

**Método Principal Nuevo:**
```python
def fill_all_channels(channels: List[dict], date=None) -> dict:
    """
    Llena TODOS los canales usando el pool compartido
    
    Args:
        channels: Lista de canales desde channel_templates.json
        date: Fecha para la programación (default: hoy)
    
    Returns:
        dict: {
            "channel_id_1": [lista de slots con contenido],
            "channel_id_2": [lista de slots con contenido],
            ...
        }
    """
```

**Lógica de Llenado de Slot:**
```python
def fill_slot(slot: dict, eligible_content: List[ContentMetadata]) -> List[dict]:
    """
    Llena un slot de tiempo con contenido elegible
    
    1. Calcular duración del slot (end_time - start_time en minutos)
    2. Shuffle eligible_content para variedad
    3. Iterar sobre contenido:
       - Si es movie: asumir ~120 min
       - Si es tv: asumir ~45 min por episodio
       - Agregar si cabe en tiempo restante (±15 min tolerance)
    4. Retornar lista de contenido que llena el slot
    """
```

---

### 5. Keyword Filter Mejorado

**Archivo:** `services/keyword_filter.py`

**Propósito:** Evitar falsos positivos en matching de keywords.

**Problema Real Encontrado:**
- Búsqueda de "western" → TMDB retorna "The Mandalorian" (space western)
- Búsqueda de "western" → Retorna westerns chinos no disponibles en MX

**Solución:**

```python
# Blacklist de keywords problemáticas
KEYWORD_BLACKLIST = {
    "western": ["space western", "sci-fi western"],
    "superhero": ["anti-hero"],
    # Agregar más según se detecten problemas
}

def filter_by_keywords(items: List[dict], required_keywords: List[str]) -> List[dict]:
    """
    Filtra items que tengan keywords requeridas
    pero excluye falsos positivos según blacklist
    
    1. Para cada item, obtener sus keywords de TMDB
    2. Verificar que matchee al menos una keyword requerida (flexible substring match)
    3. Verificar que NO matchee ninguna keyword blacklisteada
    4. Retornar solo items válidos
    """
```

**Matching Flexible:**
- No requiere match exacto
- "star wars" matchea con "star-wars-universe", "star wars saga", etc.
- Pero "western" NO matchea con "space-western" si está en blacklist

---

### 6. Availability Validator (Ajuste)

**Archivo:** `services/availability_validator.py` (ya existe, ajustar)

**Ajuste Necesario:**

Incluir TODAS las plataformas del usuario (18 plataformas):

```python
USER_PROVIDER_IDS = {
    "Netflix": 8,
    "Amazon Prime Video": 119,
    "Disney Plus": 337,
    "HBO Max": 384,
    "Apple TV Plus": 350,
    "Paramount Plus": 531,
    "Pluto TV": 300,
    "Tubi TV": 283,
    "VIX": 457,
    "Plex": 538,
    "MUBI": 11,
    "MGM Plus Amazon Channel": 528,
    "YouTube Premium": 188,
    # Agregar resto según IDs de TMDB
}

def validate_content(tmdb_item, region="MX"):
    """
    Verificar en flatrate, ads Y free
    (no solo flatrate como antes)
    """
    region_providers = get_providers(tmdb_item)
    
    available_on = []
    
    # Verificar en flatrate (suscripciones)
    if "flatrate" in region_providers:
        available_on.extend(region_providers["flatrate"])
    
    # Verificar en ads (Pluto, Tubi, VIX)
    if "ads" in region_providers:
        available_on.extend(region_providers["ads"])
    
    # Verificar en free (Plex)
    if "free" in region_providers:
        available_on.extend(region_providers["free"])
    
    # Filtrar solo las que el usuario tiene
    user_has = filter_by_user_providers(available_on)
    
    if not user_has:
        return None
    
    return {
        "available": True,
        "providers": user_has,
        "links": generate_deep_links(tmdb_item, user_has)
    }
```

---

## 📝 Estructura de channel_templates.json (Ajustes)

### Nuevos campos opcionales en slots:

```json
{
    "start": "00:00",
    "end": "08:00",
    "label": "Slot Label",
    
    // Filtros existentes (mantener)
    "genres": [878, 28],
    "decade": [2000, 2030],
    "vote_average_min": 7.5,
    "content_type": "movie",
    
    // NUEVO: Filtro por universos
    "universes": ["Star Wars", "Star Trek"],
    
    // Mantener keywords pero mejorar handling
    "keywords": ["space opera", "rebellion"]
}
```

### Ejemplo de Canal Nuevo: Star Wars Universe

```json
{
    "id": "star-wars-universe",
    "name": "⭐ Star Wars",
    "icon": "⭐",
    "slots": [
        {
            "start": "00:00",
            "end": "08:00",
            "label": "Star Wars Series",
            "content_type": "tv",
            "universes": ["Star Wars"]
        },
        {
            "start": "08:00",
            "end": "18:00",
            "label": "Skywalker Saga & Spinoffs",
            "content_type": "movie",
            "universes": ["Star Wars"]
        },
        {
            "start": "18:00",
            "end": "00:00",
            "label": "Star Wars Prime Time",
            "universes": ["Star Wars"],
            "vote_average_min": 7.0
        }
    ]
}
```

### Ejemplo: Canal Sci-Fi (General)

```json
{
    "id": "scifi-channel",
    "name": "🚀 Sci-Fi Channel",
    "icon": "🚀",
    "slots": [
        {
            "start": "06:00",
            "end": "12:00",
            "label": "Clásicos Sci-Fi",
            "genres": [878],
            "decade": [1970, 1999],
            "content_type": "movie"
        },
        {
            "start": "12:00",
            "end": "18:00",
            "label": "Series Sci-Fi",
            "genres": [878, 10765],
            "content_type": "tv"
        },
        {
            "start": "18:00",
            "end": "22:00",
            "label": "Sci-Fi Moderno",
            "genres": [878],
            "decade": [2000, 2030],
            "content_type": "movie"
        },
        {
            "start": "22:00",
            "end": "00:00",
            "label": "Sci-Fi Premium",
            "genres": [878],
            "vote_average_min": 7.5
        }
    ]
}
```

**Resultado:** Andor aparece en AMBOS canales:
- En Star Wars Universe (por universo)
- En Sci-Fi Channel (por género)

---

## 🔄 Flujo de Ejecución Completo

### Al iniciar la aplicación / actualizar programación:

```
1. CargarCanalesDesdeJSON()
   └─> Leer channel_templates.json

2. BuildContentPool()
   ├─> Queries amplias a TMDB Discover
   ├─> Para cada resultado:
   │   ├─> ValidateAvailability() [validator existente]
   │   ├─> DetectUniverses() [nuevo]
   │   ├─> GetKeywords() [TMDB API]
   │   └─> CrearContentMetadata()
   └─> Retornar pool deduplicado

3. FillAllChannels(channels, content_pool)
   ├─> Para cada canal:
   │   └─> Para cada slot:
   │       ├─> FilterPoolBySlot(pool, slot.filters)
   │       │   └─> Llamar ContentMetadata.matches_slot_filters()
   │       └─> FillSlot(slot, eligible_content)
   │           └─> Llenar tiempo del slot con contenido
   └─> Retornar programación completa

4. RetornarEPGAlFrontend()
```

---

## 🎯 Criterios de Éxito

### ✅ Debe Lograr:

1. **Multi-canal automático:**
   - Una serie como "Andor" aparece automáticamente en:
     - Sci-Fi Channel (género)
     - Star Wars Universe (universo detectado)
     - Series Premium (rating alto)

2. **Contenido infinito:**
   - Los canales nunca se quedan sin contenido
   - Mientras haya contenido disponible en plataformas, el pool lo incluye

3. **Sin curaduría manual:**
   - No se requiere agregar series/películas manualmente
   - La detección de universos es automática

4. **Matching inteligente:**
   - Keywords flexibles pero sin falsos positivos
   - "Western" no trae space westerns si no se desea

5. **Cross-platform agnóstico:**
   - El usuario NO necesita saber en qué plataforma está cada cosa
   - Solo ve "disponible" y puede sintonizar

### ✅ Debe Mantener:

1. **UI existente (EPG grid)** sin cambios
2. **API endpoints existentes** compatibles
3. **Deep links a plataformas** funcionando
4. **Validación de disponibilidad** en región MX

---

## 🚀 Plan de Implementación Sugerido

### Fase 1: Componentes Nuevos (sin romper existente)
1. Crear `services/content_metadata.py`
2. Crear `services/universe_detector.py`
3. Crear `services/content_pool_builder.py`
4. Crear `services/keyword_filter.py` (mejorado)

### Fase 2: Integración
1. Refactorizar `services/schedule_engine.py`:
   - Agregar método `build_content_pool()`
   - Modificar `fill_channel_schedule()` para usar pool
   - Agregar método `fill_all_channels()`

2. Actualizar `services/availability_validator.py`:
   - Incluir las 18 plataformas
   - Soportar flatrate + ads + free

### Fase 3: Actualizar Canales
1. Agregar campo `universes` a slots en JSON schema
2. Crear canales de universos (Star Wars, Star Trek, etc.)
3. Mantener canales de género existentes

### Fase 4: Testing
1. Verificar que "Andor" aparece en múltiples canales
2. Verificar que no hay westerns chinos en canal western
3. Verificar que contenido está disponible en plataformas del usuario
4. Verificar que UI/EPG sigue funcionando igual

---

## 📊 Métricas de Validación

Después de implementar, verificar:

1. **Pool size:** ¿Cuántos items únicos en el pool? (objetivo: 500-1000)
2. **Coverage:** ¿Qué % de slots tienen contenido? (objetivo: 95%+)
3. **Multi-canal:** ¿Contenido premium aparece en múltiples canales? (objetivo: sí)
4. **Falsos positivos:** ¿Keywords problemáticas resueltas? (objetivo: 0 westerns chinos)
5. **Disponibilidad:** ¿Todo el contenido es accesible? (objetivo: 100%)

---



## 📺 CANALES TEMÁTICOS PERSONALIZADOS *LO MAS IMPORTANTE

Además de los canales de género y universos, el sistema debe soportar canales temáticos más complejos basados en patrones emocionales, narrativos y estéticos.

### 1️⃣ CANAL: MENTORES & TRANSFORMACIÓN

**ID:** `life-lessons`
**Nombre:** `🎓 Life Lessons`
**Icono:** `🎓`

**Propósito:** Historias de relaciones mentor/discípulo que transforman vidas.

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "10:00",
            "label": "Maestros de Música",
            "keywords": ["music teacher", "orchestra", "band", "choir"],
            "genres": [18],
            "themes": ["teacher", "mentor"]
        },
        {
            "start": "10:00",
            "end": "14:00",
            "label": "Entrenadores Deportivos",
            "keywords": ["coach", "training", "sports team"],
            "genres": [18],
            "vote_average_min": 7.0
        },
        {
            "start": "14:00",
            "end": "18:00",
            "label": "Académicos Inspiradores",
            "keywords": ["teacher", "professor", "school", "student"],
            "genres": [18],
            "exclude_keywords": ["horror", "thriller"]
        },
        {
            "start": "18:00",
            "end": "22:00",
            "label": "Mentores No-Tradicionales",
            "keywords": ["mentor", "guidance", "master", "sensei"],
            "custom_titles": ["Karate Kid", "Scent of a Woman", "Finding Forrester"]
        },
        {
            "start": "22:00",
            "end": "00:00",
            "label": "Premium Mentor Stories",
            "keywords": ["teacher", "mentor", "coach"],
            "vote_average_min": 7.5
        }
    ]
}
```

**Criterios de Detección Automática:**
- Keywords: `["teacher", "mentor", "coach", "professor", "master", "sensei", "guidance"]`
- Plot keywords: `["mentorship", "coming of age", "student teacher relationship"]`
- Géneros: Drama (18), pero NO horror/thriller
- Rating típico: 7.0+

---

### 2️⃣ CANAL: CARRERA ESPACIAL & PIONEROS

**ID:** `to-the-stars`
**Nombre:** `🌌 To The Stars`
**Icono:** `🌌`

**Propósito:** Historias de pioneros, exploradores espaciales, innovadores tecnológicos.

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "12:00",
            "label": "NASA Golden Age",
            "keywords": ["nasa", "apollo", "astronaut", "space program", "mercury"],
            "decade": [1980, 2030],
            "exclude_keywords": ["alien", "mars attack"]
        },
        {
            "start": "12:00",
            "end": "18:00",
            "label": "Tech Pioneers & Innovators",
            "keywords": ["inventor", "innovation", "engineer", "technology"],
            "genres": [18, 36],
            "biographical": true
        },
        {
            "start": "18:00",
            "end": "00:00",
            "label": "Science Underdogs",
            "keywords": ["rocket", "space", "observatory", "scientist"],
            "themes": ["underdog", "triumph"],
            "custom_titles": ["October Sky", "The Dish", "Contact", "Hidden Figures"]
        }
    ]
}
```

**Criterios de Detección:**
- Keywords: `["nasa", "astronaut", "space program", "rocket scientist", "engineer", "innovator"]`
- Géneros: Drama (18), History (36)
- NO sci-fi fiction (debe ser realista/histórico)
- Temática: triunfo del ingenio humano

---

### 3️⃣ CANAL: MUSICALES SIN VERGÜENZA

**ID:** `broadway-beyond`
**Nombre:** `🎵 Broadway & Beyond`
**Icono:** `🎵`

**Propósito:** Musicales bien hechos, desde clásicos hasta modernos.

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "10:00",
            "label": "Classic Hollywood Musicals",
            "genres": [10402],
            "decade": [1950, 1979],
            "vote_average_min": 7.5
        },
        {
            "start": "10:00",
            "end": "14:00",
            "label": "80s Nostalgia Musicals",
            "keywords": ["musical", "dance"],
            "decade": [1980, 1989],
            "custom_titles": ["Grease", "Flashdance", "Footloose", "Dirty Dancing"]
        },
        {
            "start": "14:00",
            "end": "18:00",
            "label": "Rock Biopics",
            "keywords": ["musician", "rock", "band", "singer"],
            "genres": [10402, 36],
            "biographical": true
        },
        {
            "start": "18:00",
            "end": "22:00",
            "label": "Modern Broadway",
            "genres": [10402],
            "decade": [2000, 2030],
            "custom_titles": ["Hamilton", "In the Heights", "Les Misérables"]
        },
        {
            "start": "22:00",
            "end": "00:00",
            "label": "Jukebox Done Right",
            "keywords": ["jukebox musical"],
            "custom_titles": ["Mamma Mia", "Across the Universe", "Sing Street"]
        }
    ]
}
```

**Criterios de Detección:**
- Género TMDB: Musical (10402)
- Keywords: `["musical", "broadway", "song and dance"]`
- Biopics musicales: género 36 (Biography) + keywords musicales

---

### 4️⃣ CANAL: DIRECTORES (Auteur Cinema)

**ID:** `auteurs`
**Nombre:** `🎬 Auteur Cinema`
**Icono:** `🎬`

**Propósito:** Ciclos semanales de directores específicos.

**Sistema de Rotación:**

```json
{
    "rotation_type": "weekly",
    "directors": [
        {
            "name": "Steven Spielberg",
            "tmdb_person_id": 488,
            "weeks": 2,
            "subcycles": ["Wonder", "Adventure", "History", "Popcorn"]
        },
        {
            "name": "Alfred Hitchcock",
            "tmdb_person_id": 2636,
            "weeks": 2,
            "sort": "chronological"
        },
        {
            "name": "Richard Donner",
            "tmdb_person_id": 13240,
            "weeks": 1
        },
        {
            "name": "Rob Reiner",
            "tmdb_person_id": 4884,
            "weeks": 1
        },
        {
            "name": "Martin Scorsese",
            "tmdb_person_id": 1032,
            "weeks": 2,
            "decade_filter": [1970, 1999]
        },
        {
            "name": "Christopher Nolan",
            "tmdb_person_id": 525,
            "weeks": 2
        },
        {
            "name": "Ridley Scott",
            "tmdb_person_id": 578,
            "weeks": 1
        },
        {
            "name": "John G. Avildsen",
            "tmdb_person_id": 88636,
            "weeks": 1,
            "note": "Rocky, Karate Kid"
        }
    ],
    "slots": [
        {
            "start": "00:00",
            "end": "08:00",
            "label": "Early Works"
        },
        {
            "start": "08:00",
            "end": "16:00",
            "label": "Classic Period"
        },
        {
            "start": "16:00",
            "end": "00:00",
            "label": "Masterpieces"
        }
    ]
}
```

**Criterios de Detección:**
- Query TMDB: `/person/{person_id}/movie_credits` y `/person/{person_id}/tv_credits`
- Filtrar por role: "Director"
- Ordenar cronológicamente o por rating

---

### 5️⃣ CANAL: AESTHETIC TIME MACHINES

**ID:** `vintage-vibes`
**Nombre:** `📼 Vintage Vibes`
**Icono:** `📼`

**Propósito:** Películas modernas con estética retro / Period pieces bien hechos.

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "12:00",
            "label": "70s Look, Modern Films",
            "keywords": ["period", "retro", "1970s"],
            "decade": [2000, 2030],
            "aesthetic_tags": ["grainy", "warm tones", "film grain"],
            "custom_titles": ["The Holdovers", "Once Upon a Time in Hollywood"]
        },
        {
            "start": "12:00",
            "end": "18:00",
            "label": "Neo-Noir",
            "keywords": ["neo-noir", "detective", "femme fatale"],
            "genres": [53, 80],
            "decade": [1980, 2030]
        },
        {
            "start": "18:00",
            "end": "22:00",
            "label": "Silent Era Homages",
            "keywords": ["silent film", "black and white"],
            "custom_titles": ["The Artist", "Hugo"]
        },
        {
            "start": "22:00",
            "end": "00:00",
            "label": "Period Pieces Done Right",
            "keywords": ["period", "costume drama"],
            "vote_average_min": 7.5,
            "decade": [1940, 1970]
        }
    ]
}
```

**Criterios de Detección:**
- Keywords: `["period", "retro", "vintage", "neo-noir", "black and white"]`
- Películas modernas (2000+) con keywords de épocas pasadas
- Period pieces históricos con ratings altos

**Nota Especial:** Este canal requiere análisis más manual/curatorial. Considerar agregar campo `aesthetic_tags` al ContentMetadata para casos como "The Holdovers" (moderna pero look 70s).

---

### 6️⃣ CANAL: GUILTY PLEASURES

**ID:** `cult-classics`
**Nombre:** `🍿 Cult Classics`
**Icono:** `🍿`

**Propósito:** Películas "malas" pero amadas, camp sincero, comfort movies incomprendidas.

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "12:00",
            "label": "Camp Sincero",
            "keywords": ["camp", "cult"],
            "custom_titles": ["Condorman", "Supergirl", "Flash Gordon"],
            "vote_average_range": [5.0, 6.5]
        },
        {
            "start": "12:00",
            "end": "18:00",
            "label": "80s Comfort Food",
            "decade": [1980, 1989],
            "genres": [10751, 12, 35],
            "custom_titles": ["Goonies", "Gremlins", "Batteries Not Included", "Honey I Shrunk the Kids"]
        },
        {
            "start": "18:00",
            "end": "00:00",
            "label": "So-Good-It's-Good",
            "keywords": ["action", "cult classic"],
            "decade": [1980, 1995],
            "custom_titles": ["Tango & Cash", "Commando", "Big Trouble in Little China"]
        }
    ]
}
```

**Criterios de Detección:**
- Rating moderado: 5.0-6.5 (no muy bajo, no muy alto)
- Keywords: `["camp", "cult classic", "cult film", "b-movie"]`
- Géneros: Family (10751), Adventure (12), Comedy (35)
- Décadas: 1980s principalmente
- **Override de rating:** Este canal IGNORA el vote_average alto

---

### 7️⃣ CANAL: MOOD MOVIES

**ID:** `mood-match`
**Nombre:** `🎭 Mood Match`
**Icono:** `🎭`

**Propósito:** Películas para estados emocionales específicos (contexto-driven).

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "10:00",
            "label": "Need Comfort",
            "mood": "comfort",
            "keywords": ["feel-good", "uplifting", "heartwarming"],
            "custom_titles": ["Defending Your Life", "Groundhog Day", "Chef"],
            "vote_average_min": 7.0
        },
        {
            "start": "10:00",
            "end": "14:00",
            "label": "Need Catharsis (Cry)",
            "mood": "cry",
            "keywords": ["emotional", "tearjerker", "moving"],
            "genres": [18],
            "custom_titles": ["Cinema Paradiso", "It's a Wonderful Life", "Field of Dreams"]
        },
        {
            "start": "14:00",
            "end": "18:00",
            "label": "Fuck The System",
            "mood": "angry",
            "keywords": ["rebellion", "underdog", "injustice"],
            "custom_titles": ["Rocky", "First Blood", "Network", "12 Angry Men"]
        },
        {
            "start": "18:00",
            "end": "00:00",
            "label": "Pure Joy",
            "mood": "happy",
            "keywords": ["comedy", "musical", "fun"],
            "genres": [35, 10402],
            "vote_average_min": 7.0
        }
    ]
}
```

**Criterios de Detección:**
- Keywords emocionales: `["feel-good", "uplifting", "heartwarming", "tearjerker", "emotional"]`
- Plot keywords específicos
- **User Input:** Este canal puede tener selector manual de mood en UI

---

### 8️⃣ CANAL: SEASONAL / CALENDAR

**ID:** `calendar-classics`
**Nombre:** `📅 Calendar Classics`
**Icono:** `📅`

**Propósito:** Contenido que matchea con fechas/estaciones del año.

**Sistema de Activación:**

```json
{
    "dynamic_activation": true,
    "seasons": [
        {
            "id": "christmas",
            "active_dates": ["12-01", "12-31"],
            "label": "Christmas Comfort",
            "keywords": ["christmas", "santa", "holiday"],
            "custom_titles": ["It's a Wonderful Life", "A Christmas Carol"]
        },
        {
            "id": "halloween",
            "active_dates": ["10-01", "10-31"],
            "label": "Halloween Horror",
            "genres": [27],
            "vote_average_min": 6.5
        },
        {
            "id": "summer",
            "active_dates": ["06-01", "08-31"],
            "label": "Summer Blockbusters",
            "genres": [28, 12],
            "keywords": ["adventure", "action"],
            "release_months": [5, 6, 7]
        },
        {
            "id": "hispanic-heritage",
            "active_dates": ["09-15", "10-15"],
            "label": "Hispanic Heritage Month",
            "origin_country": ["MX", "ES", "AR", "CO"],
            "vote_average_min": 7.0
        },
        {
            "id": "holy-week",
            "active_dates": ["2025-04-13", "2025-04-20"],
            "label": "Semana Santa",
            "keywords": ["bible", "jesus", "religious", "biblical"],
            "custom_titles": ["The Ten Commandments", "Ben-Hur"]
        }
    ]
}
```

**Criterios de Detección:**
- Date-based activation
- Keywords específicos de festividad
- Origin country para Hispanic Heritage
- Release months para "Summer Blockbusters"

---

### 9️⃣ CANAL: CINE DE ORO MEXICANO

**ID:** `epoca-oro`
**Nombre:** `🇲🇽 Época de Oro`
**Icono:** `🇲🇽`

**Propósito:** Cine clásico mexicano y latino.

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "10:00",
            "label": "Pedro Infante Romántico",
            "keywords": ["pedro infante"],
            "origin_country": ["MX"],
            "decade": [1940, 1959]
        },
        {
            "start": "10:00",
            "end": "14:00",
            "label": "Cantinflas Clásico",
            "keywords": ["cantinflas"],
            "origin_country": ["MX"],
            "decade": [1940, 1969]
        },
        {
            "start": "14:00",
            "end": "18:00",
            "label": "Época de Oro General",
            "origin_country": ["MX"],
            "decade": [1940, 1969],
            "vote_average_min": 7.0
        },
        {
            "start": "18:00",
            "end": "00:00",
            "label": "Cine Mexicano Moderno",
            "origin_country": ["MX"],
            "decade": [2000, 2030],
            "vote_average_min": 7.5
        }
    ]
}
```

**Criterios de Detección:**
- `production_countries`: "MX"
- Keywords de actores clásicos
- Década 1940-1969 para Época de Oro
- Moderna: 2000+ con rating alto

---

### 🔟 CANAL: EPIC MAXIMALISM (RRR DNA)

**ID:** `epic-maximalism`
**Nombre:** `🔥 Epic Maximalism`
**Icono:** `🔥`

**Propósito:** Películas con la esencia de RRR (épicas visuales + sinceridad + espectáculo).

**Subcategorías/Slots:**

```json
{
    "slots": [
        {
            "start": "06:00",
            "end": "12:00",
            "label": "Visual Epics",
            "keywords": ["epic", "spectacle", "grand scale"],
            "vote_average_min": 7.5,
            "custom_titles": ["Lawrence of Arabia", "Hero", "300", "Bahubali"]
        },
        {
            "start": "12:00",
            "end": "18:00",
            "label": "Bromance Action",
            "keywords": ["buddy", "friendship", "partnership"],
            "genres": [28],
            "custom_titles": ["Face/Off", "Lethal Weapon", "The Nice Guys"]
        },
        {
            "start": "18:00",
            "end": "22:00",
            "label": "Musical Combat",
            "keywords": ["dance", "battle", "choreography"],
            "genres": [28, 10402],
            "custom_titles": ["West Side Story", "Step Up"]
        },
        {
            "start": "22:00",
            "end": "00:00",
            "label": "Sincere Maximalism",
            "keywords": ["spectacle", "visual effects"],
            "themes": ["no-irony", "earnest"],
            "custom_titles": ["Speed Racer", "Jupiter Ascending", "Alita"]
        }
    ]
}
```

**Criterios de Detección:**
- Keywords: `["epic", "spectacle", "grand scale", "visual effects"]`
- Runtime: Típicamente >140 minutos
- Budget: Alto (si disponible en TMDB)
- **Anti-pattern:** Excluir si tiene keywords de ironía/parodia

---

## 🔧 Campos Nuevos para ContentMetadata

Para soportar estos canales temáticos, agregar a `ContentMetadata`:

```python
@dataclass
class ContentMetadata:
    # ... campos existentes ...
    
    # Nuevos campos
    director_id: Optional[int] = None
    director_name: Optional[str] = None
    
    origin_country: List[str] = field(default_factory=list)  # ["MX", "US"]
    
    biographical: bool = False  # Es biopic?
    
    themes: List[str] = field(default_factory=list)  # ["underdog", "rebellion"]
    
    mood_tags: List[str] = field(default_factory=list)  # ["feel-good", "tearjerker"]
    
    aesthetic_tags: List[str] = field(default_factory=list)  # ["retro-70s", "neo-noir"]
    
    runtime: Optional[int] = None  # Minutos (para épicas largas)
    
    release_month: Optional[int] = None  # 1-12 (para seasonal)
```

---

## 🎯 Sistema de Prioridad de Canales

Cuando el mismo contenido califica para múltiples canales:

```python
CHANNEL_PRIORITY = {
    "seasonal": 10,  # Máxima prioridad cuando activo
    "mood-match": 9,  # Si usuario selecciona mood
    "universes": 8,  # Star Wars, Marvel, etc.
    "auteurs": 7,  # Ciclos de directores
    "themed": 6,  # Mentores, Carrera Espacial, Musicales
    "aesthetic": 5,  # Time Machines, Epic Maximalism
    "genre": 4,  # Sci-Fi, Action, Comedy
    "guilty-pleasures": 3,  # Lowest priority
}
```

**Todos los canales activos muestran el contenido**, pero el orden en el EPG puede reflejar la prioridad.

---

## 🔧 Configuración de Plataformas del Usuario

**Archivo:** `config/providers.py` (crear o actualizar)

```python
USER_PLATFORMS_MX = {
    "Netflix": 8,
    "Amazon Prime Video": 119,
    "Disney Plus": 337,
    "HBO Max": 384,
    "Apple TV Plus": 350,
    "Paramount Plus": 531,
    "Pluto TV": 300,
    "Tubi TV": 283,
    "VIX": 457,
    "Plex": 538,
    "MUBI": 11,
    "MGM Plus Amazon Channel": 528,
    "YouTube Premium": 188,
    # Completar resto según IDs de TMDB
}

def get_user_provider_ids() -> str:
    """Retorna string pipe-separated de IDs para TMDB API"""
    return "|".join(map(str, USER_PLATFORMS_MX.values()))
```

---

## 📝 Notas Finales para el Agente

### ⚠️ Cosas a EVITAR:

1. **NO tracking de progreso de series** - Las plataformas ya lo hacen
2. **NO limitar series a un solo canal** - Pueden aparecer en todos los canales relevantes
3. **NO canales de plataformas específicas** - No importa dónde está, solo que está. El grid es crossplatform
4. **NO canales ultra-específicos** - "The Expanse Channel" es demasiado finito
5. **NO romper la UI existente** - El EPG grid debe seguir funcionando igual

### ✅ Cosas a PRIORIZAR:

1. **Matching multi-dimensional** - Contenido matchea por múltiples atributos
2. **Pool compartido** - Un solo pool para todos los canales
3. **Detección automática** - Universos detectados, no curados manualmente
4. **Cross-platform agnóstico** - Usuario no piensa en plataformas
5. **Canales generales infinitos** - Sci-Fi, Action, Comedy, no "The Expanse"

### 🎯 Objetivo Final:

El usuario abre MyStreamTV, ve el EPG con n canales, y:
-Ve distintas opciones adecuadas a sus gustos, y dependiendo de su intención, escoge lo que quiere ver sin importar en qué plataforma está, porque está filtrado solo lo que él tiene acceso.

---

## 🚦 Criterios de Aceptación

**La refactorización es exitosa cuando:**

1. ✅ Ejecuto la app y veo contenido en todos los canales
2. ✅ Series populares (Andor, The Expanse, etc.) aparecen en múltiples canales
3. ✅ No hay westerns chinos en canales que no los buscan
4. ✅ Todo el contenido mostrado está disponible en mis 18 plataformas
5. ✅ Los canales nunca están vacíos (siempre hay contenido que mostrar)
6. ✅ Puedo agregar un nuevo canal (ej: "Mentores") solo definiendo filtros
7. ✅ El UI/UX del EPG no cambió (backward compatible)

---

## 📞 Preguntas para Resolver Durante Implementación

Si durante la implementación encuentras estos escenarios, aquí está la guía:

**Q: ¿Qué hacer si el pool tiene +5000 items?**
A: Limitar a top 1000 por popularidad/rating. El pool se puede regenerar periódicamente.

**Q: ¿Qué hacer si un slot no tiene contenido elegible?**
A: Relajar filtros (ej: expandir década, bajar rating mínimo) O mostrar "Programming Coming Soon".

**Q: ¿Qué hacer si una keyword no retorna resultados?**
A: Log warning pero continuar. No fallar el canal completo por una keyword problemática.

**Q: ¿Caching del pool?**
A: Sí, cachear por 6-12 horas. Regenerar diariamente o bajo demanda.

**Q: ¿Qué hacer con contenido sin universo detectado?**
A: Está OK. Solo aparece en canales de género, década, etc. No todos necesitan universo.

---

Fin de especificación. ¡Buena suerte con la implementación! 🚀