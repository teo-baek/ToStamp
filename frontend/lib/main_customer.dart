import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/customer/home/customer_home_screen.dart';

/// 고객 앱 엔트리포인트
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToStamp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const CustomerHomeScreen(),
    );
  }
}
