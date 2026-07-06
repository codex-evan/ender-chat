/// Settings screen

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_theme.dart';
import '../../main/app_router.dart';
import 'privacy_screen.dart';
import '../local_records/local_records_screen.dart';
import 'passphrase_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _allowCopying = true;
  String _language = 'en';
  
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
          l10n.settings,
          style: theme.textTheme.titleLarge?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: false,
        iconTheme: IconThemeData(color: isDark ? Colors.white70 : Colors.black87),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Appearance section
            _SectionTitle(title: l10n.appearance),
            const SizedBox(height: 8),
            _SettingsCard(
              items: [
                _SettingsTile(
                  title: l10n.systemTheme,
                  leading: Icons.brightness_auto,
                  trailing: DropdownButton<ThemeMode>(
                    value: _themeMode,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.systemTheme)),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.lightMode)),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.darkMode)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _themeMode = value);
                    },
                  ),
                ),
                _SettingsTile(
                  title: l10n.language,
                  leading: Icons.language,
                  trailing: DropdownButton<String>(
                    value: _language,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'zh', child: Text('中文')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _language = value);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Security section
            _SectionTitle(title: l10n.securitySettings),
            const SizedBox(height: 8),
            _SettingsCard(
              items: [
                _SettingsTile(
                  title: l10n.allowCopying,
                  subtitle: 'Allow messages to be copied',
                  leading: Icons.copy,
                  trailing: Switch(
                    value: _allowCopying,
                    onChanged: (v) => setState(() => _allowCopying = v),
                  ),
                ),
                _SettingsTile(
                  title: l10n.antiScreenshot,
                  subtitle: 'Detect and blur on screen capture',
                  leading: Icons.visibility_off,
                  onTap: () {},
                ),
                _SettingsTile(
                  title: l10n.setupPassphrase,
                  subtitle: 'Encrypt local chat history',
                  leading: Icons.key,
                  onTap: () {
                    Nav.push(context, const PassphraseSetupScreen());
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Storage section
            _SectionTitle(title: l10n.localStorage),
            const SizedBox(height: 8),
            _SettingsCard(
              items: [
                _SettingsTile(
                  title: l10n.manageSavedChats,
                  leading: Icons.folder_outlined,
                  onTap: () {
                    Nav.push(context, const LocalRecordsScreen());
                  },
                ),
                _SettingsTile(
                  title: l10n.clearCache,
                  subtitle: 'Clear all cached data',
                  leading: Icons.cleaning_services,
                  onTap: _showClearCacheDialog,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // About section
            _SectionTitle(title: l10n.about),
            const SizedBox(height: 8),
            _SettingsCard(
              items: [
                _SettingsTile(
                  title: l10n.privacyPolicy,
                  leading: Icons.shield_outlined,
                  onTap: () {
                    Nav.push(context, const PrivacyScreen());
                  },
                ),
                _SettingsTile(
                  title: l10n.version,
                  subtitle: '1.0.0',
                  leading: Icons.info_outline,
                  onTap: () {},
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Privacy button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Nav.push(context, const PrivacyScreen());
                },
                icon: Icon(Icons.lock_outline, color: AppTheme._primaryColor),
                label: Text(l10n.privacy, style: TextStyle(color: AppTheme._primaryColor)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme._primaryColor.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showClearCacheDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearCache),
        content: Text(l10n.clearCacheConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear cache logic
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.clearCache),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  
  const _SectionTitle({required this.title});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: isDark ? Colors.white54 : Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> items;
  
  const _SettingsCard({required this.items});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: items.toList(),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  
  const _SettingsTile({
    required this.title,
    this.subtitle,
    required this.leading,
    this.trailing,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(leading, size: 22, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                  )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black54,
                    )),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }
}
