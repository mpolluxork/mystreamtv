# 🚀 Cómo Correr MyStreamTV

## Inicio Rápido

### Windows

#### Opción 1: Script Automático (Recomendado)
```powershell
# PowerShell
.\start_server.ps1

# O usando CMD
start_server.bat
```

#### Opción 2: Manual
```powershell
cd backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Linux

#### Opción 1: Script Automático (Recomendado)
```bash
./start_server.sh
```

#### Opción 2: Manual
```bash
cd backend
source venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 🔧 Configuración Inicial

### Primera vez en un nuevo ambiente

**Windows:**
```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r requirements.txt
```

**Linux:**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

> ⚠️ **IMPORTANTE**: Los entornos virtuales (`venv/`, `.venv/`) están en `.gitignore` y NO se sincronizan entre ambientes. Debes crear el entorno virtual en cada máquina donde trabajes.

---

## 📱 Acceso desde Otros Dispositivos

Tu servidor estará disponible en tu red local.

### Desde cualquier dispositivo en tu red WiFi:

1. **EPG Principal**: 
   - `http://<TU_IP>:8000`
   - Abre en navegador de celular, tablet, o smart TV

2. **Admin Console**: 
   - `http://<TU_IP>:8000/admin.html`
   - Para editar canales y configuración

**Para encontrar tu IP:**
- Windows: `ipconfig` (busca IPv4 Address)
- Linux: `hostname -I` o `ip addr`

---

## 🎮 Controles del EPG

- **Flechas ←→**: Navegar entre canales
- **Flechas ↑↓**: Scroll horizontal en la programación
- **Click**: Ver detalles del programa
- **Botón "Sintonizar"**: Abrir en plataforma de streaming

---

## 🔧 Troubleshooting

### El servidor no inicia

**Windows:**
```powershell
# Verificar que el puerto 8000 esté libre
netstat -ano | findstr :8000

# Si está ocupado, matar el proceso (reemplaza PID)
taskkill /PID <PID> /F
```

**Linux:**
```bash
# Verificar que el puerto 8000 esté libre
lsof -i :8000

# Si está ocupado, matar el proceso
kill -9 <PID>
```

### Error: "Unable to create process using..."

Este error ocurre cuando el entorno virtual tiene rutas antiguas. **Solución:**

```powershell
# Windows
cd backend
Remove-Item -Path "venv" -Recurse -Force
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

```bash
# Linux
cd backend
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### No puedo acceder desde otro dispositivo

1. Verifica que ambos dispositivos estén en la misma red WiFi
2. Verifica el firewall:
   
   **Windows:**
   ```powershell
   # Permitir puerto 8000 en el firewall
   New-NetFirewallRule -DisplayName "MyStreamTV" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
   ```
   
   **Linux:**
   ```bash
   sudo ufw allow 8000/tcp
   ```

3. Verifica tu IP actual (ver sección "Acceso desde Otros Dispositivos")

### Error de TMDB API

- Verifica que `secrets.ini` tenga tu API key válida
- El archivo debe estar en la raíz del proyecto: `mystreamtv/secrets.ini`
- Usa `secrets.ini.example` como referencia

---

## 📊 Logs y Debugging

El servidor muestra logs en tiempo real:
- ✅ Pool expansion
- 🔍 Content discovery
- ⚠️ Slots vacíos
- 📝 Cooldown tracking

---

## 🛑 Detener el Servidor

Presiona `Ctrl+C` en la terminal donde corre el servidor.

---

## 🔄 Trabajando en Múltiples Ambientes

### Sincronización con Git

```bash
# Antes de hacer push
git add .
git commit -m "Tu mensaje"
git push

# En el otro ambiente
git pull
```

### Recordatorios Importantes

1. **NO** sincronices los entornos virtuales (ya están en `.gitignore`)
2. **SÍ** sincroniza:
   - Código fuente (`backend/`, `frontend/`)
   - Archivos de configuración (`requirements.txt`, etc.)
   - Datos (`data/` si es necesario)
3. Después de hacer `git pull`, verifica si `requirements.txt` cambió:
   ```bash
   pip install -r requirements.txt
   ```

---

## 🎯 Próximos Pasos

1. **Probar el EPG**: Abre `http://localhost:8000` en tu navegador
2. **Verificar canales**: Deberías ver los canales configurados
3. **Revisar admin**: Abre `http://localhost:8000/admin.html`
4. **Implementar features pendientes**:
   - Auto-generación de slots
   - Canal de favoritos
