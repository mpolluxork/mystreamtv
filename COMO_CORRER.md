# 🚀 Cómo Correr MyStreamTV

## Inicio Rápido

### Opción 1: Script Automático (Recomendado)
```bash
cd /home/mpollux/antigravity/mystreamtv
./start_server.sh
```

### Opción 2: Manual
```bash
cd /home/mpollux/antigravity/mystreamtv
source venv/bin/activate
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 📱 Acceso desde Otros Dispositivos

Tu servidor estará disponible en:

**IP Local**: `http://192.168.0.217:8000`

### Desde cualquier dispositivo en tu red WiFi:

1. **EPG Principal**: 
   - `http://192.168.0.217:8000`
   - Abre en navegador de celular, tablet, o smart TV

2. **Admin Console**: 
   - `http://192.168.0.217:8000/admin.html`
   - Para editar canales y configuración

---

## 🎮 Controles del EPG

- **Flechas ←→**: Navegar entre canales
- **Flechas ↑↓**: Scroll horizontal en la programación
- **Click**: Ver detalles del programa
- **Botón "Sintonizar"**: Abrir en plataforma de streaming

---

## 🔧 Troubleshooting

### El servidor no inicia
```bash
# Verificar que el puerto 8000 esté libre
lsof -i :8000

# Si está ocupado, matar el proceso
kill -9 <PID>
```

### No puedo acceder desde otro dispositivo
1. Verifica que ambos dispositivos estén en la misma red WiFi
2. Verifica el firewall:
   ```bash
   sudo ufw allow 8000/tcp
   ```
3. Verifica tu IP actual:
   ```bash
   hostname -I
   ```

### Error de TMDB API
- Verifica que `secrets.ini` tenga tu API key válida
- Path: `/home/mpollux/antigravity/mystreamtv/secrets.ini`

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

## 🎯 Próximos Pasos

1. **Probar el EPG**: Abre `http://192.168.0.217:8000` en tu navegador
2. **Verificar canales**: Deberías ver los 18 canales simultáneamente
3. **Revisar admin**: Abre `http://192.168.0.217:8000/admin.html`
4. **Implementar features pendientes**:
   - Auto-generación de slots
   - Canal de favoritos
