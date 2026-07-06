/// Passphrase setup screen

import 'package:flutter/material.dart';
import '../../i18n/app_localizations.dart';
import '../../main/app_router.dart';

class PassphraseSetupScreen extends StatefulWidget {
  const PassphraseSetupScreen({super.key});

  @override
  State<PassphraseSetupScreen> createState() => _PassphraseSetupScreenState();
}

class _PassphraseSetupScreenState extends State<PassphraseSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassphrase = true;
  bool _confirmObscure = true;
  
  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
  
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
          l10n.setupPassphrase,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Warning card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.orange : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.passphraseWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  l10n.setupPassphraseDesc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Passphrase input
                TextFormField(
                  controller: _passphraseController,
                  obscureText: _obscurePassphrase,
                  decoration: InputDecoration(
                    labelText: l10n.passphrase,
                    hintText: l10n.passphraseHint,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassphrase ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassphrase = !_obscurePassphrase),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 4) {
                      return 'Passphrase must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Confirm passphrase
                TextFormField(
                  controller: _confirmController,
                  obscureText: _confirmObscure,
                  decoration: InputDecoration(
                    labelText: l10n.passphraseConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(_confirmObscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _confirmObscure = !_confirmObscure),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passphraseController.text) {
                      return 'Passphrases do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Save passphrase-derived key locally
                      Nav.pop(context, _passphraseController.text);
                    }
                  },
                  child: Text(l10n.setupPassphrase),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
