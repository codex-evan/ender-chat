/// Main entry point for the Encrypted Chat app.
/// 
/// This app implements end-to-end encryption for anonymous messaging.
/// No user accounts, phone numbers, emails, or personal data are collected.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'main/app_locator.dart';
import 'main/app_router.dart';
import 'main/app_theme.dart';
import 'i18n/app_localizations.dart';
import 'services/crypto_service.dart';
import 'services/ws_service.dart';
import 'services/storage_service.dart';
import 'utils/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await AppLocator.init();
  
  // Auto-connect to server
  AppLocator.wsService.connect(AppConfig.serverUrl);
  
  runApp(const EncChatApp());
}

class EncChatApp extends StatelessWidget {
  const EncChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: AppLocator.cryptoService),
        ChangeNotifierProvider.value(value: AppLocator.wsService),
        Provider.value(value: AppLocator.storageService),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        
        // Theme
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        
        // Localizations
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
        ],
        
        // Router
        home: const AppRouter(),
      ),
    );
  }
}
