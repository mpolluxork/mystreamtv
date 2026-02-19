import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/server_config.dart';
import '../core/api_service.dart';

/// Shown on first launch (or when no server is configured).
/// Asks the user for the backend IP and validates the connection.
class ServerSetupScreen extends StatefulWidget {
  final VoidCallback onConnected;
  const ServerSetupScreen({super.key, required this.onConnected});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _controller = TextEditingController(text: '192.168.1.');
  final _focusNode = FocusNode();
  bool _testing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Escribe la IP o dirección del servidor');
      return;
    }

    setState(() { _testing = true; _error = null; });

    // Normalize URL
    var url = input;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.port == 0) {
      url = '${url.trimRight().replaceAll(RegExp(r'/+$'), '')}:8000';
    }

    final ok = await ApiService.checkHealth(url);

    if (!mounted) return;

    if (ok) {
      await ServerConfig.save(url);
      widget.onConnected();
    } else {
      setState(() {
        _testing = false;
        _error = 'No se pudo conectar a $url\n'
            'Verifica que el servidor esté corriendo y la IP sea correcta.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tv = isTV(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: tv ? 600 : double.infinity,
            padding: EdgeInsets.all(tv ? 48 : 24),
            margin: EdgeInsets.all(tv ? 0 : 24),
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kBorderColor),
              boxShadow: [
                BoxShadow(
                  color: kAccentColor.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo / title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kAccentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('📺', style: TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MyStreamTV',
                          style: TextStyle(
                            color: kTextPrimary,
                            fontSize: tv ? 28 : 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Primera configuración',
                          style: TextStyle(
                            color: kAccentColor,
                            fontSize: tv ? 16 : 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                Text(
                  'Dirección del servidor',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: tv ? 18 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Escribe la IP de la computadora donde corre el backend de MyStreamTV.',
                  style: TextStyle(
                    color: kTextDim,
                    fontSize: tv ? 15 : 12,
                  ),
                ),
                const SizedBox(height: 16),

                // IP input
                KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      _connect();
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: tv ? 20 : 16,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: '192.168.1.50  o  192.168.1.50:8000',
                      hintStyle: TextStyle(color: kTextDim, fontSize: tv ? 16 : 13),
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: tv ? 20 : 14,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _connect(),
                  ),
                ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: tv ? 15 : 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Connect button
                SizedBox(
                  width: double.infinity,
                  height: tv ? 60 : 48,
                  child: ElevatedButton.icon(
                    onPressed: _testing ? null : _connect,
                    icon: _testing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.wifi_rounded),
                    label: Text(
                      _testing ? 'Conectando...' : 'Conectar',
                      style: TextStyle(
                        fontSize: tv ? 18 : 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Hint
                Text(
                  '💡 Tip: El servidor debe estar corriendo con:\n'
                  '   uvicorn main:app --host 0.0.0.0 --port 8000',
                  style: TextStyle(
                    color: kTextDim,
                    fontSize: tv ? 14 : 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
