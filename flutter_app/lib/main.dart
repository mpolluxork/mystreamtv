// MyStreamTV Flutter App - Main entry point
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/server_config.dart';
import 'providers/epg_provider.dart';
import 'providers/focus_provider.dart';
import 'screens/server_setup_screen.dart';
import 'screens/epg_screen.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.init();
  runApp(const MyStreamTVApp());
}

class MyStreamTVApp extends StatelessWidget {
  const MyStreamTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EpgProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
      ],
      child: MaterialApp(
        title: 'MyStreamTV',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: kAccentColor,
            surface: kSurfaceColor,
          ),
          scaffoldBackgroundColor: kBackgroundColor,
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        home: const AppRouter(),
      ),
    );
  }
}

/// Routes to setup screen or EPG depending on whether server is configured.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  Widget build(BuildContext context) {
    final hasServer = ServerConfig.baseUrl != null;
    if (hasServer) {
      return const EpgScreen();
    } else {
      return ServerSetupScreen(
        onConnected: () => setState(() {}),
      );
    }
  }
}
