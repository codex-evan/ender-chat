/// Room selection screen - create or join

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_theme.dart';
import '../../main/app_router.dart';
import 'room_create_screen.dart';
import 'room_join_screen.dart';

class RoomSelectScreen extends StatelessWidget {
  const RoomSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 96,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 32),
                Text(
                  'EncChat',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anonymous End-to-End Encrypted Chat',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                FilledButton.icon(
                  onPressed: () => Nav.push(context, const RoomCreateScreen()),
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.createRoom),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () => Nav.push(context, const RoomJoinScreen()),
                  icon: const Icon(Icons.login),
                  label: Text(l10n.joinRoom),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),

                const SizedBox(height: 48),

                Text(
                  'No accounts. No tracking. No server-side decryption.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
