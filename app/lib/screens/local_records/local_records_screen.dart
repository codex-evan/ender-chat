/// Local records management screen

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_router.dart';
import '../settings/passphrase_unlock_screen.dart';

class LocalRecordsScreen extends StatelessWidget {
  const LocalRecordsScreen({super.key});

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
        title: Text(
          l10n.localRecords,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 16),
                Text(
                  l10n.noLocalRecords,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.localRecordsDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
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
