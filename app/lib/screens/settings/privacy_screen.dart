/// Privacy and security information screen

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          l10n.privacy,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined, size: 48, color: AppTheme.primaryColor),
                    const SizedBox(height: 12),
                    Text(
                      l10n.privacyTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Privacy points
              _PrivacyPoint(
                icon: Icons.no_accounts,
                title: 'No Registration Required',
                description: l10n.privacyIntro1,
              ),
              _PrivacyPoint(
                icon: Icons.person_off,
                title: 'No Personal Data Collected',
                description: l10n.privacyIntro2,
              ),
              _PrivacyPoint(
                icon: Icons.visibility_off,
                title: 'Server Cannot See Content',
                description: l10n.privacyIntro3,
              ),
              _PrivacyPoint(
                icon: Icons.lock_outline,
                title: 'Pre-Send Encryption',
                description: l10n.privacyIntro4,
              ),
              _PrivacyPoint(
                icon: Icons.hourglass_top,
                title: '7-Day Max Retention',
                description: l10n.privacyIntro5,
              ),
              _PrivacyPoint(
                icon: Icons.delete_sweep,
                title: 'Auto-Delete on Exit',
                description: l10n.privacyIntro6,
              ),
              _PrivacyPoint(
                icon: Icons.device_hub,
                title: 'Local Storage Only',
                description: l10n.privacyIntro7,
              ),
              _PrivacyPoint(
                icon: Icons.warning_amber_rounded,
                title: 'Irreversible Encryption',
                description: l10n.privacyIntro8,
              ),
              
              const SizedBox(height: 32),
              
              // Platform limitations
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.orange : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Platform Limitations',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'iOS: Cannot fully prevent screenshots. App detects and notifies.\n\n'
                      'Android: FLAG_SECURE prevents screenshots and screen recording.\n\n'
                      'Windows: Best-effort protection. System limitations apply.\n\n'
                      'All platforms: Anti-screenshot measures are best-effort only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Encryption info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.green : Colors.green).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Encryption Standards',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• X25519 Key Exchange\n'
                      '• AES-256-GCM / ChaCha20-Poly1305\n'
                      '• HKDF Key Derivation\n'
                      '• PBKDF2 (100,000 iterations)\n'
                      '• Unique nonce per message\n'
                      '• Chunked file encryption',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.description,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
