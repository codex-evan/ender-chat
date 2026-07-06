/// Application services locator / dependency injection
/// 
/// Centralizes initialization of all core services.

import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../services/ws_service.dart';
import '../services/storage_service.dart';

class AppLocator extends ChangeNotifier {
  static late final CryptoService cryptoService;
  static late final WsService wsService;
  static late final StorageService storageService;
  
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static Future<void> init() async {
    cryptoService = CryptoService();
    await cryptoService.init();
    
    storageService = StorageService();
    await storageService.init();
    
    wsService = WsService(
      cryptoService: cryptoService,
      storageService: storageService,
    );
    await wsService.init();
  }
}
