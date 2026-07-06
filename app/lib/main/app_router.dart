/// App router - handles navigation between screens

import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/room/room_select_screen.dart';
import '../screens/room/room_waiting_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/local_records/local_records_screen.dart';
import '../screens/chat/image_preview_screen.dart';
import '../screens/settings/passphrase_setup_screen.dart';
import '../screens/settings/passphrase_unlock_screen.dart';
import '../i18n/app_localizations.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  int _currentPage = 0;
  
  final List<Widget> _pages = const [
    RoomSelectScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentPage],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (index) => setState(() => _currentPage = index),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: AppLocalizations.of(context)!.rooms,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
      ),
    );
  }
}

/// Navigation helpers
class Nav {
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
  
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }
  
  static Future<T?> pushNamed<T>(BuildContext context, String route, {Object? arguments}) {
    return Navigator.pushNamed(context, route, arguments: arguments);
  }
  
  static void replaceWith(BuildContext context, Widget page) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }
}

/// Named routes
class Routes {
  static const splash = '/splash';
  static const roomSelect = '/room-select';
  static const roomWaiting = '/room-waiting';
  static const chat = '/chat';
  static const settings = '/settings';
  static const localRecords = '/local-records';
  static const imagePreview = '/image-preview';
  static const passphraseSetup = '/passphrase-setup';
  static const passphraseUnlock = '/passphrase-unlock';
}
