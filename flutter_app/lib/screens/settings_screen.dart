import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/server_config.dart';
import '../core/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _controller;
  bool _testing = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ServerConfig.baseUrl ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() { _message = 'La URL no puede estar vacía'; _messageIsError = true; });
      return;
    }
    setState(() { _testing = true; _message = null; });

    var url = input;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null && !uri.hasPort) {
      url = '${url.trimRight().replaceAll(RegExp(r'/+$'), '')}:8000';
    }

    final ok = await ApiService.checkHealth(url);
    if (!mounted) return;

    if (ok) {
      await ServerConfig.save(url);
      setState(() {
        _testing = false;
        _message = '✅ Conectado correctamente a $url';
        _messageIsError = false;
        _controller.text = url;
      });
    } else {
      setState(() {
        _testing = false;
        _message = '❌ No se pudo conectar a $url';
        _messageIsError = true;
      });
    }
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurfaceColor,
        title: const Text('¿Borrar configuración?',
            style: TextStyle(color: kTextPrimary)),
        content: const Text(
          'Se borrará la URL del servidor. La próxima vez que abras la app tendrás que configurarla de nuevo.',
          style: TextStyle(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ServerConfig.clear();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTV(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        foregroundColor: kTextPrimary,
        title: const Text('⚙️  Configuración'),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: tv ? 600 : double.infinity,
          padding: EdgeInsets.all(tv ? 40 : 24),
          margin: EdgeInsets.all(tv ? 0 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Servidor backend',
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: tv ? 20 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'IP o dirección de la computadora donde corre MyStreamTV.',
                style: TextStyle(color: kTextDim, fontSize: tv ? 15 : 12),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _controller,
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: tv ? 18 : 15,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: '192.168.1.50:8000',
                  hintStyle: TextStyle(color: kTextDim),
                  prefixIcon: Icon(Icons.dns_rounded, color: kAccentColor),
                  filled: true,
                  fillColor: kCardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kAccentColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: kBorderColor),
                  ),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _save(),
              ),

              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_messageIsError ? Colors.red : Colors.green)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_messageIsError ? Colors.red : Colors.green)
                          .withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _messageIsError ? Colors.redAccent : Colors.greenAccent,
                      fontSize: tv ? 14 : 12,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _testing ? null : _save,
                      icon: _testing
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_testing ? 'Probando...' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: tv ? 16 : 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent),
                    label: const Text('Borrar',
                        style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: EdgeInsets.symmetric(
                          vertical: tv ? 16 : 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Divider(color: kBorderColor),
              const SizedBox(height: 16),

              Text(
                '💡 Tip: Inicia el servidor con:\n'
                '   uvicorn main:app --host 0.0.0.0 --port 8000\n\n'
                '   El flag --host 0.0.0.0 es necesario para que\n'
                '   otros dispositivos en la red puedan conectarse.',
                style: TextStyle(
                  color: kTextDim,
                  fontSize: tv ? 13 : 11,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
