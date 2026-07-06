/// Room creation screen

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_theme.dart';
import '../../main/app_router.dart';
import '../../services/crypto_service.dart';
import 'room_waiting_screen.dart';

class RoomCreateScreen extends StatefulWidget {
  const RoomCreateScreen({super.key});

  @override
  State<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends State<RoomCreateScreen> {
  bool _creating = false;
  final CryptoService _crypto = CryptoService();
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87),
          onPressed: () => Nav.pop(context),
        ),
        title: Text(
          l10n.createRoom,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.createRoom,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Creating an encrypted room...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),
                
                if (_creating)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _createRoom,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(l10n.create),
                  ),
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Nav.pop(context),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> _createRoom() async {
    setState(() => _creating = true);
    
    // Simulate room creation delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      final roomCode = _crypto.generateRoomCode();
      final roomSecret = _crypto.generateRoomSecret();
      
      Nav.push(context, RoomWaitingScreen(
        roomCode: roomCode,
        roomSecret: roomSecret,
      ));
    }
  }
}
