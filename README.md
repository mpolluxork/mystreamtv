# MyStreamTV - EPG-Style Streaming Guide

🚀 **Elimina la parálisis de decisión en streaming con una guía de programación estilo 90s**

Una aplicación web que simula la experiencia de una guía de programación electrónica (EPG) clásica, pero para contenido de Netflix, Disney+, HBO Max y Prime Video disponible en México.

![EPG Style](https://via.placeholder.com/800x400/1a1a2e/00d9ff?text=MyStreamTV+EPG)

## ✨ Características

- **Programación Temática por Canal**:
  - 🚀 Sci-Fi (Marcianos, Viajes en el Tiempo, Clásicos)
  - 🕵️ Espías (James Bond, Guerra Fría, Infiltrados)
  - 🏆 Oscares (Dramas Aclamados, Biografías)
  - 😂 Comedia (Romántica, Parodias, Familiar)
  - 👻 Terror (Slashers, Psicológico, Clásicos)
  - 💥 Acción (Artes Marciales, Superhéroes, 80s-90s)
  - 🎬 Familiar (Animación, Pixar, Aventuras)

- **Estética EPG Vintage**: Diseño inspirado en guías de cable de los 90s con efecto scanlines CRT
- **Navegación de Teclado**: 100% compatible con controles de Smart TV (flechas + Enter)
- **Posters HD de Fondo**: Al enfocar un programa, se muestra su backdrop de TMDB. En cada casilla del grid se muestra el thumbnail de la película.
- **Botón "Sintonizar"**: Deep links directos a Netflix, Disney+, HBO Max, Prime Video

## 🛠️ Tech Stack

- **Backend**: Python 3.11+ · FastAPI · httpx
- **Frontend**: HTML · CSS · JavaScript (Vanilla)
- **Data**: TMDB API (filtrado por región México)

## 🚀 Quick Start

```bash
cd mystreamtv/backend

# Crear entorno virtual
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt

# Iniciar servidor (sirve tanto API como frontend)
uvicorn main:app --reload --port 8000
```

Abre http://localhost:8000 en tu navegador.

> **Nota**: El backend de FastAPI sirve automáticamente los archivos estáticos del frontend (HTML/CSS/JS). No necesitas Node.js ni npm.

## 🎮 Controles

| Tecla | Acción |
|-------|--------|
| ← → | Navegar entre programas |
| ↑ ↓ | Navegar entre canales |
| Enter | Ver detalles / Sintonizar |
| Esc | Cerrar modal |

## 📁 Estructura del Proyecto

```
mystreamtv/
├── backend/
│   ├── main.py              # FastAPI app
│   ├── config.py            # Configuración TMDB
│   ├── services/
│   │   ├── tmdb_client.py   # Cliente TMDB
│   │   └── schedule_engine.py  # Motor de programación
│   ├── models/
│   │   └── models.py        # Dataclasses
│   └── routers/
│       └── epg.py           # Endpoints API
├── frontend/
│   ├── index.html           # Página principal
│   ├── app.js               # Lógica de la aplicación
│   └── styles.css           # Estilos EPG vintage
├── data/
│   └── channel_templates.json  # Definición de canales
└── secrets.ini              # API key TMDB
```

## 🔌 API Endpoints

| Endpoint | Descripción |
|----------|-------------|
| `GET /api/epg/channels` | Lista de canales |
| `GET /api/epg/guide?hours=6` | Guía de programación |
| `GET /api/epg/now-playing` | Lo que está al aire ahora |
| `GET /api/epg/program/{id}/providers` | Plataformas de streaming |

## 🎨 Personalización

Edita `data/channel_templates.json` para modificar:
- Horarios de los slots
- Géneros y décadas por slot
- Palabras clave de búsqueda
- Iconos y nombres de canales

## 📝 Roadmap

- [ ] Parser de listas Letterboxd para personalización
- [ ] Objetos de relleno (trailers, bumpers)
- [ ] Canales de deportes en vivo
- [ ] Modo teatro (autoplay continuo)
