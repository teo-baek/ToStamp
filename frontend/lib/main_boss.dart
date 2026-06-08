import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/boss/agent/agent_screen.dart';
import 'features/boss/dashboard/dashboard_screen.dart';
import 'features/boss/scanner/scanner_screen.dart';
import 'features/boss/store_setup/store_setup_screen.dart';

/// 사장님 앱 엔트리포인트
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BossApp());
}

class BossApp extends StatelessWidget {
  const BossApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToStamp 사장님',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/setup',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/setup':
            return MaterialPageRoute(
              builder: (_) => const StoreSetupScreen(),
            );
          case '/dashboard':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => DashboardScreen(
                storeId: args?['id'] ?? '',
                storeName: args?['store_name'] ?? 'ToStamp',
              ),
            );
          case '/scanner':
            final storeId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => ScannerScreen(storeId: storeId),
            );
          case '/agent':
            final storeId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => AgentScreen(storeId: storeId),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const StoreSetupScreen(),
            );
        }
      },
    );
  }
}
