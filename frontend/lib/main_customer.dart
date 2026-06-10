import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'core/theme/app_theme.dart';
import 'features/customer/home/customer_home_screen.dart';

/// 고객 앱 엔트리포인트
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const kakaoNativeKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  const kakaoJsKey = String.fromEnvironment('KAKAO_JS_APP_KEY');
  if (kakaoNativeKey.isNotEmpty) {
    KakaoSdk.init(
      nativeAppKey: kakaoNativeKey,
      javaScriptAppKey: kakaoJsKey.isNotEmpty ? kakaoJsKey : null,
    );
  }

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
